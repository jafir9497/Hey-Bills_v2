import 'dart:io';

import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/app_error.dart';
import '../../../core/network/supabase_service.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/models/receipt_model.dart';
import '../models/receipt_ocr_data.dart';
import 'ocr_service.dart';

class ReceiptService {
  static final Logger _logger = Logger();
  static const _uuid = Uuid();

  /// Get all receipts for current user
  static Future<List<Receipt>> getUserReceipts({
    int? limit,
    int? offset,
    String? category,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw AuthenticationError.notAuthenticated();
      }

      _logger.i('Fetching receipts for user: $userId');

      var query = supabase
          .from('receipts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // Apply filters
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'merchant_name.ilike.%$searchQuery%,'
          'category.ilike.%$searchQuery%',
        );
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 20) - 1);
      }

      final response = await query;
      
      final receipts = (response as List)
          .map((json) => Receipt.fromJson(json))
          .toList();

      _logger.i('Fetched ${receipts.length} receipts');
      return receipts;
    } catch (e) {
      _logger.e('Failed to fetch receipts: $e');
      
      if (e is AppError) {
        rethrow;
      }
      
      throw DatabaseError.queryFailed();
    }
  }

  /// Get receipt by ID
  static Future<Receipt?> getReceipt(String receiptId) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw AuthenticationError.notAuthenticated();
      }

      _logger.i('Fetching receipt: $receiptId');

      final response = await supabase
          .from('receipts')
          .select()
          .eq('id', receiptId)
          .eq('user_id', userId)
          .single();

      final receipt = Receipt.fromJson(response);
      _logger.i('Fetched receipt: ${receipt.merchantName}');
      return receipt;
    } catch (e) {
      _logger.e('Failed to fetch receipt: $e');
      
      if (e.toString().contains('Multiple rows returned') ||
          e.toString().contains('No rows returned')) {
        return null;
      }
      
      if (e is AppError) {
        rethrow;
      }
      
      throw DatabaseError.queryFailed();
    }
  }

  /// Create new receipt with image processing
  static Future<Receipt> createReceipt({
    required String imagePath,
    String? merchantName,
    double? totalAmount,
    String? category,
    DateTime? date,
  }) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw AuthenticationError.notAuthenticated();
      }

      _logger.i('Creating receipt for user: $userId');

      // Process image with OCR if no manual data provided
      ReceiptOCRData? ocrData;
      if (merchantName == null || totalAmount == null) {
        ocrData = await OCRService.processReceiptImage(imagePath: imagePath);
      }

      // Upload image to storage
      final imageUrl = await _uploadReceiptImage(imagePath, userId);

      // Prepare receipt data
      final receiptData = ReceiptCreate(
        userId: userId,
        imageUrl: imageUrl,
        merchantName: merchantName ?? ocrData?.merchantName ?? 'Unknown',
        totalAmount: totalAmount ?? ocrData?.totalAmount ?? 0.0,
        category: category ?? ocrData?.category ?? 'Other',
        ocrData: ocrData?.toJson(),
      );

      // Save to database
      final response = await supabase
          .from('receipts')
          .insert(receiptData.toJson())
          .select()
          .single();

      final receipt = Receipt.fromJson(response);
      _logger.i('Created receipt: ${receipt.id}');
      return receipt;
    } catch (e) {
      _logger.e('Failed to create receipt: $e');
      
      if (e is AppError) {
        rethrow;
      }
      
      throw DatabaseError.insertFailed();
    }
  }

  /// Update existing receipt
  static Future<Receipt> updateReceipt({
    required String receiptId,
    String? merchantName,
    double? totalAmount,
    String? category,
    Map<String, dynamic>? ocrData,
  }) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw AuthenticationError.notAuthenticated();
      }

      _logger.i('Updating receipt: $receiptId');

      final updateData = <String, dynamic>{};
      
      if (merchantName != null) updateData['merchant_name'] = merchantName;
      if (totalAmount != null) updateData['total_amount'] = totalAmount;
      if (category != null) updateData['category'] = category;
      if (ocrData != null) updateData['ocr_data'] = ocrData;
      
      updateData['updated_at'] = DateTime.now().toIso8601String();

      final response = await supabase
          .from('receipts')
          .update(updateData)
          .eq('id', receiptId)
          .eq('user_id', userId)
          .select()
          .single();

      final receipt = Receipt.fromJson(response);
      _logger.i('Updated receipt: ${receipt.merchantName}');
      return receipt;
    } catch (e) {
      _logger.e('Failed to update receipt: $e');
      
      if (e is AppError) {
        rethrow;
      }
      
      throw DatabaseError.updateFailed();
    }
  }

  /// Delete receipt
  static Future<void> deleteReceipt(String receiptId) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw AuthenticationError.notAuthenticated();
      }

      _logger.i('Deleting receipt: $receiptId');

      // Get receipt to access image URL for cleanup
      final receipt = await getReceipt(receiptId);
      
      // Delete from database
      await supabase
          .from('receipts')
          .delete()
          .eq('id', receiptId)
          .eq('user_id', userId);

      // Clean up image from storage
      if (receipt != null && receipt.imageUrl.isNotEmpty) {
        try {
          final uri = Uri.parse(receipt.imageUrl);
          final imagePath = uri.pathSegments.last;
          await SupabaseService.deleteFile(
            bucket: AppConstants.receiptsBucket,
            path: 'receipts/$userId/$imagePath',
          );
        } catch (e) {
          _logger.w('Failed to delete receipt image: $e');
        }
      }

      _logger.i('Deleted receipt: $receiptId');
    } catch (e) {
      _logger.e('Failed to delete receipt: $e');
      
      if (e is AppError) {
        rethrow;
      }
      
      throw DatabaseError.deleteFailed();
    }
  }

  /// Get receipt statistics
  static Future<Map<String, dynamic>> getReceiptStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw AuthenticationError.notAuthenticated();
      }

      _logger.i('Fetching receipt statistics for user: $userId');

      var query = supabase
          .from('receipts')
          .select('total_amount, category, created_at')
          .eq('user_id', userId);

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response = await query;
      final receipts = response as List;

      // Calculate statistics
      final stats = <String, dynamic>{
        'total_receipts': receipts.length,
        'total_amount': receipts.fold<double>(
          0.0,
          (sum, receipt) => sum + (receipt['total_amount'] as num).toDouble(),
        ),
        'average_amount': receipts.isEmpty
            ? 0.0
            : receipts.fold<double>(
                0.0,
                (sum, receipt) => sum + (receipt['total_amount'] as num).toDouble(),
              ) / receipts.length,
        'categories': _calculateCategoryStats(receipts),
        'monthly_totals': _calculateMonthlyTotals(receipts),
      };

      _logger.i('Calculated receipt statistics');
      return stats;
    } catch (e) {
      _logger.e('Failed to fetch receipt statistics: $e');
      
      if (e is AppError) {
        rethrow;
      }
      
      throw DatabaseError.queryFailed();
    }
  }

  /// Get available receipt categories
  static Future<List<String>> getReceiptCategories() async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw AuthenticationError.notAuthenticated();
      }

      final response = await supabase
          .from('receipts')
          .select('category')
          .eq('user_id', userId);

      final categories = (response as List)
          .map((item) => item['category'] as String)
          .toSet()
          .toList()
        ..sort();

      return categories;
    } catch (e) {
      _logger.e('Failed to fetch receipt categories: $e');
      return AppConstants.defaultCategories;
    }
  }

  /// Upload receipt image to storage
  static Future<String> _uploadReceiptImage(String imagePath, String userId) async {
    try {
      final file = File(imagePath);
      final fileName = '${_uuid.v4()}.${imagePath.split('.').last}';
      final storagePath = 'receipts/$userId/$fileName';

      _logger.i('Uploading receipt image: $storagePath');

      final imageUrl = await SupabaseService.uploadFile(
        bucket: AppConstants.receiptsBucket,
        path: storagePath,
        file: file,
        metadata: {
          'user_id': userId,
          'uploaded_at': DateTime.now().toIso8601String(),
        },
      );

      _logger.i('Receipt image uploaded successfully');
      return imageUrl;
    } catch (e) {
      _logger.e('Failed to upload receipt image: $e');
      
      if (e is AppError) {
        rethrow;
      }
      
      throw StorageError.uploadFailed();
    }
  }

  /// Calculate category statistics
  static Map<String, dynamic> _calculateCategoryStats(List<dynamic> receipts) {
    final categoryStats = <String, Map<String, dynamic>>{};
    
    for (final receipt in receipts) {
      final category = receipt['category'] as String;
      final amount = (receipt['total_amount'] as num).toDouble();
      
      if (categoryStats.containsKey(category)) {
        categoryStats[category]!['count'] = categoryStats[category]!['count'] + 1;
        categoryStats[category]!['total'] = categoryStats[category]!['total'] + amount;
      } else {
        categoryStats[category] = {
          'count': 1,
          'total': amount,
        };
      }
    }
    
    return categoryStats;
  }

  /// Calculate monthly totals
  static Map<String, double> _calculateMonthlyTotals(List<dynamic> receipts) {
    final monthlyTotals = <String, double>{};
    
    for (final receipt in receipts) {
      final createdAt = DateTime.parse(receipt['created_at'] as String);
      final monthKey = '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
      final amount = (receipt['total_amount'] as num).toDouble();
      
      monthlyTotals[monthKey] = (monthlyTotals[monthKey] ?? 0.0) + amount;
    }
    
    return monthlyTotals;
  }

  /// Search receipts with advanced filters
  static Future<List<Receipt>> searchReceipts({
    required String query,
    List<String>? categories,
    double? minAmount,
    double? maxAmount,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      final userId = SupabaseService.getCurrentUser()?.id;
      if (userId == null) {
        throw AuthenticationError.notAuthenticated();
      }

      _logger.i('Searching receipts with query: $query');

      var dbQuery = supabase
          .from('receipts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      // Text search
      if (query.isNotEmpty) {
        dbQuery = dbQuery.or(
          'merchant_name.ilike.%$query%,'
          'category.ilike.%$query%',
        );
      }

      // Category filter
      if (categories != null && categories.isNotEmpty) {
        dbQuery = dbQuery.in_('category', categories);
      }

      // Amount range
      if (minAmount != null) {
        dbQuery = dbQuery.gte('total_amount', minAmount);
      }
      if (maxAmount != null) {
        dbQuery = dbQuery.lte('total_amount', maxAmount);
      }

      // Date range
      if (startDate != null) {
        dbQuery = dbQuery.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        dbQuery = dbQuery.lte('created_at', endDate.toIso8601String());
      }

      final response = await dbQuery;
      
      final receipts = (response as List)
          .map((json) => Receipt.fromJson(json))
          .toList();

      _logger.i('Found ${receipts.length} receipts');
      return receipts;
    } catch (e) {
      _logger.e('Failed to search receipts: $e');
      
      if (e is AppError) {
        rethrow;
      }
      
      throw DatabaseError.queryFailed();
    }
  }
}
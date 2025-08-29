import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logger/logger.dart';

import '../../../core/error/app_error.dart';
import '../../../shared/constants/app_constants.dart';
import '../models/receipt_ocr_data.dart';

class OCRService {
  static final Logger _logger = Logger();
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Process image and extract receipt data
  static Future<ReceiptOCRData> processReceiptImage({
    required String imagePath,
  }) async {
    try {
      _logger.i('Processing receipt image: $imagePath');
      
      // Validate file exists and size
      final file = File(imagePath);
      if (!await file.exists()) {
        throw OCRError.invalidImage();
      }
      
      final fileSize = await file.length();
      if (fileSize > AppConstants.maxImageSizeBytes) {
        throw StorageError.fileTooLarge();
      }

      // Create InputImage for ML Kit
      final inputImage = InputImage.fromFilePath(imagePath);
      
      // Recognize text
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      if (recognizedText.text.isEmpty) {
        throw OCRError.noTextFound();
      }

      // Parse receipt data
      final ocrData = _parseReceiptText(recognizedText);
      
      _logger.i('OCR processing completed successfully');
      return ocrData;
    } catch (e) {
      _logger.e('OCR processing failed: $e');
      
      if (e is AppError) {
        rethrow;
      }
      
      throw OCRError.processingFailed();
    }
  }

  /// Parse recognized text into structured receipt data
  static ReceiptOCRData _parseReceiptText(RecognizedText recognizedText) {
    final lines = recognizedText.text.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Extract merchant name (usually first few lines)
    String merchantName = _extractMerchantName(lines);
    
    // Extract total amount
    double totalAmount = _extractTotalAmount(lines);
    
    // Extract date
    DateTime? date = _extractDate(lines);
    
    // Extract items
    List<ReceiptItem> items = _extractItems(lines);
    
    // Try to categorize based on merchant name
    String category = _categorizeReceipt(merchantName, items);
    
    return ReceiptOCRData(
      rawText: recognizedText.text,
      merchantName: merchantName,
      totalAmount: totalAmount,
      date: date ?? DateTime.now(),
      items: items,
      category: category,
      confidence: _calculateConfidence(merchantName, totalAmount, items),
      processingMetadata: {
        'processing_time': DateTime.now().toIso8601String(),
        'lines_processed': lines.length,
        'blocks_detected': recognizedText.blocks.length,
      },
    );
  }

  /// Extract merchant name from receipt lines
  static String _extractMerchantName(List<String> lines) {
    // Look for merchant name in first few lines
    for (int i = 0; i < (lines.length < 5 ? lines.length : 5); i++) {
      final line = lines[i];
      
      // Skip lines that look like addresses, phone numbers, or common receipt headers
      if (_isLikelyMerchantName(line)) {
        return line;
      }
    }
    
    // Fallback to first non-empty line
    return lines.isNotEmpty ? lines[0] : 'Unknown Merchant';
  }

  /// Check if line is likely a merchant name
  static bool _isLikelyMerchantName(String line) {
    // Skip if contains common non-merchant patterns
    if (RegExp(r'\d{3}[-\s]\d{3}[-\s]\d{4}').hasMatch(line)) return false; // Phone
    if (RegExp(r'\d+\s+[NSEW]?\s*\w+\s+(st|ave|rd|blvd|dr)', caseSensitive: false).hasMatch(line)) return false; // Address
    if (RegExp(r'(receipt|invoice|bill|order)', caseSensitive: false).hasMatch(line)) return false; // Common headers
    if (line.length < 3 || line.length > 50) return false; // Reasonable length
    
    // Should contain letters
    if (!RegExp(r'[a-zA-Z]').hasMatch(line)) return false;
    
    return true;
  }

  /// Extract total amount from receipt lines
  static double _extractTotalAmount(List<String> lines) {
    final totalPatterns = [
      RegExp(r'total[:\s]*\$?(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'amount[:\s]*\$?(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'balance[:\s]*\$?(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'\$(\d+\.?\d*)$', caseSensitive: false),
    ];

    // Look for total amount patterns
    for (final line in lines.reversed) { // Start from bottom
      for (final pattern in totalPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final amountStr = match.group(1);
          if (amountStr != null) {
            final amount = double.tryParse(amountStr);
            if (amount != null && amount > 0) {
              return amount;
            }
          }
        }
      }
    }

    return 0.0;
  }

  /// Extract date from receipt lines
  static DateTime? _extractDate(List<String> lines) {
    final datePatterns = [
      RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})'), // MM/DD/YYYY or M/D/YY
      RegExp(r'(\d{1,2})-(\d{1,2})-(\d{2,4})'), // MM-DD-YYYY
      RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})'), // YYYY-MM-DD
    ];

    for (final line in lines) {
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          try {
            int year, month, day;
            
            if (pattern == datePatterns[2]) { // YYYY-MM-DD
              year = int.parse(match.group(1)!);
              month = int.parse(match.group(2)!);
              day = int.parse(match.group(3)!);
            } else { // MM/DD/YYYY or MM-DD-YYYY
              month = int.parse(match.group(1)!);
              day = int.parse(match.group(2)!);
              year = int.parse(match.group(3)!);
              
              // Handle 2-digit years
              if (year < 100) {
                year += 2000;
              }
            }

            final date = DateTime(year, month, day);
            if (date.isBefore(DateTime.now().add(const Duration(days: 1)))) {
              return date;
            }
          } catch (e) {
            // Continue searching if this date is invalid
            continue;
          }
        }
      }
    }

    return null;
  }

  /// Extract line items from receipt
  static List<ReceiptItem> _extractItems(List<String> lines) {
    final items = <ReceiptItem>[];
    final itemPattern = RegExp(r'^(.+?)\s+\$?(\d+\.?\d*)$');

    for (final line in lines) {
      // Skip lines that are clearly not items
      if (_isHeaderOrFooterLine(line)) continue;

      final match = itemPattern.firstMatch(line);
      if (match != null) {
        final itemName = match.group(1)?.trim();
        final priceStr = match.group(2);
        
        if (itemName != null && priceStr != null) {
          final price = double.tryParse(priceStr);
          if (price != null && price > 0 && itemName.isNotEmpty) {
            items.add(ReceiptItem(
              name: itemName,
              price: price,
              quantity: 1, // Default quantity
            ));
          }
        }
      }
    }

    return items;
  }

  /// Check if line is likely a header or footer
  static bool _isHeaderOrFooterLine(String line) {
    final headerFooterPatterns = [
      RegExp(r'(receipt|invoice|thank you|visit|welcome)', caseSensitive: false),
      RegExp(r'(total|subtotal|tax|discount)', caseSensitive: false),
      RegExp(r'\d{3}[-\s]\d{3}[-\s]\d{4}'), // Phone numbers
      RegExp(r'www\.|\.com|@'), // Websites and emails
    ];

    return headerFooterPatterns.any((pattern) => pattern.hasMatch(line));
  }

  /// Categorize receipt based on merchant and items
  static String _categorizeReceipt(String merchantName, List<ReceiptItem> items) {
    final merchant = merchantName.toLowerCase();
    
    // Merchant-based categorization
    if (RegExp(r'(restaurant|cafe|coffee|pizza|burger|food|deli|bistro)')
        .hasMatch(merchant)) {
      return 'Food & Dining';
    }
    
    if (RegExp(r'(gas|fuel|shell|chevron|exxon|bp|mobil)')
        .hasMatch(merchant)) {
      return 'Transportation';
    }
    
    if (RegExp(r'(grocery|market|store|walmart|target|costco)')
        .hasMatch(merchant)) {
      return 'Shopping';
    }
    
    if (RegExp(r'(pharmacy|cvs|walgreens|hospital|clinic|medical)')
        .hasMatch(merchant)) {
      return 'Healthcare';
    }

    // Item-based categorization
    final itemText = items.map((item) => item.name.toLowerCase()).join(' ');
    
    if (RegExp(r'(food|drink|meal|coffee|tea|soda|bread|milk)')
        .hasMatch(itemText)) {
      return 'Food & Dining';
    }

    // Default category
    return 'Other';
  }

  /// Calculate confidence score based on extracted data quality
  static double _calculateConfidence(String merchantName, double totalAmount, List<ReceiptItem> items) {
    double confidence = 0.0;
    
    // Merchant name quality
    if (merchantName != 'Unknown Merchant' && merchantName.length > 3) {
      confidence += 0.3;
    }
    
    // Total amount validity
    if (totalAmount > 0) {
      confidence += 0.4;
    }
    
    // Items extracted
    if (items.isNotEmpty) {
      confidence += 0.2;
    }
    
    // Additional quality checks
    if (items.length > 2) {
      confidence += 0.1;
    }
    
    return confidence.clamp(0.0, 1.0);
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
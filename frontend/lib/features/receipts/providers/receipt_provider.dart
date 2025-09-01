import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../shared/models/receipt_model.dart';
import '../services/receipt_service.dart';

final _logger = Logger();

/// Receipt state class
class ReceiptState {
  final List<Receipt> receipts;
  final Receipt? selectedReceipt;
  final bool isLoading;
  final bool isCreating;
  final bool isUpdating;
  final bool isDeleting;
  final String? error;
  final Map<String, dynamic>? stats;
  final List<String> categories;

  const ReceiptState({
    this.receipts = const [],
    this.selectedReceipt,
    this.isLoading = false,
    this.isCreating = false,
    this.isUpdating = false,
    this.isDeleting = false,
    this.error,
    this.stats,
    this.categories = const [],
  });

  ReceiptState copyWith({
    List<Receipt>? receipts,
    Receipt? selectedReceipt,
    bool clearSelectedReceipt = false,
    bool? isLoading,
    bool? isCreating,
    bool? isUpdating,
    bool? isDeleting,
    String? error,
    bool clearError = false,
    Map<String, dynamic>? stats,
    List<String>? categories,
  }) {
    return ReceiptState(
      receipts: receipts ?? this.receipts,
      selectedReceipt: clearSelectedReceipt ? null : (selectedReceipt ?? this.selectedReceipt),
      isLoading: isLoading ?? this.isLoading,
      isCreating: isCreating ?? this.isCreating,
      isUpdating: isUpdating ?? this.isUpdating,
      isDeleting: isDeleting ?? this.isDeleting,
      error: clearError ? null : (error ?? this.error),
      stats: stats ?? this.stats,
      categories: categories ?? this.categories,
    );
  }

  bool get hasError => error != null;
  bool get isProcessing => isLoading || isCreating || isUpdating || isDeleting;
}

/// Receipt search filters
class ReceiptFilters {
  final String searchQuery;
  final String? category;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;

  const ReceiptFilters({
    this.searchQuery = '',
    this.category,
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
  });

  ReceiptFilters copyWith({
    String? searchQuery,
    String? category,
    bool clearCategory = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    double? minAmount,
    bool clearMinAmount = false,
    double? maxAmount,
    bool clearMaxAmount = false,
  }) {
    return ReceiptFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      category: clearCategory ? null : (category ?? this.category),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
    );
  }

  bool get hasFilters =>
      searchQuery.isNotEmpty ||
      category != null ||
      startDate != null ||
      endDate != null ||
      minAmount != null ||
      maxAmount != null;
}

/// Receipt notifier class
class ReceiptNotifier extends StateNotifier<ReceiptState> {
  ReceiptNotifier() : super(const ReceiptState()) {
    _initialize();
  }

  /// Initialize provider
  Future<void> _initialize() async {
    await Future.wait([
      loadReceipts(),
      loadCategories(),
    ]);
  }

  /// Load all receipts
  Future<void> loadReceipts({
    int? limit,
    int? offset,
    bool refresh = false,
  }) async {
    try {
      if (!refresh && state.receipts.isNotEmpty) return;

      state = state.copyWith(isLoading: true, clearError: true);
      
      final receipts = await ReceiptService.getUserReceipts(
        limit: limit,
        offset: offset,
      );
      
      state = state.copyWith(
        receipts: receipts,
        isLoading: false,
      );
      
      _logger.i('Loaded ${receipts.length} receipts');
    } catch (e) {
      _logger.e('Failed to load receipts: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load receipts: ${e.toString()}',
      );
    }
  }

  /// Search receipts with filters
  Future<void> searchReceipts(ReceiptFilters filters) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      
      List<Receipt> receipts;
      
      if (filters.hasFilters) {
        receipts = await ReceiptService.searchReceipts(
          query: filters.searchQuery,
          categories: filters.category != null ? [filters.category!] : null,
          minAmount: filters.minAmount,
          maxAmount: filters.maxAmount,
          startDate: filters.startDate,
          endDate: filters.endDate,
        );
      } else {
        receipts = await ReceiptService.getUserReceipts();
      }
      
      state = state.copyWith(
        receipts: receipts,
        isLoading: false,
      );
      
      _logger.i('Found ${receipts.length} receipts with filters');
    } catch (e) {
      _logger.e('Failed to search receipts: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Search failed: ${e.toString()}',
      );
    }
  }

  /// Load receipt by ID
  Future<void> loadReceipt(String receiptId) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
      
      final receipt = await ReceiptService.getReceipt(receiptId);
      
      state = state.copyWith(
        selectedReceipt: receipt,
        isLoading: false,
      );
      
      _logger.i('Loaded receipt: ${receipt?.merchantName}');
    } catch (e) {
      _logger.e('Failed to load receipt: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load receipt: ${e.toString()}',
      );
    }
  }

  /// Create new receipt
  Future<Receipt?> createReceipt({
    required String imagePath,
    String? merchantName,
    double? totalAmount,
    String? category,
    DateTime? date,
  }) async {
    try {
      state = state.copyWith(isCreating: true, clearError: true);
      
      final receipt = await ReceiptService.createReceipt(
        imagePath: imagePath,
        merchantName: merchantName,
        totalAmount: totalAmount,
        category: category,
        date: date,
      );
      
      // Add to current list
      state = state.copyWith(
        receipts: [receipt, ...state.receipts],
        selectedReceipt: receipt,
        isCreating: false,
      );
      
      _logger.i('Created receipt: ${receipt.merchantName}');
      
      // Refresh categories if new category was added
      if (category != null && !state.categories.contains(category)) {
        loadCategories();
      }
      
      return receipt;
    } catch (e) {
      _logger.e('Failed to create receipt: $e');
      state = state.copyWith(
        isCreating: false,
        error: 'Failed to create receipt: ${e.toString()}',
      );
      return null;
    }
  }

  /// Update receipt
  Future<Receipt?> updateReceipt({
    required String receiptId,
    String? merchantName,
    double? totalAmount,
    String? category,
    Map<String, dynamic>? ocrData,
  }) async {
    try {
      state = state.copyWith(isUpdating: true, clearError: true);
      
      final receipt = await ReceiptService.updateReceipt(
        receiptId: receiptId,
        merchantName: merchantName,
        totalAmount: totalAmount,
        category: category,
        ocrData: ocrData,
      );
      
      // Update in current list
      final updatedReceipts = state.receipts.map((r) {
        return r.id == receiptId ? receipt : r;
      }).toList();
      
      state = state.copyWith(
        receipts: updatedReceipts,
        selectedReceipt: receipt,
        isUpdating: false,
      );
      
      _logger.i('Updated receipt: ${receipt.merchantName}');
      
      // Refresh categories if new category was added
      if (category != null && !state.categories.contains(category)) {
        loadCategories();
      }
      
      return receipt;
    } catch (e) {
      _logger.e('Failed to update receipt: $e');
      state = state.copyWith(
        isUpdating: false,
        error: 'Failed to update receipt: ${e.toString()}',
      );
      return null;
    }
  }

  /// Delete receipt
  Future<bool> deleteReceipt(String receiptId) async {
    try {
      state = state.copyWith(isDeleting: true, clearError: true);
      
      await ReceiptService.deleteReceipt(receiptId);
      
      // Remove from current list
      final updatedReceipts = state.receipts
          .where((receipt) => receipt.id != receiptId)
          .toList();
      
      state = state.copyWith(
        receipts: updatedReceipts,
        clearSelectedReceipt: state.selectedReceipt?.id == receiptId,
        isDeleting: false,
      );
      
      _logger.i('Deleted receipt: $receiptId');
      return true;
    } catch (e) {
      _logger.e('Failed to delete receipt: $e');
      state = state.copyWith(
        isDeleting: false,
        error: 'Failed to delete receipt: ${e.toString()}',
      );
      return false;
    }
  }

  /// Load receipt statistics
  Future<void> loadStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final stats = await ReceiptService.getReceiptStats(
        startDate: startDate,
        endDate: endDate,
      );
      
      state = state.copyWith(stats: stats);
      _logger.i('Loaded receipt statistics');
    } catch (e) {
      _logger.e('Failed to load receipt statistics: $e');
    }
  }

  /// Load available categories
  Future<void> loadCategories() async {
    try {
      final categories = await ReceiptService.getReceiptCategories();
      state = state.copyWith(categories: categories);
      _logger.i('Loaded ${categories.length} categories');
    } catch (e) {
      _logger.e('Failed to load categories: $e');
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear selected receipt
  void clearSelectedReceipt() {
    state = state.copyWith(clearSelectedReceipt: true);
  }

  /// Refresh all data
  Future<void> refresh() async {
    await Future.wait([
      loadReceipts(refresh: true),
      loadCategories(),
      loadStats(),
    ]);
  }
}

/// Receipt provider
final receiptProvider = StateNotifierProvider<ReceiptNotifier, ReceiptState>((ref) {
  return ReceiptNotifier();
});

/// Receipt filters provider
final receiptFiltersProvider = StateProvider<ReceiptFilters>((ref) {
  return const ReceiptFilters();
});

/// Filtered receipts provider
final filteredReceiptsProvider = Provider<List<Receipt>>((ref) {
  final receipts = ref.watch(receiptProvider).receipts;
  final filters = ref.watch(receiptFiltersProvider);
  
  if (!filters.hasFilters) return receipts;
  
  return receipts.where((receipt) {
    // Search query filter
    if (filters.searchQuery.isNotEmpty) {
      final query = filters.searchQuery.toLowerCase();
      if (!receipt.merchantName.toLowerCase().contains(query) &&
          !receipt.category.toLowerCase().contains(query)) {
        return false;
      }
    }
    
    // Category filter
    if (filters.category != null && receipt.category != filters.category) {
      return false;
    }
    
    // Date range filter
    if (filters.startDate != null && receipt.createdAt.isBefore(filters.startDate!)) {
      return false;
    }
    
    if (filters.endDate != null && receipt.createdAt.isAfter(filters.endDate!)) {
      return false;
    }
    
    // Amount range filter
    if (filters.minAmount != null && receipt.totalAmount < filters.minAmount!) {
      return false;
    }
    
    if (filters.maxAmount != null && receipt.totalAmount > filters.maxAmount!) {
      return false;
    }
    
    return true;
  }).toList();
});

/// Receipt by ID provider
final receiptByIdProvider = Provider.family<Receipt?, String>((ref, receiptId) {
  final receipts = ref.watch(receiptProvider).receipts;
  try {
    return receipts.firstWhere((receipt) => receipt.id == receiptId);
  } catch (e) {
    return null;
  }
});
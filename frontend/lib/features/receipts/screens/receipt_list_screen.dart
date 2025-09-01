import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/route_paths.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/constants/app_constants.dart';
import '../providers/receipt_provider.dart';
import '../widgets/receipt_card.dart';

class ReceiptListScreen extends ConsumerStatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  ConsumerState<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends ConsumerState<ReceiptListScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(receiptProvider.notifier).loadReceipts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final filters = ref.read(receiptFiltersProvider);
    ref.read(receiptFiltersProvider.notifier).state = filters.copyWith(
      searchQuery: _searchController.text,
    );
  }

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category ?? 'All';
    });
    
    final filters = ref.read(receiptFiltersProvider);
    ref.read(receiptFiltersProvider.notifier).state = filters.copyWith(
      category: category == 'All' ? null : category,
      clearCategory: category == 'All',
    );
  }

  void _onDateRangeChanged(DateTimeRange? range) {
    setState(() {
      _selectedDateRange = range;
    });
    
    final filters = ref.read(receiptFiltersProvider);
    ref.read(receiptFiltersProvider.notifier).state = filters.copyWith(
      startDate: range?.start,
      endDate: range?.end,
      clearStartDate: range == null,
      clearEndDate: range == null,
    );
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppTheme.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    _onDateRangeChanged(range);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedCategory = 'All';
      _selectedDateRange = null;
    });
    
    ref.read(receiptFiltersProvider.notifier).state = const ReceiptFilters();
  }

  @override
  Widget build(BuildContext context) {
    final receiptState = ref.watch(receiptProvider);
    final filteredReceipts = ref.watch(filteredReceiptsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filters
          _buildSearchAndFilters(),
          
          // Receipts list
          Expanded(
            child: _buildReceiptsList(receiptState, filteredReceipts),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RoutePaths.addReceipt),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: (_) => _onSearchChanged(),
            decoration: InputDecoration(
              hintText: 'Search receipts...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMedium,
                vertical: AppTheme.spacingSmall,
              ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingSmall),
          
          // Filter chips
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final categories = ref.watch(receiptProvider).categories;
    final filters = ref.watch(receiptFiltersProvider);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Category filter
          FilterChip(
            label: Text(_selectedCategory),
            selected: _selectedCategory != 'All',
            onSelected: (_) => _showCategoryFilter(categories),
            avatar: Icon(
              Icons.category,
              size: 16,
              color: _selectedCategory != 'All' ? Colors.white : null,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingSmall),
          
          // Date range filter
          FilterChip(
            label: Text(
              _selectedDateRange != null
                  ? 'Custom Range'
                  : 'All Dates',
            ),
            selected: _selectedDateRange != null,
            onSelected: (_) => _selectDateRange(),
            avatar: Icon(
              Icons.date_range,
              size: 16,
              color: _selectedDateRange != null ? Colors.white : null,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingSmall),
          
          // Clear filters
          if (filters.hasFilters)
            ActionChip(
              label: const Text('Clear'),
              onPressed: _clearFilters,
              avatar: const Icon(Icons.clear, size: 16),
            ),
        ],
      ),
    );
  }

  Widget _buildReceiptsList(ReceiptState state, List receipts) {
    if (state.isLoading && receipts.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (state.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            ElevatedButton(
              onPressed: () => ref.read(receiptProvider.notifier).loadReceipts(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              'No receipts found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              'Start by adding your first receipt',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            ElevatedButton.icon(
              onPressed: () => context.push(RoutePaths.addReceipt),
              icon: const Icon(Icons.add),
              label: const Text('Add Receipt'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => ref.read(receiptProvider.notifier).refresh(),
      child: ListView.builder(
        itemCount: receipts.length,
        itemBuilder: (context, index) {
          final receipt = receipts[index];
          
          return ReceiptCard(
            receipt: receipt,
            onTap: () => context.push(
              RoutePaths.receiptDetailPath(receipt.id),
            ),
            onEdit: () => context.push(
              RoutePaths.editReceiptPath(receipt.id),
            ),
            onDelete: () => _deleteReceipt(receipt.id),
          );
        },
      ),
    );
  }

  void _showCategoryFilter(List<String> categories) {
    final allCategories = ['All', ...categories];
    
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Text(
                'Select Category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allCategories.length,
                itemBuilder: (context, index) {
                  final category = allCategories[index];
                  final isSelected = category == _selectedCategory;
                  
                  return ListTile(
                    leading: Icon(
                      _getCategoryIcon(category),
                      color: isSelected ? AppTheme.primaryColor : null,
                    ),
                    title: Text(category),
                    trailing: isSelected ? const Icon(Icons.check) : null,
                    onTap: () {
                      _onCategoryChanged(category);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(AppTheme.spacingMedium),
                child: Column(
                  children: [
                    Text(
                      'Filter Receipts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        children: [
                          // Advanced filter options would go here
                          ListTile(
                            leading: const Icon(Icons.category),
                            title: const Text('Category'),
                            subtitle: Text(_selectedCategory),
                            onTap: () {
                              Navigator.of(context).pop();
                              _showCategoryFilter(ref.read(receiptProvider).categories);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.date_range),
                            title: const Text('Date Range'),
                            subtitle: Text(
                              _selectedDateRange != null
                                  ? '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}'
                                  : 'All dates',
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              _selectDateRange();
                            },
                          ),
                          const SizedBox(height: AppTheme.spacingLarge),
                          ElevatedButton(
                            onPressed: () {
                              _clearFilters();
                              Navigator.of(context).pop();
                            },
                            child: const Text('Clear All Filters'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteReceipt(String receiptId) async {
    final success = await ref.read(receiptProvider.notifier).deleteReceipt(receiptId);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt deleted successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'all':
        return Icons.all_inclusive;
      case 'food & dining':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_bag;
      case 'transportation':
        return Icons.directions_car;
      case 'healthcare':
        return Icons.local_hospital;
      case 'entertainment':
        return Icons.movie;
      case 'utilities':
        return Icons.bolt;
      default:
        return Icons.receipt;
    }
  }
}
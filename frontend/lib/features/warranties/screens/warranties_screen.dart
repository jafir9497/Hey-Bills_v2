import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/loading_overlay.dart';
import '../../../shared/components/empty_state.dart';
import '../providers/warranty_provider.dart';
import '../widgets/warranty_card.dart';
import '../widgets/warranty_status_filter.dart';
import '../widgets/warranty_search_bar.dart';
import '../models/warranty_model.dart';

class WarrantiesScreen extends ConsumerStatefulWidget {
  const WarrantiesScreen({super.key});

  @override
  ConsumerState<WarrantiesScreen> createState() => _WarrantiesScreenState();
}

class _WarrantiesScreenState extends ConsumerState<WarrantiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  WarrantyStatus? _selectedStatus;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Load warranties
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(warrantyProvider.notifier).loadWarranties();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final warrantiesState = ref.watch(warrantyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warranties'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addWarranty,
            tooltip: 'Add Warranty',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportWarranties();
                  break;
                case 'sync':
                  _syncWarranties();
                  break;
                case 'notifications':
                  _manageNotifications();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 12),
                    Text('Export'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.sync),
                    SizedBox(width: 12),
                    Text('Sync'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications),
                    SizedBox(width: 12),
                    Text('Notifications'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: WarrantySearchBar(
                  controller: _searchController,
                  onChanged: (query) {
                    setState(() {
                      _searchQuery = query;
                    });
                    _filterWarranties();
                  },
                  onFilterTap: _showFilterDialog,
                ),
              ),
              
              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Active'),
                  Tab(text: 'Expiring'),
                  Tab(text: 'Expired'),
                ],
                onTap: (index) => _onTabChanged(index),
              ),
            ],
          ),
        ),
      ),
      body: warrantiesState.when(
        data: (warranties) => warranties.isEmpty
            ? const EmptyState(
                title: 'No Warranties',
                subtitle: 'Add your first warranty to start tracking',
                icon: Icons.verified_user_outlined,
                actionText: 'Add Warranty',
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildWarrantiesList(warranties),
                  _buildWarrantiesList(warranties.where((w) => w.status == WarrantyStatus.active).toList()),
                  _buildWarrantiesList(warranties.where((w) => w.isExpiringSoon && !w.isExpired).toList()),
                  _buildWarrantiesList(warranties.where((w) => w.isExpired).toList()),
                ],
              ),
        loading: () => const LoadingOverlay(),
        error: (error, stack) => EmptyState(
          title: 'Error Loading Warranties',
          subtitle: error.toString(),
          icon: Icons.error_outline,
          action: ElevatedButton(
            onPressed: () => ref.read(warrantyProvider.notifier).loadWarranties(),
            child: const Text('Retry'),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWarranty,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildWarrantiesList(List<Warranty> warranties) {
    final filteredWarranties = _filterWarrantiesList(warranties);

    if (filteredWarranties.isEmpty) {
      return const Center(
        child: EmptyState(
          title: 'No Warranties Found',
          subtitle: 'Try adjusting your search or filters',
          icon: Icons.search_off,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(warrantyProvider.notifier).loadWarranties(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredWarranties.length,
        itemBuilder: (context, index) {
          final warranty = filteredWarranties[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WarrantyCard(
              warranty: warranty,
              onTap: () => _viewWarrantyDetails(warranty),
              onEdit: () => _editWarranty(warranty),
              onDelete: () => _deleteWarranty(warranty),
              onClaim: () => _claimWarranty(warranty),
            ),
          );
        },
      ),
    );
  }

  List<Warranty> _filterWarrantiesList(List<Warranty> warranties) {
    var filtered = warranties;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((warranty) {
        return warranty.productName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               warranty.brand.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               warranty.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               warranty.retailer.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != null) {
      filtered = filtered.where((warranty) => warranty.status == _selectedStatus).toList();
    }

    return filtered;
  }

  void _onTabChanged(int index) {
    // Optional: Add analytics or specific behavior for tab changes
  }

  void _filterWarranties() {
    setState(() {
      // Trigger rebuild with new filters
    });
  }

  void _addWarranty() {
    context.push('/warranties/add');
  }

  void _viewWarrantyDetails(Warranty warranty) {
    context.push('/warranties/${warranty.id}');
  }

  void _editWarranty(Warranty warranty) {
    context.push('/warranties/${warranty.id}/edit');
  }

  void _deleteWarranty(Warranty warranty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Warranty'),
        content: Text(
          'Are you sure you want to delete the warranty for ${warranty.productName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(warrantyProvider.notifier).deleteWarranty(warranty.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Warranty deleted successfully'),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting warranty: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _claimWarranty(Warranty warranty) {
    context.push('/warranties/${warranty.id}/claim');
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Warranties',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              
              // Status Filter
              const Text(
                'Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              WarrantyStatusFilter(
                selectedStatus: _selectedStatus,
                onStatusChanged: (status) {
                  setState(() {
                    _selectedStatus = status;
                  });
                },
              ),
              
              const SizedBox(height: 24),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _filterWarranties();
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _exportWarranties() {
    // TODO: Implement warranty export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality coming soon')),
    );
  }

  void _syncWarranties() {
    ref.read(warrantyProvider.notifier).loadWarranties();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Warranties synced')),
    );
  }

  void _manageNotifications() {
    context.push('/warranties/notifications');
  }
}
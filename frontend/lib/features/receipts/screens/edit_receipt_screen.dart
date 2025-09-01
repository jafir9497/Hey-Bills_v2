import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/navigation/route_paths.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/receipt_provider.dart';
import '../widgets/receipt_form.dart';

class EditReceiptScreen extends ConsumerStatefulWidget {
  final String receiptId;

  const EditReceiptScreen({
    super.key,
    required this.receiptId,
  });

  @override
  ConsumerState<EditReceiptScreen> createState() => _EditReceiptScreenState();
}

class _EditReceiptScreenState extends ConsumerState<EditReceiptScreen> {
  ReceiptFormData? _formData;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReceipt();
    });
  }

  void _loadReceipt() {
    final receipt = ref.read(receiptByIdProvider(widget.receiptId));
    if (receipt == null) {
      ref.read(receiptProvider.notifier).loadReceipt(widget.receiptId);
    } else {
      _initializeForm(receipt);
    }
  }

  void _initializeForm(receipt) {
    setState(() {
      _formData = ReceiptFormData(
        merchantName: receipt.merchantName,
        totalAmount: receipt.totalAmount,
        category: receipt.category,
        date: receipt.createdAt,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final receiptState = ref.watch(receiptProvider);
    final receipt = receiptState.selectedReceipt ?? 
                   ref.watch(receiptByIdProvider(widget.receiptId));
    final categories = receiptState.categories;

    // Initialize form if we have receipt data but haven't set up form yet
    if (receipt != null && _formData == null) {
      _initializeForm(receipt);
    }

    if (receiptState.isLoading) {
      return const Scaffold(
        appBar: AppBar(title: Text('Edit Receipt')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (receiptState.hasError || receipt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Receipt')),
        body: Center(
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
                receiptState.error ?? 'Receipt not found',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppTheme.spacingMedium),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_formData == null) {
      return const Scaffold(
        appBar: AppBar(title: Text('Edit Receipt')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) {
        if (!didPop && _hasChanges) {
          _showUnsavedChangesDialog();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit Receipt'),
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: receiptState.isUpdating ? null : _saveChanges,
                child: receiptState.isUpdating 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Receipt image preview
              _buildImagePreview(receipt),
              
              const SizedBox(height: AppTheme.spacingLarge),
              
              // Edit form
              _buildEditForm(categories),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(receipt) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.image,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                Text(
                  'Receipt Image',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _viewFullImage,
                  icon: const Icon(Icons.zoom_in, size: 20),
                  label: const Text('View'),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMedium),
            
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: receipt.imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: receipt.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 8),
                              Text('Image not available'),
                            ],
                          ),
                        ),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text('No image available'),
                          ],
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingSmall),
            
            Text(
              'Note: Image cannot be changed after receipt creation',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(List<String> categories) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.edit,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                Text(
                  'Edit Receipt Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingMedium),
            
            ReceiptForm(
              initialData: _formData!,
              availableCategories: categories,
              onChanged: (data) {
                setState(() {
                  _formData = data;
                  _hasChanges = true;
                });
              },
              onSubmit: _saveChanges,
              submitButtonText: 'Update Receipt',
              isLoading: ref.watch(receiptProvider).isUpdating,
            ),
            
            const SizedBox(height: AppTheme.spacingLarge),
            
            // Delete button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                label: const Text(
                  'Delete Receipt',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.errorColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_formData == null) return;

    final updatedReceipt = await ref.read(receiptProvider.notifier).updateReceipt(
      receiptId: widget.receiptId,
      merchantName: _formData!.merchantName,
      totalAmount: _formData!.totalAmount,
      category: _formData!.category,
    );

    if (updatedReceipt != null && mounted) {
      setState(() {
        _hasChanges = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt updated successfully!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      context.pushReplacement(
        RoutePaths.receiptDetailPath(widget.receiptId),
      );
    } else if (mounted) {
      final error = ref.read(receiptProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Failed to update receipt'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showUnsavedChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Do you want to save before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _hasChanges = false;
              });
              Navigator.of(context).pop();
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _saveChanges();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: const Text(
          'Are you sure you want to delete this receipt? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteReceipt();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReceipt() async {
    final success = await ref.read(receiptProvider.notifier).deleteReceipt(widget.receiptId);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt deleted successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      // Navigate back to receipts list
      context.go(RoutePaths.receipts);
    }
  }

  void _viewFullImage() {
    final receipt = ref.read(receiptProvider).selectedReceipt ?? 
                   ref.read(receiptByIdProvider(widget.receiptId));
                   
    if (receipt?.imageUrl.isNotEmpty == true) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Receipt Image'),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: receipt!.imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
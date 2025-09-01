import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/navigation/route_paths.dart';
import '../../../shared/theme/app_theme.dart';
import '../providers/receipt_provider.dart';
import '../models/receipt_ocr_data.dart';

class ReceiptDetailScreen extends ConsumerStatefulWidget {
  final String receiptId;

  const ReceiptDetailScreen({
    super.key,
    required this.receiptId,
  });

  @override
  ConsumerState<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends ConsumerState<ReceiptDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(receiptProvider.notifier).loadReceipt(widget.receiptId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final receiptState = ref.watch(receiptProvider);
    final receipt = receiptState.selectedReceipt;

    if (receiptState.isLoading) {
      return const Scaffold(
        appBar: AppBar(title: Text('Receipt Details')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (receiptState.hasError || receipt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Receipt Details')),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push(
              RoutePaths.editReceiptPath(receipt.id),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  _showDeleteConfirmation();
                  break;
                case 'share':
                  _shareReceipt();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: AppTheme.errorColor)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receipt header
            _buildReceiptHeader(receipt),
            
            const SizedBox(height: AppTheme.spacingLarge),
            
            // Receipt image
            _buildReceiptImage(receipt),
            
            const SizedBox(height: AppTheme.spacingLarge),
            
            // Receipt details
            _buildReceiptDetails(receipt),
            
            const SizedBox(height: AppTheme.spacingLarge),
            
            // OCR data if available
            if (receipt.ocrData != null) _buildOCRData(receipt),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptHeader(receipt) {
    final currencyFormat = NumberFormat.simpleCurrency();
    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category icon
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingSmall),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(receipt.category).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Icon(
                    _getCategoryIcon(receipt.category),
                    color: _getCategoryColor(receipt.category),
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: AppTheme.spacingMedium),
                
                // Receipt info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.merchantName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacingXSmall),
                      
                      Text(
                        receipt.category,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _getCategoryColor(receipt.category),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const SizedBox(height: AppTheme.spacingSmall),
                      
                      Text(
                        dateFormat.format(receipt.createdAt),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacingLarge),
            
            // Total amount
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Total Amount',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXSmall),
                  Text(
                    currencyFormat.format(receipt.totalAmount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptImage(receipt) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt Image',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingMedium),
            
            Container(
              width: double.infinity,
              height: 400,
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
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: receipt.imageUrl.isNotEmpty ? _viewFullImage : null,
                  icon: const Icon(Icons.zoom_in),
                  label: const Text('View Full Size'),
                ),
                TextButton.icon(
                  onPressed: receipt.imageUrl.isNotEmpty ? _downloadImage : null,
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptDetails(receipt) {
    final dateFormat = DateFormat('MMM dd, yyyy \'at\' h:mm a');
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Receipt Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: AppTheme.spacingMedium),
            
            _buildDetailRow(
              'Receipt ID',
              receipt.id,
              Icons.receipt_long,
            ),
            
            _buildDetailRow(
              'Merchant',
              receipt.merchantName,
              Icons.store,
            ),
            
            _buildDetailRow(
              'Category',
              receipt.category,
              Icons.category,
            ),
            
            _buildDetailRow(
              'Amount',
              NumberFormat.simpleCurrency().format(receipt.totalAmount),
              Icons.attach_money,
            ),
            
            _buildDetailRow(
              'Date Added',
              dateFormat.format(receipt.createdAt),
              Icons.access_time,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOCRData(receipt) {
    try {
      final ocrData = ReceiptOCRData.fromJson(receipt.ocrData!);
      
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'OCR Analysis',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSmall,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(ocrData.confidence).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      '${(ocrData.confidence * 100).round()}% confidence',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _getConfidenceColor(ocrData.confidence),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingMedium),
              
              if (ocrData.items.isNotEmpty) ...[
                Text(
                  'Items Detected',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSmall),
                ...ocrData.items.map((item) => _buildItemRow(item)),
                const SizedBox(height: AppTheme.spacingMedium),
              ],
              
              ExpansionTile(
                title: const Text('Raw Text'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacingMedium),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      ocrData.rawText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildItemRow(ReceiptItem item) {
    final currencyFormat = NumberFormat.simpleCurrency();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              'Qty: ${item.quantity}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              currencyFormat.format(item.totalPrice),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppTheme.successColor;
    if (confidence >= 0.6) return AppTheme.warningColor;
    return AppTheme.errorColor;
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
      context.pop();
    }
  }

  void _viewFullImage() {
    final receipt = ref.read(receiptProvider).selectedReceipt;
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

  void _downloadImage() {
    // Implementation would go here - could use image downloading plugin
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download functionality coming soon'),
      ),
    );
  }

  void _shareReceipt() {
    // Implementation would go here - could use share plugin
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon'),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food & dining':
        return Colors.orange;
      case 'shopping':
        return Colors.blue;
      case 'transportation':
        return Colors.green;
      case 'healthcare':
        return Colors.red;
      case 'entertainment':
        return Colors.purple;
      case 'utilities':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }
}
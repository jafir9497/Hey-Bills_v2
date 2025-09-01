import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../shared/models/receipt_model.dart';
import '../../../shared/theme/app_theme.dart';

class ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showActions;

  const ReceiptCard({
    super.key,
    required this.receipt,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final currencyFormat = NumberFormat.simpleCurrency();

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Receipt image thumbnail
              _buildImageThumbnail(),
              
              const SizedBox(width: AppTheme.spacingMedium),
              
              // Receipt details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Merchant name
                    Text(
                      receipt.merchantName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: AppTheme.spacingXSmall),
                    
                    // Category
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSmall,
                        vertical: AppTheme.spacingXSmall,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(receipt.category).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        receipt.category,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _getCategoryColor(receipt.category),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingSmall),
                    
                    // Amount and date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          currencyFormat.format(receipt.totalAmount),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          dateFormat.format(receipt.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Actions menu
              if (showActions) _buildActionsMenu(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        color: Colors.grey[200],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: receipt.imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: receipt.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.receipt_outlined,
                  color: Colors.grey[600],
                  size: 24,
                ),
              )
            : Icon(
                Icons.receipt_outlined,
                color: Colors.grey[600],
                size: 24,
              ),
      ),
    );
  }

  Widget _buildActionsMenu(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            _showDeleteConfirmation(context);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: Theme.of(context).iconTheme.color,
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              const Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                size: 18,
                color: AppTheme.errorColor,
              ),
              const SizedBox(width: AppTheme.spacingSmall),
              const Text(
                'Delete',
                style: TextStyle(color: AppTheme.errorColor),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingXSmall),
        child: Icon(
          Icons.more_vert,
          color: Colors.grey[600],
          size: 20,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: Text(
          'Are you sure you want to delete the receipt from "${receipt.merchantName}"? '
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
              onDelete?.call();
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

class ReceiptListTile extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback? onTap;

  const ReceiptListTile({
    super.key,
    required this.receipt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd');
    final currencyFormat = NumberFormat.simpleCurrency();

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _getCategoryColor(receipt.category).withOpacity(0.2),
        child: Icon(
          _getCategoryIcon(receipt.category),
          color: _getCategoryColor(receipt.category),
          size: 20,
        ),
      ),
      title: Text(
        receipt.merchantName,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        receipt.category,
        style: TextStyle(
          color: _getCategoryColor(receipt.category),
          fontSize: 12,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            currencyFormat.format(receipt.totalAmount),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          Text(
            dateFormat.format(receipt.createdAt),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
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
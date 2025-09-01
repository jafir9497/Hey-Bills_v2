import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/models/receipt_model.dart';

class RecentReceiptsWidget extends ConsumerWidget {
  final List<Receipt> receipts;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const RecentReceiptsWidget({
    super.key,
    required this.receipts,
    this.isLoading = false,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Receipts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (receipts.isEmpty)
            _buildEmptyState()
          else
            _buildReceiptsList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(
            Icons.receipt_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No receipts yet',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan your first receipt to get started',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptsList() {
    // Show only first 3 receipts
    final displayReceipts = receipts.take(3).toList();
    
    return Column(
      children: displayReceipts.map((receipt) => _buildReceiptItem(receipt)).toList(),
    );
  }

  Widget _buildReceiptItem(Receipt receipt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(receipt.category),
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.merchantName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, y').format(receipt.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            NumberFormat.currency(symbol: '\$').format(receipt.totalAmount),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
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
        return Icons.electric_bolt;
      default:
        return Icons.receipt;
    }
  }
}
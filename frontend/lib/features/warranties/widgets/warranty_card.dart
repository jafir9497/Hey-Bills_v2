import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../models/warranty_model.dart';

class WarrantyCard extends StatelessWidget {
  final Warranty warranty;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onClaim;

  const WarrantyCard({
    super.key,
    required this.warranty,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: _getBorderColor(),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        warranty.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${warranty.brand} ${warranty.model}'.trim(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),

            const SizedBox(height: 12),

            // Progress Bar
            if (!warranty.isExpired) _buildProgressBar(),

            const SizedBox(height: 12),

            // Details Row
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    icon: Icons.calendar_today,
                    label: 'Expires',
                    value: DateFormat('MMM d, y').format(warranty.warrantyEndDate),
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    icon: Icons.schedule,
                    label: warranty.isExpired ? 'Expired' : 'Days Left',
                    value: warranty.isExpired ? 'Expired' : '${warranty.daysRemaining}',
                  ),
                ),
              ],
            ),

            if (warranty.retailer.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildDetailItem(
                icon: Icons.store,
                label: 'Retailer',
                value: warranty.retailer,
              ),
            ],

            if (warranty.purchasePrice > 0) ...[
              const SizedBox(height: 8),
              _buildDetailItem(
                icon: Icons.attach_money,
                label: 'Purchase Price',
                value: NumberFormat.currency(symbol: '\$').format(warranty.purchasePrice),
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                if (warranty.status == WarrantyStatus.active && onClaim != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onClaim,
                      icon: const Icon(Icons.report_problem, size: 16),
                      label: const Text('Claim'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warningColor,
                        side: BorderSide(color: AppTheme.warningColor),
                      ),
                    ),
                  ),
                
                if (warranty.status == WarrantyStatus.active && onClaim != null)
                  const SizedBox(width: 8),
                
                if (onEdit != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                    ),
                  ),
                
                const SizedBox(width: 8),
                
                // More Options
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        onTap?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility),
                          SizedBox(width: 12),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  child: const Icon(Icons.more_vert, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color backgroundColor;
    Color textColor;
    String label;

    if (warranty.isExpired) {
      backgroundColor = AppTheme.errorColor.withOpacity(0.1);
      textColor = AppTheme.errorColor;
      label = 'Expired';
    } else if (warranty.isExpiringSoon) {
      backgroundColor = AppTheme.warningColor.withOpacity(0.1);
      textColor = AppTheme.warningColor;
      label = 'Expiring Soon';
    } else {
      backgroundColor = AppTheme.successColor.withOpacity(0.1);
      textColor = AppTheme.successColor;
      label = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Warranty Progress',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(warranty.completionPercentage * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: warranty.completionPercentage,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(
            warranty.isExpiringSoon 
                ? AppTheme.warningColor 
                : AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getBorderColor() {
    if (warranty.isExpired) {
      return AppTheme.errorColor.withOpacity(0.3);
    } else if (warranty.isExpiringSoon) {
      return AppTheme.warningColor.withOpacity(0.3);
    } else {
      return AppTheme.primaryColor.withOpacity(0.1);
    }
  }
}
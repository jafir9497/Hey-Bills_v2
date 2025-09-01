import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../models/warranty_model.dart';

class WarrantyStatusFilter extends StatelessWidget {
  final WarrantyStatus? selectedStatus;
  final Function(WarrantyStatus?) onStatusChanged;

  const WarrantyStatusFilter({
    super.key,
    this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildFilterChip(
          label: 'All',
          isSelected: selectedStatus == null,
          onSelected: () => onStatusChanged(null),
        ),
        _buildFilterChip(
          label: 'Active',
          isSelected: selectedStatus == WarrantyStatus.active,
          onSelected: () => onStatusChanged(WarrantyStatus.active),
          color: AppTheme.successColor,
        ),
        _buildFilterChip(
          label: 'Expired',
          isSelected: selectedStatus == WarrantyStatus.expired,
          onSelected: () => onStatusChanged(WarrantyStatus.expired),
          color: AppTheme.errorColor,
        ),
        _buildFilterChip(
          label: 'Claimed',
          isSelected: selectedStatus == WarrantyStatus.claimed,
          onSelected: () => onStatusChanged(WarrantyStatus.claimed),
          color: AppTheme.warningColor,
        ),
        _buildFilterChip(
          label: 'Archived',
          isSelected: selectedStatus == WarrantyStatus.archived,
          onSelected: () => onStatusChanged(WarrantyStatus.archived),
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
  }) {
    final chipColor = color ?? AppTheme.primaryColor;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.grey.shade100,
      selectedColor: chipColor.withOpacity(0.2),
      checkmarkColor: chipColor,
      labelStyle: TextStyle(
        color: isSelected ? chipColor : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? chipColor : Colors.grey.shade300,
      ),
    );
  }
}
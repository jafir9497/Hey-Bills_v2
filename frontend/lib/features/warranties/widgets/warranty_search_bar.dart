import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

class WarrantySearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final VoidCallback? onFilterTap;
  final String hintText;

  const WarrantySearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onFilterTap,
    this.hintText = 'Search warranties...',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.grey.shade500,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  color: Colors.grey.shade500,
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
              if (onFilterTap != null)
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  color: AppTheme.primaryColor,
                  onPressed: onFilterTap,
                ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}
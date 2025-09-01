import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

class TrendIndicator extends StatelessWidget {
  final String title;
  final double value;
  final bool isPercentage;
  final String? subtitle;
  final IconData? customIcon;

  const TrendIndicator({
    super.key,
    required this.title,
    required this.value,
    this.isPercentage = false,
    this.subtitle,
    this.customIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = value > 0;
    final isNeutral = value == 0;

    Color trendColor;
    IconData trendIcon;
    String description;

    if (isNeutral) {
      trendColor = Colors.grey;
      trendIcon = customIcon ?? Icons.trending_flat;
      description = 'No change';
    } else if (isPositive) {
      trendColor = AppTheme.successColor;
      trendIcon = customIcon ?? Icons.trending_up;
      description = 'Increase';
    } else {
      trendColor = AppTheme.errorColor;
      trendIcon = customIcon ?? Icons.trending_down;
      description = 'Decrease';
    }

    final displayValue = isPercentage 
        ? '${isPositive ? '+' : ''}${value.toStringAsFixed(1)}%'
        : value.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: trendColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              trendIcon,
              color: trendColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: trendColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: trendColor,
                ),
              ),
              if (isPercentage && !isNeutral)
                Text(
                  'vs last period',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
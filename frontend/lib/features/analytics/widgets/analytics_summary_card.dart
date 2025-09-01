import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';

class AnalyticsSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final double? trend;
  final VoidCallback? onTap;

  const AnalyticsSummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.trend,
    this.onTap,
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
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
                if (trend != null) _buildTrendIndicator(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator() {
    if (trend == null) return const SizedBox.shrink();

    final isPositive = trend! > 0;
    final isNeutral = trend! == 0;

    Color trendColor;
    IconData trendIcon;

    if (isNeutral) {
      trendColor = Colors.grey;
      trendIcon = Icons.trending_flat;
    } else if (isPositive) {
      trendColor = AppTheme.successColor;
      trendIcon = Icons.trending_up;
    } else {
      trendColor = AppTheme.errorColor;
      trendIcon = Icons.trending_down;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trendIcon,
            size: 12,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text(
            '${isPositive ? '+' : ''}${trend!.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}
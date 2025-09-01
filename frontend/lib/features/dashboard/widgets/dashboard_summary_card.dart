import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';

class DashboardSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final double? trend;
  final VoidCallback? onTap;
  final bool isLoading;

  const DashboardSummaryCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.trend,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: isLoading
            ? const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 20,
                        ),
                      ),
                      if (trend != null) _buildTrendIndicator(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: trendColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            trendIcon,
            size: 10,
            color: trendColor,
          ),
          const SizedBox(width: 2),
          Text(
            '${isPositive ? '+' : ''}${trend!.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: trendColor,
            ),
          ),
        ],
      ),
    );
  }
}
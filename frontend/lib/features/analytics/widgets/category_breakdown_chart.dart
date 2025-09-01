import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../models/analytics_data.dart';

class CategoryBreakdownChart extends StatefulWidget {
  final List<CategorySpending> categorySpending;
  final bool showLegend;
  final bool showPercentages;

  const CategoryBreakdownChart({
    super.key,
    required this.categorySpending,
    this.showLegend = true,
    this.showPercentages = true,
  });

  @override
  State<CategoryBreakdownChart> createState() => _CategoryBreakdownChartState();
}

class _CategoryBreakdownChartState extends State<CategoryBreakdownChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.categorySpending.isEmpty) {
      return const Center(
        child: Text(
          'No category data available',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: _getSections(),
            ),
          ),
        ),
        if (widget.showLegend) ...[
          const SizedBox(height: 16),
          _buildLegend(),
        ],
      ],
    );
  }

  List<PieChartSectionData> _getSections() {
    return widget.categorySpending.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final isTouched = index == touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 80.0 : 70.0;
      final shadows = isTouched ? [const Shadow(color: Colors.black, blurRadius: 2)] : <Shadow>[];

      final color = Color(int.parse(category.color.substring(1, 7), radix: 16) + 0xFF000000);

      return PieChartSectionData(
        color: color,
        value: category.percentage,
        title: widget.showPercentages ? '${category.percentage.toStringAsFixed(1)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: shadows,
        ),
        badgeWidget: isTouched
            ? _buildBadge(category)
            : null,
        badgePositionPercentageOffset: .98,
      );
    }).toList();
  }

  Widget _buildBadge(CategorySpending category) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            category.category,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          Text(
            NumberFormat.currency(symbol: '\$').format(category.amount),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: widget.categorySpending.map((category) {
        final color = Color(int.parse(category.color.substring(1, 7), radix: 16) + 0xFF000000);
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              category.category,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
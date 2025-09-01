import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../models/analytics_data.dart';

class SpendingChart extends StatefulWidget {
  final List<DailySpending> dailySpending;
  final bool showTitles;
  final bool showGrid;

  const SpendingChart({
    super.key,
    required this.dailySpending,
    this.showTitles = true,
    this.showGrid = true,
  });

  @override
  State<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends State<SpendingChart> {
  List<Color> gradientColors = [
    AppTheme.primaryColor,
    AppTheme.primaryVariant,
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.dailySpending.isEmpty) {
      return const Center(
        child: Text(
          'No spending data available',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: widget.showGrid,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval: null,
          verticalInterval: null,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 0.5,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.shade300,
              strokeWidth: 0.5,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: widget.showTitles,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < widget.dailySpending.length) {
                  final date = widget.dailySpending[value.toInt()].date;
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      DateFormat('M/d').format(date),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: null,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toInt()}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                );
              },
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        minX: 0,
        maxX: widget.dailySpending.length - 1.0,
        minY: 0,
        maxY: widget.dailySpending
            .map((e) => e.amount)
            .reduce((a, b) => a > b ? a : b) * 1.1,
        lineBarsData: [
          LineChartBarData(
            spots: widget.dailySpending.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.amount);
            }).toList(),
            isCurved: true,
            gradient: LinearGradient(
              colors: gradientColors,
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(
              show: false,
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: gradientColors
                    .map((color) => color.withOpacity(0.3))
                    .toList(),
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.blueGrey.withOpacity(0.8),
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final flSpot = barSpot;
                final index = flSpot.x.toInt();
                
                if (index < widget.dailySpending.length) {
                  final dailyData = widget.dailySpending[index];
                  return LineTooltipItem(
                    '${DateFormat('MMM d').format(dailyData.date)}\n',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: NumberFormat.currency(symbol: '\$').format(dailyData.amount),
                        style: const TextStyle(
                          color: Colors.yellow,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: '\n${dailyData.transactionCount} transaction${dailyData.transactionCount != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }
                return null;
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
            return spotIndexes.map((spotIndex) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
                FlDotData(
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: AppTheme.primaryColor,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}
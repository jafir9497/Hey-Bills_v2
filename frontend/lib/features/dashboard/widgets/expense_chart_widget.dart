import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';

class ExpenseChartWidget extends StatelessWidget {
  final List<ExpenseData> data;
  final bool isLoading;
  final String period;

  const ExpenseChartWidget({
    super.key,
    required this.data,
    this.isLoading = false,
    this.period = '7 Days',
  });

  @override
  Widget build(BuildContext context) {
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
                'Spending Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                period,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (data.isEmpty)
            _buildEmptyState()
          else
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < data.length) {
                            return Text(
                              data[value.toInt()].label,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.amount);
                      }).toList(),
                      isCurved: true,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: AppTheme.primaryColor,
                            strokeWidth: 1,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primaryColor.withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => Colors.black87,
                      getTooltipItems: (touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final flSpot = barSpot;
                          if (flSpot.x.toInt() < data.length) {
                            final expense = data[flSpot.x.toInt()];
                            return LineTooltipItem(
                              '${expense.label}\n\$${expense.amount.toStringAsFixed(2)}',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            'No expense data',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseData {
  final String label;
  final double amount;
  final DateTime date;

  const ExpenseData({
    required this.label,
    required this.amount,
    required this.date,
  });
}
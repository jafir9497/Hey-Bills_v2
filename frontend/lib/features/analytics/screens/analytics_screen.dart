import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../shared/theme/app_theme.dart';
import '../../../shared/components/loading_overlay.dart';
import '../../../shared/components/empty_state.dart';
import '../providers/analytics_provider.dart';
import '../widgets/spending_chart.dart';
import '../widgets/category_breakdown_chart.dart';
import '../widgets/analytics_summary_card.dart';
import '../widgets/trend_indicator.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '30d';

  final List<String> _periods = ['7d', '30d', '90d', '1y'];
  final List<String> _periodLabels = ['7 Days', '30 Days', '3 Months', '1 Year'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsProvider.notifier).loadAnalyticsData(_selectedPeriod);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analyticsState = ref.watch(analyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _showExportDialog();
                  break;
                case 'refresh':
                  _refreshData();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 12),
                    Text('Export Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Period Selector
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Period: ',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_periods.length, (index) {
                            final period = _periods[index];
                            final label = _periodLabels[index];
                            final isSelected = _selectedPeriod == period;
                            
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (_) => _changePeriod(period),
                                backgroundColor: Colors.white.withOpacity(0.1),
                                selectedColor: Colors.white,
                                labelStyle: TextStyle(
                                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected ? Colors.white : Colors.white54,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Tab Bar
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Trends'),
                  Tab(text: 'Categories'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: analyticsState.when(
        data: (data) => data == null
            ? const EmptyState(
                title: 'No Data Available',
                subtitle: 'Start scanning receipts to see your spending analytics',
                icon: Icons.analytics_outlined,
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(data),
                  _buildTrendsTab(data),
                  _buildCategoriesTab(data),
                ],
              ),
        loading: () => const LoadingOverlay(),
        error: (error, stack) => EmptyState(
          title: 'Error Loading Analytics',
          subtitle: error.toString(),
          icon: Icons.error_outline,
          action: ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Retry'),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(dynamic analyticsData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: AnalyticsSummaryCard(
                  title: 'Total Spent',
                  value: NumberFormat.currency(symbol: '\$')
                      .format(analyticsData.totalSpent),
                  icon: Icons.attach_money,
                  color: AppTheme.primaryColor,
                  trend: analyticsData.trends.monthlyGrowthRate,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AnalyticsSummaryCard(
                  title: 'Daily Average',
                  value: NumberFormat.currency(symbol: '\$')
                      .format(analyticsData.averagePerDay),
                  icon: Icons.today,
                  color: AppTheme.secondaryColor,
                  trend: analyticsData.trends.budgetVariance,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Spending Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spending Over Time',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: SpendingChart(
                      dailySpending: analyticsData.dailySpending,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Quick Insights
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Insights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInsightItem(
                    'Top Category',
                    analyticsData.trends.primaryCategory,
                    Icons.category,
                  ),
                  _buildInsightItem(
                    'Peak Days',
                    analyticsData.trends.peakSpendingDays.join(', '),
                    Icons.calendar_today,
                  ),
                  _buildInsightItem(
                    'Weekly Average',
                    NumberFormat.currency(symbol: '\$')
                        .format(analyticsData.trends.weeklyAverage),
                    Icons.trending_up,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsTab(dynamic analyticsData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trend Indicators
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spending Trends',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TrendIndicator(
                    title: 'Monthly Growth',
                    value: analyticsData.trends.monthlyGrowthRate,
                    isPercentage: true,
                  ),
                  const SizedBox(height: 12),
                  TrendIndicator(
                    title: 'Budget Variance',
                    value: analyticsData.trends.budgetVariance,
                    isPercentage: true,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Monthly Comparison
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Comparison',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: analyticsData.monthlySpending
                            .map((e) => e.amount)
                            .reduce((a, b) => a > b ? a : b) * 1.2,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.blueGrey,
                            tooltipHorizontalAlignment: FLHorizontalAlignment.right,
                            tooltipMargin: -10,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final month = analyticsData.monthlySpending[group.x.toInt()];
                              return BarTooltipItem(
                                '${month.month}\n',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                children: <TextSpan>[
                                  TextSpan(
                                    text: NumberFormat.currency(symbol: '\$').format(rod.toY),
                                    style: const TextStyle(
                                      color: Colors.yellow,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
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
                                if (value.toInt() < analyticsData.monthlySpending.length) {
                                  final month = analyticsData.monthlySpending[value.toInt()];
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      month.month.substring(0, 3),
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 42,
                              interval: null,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '\$${value.toInt()}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: analyticsData.monthlySpending.asMap().entries.map<BarChartGroupData>((entry) {
                          final index = entry.key;
                          final month = entry.value;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: month.amount,
                                color: AppTheme.primaryColor,
                                width: 22,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab(dynamic analyticsData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Category Breakdown Chart
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Spending by Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 250,
                    child: CategoryBreakdownChart(
                      categorySpending: analyticsData.categorySpending,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Category List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Category Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...analyticsData.categorySpending.map<Widget>((category) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Color(int.parse(category.color.substring(1, 7), radix: 16) + 0xFF000000),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${category.transactionCount} transactions',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                NumberFormat.currency(symbol: '\$').format(category.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${category.percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _changePeriod(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    ref.read(analyticsProvider.notifier).loadAnalyticsData(period);
  }

  void _refreshData() {
    ref.read(analyticsProvider.notifier).loadAnalyticsData(_selectedPeriod);
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Analytics'),
        content: const Text(
          'Choose the format to export your analytics data:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportData('csv');
            },
            child: const Text('CSV'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _exportData('json');
            },
            child: const Text('JSON'),
          ),
        ],
      ),
    );
  }

  void _exportData(String format) {
    ref.read(analyticsProvider.notifier).exportData(format, _selectedPeriod);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting data as $format...'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            // TODO: Open export file
          },
        ),
      ),
    );
  }
}
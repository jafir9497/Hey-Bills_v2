import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'analytics_data.g.dart';

/// Analytics data model for spending insights
@JsonSerializable()
class AnalyticsData extends Equatable {
  final String userId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalSpent;
  final double averagePerDay;
  final List<CategorySpending> categorySpending;
  final List<MonthlySpending> monthlySpending;
  final List<DailySpending> dailySpending;
  final SpendingTrends trends;
  final List<TopMerchant> topMerchants;

  const AnalyticsData({
    required this.userId,
    required this.startDate,
    required this.endDate,
    required this.totalSpent,
    required this.averagePerDay,
    required this.categorySpending,
    required this.monthlySpending,
    required this.dailySpending,
    required this.trends,
    required this.topMerchants,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsDataFromJson(json);

  Map<String, dynamic> toJson() => _$AnalyticsDataToJson(this);

  @override
  List<Object?> get props => [
        userId,
        startDate,
        endDate,
        totalSpent,
        averagePerDay,
        categorySpending,
        monthlySpending,
        dailySpending,
        trends,
        topMerchants,
      ];
}

@JsonSerializable()
class CategorySpending extends Equatable {
  final String category;
  final double amount;
  final double percentage;
  final int transactionCount;
  final String color;

  const CategorySpending({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
    required this.color,
  });

  factory CategorySpending.fromJson(Map<String, dynamic> json) =>
      _$CategorySpendingFromJson(json);

  Map<String, dynamic> toJson() => _$CategorySpendingToJson(this);

  @override
  List<Object?> get props => [category, amount, percentage, transactionCount, color];
}

@JsonSerializable()
class MonthlySpending extends Equatable {
  final String month;
  final int year;
  final double amount;
  final int transactionCount;

  const MonthlySpending({
    required this.month,
    required this.year,
    required this.amount,
    required this.transactionCount,
  });

  factory MonthlySpending.fromJson(Map<String, dynamic> json) =>
      _$MonthlySpendingFromJson(json);

  Map<String, dynamic> toJson() => _$MonthlySpendingToJson(this);

  @override
  List<Object?> get props => [month, year, amount, transactionCount];
}

@JsonSerializable()
class DailySpending extends Equatable {
  final DateTime date;
  final double amount;
  final int transactionCount;

  const DailySpending({
    required this.date,
    required this.amount,
    required this.transactionCount,
  });

  factory DailySpending.fromJson(Map<String, dynamic> json) =>
      _$DailySpendingFromJson(json);

  Map<String, dynamic> toJson() => _$DailySpendingToJson(this);

  @override
  List<Object?> get props => [date, amount, transactionCount];
}

@JsonSerializable()
class SpendingTrends extends Equatable {
  final double monthlyGrowthRate;
  final double weeklyAverage;
  final String primaryCategory;
  final List<String> peakSpendingDays;
  final double budgetVariance;

  const SpendingTrends({
    required this.monthlyGrowthRate,
    required this.weeklyAverage,
    required this.primaryCategory,
    required this.peakSpendingDays,
    required this.budgetVariance,
  });

  factory SpendingTrends.fromJson(Map<String, dynamic> json) =>
      _$SpendingTrendsFromJson(json);

  Map<String, dynamic> toJson() => _$SpendingTrendsToJson(this);

  @override
  List<Object?> get props => [
        monthlyGrowthRate,
        weeklyAverage,
        primaryCategory,
        peakSpendingDays,
        budgetVariance,
      ];
}

@JsonSerializable()
class TopMerchant extends Equatable {
  final String name;
  final double totalSpent;
  final int visitCount;
  final String category;

  const TopMerchant({
    required this.name,
    required this.totalSpent,
    required this.visitCount,
    required this.category,
  });

  factory TopMerchant.fromJson(Map<String, dynamic> json) =>
      _$TopMerchantFromJson(json);

  Map<String, dynamic> toJson() => _$TopMerchantToJson(this);

  @override
  List<Object?> get props => [name, totalSpent, visitCount, category];
}
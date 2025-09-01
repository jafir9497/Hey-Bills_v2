import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_error.dart';
import '../../../shared/utils/logger.dart';
import '../models/analytics_data.dart';

class AnalyticsService {
  static final Logger _logger = Logger();
  final Dio _dio = Dio();

  AnalyticsService() {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  /// Get user analytics data
  Future<AnalyticsData> getAnalyticsData({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String period = '30d',
  }) async {
    try {
      _logger.i('Fetching analytics data for user: $userId');

      final queryParams = {
        'userId': userId,
        'period': period,
        if (startDate != null) 'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate.toIso8601String(),
      };

      final response = await _dio.get(
        '/analytics/spending',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final data = AnalyticsData.fromJson(response.data);
        _logger.i('Analytics data fetched successfully');
        return data;
      } else {
        throw NetworkError.serverError();
      }
    } on DioException catch (e) {
      _logger.e('Network error fetching analytics: ${e.message}');
      if (e.response?.statusCode == 404) {
        throw NetworkError.notFound();
      }
      throw NetworkError.connectionFailed();
    } catch (e) {
      _logger.e('Error fetching analytics data: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Get category breakdown
  Future<List<CategorySpending>> getCategoryBreakdown({
    required String userId,
    String period = '30d',
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/categories',
        queryParameters: {
          'userId': userId,
          'period': period,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['categories'];
        return data.map((item) => CategorySpending.fromJson(item)).toList();
      } else {
        throw NetworkError.serverError();
      }
    } catch (e) {
      _logger.e('Error fetching category breakdown: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Get spending trends
  Future<SpendingTrends> getSpendingTrends({
    required String userId,
    String period = '30d',
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/trends',
        queryParameters: {
          'userId': userId,
          'period': period,
        },
      );

      if (response.statusCode == 200) {
        return SpendingTrends.fromJson(response.data);
      } else {
        throw NetworkError.serverError();
      }
    } catch (e) {
      _logger.e('Error fetching spending trends: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Get top merchants
  Future<List<TopMerchant>> getTopMerchants({
    required String userId,
    String period = '30d',
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/merchants',
        queryParameters: {
          'userId': userId,
          'period': period,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['merchants'];
        return data.map((item) => TopMerchant.fromJson(item)).toList();
      } else {
        throw NetworkError.serverError();
      }
    } catch (e) {
      _logger.e('Error fetching top merchants: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Get monthly comparison
  Future<List<MonthlySpending>> getMonthlyComparison({
    required String userId,
    int months = 12,
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/monthly',
        queryParameters: {
          'userId': userId,
          'months': months,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['monthly'];
        return data.map((item) => MonthlySpending.fromJson(item)).toList();
      } else {
        throw NetworkError.serverError();
      }
    } catch (e) {
      _logger.e('Error fetching monthly comparison: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Export analytics data
  Future<String> exportAnalyticsData({
    required String userId,
    String format = 'csv',
    String period = '30d',
  }) async {
    try {
      final response = await _dio.get(
        '/analytics/export',
        queryParameters: {
          'userId': userId,
          'format': format,
          'period': period,
        },
      );

      if (response.statusCode == 200) {
        return response.data['downloadUrl'];
      } else {
        throw NetworkError.serverError();
      }
    } catch (e) {
      _logger.e('Error exporting analytics data: $e');
      throw NetworkError.unknownError();
    }
  }
}
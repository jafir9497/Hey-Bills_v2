import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/providers/auth_provider.dart';
import '../models/analytics_data.dart';
import '../services/analytics_service.dart';

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

final analyticsProvider = StateNotifierProvider<AnalyticsNotifier, AsyncValue<AnalyticsData?>>((ref) {
  final service = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authProvider);
  return AnalyticsNotifier(service, authState);
});

final categoryBreakdownProvider = StateNotifierProvider<CategoryBreakdownNotifier, AsyncValue<List<CategorySpending>>>((ref) {
  final service = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authProvider);
  return CategoryBreakdownNotifier(service, authState);
});

final spendingTrendsProvider = StateNotifierProvider<SpendingTrendsNotifier, AsyncValue<SpendingTrends?>>((ref) {
  final service = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authProvider);
  return SpendingTrendsNotifier(service, authState);
});

final topMerchantsProvider = StateNotifierProvider<TopMerchantsNotifier, AsyncValue<List<TopMerchant>>>((ref) {
  final service = ref.watch(analyticsServiceProvider);
  final authState = ref.watch(authProvider);
  return TopMerchantsNotifier(service, authState);
});

class AnalyticsNotifier extends StateNotifier<AsyncValue<AnalyticsData?>> {
  final AnalyticsService _service;
  final dynamic _authState;
  final Logger _logger = Logger();

  AnalyticsNotifier(this._service, this._authState) : super(const AsyncValue.loading()) {
    if (_authState?.user?.id != null) {
      loadAnalyticsData('30d');
    }
  }

  Future<void> loadAnalyticsData(String period) async {
    try {
      state = const AsyncValue.loading();
      
      if (_authState?.user?.id == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final data = await _service.getAnalyticsData(
        userId: _authState.user.id,
        period: period,
      );

      state = AsyncValue.data(data);
    } catch (error, stack) {
      _logger.e('Error loading analytics data: $error');
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> refreshData([String period = '30d']) async {
    await loadAnalyticsData(period);
  }

  Future<void> exportData(String format, String period) async {
    try {
      if (_authState?.user?.id == null) return;

      final downloadUrl = await _service.exportAnalyticsData(
        userId: _authState.user.id,
        format: format,
        period: period,
      );

      // TODO: Handle download URL (open in browser or download)
      _logger.i('Export URL: $downloadUrl');
    } catch (error) {
      _logger.e('Error exporting data: $error');
      rethrow;
    }
  }
}

class CategoryBreakdownNotifier extends StateNotifier<AsyncValue<List<CategorySpending>>> {
  final AnalyticsService _service;
  final dynamic _authState;
  final Logger _logger = Logger();

  CategoryBreakdownNotifier(this._service, this._authState) : super(const AsyncValue.loading());

  Future<void> loadCategoryBreakdown(String period) async {
    try {
      state = const AsyncValue.loading();
      
      if (_authState?.user?.id == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final data = await _service.getCategoryBreakdown(
        userId: _authState.user.id,
        period: period,
      );

      state = AsyncValue.data(data);
    } catch (error, stack) {
      _logger.e('Error loading category breakdown: $error');
      state = AsyncValue.error(error, stack);
    }
  }
}

class SpendingTrendsNotifier extends StateNotifier<AsyncValue<SpendingTrends?>> {
  final AnalyticsService _service;
  final dynamic _authState;
  final Logger _logger = Logger();

  SpendingTrendsNotifier(this._service, this._authState) : super(const AsyncValue.loading());

  Future<void> loadSpendingTrends(String period) async {
    try {
      state = const AsyncValue.loading();
      
      if (_authState?.user?.id == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final data = await _service.getSpendingTrends(
        userId: _authState.user.id,
        period: period,
      );

      state = AsyncValue.data(data);
    } catch (error, stack) {
      _logger.e('Error loading spending trends: $error');
      state = AsyncValue.error(error, stack);
    }
  }
}

class TopMerchantsNotifier extends StateNotifier<AsyncValue<List<TopMerchant>>> {
  final AnalyticsService _service;
  final dynamic _authState;
  final Logger _logger = Logger();

  TopMerchantsNotifier(this._service, this._authState) : super(const AsyncValue.loading());

  Future<void> loadTopMerchants(String period, int limit) async {
    try {
      state = const AsyncValue.loading();
      
      if (_authState?.user?.id == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final data = await _service.getTopMerchants(
        userId: _authState.user.id,
        period: period,
        limit: limit,
      );

      state = AsyncValue.data(data);
    } catch (error, stack) {
      _logger.e('Error loading top merchants: $error');
      state = AsyncValue.error(error, stack);
    }
  }
}
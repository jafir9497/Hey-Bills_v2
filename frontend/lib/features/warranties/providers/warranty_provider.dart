import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/providers/auth_provider.dart';
import '../models/warranty_model.dart';
import '../services/warranty_service.dart';

final warrantyServiceProvider = Provider<WarrantyService>((ref) {
  return WarrantyService();
});

final warrantyProvider = StateNotifierProvider<WarrantyNotifier, AsyncValue<List<Warranty>>>((ref) {
  final service = ref.watch(warrantyServiceProvider);
  final authState = ref.watch(authProvider);
  return WarrantyNotifier(service, authState);
});

final warrantyDetailProvider = StateNotifierProvider.family<WarrantyDetailNotifier, AsyncValue<Warranty?>, String>((ref, warrantyId) {
  final service = ref.watch(warrantyServiceProvider);
  return WarrantyDetailNotifier(service, warrantyId);
});

final warrantyNotificationsProvider = StateNotifierProvider<WarrantyNotificationsNotifier, AsyncValue<List<WarrantyNotification>>>((ref) {
  final service = ref.watch(warrantyServiceProvider);
  final authState = ref.watch(authProvider);
  return WarrantyNotificationsNotifier(service, authState);
});

class WarrantyNotifier extends StateNotifier<AsyncValue<List<Warranty>>> {
  final WarrantyService _service;
  final dynamic _authState;
  final Logger _logger = Logger();

  WarrantyNotifier(this._service, this._authState) : super(const AsyncValue.loading()) {
    if (_authState?.user?.id != null) {
      loadWarranties();
    }
  }

  Future<void> loadWarranties() async {
    try {
      state = const AsyncValue.loading();
      
      if (_authState?.user?.id == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final warranties = await _service.getWarranties(
        userId: _authState.user.id,
      );

      state = AsyncValue.data(warranties);
    } catch (error, stack) {
      _logger.e('Error loading warranties: $error');
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> addWarranty(Warranty warranty) async {
    try {
      final newWarranty = await _service.createWarranty(warranty);
      
      state.whenData((warranties) {
        state = AsyncValue.data([...warranties, newWarranty]);
      });
    } catch (error) {
      _logger.e('Error adding warranty: $error');
      rethrow;
    }
  }

  Future<void> updateWarranty(Warranty warranty) async {
    try {
      final updatedWarranty = await _service.updateWarranty(warranty);
      
      state.whenData((warranties) {
        final updatedList = warranties.map((w) {
          return w.id == warranty.id ? updatedWarranty : w;
        }).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (error) {
      _logger.e('Error updating warranty: $error');
      rethrow;
    }
  }

  Future<void> deleteWarranty(String warrantyId) async {
    try {
      await _service.deleteWarranty(warrantyId);
      
      state.whenData((warranties) {
        final filteredList = warranties.where((w) => w.id != warrantyId).toList();
        state = AsyncValue.data(filteredList);
      });
    } catch (error) {
      _logger.e('Error deleting warranty: $error');
      rethrow;
    }
  }

  Future<void> claimWarranty(String warrantyId, String issueDescription) async {
    try {
      await _service.claimWarranty(warrantyId, issueDescription);
      
      // Reload warranties to get updated status
      await loadWarranties();
    } catch (error) {
      _logger.e('Error claiming warranty: $error');
      rethrow;
    }
  }

  List<Warranty> getExpiringWarranties([int days = 30]) {
    return state.whenOrNull(
      data: (warranties) => warranties.where((warranty) {
        final daysUntilExpiry = warranty.warrantyEndDate.difference(DateTime.now()).inDays;
        return daysUntilExpiry <= days && daysUntilExpiry > 0;
      }).toList(),
    ) ?? [];
  }

  List<Warranty> getExpiredWarranties() {
    return state.whenOrNull(
      data: (warranties) => warranties.where((warranty) => warranty.isExpired).toList(),
    ) ?? [];
  }
}

class WarrantyDetailNotifier extends StateNotifier<AsyncValue<Warranty?>> {
  final WarrantyService _service;
  final String _warrantyId;
  final Logger _logger = Logger();

  WarrantyDetailNotifier(this._service, this._warrantyId) : super(const AsyncValue.loading()) {
    loadWarranty();
  }

  Future<void> loadWarranty() async {
    try {
      state = const AsyncValue.loading();
      
      final warranty = await _service.getWarranty(_warrantyId);
      
      state = AsyncValue.data(warranty);
    } catch (error, stack) {
      _logger.e('Error loading warranty detail: $error');
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> refreshWarranty() async {
    await loadWarranty();
  }
}

class WarrantyNotificationsNotifier extends StateNotifier<AsyncValue<List<WarrantyNotification>>> {
  final WarrantyService _service;
  final dynamic _authState;
  final Logger _logger = Logger();

  WarrantyNotificationsNotifier(this._service, this._authState) : super(const AsyncValue.loading()) {
    if (_authState?.user?.id != null) {
      loadNotifications();
    }
  }

  Future<void> loadNotifications() async {
    try {
      state = const AsyncValue.loading();
      
      if (_authState?.user?.id == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final notifications = await _service.getWarrantyNotifications(
        userId: _authState.user.id,
      );

      state = AsyncValue.data(notifications);
    } catch (error, stack) {
      _logger.e('Error loading warranty notifications: $error');
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _service.markNotificationAsRead(notificationId);
      
      state.whenData((notifications) {
        final updatedList = notifications.map((n) {
          return n.id == notificationId ? n.copyWith(isRead: true) : n;
        }).toList();
        state = AsyncValue.data(updatedList);
      });
    } catch (error) {
      _logger.e('Error marking notification as read: $error');
      rethrow;
    }
  }

  int get unreadCount {
    return state.whenOrNull(
      data: (notifications) => notifications.where((n) => !n.isRead).length,
    ) ?? 0;
  }
}
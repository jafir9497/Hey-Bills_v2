import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/app_error.dart';
import '../../../shared/utils/logger.dart';
import '../models/warranty_model.dart';

class WarrantyService {
  static final Logger _logger = Logger();
  final Dio _dio = Dio();

  WarrantyService() {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  /// Get all warranties for a user
  Future<List<Warranty>> getWarranties({
    required String userId,
  }) async {
    try {
      _logger.i('Fetching warranties for user: $userId');

      final response = await _dio.get(
        '/warranties',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['warranties'];
        final warranties = data.map((item) => Warranty.fromJson(item)).toList();
        
        _logger.i('Fetched ${warranties.length} warranties');
        return warranties;
      } else {
        throw NetworkError.serverError();
      }
    } on DioException catch (e) {
      _logger.e('Network error fetching warranties: ${e.message}');
      if (e.response?.statusCode == 404) {
        throw NetworkError.notFound();
      }
      throw NetworkError.connectionFailed();
    } catch (e) {
      _logger.e('Error fetching warranties: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Get a specific warranty by ID
  Future<Warranty> getWarranty(String warrantyId) async {
    try {
      _logger.i('Fetching warranty: $warrantyId');

      final response = await _dio.get('/warranties/$warrantyId');

      if (response.statusCode == 200) {
        return Warranty.fromJson(response.data['warranty']);
      } else {
        throw NetworkError.serverError();
      }
    } on DioException catch (e) {
      _logger.e('Network error fetching warranty: ${e.message}');
      if (e.response?.statusCode == 404) {
        throw NetworkError.notFound();
      }
      throw NetworkError.connectionFailed();
    } catch (e) {
      _logger.e('Error fetching warranty: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Create a new warranty
  Future<Warranty> createWarranty(Warranty warranty) async {
    try {
      _logger.i('Creating warranty: ${warranty.productName}');

      final response = await _dio.post(
        '/warranties',
        data: warranty.toJson(),
      );

      if (response.statusCode == 201) {
        final createdWarranty = Warranty.fromJson(response.data['warranty']);
        _logger.i('Warranty created successfully: ${createdWarranty.id}');
        return createdWarranty;
      } else {
        throw NetworkError.serverError();
      }
    } on DioException catch (e) {
      _logger.e('Network error creating warranty: ${e.message}');
      if (e.response?.statusCode == 400) {
        throw ValidationError.invalidData();
      }
      throw NetworkError.connectionFailed();
    } catch (e) {
      _logger.e('Error creating warranty: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Update an existing warranty
  Future<Warranty> updateWarranty(Warranty warranty) async {
    try {
      _logger.i('Updating warranty: ${warranty.id}');

      final response = await _dio.put(
        '/warranties/${warranty.id}',
        data: warranty.toJson(),
      );

      if (response.statusCode == 200) {
        final updatedWarranty = Warranty.fromJson(response.data['warranty']);
        _logger.i('Warranty updated successfully');
        return updatedWarranty;
      } else {
        throw NetworkError.serverError();
      }
    } on DioException catch (e) {
      _logger.e('Network error updating warranty: ${e.message}');
      if (e.response?.statusCode == 404) {
        throw NetworkError.notFound();
      } else if (e.response?.statusCode == 400) {
        throw ValidationError.invalidData();
      }
      throw NetworkError.connectionFailed();
    } catch (e) {
      _logger.e('Error updating warranty: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Delete a warranty
  Future<void> deleteWarranty(String warrantyId) async {
    try {
      _logger.i('Deleting warranty: $warrantyId');

      final response = await _dio.delete('/warranties/$warrantyId');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw NetworkError.serverError();
      }

      _logger.i('Warranty deleted successfully');
    } on DioException catch (e) {
      _logger.e('Network error deleting warranty: ${e.message}');
      if (e.response?.statusCode == 404) {
        throw NetworkError.notFound();
      }
      throw NetworkError.connectionFailed();
    } catch (e) {
      _logger.e('Error deleting warranty: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Create a warranty claim
  Future<WarrantyClaim> claimWarranty(String warrantyId, String issueDescription) async {
    try {
      _logger.i('Creating warranty claim for: $warrantyId');

      final response = await _dio.post(
        '/warranties/$warrantyId/claims',
        data: {
          'issueDescription': issueDescription,
          'claimDate': DateTime.now().toIso8601String(),
        },
      );

      if (response.statusCode == 201) {
        final claim = WarrantyClaim.fromJson(response.data['claim']);
        _logger.i('Warranty claim created successfully');
        return claim;
      } else {
        throw NetworkError.serverError();
      }
    } on DioException catch (e) {
      _logger.e('Network error creating warranty claim: ${e.message}');
      if (e.response?.statusCode == 400) {
        throw ValidationError.invalidData();
      } else if (e.response?.statusCode == 404) {
        throw NetworkError.notFound();
      }
      throw NetworkError.connectionFailed();
    } catch (e) {
      _logger.e('Error creating warranty claim: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Get warranty claims for a warranty
  Future<List<WarrantyClaim>> getWarrantyClaims(String warrantyId) async {
    try {
      final response = await _dio.get('/warranties/$warrantyId/claims');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['claims'];
        return data.map((item) => WarrantyClaim.fromJson(item)).toList();
      } else {
        throw NetworkError.serverError();
      }
    } catch (e) {
      _logger.e('Error fetching warranty claims: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Get warranty notifications for a user
  Future<List<WarrantyNotification>> getWarrantyNotifications({
    required String userId,
  }) async {
    try {
      final response = await _dio.get(
        '/warranties/notifications',
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['notifications'];
        return data.map((item) => WarrantyNotification.fromJson(item)).toList();
      } else {
        throw NetworkError.serverError();
      }
    } catch (e) {
      _logger.e('Error fetching warranty notifications: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Mark a warranty notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _dio.patch(
        '/warranties/notifications/$notificationId',
        data: {'isRead': true},
      );
    } catch (e) {
      _logger.e('Error marking notification as read: $e');
      throw NetworkError.unknownError();
    }
  }

  /// Get expiring warranties
  Future<List<Warranty>> getExpiringWarranties({
    required String userId,
    int days = 30,
  }) async {
    try {
      final response = await _dio.get(
        '/warranties/expiring',
        queryParameters: {
          'userId': userId,
          'days': days,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['warranties'];
        return data.map((item) => Warranty.fromJson(item)).toList();
      } else {
        throw NetworkError.serverError();
      }
    } catch (e) {
      _logger.e('Error fetching expiring warranties: $e');
      throw NetworkError.unknownError();
    }
  }
}
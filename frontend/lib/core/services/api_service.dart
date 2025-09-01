import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../error/app_error.dart';
import '../../shared/utils/logger.dart';

/// API Service for handling HTTP requests
class ApiService {
  late final Dio _dio;
  static const Duration _defaultTimeout = Duration(seconds: 30);

  ApiService({String? baseUrl}) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://localhost:3001',
      connectTimeout: _defaultTimeout,
      receiveTimeout: _defaultTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        AppLogger.debug('API Request: ${options.method} ${options.path}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        AppLogger.debug('API Response: ${response.statusCode} ${response.requestOptions.path}');
        handler.next(response);
      },
      onError: (error, handler) {
        AppLogger.error('API Error: ${error.requestOptions.path}', error);
        handler.next(error);
      },
    ));
  }

  /// GET request
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        options: Options(headers: headers),
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<Map<String, dynamic>> put(
    String path, {
    dynamic data,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        options: Options(headers: headers),
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        options: Options(headers: headers),
      );
      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Upload file
  Future<Map<String, dynamic>> uploadFile(
    String path,
    File file, {
    String fieldName = 'file',
    Map<String, String>? headers,
    Map<String, String>? additionalData,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final formData = FormData();
      
      // Add file
      formData.files.add(MapEntry(
        fieldName,
        await MultipartFile.fromFile(file.path),
      ));

      // Add additional data
      if (additionalData != null) {
        for (final entry in additionalData.entries) {
          formData.fields.add(MapEntry(entry.key, entry.value));
        }
      }

      final response = await _dio.post(
        path,
        data: formData,
        options: Options(headers: headers),
        onSendProgress: onSendProgress,
      );

      return _handleResponse(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle successful response
  Map<String, dynamic> _handleResponse(Response response) {
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    } else if (response.data is String) {
      try {
        return json.decode(response.data) as Map<String, dynamic>;
      } catch (e) {
        return {'data': response.data};
      }
    } else {
      return {'data': response.data};
    }
  }

  /// Handle API errors
  AppError _handleError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return NetworkError.timeout();
        case DioExceptionType.connectionError:
          return NetworkError.connectionFailed();
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          final message = error.response?.data?['message'] ?? error.message;
          
          switch (statusCode) {
            case 400:
              return ValidationError.invalidData(message: message);
            case 401:
              return AuthError.unauthorized();
            case 403:
              return AuthError.forbidden();
            case 404:
              return NetworkError.notFound();
            case 422:
              return ValidationError.invalidData(message: message);
            case 429:
              return NetworkError.rateLimited();
            case 500:
              return NetworkError.serverError();
            default:
              return NetworkError.unknownError(message: message);
          }
        case DioExceptionType.cancel:
          return NetworkError.cancelled();
        default:
          return NetworkError.unknownError(message: error.message);
      }
    } else {
      return NetworkError.unknownError(message: error.toString());
    }
  }

  /// Set authorization token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear authorization token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Update base URL
  void updateBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
  }
}
import 'package:supabase_flutter/supabase_flutter.dart';

/// Base class for all application errors
abstract class AppError implements Exception {
  const AppError(this.message, [this.details]);

  final String message;
  final dynamic details;

  @override
  String toString() => message;
}

/// Authentication related errors
class AuthError extends AppError {
  const AuthError(super.message, [super.details]);

  factory AuthError.fromSupabaseException(AuthException e) {
    switch (e.statusCode) {
      case '400':
        return const AuthError('Invalid credentials provided');
      case '422':
        return const AuthError('Email or password is invalid');
      case '429':
        return const AuthError('Too many requests. Please try again later');
      default:
        return AuthError('Authentication failed: ${e.message}');
    }
  }
}

/// Network related errors
class NetworkError extends AppError {
  const NetworkError(super.message, [super.details]);

  factory NetworkError.noConnection() {
    return const NetworkError('No internet connection available');
  }

  factory NetworkError.timeout() {
    return const NetworkError('Request timed out. Please try again');
  }

  factory NetworkError.serverError() {
    return const NetworkError('Server error. Please try again later');
  }
}

/// Database related errors
class DatabaseError extends AppError {
  const DatabaseError(super.message, [super.details]);

  factory DatabaseError.fromPostgrestException(PostgrestException e) {
    switch (e.code) {
      case '23505':
        return const DatabaseError('Duplicate entry found');
      case '23503':
        return const DatabaseError('Referenced record not found');
      case '42501':
        return const DatabaseError('Access denied');
      default:
        return DatabaseError('Database error: ${e.message}');
    }
  }
}

/// File storage related errors
class StorageError extends AppError {
  const StorageError(super.message, [super.details]);

  factory StorageError.fileNotFound() {
    return const StorageError('File not found');
  }

  factory StorageError.fileTooLarge() {
    return const StorageError('File size exceeds the maximum limit');
  }

  factory StorageError.invalidFileType() {
    return const StorageError('File type is not supported');
  }

  factory StorageError.fromStorageException(StorageException e) {
    switch (e.statusCode) {
      case '400':
        return const StorageError('Invalid file or request');
      case '413':
        return const StorageError('File size too large');
      case '415':
        return const StorageError('File type not supported');
      default:
        return StorageError('Storage error: ${e.message}');
    }
  }
}

/// OCR processing errors
class OCRError extends AppError {
  const OCRError(super.message, [super.details]);

  factory OCRError.processingFailed() {
    return const OCRError('Failed to process image. Please try with a clearer image');
  }

  factory OCRError.noTextFound() {
    return const OCRError('No text found in the image');
  }

  factory OCRError.invalidImage() {
    return const OCRError('Invalid or corrupted image file');
  }
}

/// Validation errors
class ValidationError extends AppError {
  const ValidationError(super.message, [super.details]);

  factory ValidationError.requiredField(String field) {
    return ValidationError('$field is required');
  }

  factory ValidationError.invalidEmail() {
    return const ValidationError('Please enter a valid email address');
  }

  factory ValidationError.passwordTooWeak() {
    return const ValidationError('Password must be at least 6 characters long');
  }

  factory ValidationError.invalidAmount() {
    return const ValidationError('Please enter a valid amount');
  }

  factory ValidationError.pastDate() {
    return const ValidationError('Date cannot be in the past');
  }
}

/// Generic application error
class GenericError extends AppError {
  const GenericError(super.message, [super.details]);

  factory GenericError.unknown() {
    return const GenericError('An unexpected error occurred. Please try again');
  }
}

/// Error handler utility class
class ErrorHandler {
  /// Convert various exceptions to AppError
  static AppError handleError(dynamic error) {
    if (error is AppError) {
      return error;
    }

    if (error is AuthException) {
      return AuthError.fromSupabaseException(error);
    }

    if (error is PostgrestException) {
      return DatabaseError.fromPostgrestException(error);
    }

    if (error is StorageException) {
      return StorageError.fromStorageException(error);
    }

    // Network errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('HttpException')) {
      return NetworkError.noConnection();
    }

    if (error.toString().contains('TimeoutException')) {
      return NetworkError.timeout();
    }

    // Generic error for unknown exceptions
    return GenericError('An unexpected error occurred: ${error.toString()}');
  }

  /// Get user-friendly error message
  static String getUserMessage(AppError error) {
    // You can customize messages here based on error type
    return error.message;
  }
}
import 'package:logger/logger.dart';

/// Application logger singleton
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  /// Log verbose message
  static void verbose(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.t(message, error: error, stackTrace: stackTrace);
  }

  /// Log debug message
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// Log info message
  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// Log error message
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log fatal message
  static void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }
}

// Legacy Logger class for backward compatibility
class Logger {
  static void i(String message) => AppLogger.info(message);
  static void d(String message) => AppLogger.debug(message);
  static void w(String message) => AppLogger.warning(message);
  static void e(String message, [dynamic error, StackTrace? stackTrace]) => 
      AppLogger.error(message, error, stackTrace);
}
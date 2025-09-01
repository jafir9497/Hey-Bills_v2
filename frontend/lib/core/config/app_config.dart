import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // App Information
  static String get appName => dotenv.env['APP_NAME'] ?? 'Hey Bills';
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0+1';
  static String get packageName => dotenv.env['PACKAGE_NAME'] ?? 'com.heybills.app';
  
  // Environment
  static String get environment => dotenv.env['FLUTTER_ENV'] ?? 'development';
  static bool get isDebugMode => kDebugMode;
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  
  // Supabase configuration
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  // API Configuration
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
  static String get apiVersion => dotenv.env['API_VERSION'] ?? 'v1';
  static String get websocketUrl => dotenv.env['WEBSOCKET_URL'] ?? 'ws://localhost:3000';
  
  // Deep Linking
  static String get urlScheme => dotenv.env['URL_SCHEME'] ?? 'heybills';
  static String get deepLinkHost => dotenv.env['DEEP_LINK_HOST'] ?? 'app';
  
  // OAuth Configuration
  static String get googleClientIdAndroid => dotenv.env['GOOGLE_CLIENT_ID_ANDROID'] ?? '';
  static String get googleClientIdIos => dotenv.env['GOOGLE_CLIENT_ID_IOS'] ?? '';
  static String get googleClientIdWeb => dotenv.env['GOOGLE_CLIENT_ID_WEB'] ?? '';
  
  // Feature Flags
  static bool get enableBiometricAuth => _getBool('ENABLE_BIOMETRIC_AUTH', true);
  static bool get enableDarkMode => _getBool('ENABLE_DARK_MODE', true);
  static bool get enableOfflineMode => _getBool('ENABLE_OFFLINE_MODE', true);
  static bool get enablePushNotifications => _getBool('ENABLE_PUSH_NOTIFICATIONS', true);
  static bool get enableOcrScanning => _getBool('ENABLE_OCR_SCANNING', true);
  static bool get enableAiChat => _getBool('ENABLE_AI_CHAT', true);
  static bool get enableVoiceSearch => _getBool('ENABLE_VOICE_SEARCH', false);
  static bool get enableLocationTracking => _getBool('ENABLE_LOCATION_TRACKING', false);
  
  // Performance Configuration
  static int get networkTimeoutSeconds => int.tryParse(dotenv.env['NETWORK_TIMEOUT_SECONDS'] ?? '30') ?? 30;
  static int get retryAttempts => int.tryParse(dotenv.env['RETRY_ATTEMPTS'] ?? '3') ?? 3;
  static int get retryDelaySeconds => int.tryParse(dotenv.env['RETRY_DELAY_SECONDS'] ?? '2') ?? 2;
  
  // OCR Configuration
  static int get maxImageSizeMB => int.tryParse(dotenv.env['MAX_IMAGE_SIZE_MB'] ?? '10') ?? 10;
  static bool get compressImages => _getBool('COMPRESS_IMAGES', true);
  static int get imageQuality => int.tryParse(dotenv.env['IMAGE_QUALITY'] ?? '80') ?? 80;
  
  // Cache Configuration
  static int get maxLocalStorageSizeMB => int.tryParse(dotenv.env['MAX_LOCAL_STORAGE_SIZE_MB'] ?? '100') ?? 100;
  static int get cacheExpiryHours => int.tryParse(dotenv.env['CACHE_EXPIRY_HOURS'] ?? '24') ?? 24;
  
  // Animation Configuration
  static bool get enableAnimations => _getBool('ENABLE_ANIMATIONS', true);
  static int get animationDuration => int.tryParse(dotenv.env['ANIMATION_DURATION'] ?? '300') ?? 300;
  
  // Security Configuration
  static bool get enableDataEncryption => _getBool('ENABLE_DATA_ENCRYPTION', true);
  static bool get enableBiometricLock => _getBool('ENABLE_BIOMETRIC_LOCK', true);
  static int get autoLockTimeout => int.tryParse(dotenv.env['AUTO_LOCK_TIMEOUT'] ?? '300') ?? 300;
  
  // Analytics Configuration
  static bool get enableAnalytics => _getBool('ENABLE_ANALYTICS', true);
  static bool get enableCrashReporting => _getBool('ENABLE_CRASH_REPORTING', true);
  static bool get enableUsageTracking => _getBool('ENABLE_USAGE_TRACKING', false);
  
  // Support URLs
  static String get supportEmail => dotenv.env['SUPPORT_EMAIL'] ?? 'support@heybills.com';
  static String get supportUrl => dotenv.env['SUPPORT_URL'] ?? 'https://heybills.com/support';
  static String get privacyPolicyUrl => dotenv.env['PRIVACY_POLICY_URL'] ?? 'https://heybills.com/privacy';
  static String get termsOfServiceUrl => dotenv.env['TERMS_OF_SERVICE_URL'] ?? 'https://heybills.com/terms';
  
  // Performance targets from architecture
  static const Duration appLaunchTarget = Duration(seconds: 3);
  static const Duration ocrProcessingTarget = Duration(seconds: 5);
  static const Duration apiResponseTarget = Duration(milliseconds: 200);
  
  // Helper method to parse boolean environment variables
  static bool _getBool(String key, bool defaultValue) {
    final value = dotenv.env[key]?.toLowerCase();
    if (value == null) return defaultValue;
    return value == 'true' || value == '1' || value == 'yes';
  }
  
  // Validation method
  static bool validateConfiguration() {
    final requiredVars = {
      'SUPABASE_URL': supabaseUrl,
      'SUPABASE_ANON_KEY': supabaseAnonKey,
    };
    
    for (final entry in requiredVars.entries) {
      if (entry.value.isEmpty) {
        if (kDebugMode) {
          print('❌ Missing required environment variable: ${entry.key}');
        }
        return false;
      }
    }
    
    return true;
  }
  
  // Initialize method to load environment
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
    
    if (kDebugMode) {
      print('🚀 App Configuration Initialized');
      print('   App Name: $appName');
      print('   Version: $appVersion');
      print('   Environment: $environment');
      print('   Package: $packageName');
    }
  }
}
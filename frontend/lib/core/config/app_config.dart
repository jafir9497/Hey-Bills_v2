import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Hey Bills';
  static const String appVersion = '1.0.0';
  
  // Supabase configuration
  static const String supabaseUrl = kDebugMode 
      ? 'https://your-project.supabase.co' // Development
      : 'https://your-project.supabase.co'; // Production
      
  static const String supabaseAnonKey = kDebugMode 
      ? 'your-anon-key' // Development
      : 'your-anon-key'; // Production
  
  // OCR Configuration
  static const Duration ocrTimeout = Duration(seconds: 30);
  static const int maxImageSizeMB = 10;
  
  // Performance targets from architecture
  static const Duration appLaunchTarget = Duration(seconds: 3);
  static const Duration ocrProcessingTarget = Duration(seconds: 5);
  static const Duration apiResponseTarget = Duration(milliseconds: 200);
  
  // Feature flags
  static const bool enableAnalytics = true;
  static const bool enablePushNotifications = true;
  static const bool enableOfflineMode = false;
}
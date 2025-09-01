class AppConstants {
  // App information
  static const String appName = 'Hey Bills';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'AI-Powered Financial Wellness Companion';
  
  // API configuration
  static const String baseUrl = 'https://hey-bills-api.com';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  
  // Image and file limits
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int maxImageWidth = 1920;
  static const int maxImageHeight = 1920;
  static const int imageQuality = 85;
  
  // Storage buckets
  static const String receiptsBucket = 'receipts';
  static const String avatarsBucket = 'avatars';
  static const String documentsBucket = 'documents';
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Receipt categories
  static const List<String> defaultCategories = [
    'Food & Dining',
    'Shopping',
    'Transportation',
    'Healthcare',
    'Entertainment',
    'Utilities',
    'Education',
    'Home & Garden',
    'Travel',
    'Business',
    'Other',
  ];
  
  // Currency settings
  static const String defaultCurrency = 'USD';
  static const String currencySymbol = '\$';
  
  // Date formats
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';
  static const String displayDateFormat = 'MMM dd, yyyy';
  static const String displayDateTimeFormat = 'MMM dd, yyyy \'at\' h:mm a';
  
  // OCR configuration
  static const double minOCRConfidence = 0.5;
  static const int maxOCRRetries = 3;
  static const Duration ocrTimeout = Duration(seconds: 60);
  
  // Analytics tracking
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  
  // Feature flags
  static const bool enableBiometricAuth = true;
  static const bool enablePushNotifications = true;
  static const bool enableOfflineMode = true;
  static const bool enableDataExport = true;
  
  // Local storage keys
  static const String userPreferencesKey = 'user_preferences';
  static const String authTokenKey = 'auth_token';
  static const String lastSyncKey = 'last_sync';
  static const String offlineDataKey = 'offline_data';
  
  // Deep linking
  static const String urlScheme = 'heybills';
  static const String universalLinkDomain = 'app.heybills.com';
  
  // Support and help
  static const String supportEmail = 'support@heybills.com';
  static const String privacyPolicyUrl = 'https://heybills.com/privacy';
  static const String termsOfServiceUrl = 'https://heybills.com/terms';
  static const String helpCenterUrl = 'https://help.heybills.com';
  
  // Social media
  static const String twitterUrl = 'https://twitter.com/heybills';
  static const String facebookUrl = 'https://facebook.com/heybills';
  static const String linkedinUrl = 'https://linkedin.com/company/heybills';
  
  // Animations
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  
  // Network
  static const Duration cacheMaxAge = Duration(hours: 1);
  static const Duration cacheStaleWhileRevalidate = Duration(hours: 24);
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 50;
  
  // Receipt validation
  static const double minReceiptAmount = 0.01;
  static const double maxReceiptAmount = 999999.99;
  static const int maxMerchantNameLength = 100;
  static const int maxNotesLength = 500;
  
  // Warranty settings
  static const int defaultWarrantyMonths = 12;
  static const int maxWarrantyYears = 10;
  static const List<int> warrantyDurationOptions = [
    3, 6, 12, 18, 24, 36, 48, 60,
  ]; // months
  
  // Notification settings
  static const int defaultWarrantyReminderDays = 30;
  static const List<int> reminderDayOptions = [
    7, 14, 30, 60, 90,
  ];
  
  // Subscription plans (for future use)
  static const String freePlanId = 'free';
  static const String proPlanId = 'pro';
  static const String premiumPlanId = 'premium';
  
  // Rate limiting
  static const int maxApiCallsPerMinute = 60;
  static const int maxUploadSizePerHour = 100 * 1024 * 1024; // 100MB
  
  // Error messages
  static const String networkErrorMessage = 'Please check your internet connection and try again.';
  static const String serverErrorMessage = 'Server error occurred. Please try again later.';
  static const String unauthorizedErrorMessage = 'Please log in again to continue.';
  static const String forbiddenErrorMessage = 'You don\'t have permission to perform this action.';
  static const String notFoundErrorMessage = 'The requested resource was not found.';
  static const String timeoutErrorMessage = 'Request timed out. Please try again.';
  static const String genericErrorMessage = 'An unexpected error occurred. Please try again.';
  
  // Success messages
  static const String receiptSavedMessage = 'Receipt saved successfully!';
  static const String receiptUpdatedMessage = 'Receipt updated successfully!';
  static const String receiptDeletedMessage = 'Receipt deleted successfully!';
  static const String profileUpdatedMessage = 'Profile updated successfully!';
  
  // Loading messages
  static const String loadingReceiptsMessage = 'Loading receipts...';
  static const String processingImageMessage = 'Processing image...';
  static const String savingReceiptMessage = 'Saving receipt...';
  static const String uploadingImageMessage = 'Uploading image...';
  
  // Empty state messages
  static const String noReceiptsMessage = 'No receipts found';
  static const String noReceiptsSubMessage = 'Start by adding your first receipt';
  static const String noWarrantiesMessage = 'No warranties found';
  static const String noAnalyticsMessage = 'No spending data available';
  
  // Export formats
  static const List<String> supportedExportFormats = [
    'PDF',
    'CSV',
    'Excel',
    'JSON',
  ];
  
  // Theme settings
  static const String lightThemeKey = 'light';
  static const String darkThemeKey = 'dark';
  static const String systemThemeKey = 'system';
  
  // Language settings
  static const String defaultLanguage = 'en';
  static const List<String> supportedLanguages = [
    'en', 'es', 'fr', 'de', 'it', 'pt', 'ja', 'ko', 'zh',
  ];
  
  // Business types for expense validation
  static const List<String> businessTypes = [
    'Sole Proprietorship',
    'Partnership',
    'LLC',
    'Corporation',
    'S-Corp',
    'Non-Profit',
    'Freelancer',
    'Consultant',
    'Other',
  ];
}
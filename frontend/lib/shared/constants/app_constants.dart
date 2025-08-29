class AppConstants {
  // Route names
  static const String homeRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String dashboardRoute = '/dashboard';
  static const String receiptScanRoute = '/scan';
  static const String receiptDetailRoute = '/receipt';
  static const String warrantiesRoute = '/warranties';
  static const String analyticsRoute = '/analytics';
  static const String profileRoute = '/profile';
  
  // Database table names (matching architecture schema)
  static const String usersTable = 'users';
  static const String receiptsTable = 'receipts';
  static const String warrantiesTable = 'warranties';
  static const String budgetsTable = 'budgets';
  
  // Storage buckets
  static const String receiptImagesBucket = 'receipt-images';
  static const String warrantyDocsBucket = 'warranty-docs';
  
  // Business types
  static const List<String> businessTypes = [
    'Personal',
    'Freelancer',
    'Small Business',
    'Corporation',
    'Non-Profit',
  ];
  
  // Receipt categories
  static const List<String> receiptCategories = [
    'Food & Dining',
    'Transportation',
    'Shopping',
    'Entertainment',
    'Bills & Utilities',
    'Healthcare',
    'Travel',
    'Business Expenses',
    'Home & Garden',
    'Other',
  ];
  
  // Warranty alert preferences
  static const List<int> warrantyAlertDays = [1, 7, 30, 90];
  
  // File constraints
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png', 'webp'];
  
  // Animation durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  
  // Error messages
  static const String networkError = 'Network connection error. Please check your internet connection.';
  static const String genericError = 'An unexpected error occurred. Please try again.';
  static const String authError = 'Authentication error. Please log in again.';
  static const String fileUploadError = 'Failed to upload file. Please try again.';
  static const String ocrError = 'Failed to process receipt. Please try again with a clearer image.';
}
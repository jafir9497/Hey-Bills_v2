/// Route paths for the application
class RoutePaths {
  // Auth routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  
  // Main routes
  static const String dashboard = '/dashboard';
  static const String receipts = '/dashboard/receipts';
  static const String addReceipt = '/dashboard/receipts/add';
  static const String receiptDetail = '/dashboard/receipts/:receiptId';
  static const String editReceipt = '/dashboard/receipts/:receiptId/edit';
  
  static const String chat = '/dashboard/chat';
  static const String analytics = '/dashboard/analytics';
  
  static const String warranties = '/dashboard/warranties';
  static const String addWarranty = '/dashboard/warranties/add';
  static const String warrantyDetail = '/dashboard/warranties/:warrantyId';
  static const String editWarranty = '/dashboard/warranties/:warrantyId/edit';
  
  static const String settings = '/dashboard/settings';
  static const String profile = '/dashboard/settings/profile';
  static const String preferences = '/dashboard/settings/preferences';
}

/// Route names for the application
class RouteNames {
  // Auth routes
  static const String splash = 'splash';
  static const String login = 'login';
  static const String register = 'register';
  
  // Main routes
  static const String dashboard = 'dashboard';
  static const String receipts = 'receipts';
  static const String addReceipt = 'addReceipt';
  static const String receiptDetail = 'receiptDetail';
  static const String editReceipt = 'editReceipt';
  
  static const String chat = 'chat';
  static const String analytics = 'analytics';
  
  static const String warranties = 'warranties';
  static const String addWarranty = 'addWarranty';
  static const String warrantyDetail = 'warrantyDetail';
  static const String editWarranty = 'editWarranty';
  
  static const String settings = 'settings';
  static const String profile = 'profile';
  static const String preferences = 'preferences';
}
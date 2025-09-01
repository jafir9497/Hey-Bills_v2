// Hey-Bills Flutter Supabase Configuration
// This file provides centralized Supabase client setup for the Flutter frontend

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Supabase Configuration Class
/// Manages Supabase client initialization and configuration
class SupabaseConfig {
  // Environment variables
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  // API endpoints
  static String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:3000';
  static String get websocketUrl => dotenv.env['WEBSOCKET_URL'] ?? 'ws://localhost:3000';
  
  // Google OAuth client IDs
  static String get googleClientIdAndroid => dotenv.env['GOOGLE_CLIENT_ID_ANDROID'] ?? '';
  static String get googleClientIdIos => dotenv.env['GOOGLE_CLIENT_ID_IOS'] ?? '';
  static String get googleClientIdWeb => dotenv.env['GOOGLE_CLIENT_ID_WEB'] ?? '';
  
  // App configuration
  static String get appName => dotenv.env['APP_NAME'] ?? 'Hey Bills';
  static String get packageName => dotenv.env['PACKAGE_NAME'] ?? 'com.heybills.app';
  static String get urlScheme => dotenv.env['URL_SCHEME'] ?? 'heybills';
  
  /// Initialize Supabase with Flutter integration
  static Future<void> initialize() async {
    // Validate environment variables
    _validateEnvironment();
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: kDebugMode ? RealtimeLogLevel.info : RealtimeLogLevel.error,
        eventsPerSecond: 10,
      ),
      storageOptions: const StorageClientOptions(
        retryAttempts: 3,
      ),
      postgrestOptions: const PostgrestClientOptions(
        schema: 'public',
      ),
      authCallbackUrlHostname: 'login-callback',
      debug: kDebugMode,
    );
    
    if (kDebugMode) {
      print('✅ Supabase initialized successfully');
      print('   URL: $supabaseUrl');
      print('   Environment: ${dotenv.env['FLUTTER_ENV'] ?? 'development'}');
    }
  }
  
  /// Validate required environment variables
  static void _validateEnvironment() {
    final requiredVars = {
      'SUPABASE_URL': supabaseUrl,
      'SUPABASE_ANON_KEY': supabaseAnonKey,
    };
    
    final missing = <String>[];
    final placeholders = <String>[];
    
    requiredVars.forEach((key, value) {
      if (value.isEmpty) {
        missing.add(key);
      } else if (value.contains('your-project-ref') || 
                 value.contains('your-actual-anon-key') ||
                 value.contains('your-anon-key-here') ||
                 value.contains('your-project-id')) {
        placeholders.add(key);
      }
    });
    
    if (missing.isNotEmpty) {
      throw Exception(
        'Missing required environment variables: ${missing.join(', ')}\n'
        'Please check your .env file and ensure all Supabase credentials are configured.'
      );
    }
    
    if (placeholders.isNotEmpty) {
      throw Exception(
        'Found placeholder values in environment variables: ${placeholders.join(', ')}\n'
        'Please replace with your actual Supabase project credentials.'
      );
    }
  }
  
  /// Get the current Supabase client instance
  static SupabaseClient get client => Supabase.instance.client;
  
  /// Get the current authenticated user
  static User? get currentUser => client.auth.currentUser;
  
  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
  
  /// Get current user ID
  static String? get currentUserId => currentUser?.id;
}

/// Database Table and Bucket Names
/// Centralized reference for all database entities
class SupabaseSchema {
  // Core tables
  static const String userProfiles = 'user_profiles';
  static const String categories = 'categories';
  static const String receipts = 'receipts';
  static const String receiptItems = 'receipt_items';
  static const String warranties = 'warranties';
  static const String notifications = 'notifications';
  static const String budgets = 'budgets';
  
  // AI/ML tables
  static const String receiptEmbeddings = 'receipt_embeddings';
  static const String warrantyEmbeddings = 'warranty_embeddings';
  
  // Storage buckets
  static const String receiptsBucket = 'receipts';
  static const String warrantiesBucket = 'warranties';
  static const String profilesBucket = 'profiles';
  
  // RPC functions
  static const String searchReceipts = 'search_receipts';
  static const String matchSimilarReceipts = 'match_similar_receipts';
  static const String generateEmbeddings = 'generate_embeddings';
  static const String updateBudgetStats = 'update_budget_stats';
}

/// Common Database Operations Helper
class SupabaseHelper {
  static final SupabaseClient _client = SupabaseConfig.client;
  
  /// User Profile Operations
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final response = await _client
        .from(SupabaseSchema.userProfiles)
        .select()
        .eq('id', userId)
        .single();
    
    return response;
  }
  
  static Future<Map<String, dynamic>?> upsertUserProfile(
      Map<String, dynamic> profile) async {
    final response = await _client
        .from(SupabaseSchema.userProfiles)
        .upsert(profile)
        .select()
        .single();
    
    return response;
  }
  
  /// Receipt Operations
  static Future<List<Map<String, dynamic>>> getUserReceipts(
    String userId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from(SupabaseSchema.receipts)
        .select('*, receipt_items(*)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  static Future<Map<String, dynamic>?> getReceipt(String receiptId) async {
    final response = await _client
        .from(SupabaseSchema.receipts)
        .select('*, receipt_items(*)')
        .eq('id', receiptId)
        .single();
    
    return response;
  }
  
  static Future<Map<String, dynamic>?> createReceipt(
      Map<String, dynamic> receipt) async {
    final response = await _client
        .from(SupabaseSchema.receipts)
        .insert(receipt)
        .select()
        .single();
    
    return response;
  }
  
  static Future<Map<String, dynamic>?> updateReceipt(
    String receiptId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _client
        .from(SupabaseSchema.receipts)
        .update(updates)
        .eq('id', receiptId)
        .select()
        .single();
    
    return response;
  }
  
  static Future<void> deleteReceipt(String receiptId) async {
    await _client
        .from(SupabaseSchema.receipts)
        .delete()
        .eq('id', receiptId);
  }
  
  /// Category Operations
  static Future<List<Map<String, dynamic>>> getUserCategories(
      String userId) async {
    final response = await _client
        .from(SupabaseSchema.categories)
        .select()
        .eq('user_id', userId)
        .order('sort_order', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Warranty Operations
  static Future<List<Map<String, dynamic>>> getUserWarranties(
    String userId, {
    String? status,
  }) async {
    var query = _client
        .from(SupabaseSchema.warranties)
        .select()
        .eq('user_id', userId);
    
    if (status != null) {
      query = query.eq('status', status);
    }
    
    final response = await query.order('expiry_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Search Operations
  static Future<List<Map<String, dynamic>>> searchReceipts(
    String userId,
    String query, {
    int limit = 10,
  }) async {
    final response = await _client.rpc(
      SupabaseSchema.searchReceipts,
      params: {
        'user_id': userId,
        'search_query': query,
        'match_limit': limit,
      },
    );
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Storage Operations
  static Future<String> uploadFile(
    String bucket,
    String path,
    List<int> fileBytes, {
    FileOptions? fileOptions,
  }) async {
    final response = await _client.storage
        .from(bucket)
        .uploadBinary(path, fileBytes, fileOptions: fileOptions);
    
    return response;
  }
  
  static Future<List<int>> downloadFile(String bucket, String path) async {
    final response = await _client.storage.from(bucket).download(path);
    return response;
  }
  
  static String getPublicUrl(String bucket, String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }
  
  static Future<List<FileObject>> listFiles(
    String bucket, {
    String? path,
    SearchOptions? searchOptions,
  }) async {
    final response = await _client.storage
        .from(bucket)
        .list(path: path, searchOptions: searchOptions);
    
    return response;
  }
  
  static Future<List<FileObject>> removeFiles(
      String bucket, List<String> paths) async {
    final response = await _client.storage.from(bucket).remove(paths);
    return response;
  }
  
  /// Real-time subscriptions
  static RealtimeChannel subscribeToReceipts(
    String userId,
    void Function(PostgresChangePayload) callback,
  ) {
    return _client
        .channel('receipts:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseSchema.receipts,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: callback,
        )
        .subscribe();
  }
  
  static RealtimeChannel subscribeToNotifications(
    String userId,
    void Function(PostgresChangePayload) callback,
  ) {
    return _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseSchema.notifications,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: callback,
        )
        .subscribe();
  }
}

/// Authentication Helper
class SupabaseAuth {
  static final GoTrueClient _auth = SupabaseConfig.client.auth;
  
  /// Sign in with email and password
  static Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  /// Sign up with email and password
  static Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password, {
    String? fullName,
    Map<String, dynamic>? data,
  }) async {
    final authData = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      ...?data,
    };
    
    return await _auth.signUp(
      email: email,
      password: password,
      data: authData.isNotEmpty ? authData : null,
    );
  }
  
  /// Sign in with Google OAuth
  static Future<bool> signInWithGoogle() async {
    try {
      final response = await _auth.signInWithOAuth(
        Provider.google,
        redirectTo: '${SupabaseConfig.urlScheme}://login-callback/',
      );
      
      return response;
    } catch (error) {
      if (kDebugMode) {
        print('Google sign-in error: $error');
      }
      return false;
    }
  }
  
  /// Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
  }
  
  /// Reset password
  static Future<void> resetPassword(String email) async {
    await _auth.resetPasswordForEmail(
      email,
      redirectTo: '${SupabaseConfig.urlScheme}://reset-password/',
    );
  }
  
  /// Update password
  static Future<UserResponse> updatePassword(String newPassword) async {
    return await _auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
  
  /// Update user profile
  static Future<UserResponse> updateProfile(Map<String, dynamic> data) async {
    return await _auth.updateUser(UserAttributes(data: data));
  }
  
  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;
}

/// Health Check Helper
class SupabaseHealthCheck {
  static Future<Map<String, bool>> checkHealth() async {
    final client = SupabaseConfig.client;
    final results = <String, bool>{
      'database': false,
      'auth': false,
      'storage': false,
      'realtime': false,
    };
    
    // Test database
    try {
      await client.from(SupabaseSchema.categories).select('count').limit(1);
      results['database'] = true;
    } catch (error) {
      if (kDebugMode) print('Database health check failed: $error');
    }
    
    // Test auth
    try {
      await client.auth.getSession();
      results['auth'] = true;
    } catch (error) {
      if (kDebugMode) print('Auth health check failed: $error');
    }
    
    // Test storage
    try {
      await client.storage.listBuckets();
      results['storage'] = true;
    } catch (error) {
      if (kDebugMode) print('Storage health check failed: $error');
    }
    
    // Test realtime
    try {
      final channel = client.channel('health-check');
      results['realtime'] = true;
      await channel.unsubscribe();
    } catch (error) {
      if (kDebugMode) print('Realtime health check failed: $error');
    }
    
    return results;
  }
}
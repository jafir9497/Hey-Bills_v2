import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Global Supabase client instance
final supabase = Supabase.instance.client;

class SupabaseService {
  static final Logger _logger = Logger();

  /// Initialize Supabase
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
        storageOptions: const StorageClientOptions(
          retryAttempts: 10,
        ),
        postgrestOptions: const PostgrestClientOptions(
          schema: 'public',
        ),
      );
      
      _logger.i('Supabase initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize Supabase: $e');
      rethrow;
    }
  }

  /// Get current user
  static User? getCurrentUser() {
    return supabase.auth.currentUser;
  }

  /// Check if user is authenticated
  static bool get isAuthenticated => getCurrentUser() != null;

  /// Get current session
  static Session? getCurrentSession() {
    return supabase.auth.currentSession;
  }

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges {
    return supabase.auth.onAuthStateChange;
  }

  /// Sign in with email and password
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      _logger.i('User signed in: ${response.user?.id}');
      return response;
    } catch (e) {
      _logger.e('Sign in failed: $e');
      rethrow;
    }
  }

  /// Sign up with email and password
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? userData,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: userData,
      );
      
      _logger.i('User signed up: ${response.user?.id}');
      return response;
    } catch (e) {
      _logger.e('Sign up failed: $e');
      rethrow;
    }
  }

  /// Sign in with Google OAuth
  static Future<bool> signInWithGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'heybills://login-callback',
      );
      
      _logger.i('Initiated Google OAuth sign in');
      return true;
    } catch (e) {
      _logger.e('Google OAuth failed: $e');
      rethrow;
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      await supabase.auth.signOut();
      _logger.i('User signed out');
    } catch (e) {
      _logger.e('Sign out failed: $e');
      rethrow;
    }
  }

  /// Reset password
  static Future<void> resetPassword({
    required String email,
  }) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'heybills://reset-password',
      );
      
      _logger.i('Password reset email sent to: $email');
    } catch (e) {
      _logger.e('Password reset failed: $e');
      rethrow;
    }
  }

  /// Update user password
  static Future<UserResponse> updatePassword({
    required String newPassword,
  }) async {
    try {
      final response = await supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      
      _logger.i('Password updated for user: ${response.user?.id}');
      return response;
    } catch (e) {
      _logger.e('Password update failed: $e');
      rethrow;
    }
  }

  /// Get user profile from users table
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return response;
    } catch (e) {
      _logger.e('Failed to get user profile: $e');
      rethrow;
    }
  }

  /// Create or update user profile
  static Future<void> upsertUserProfile({
    required String userId,
    required Map<String, dynamic> profileData,
  }) async {
    try {
      await supabase
          .from('users')
          .upsert({
            'id': userId,
            ...profileData,
            'updated_at': DateTime.now().toIso8601String(),
          });

      _logger.i('User profile updated: $userId');
    } catch (e) {
      _logger.e('Failed to update user profile: $e');
      rethrow;
    }
  }

  /// Upload file to storage
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required dynamic file, // File or Uint8List
    Map<String, String>? metadata,
  }) async {
    try {
      await supabase.storage.from(bucket).upload(
        path,
        file,
        fileOptions: FileOptions(
          upsert: true,
          metadata: metadata,
        ),
      );

      final publicUrl = supabase.storage.from(bucket).getPublicUrl(path);
      
      _logger.i('File uploaded: $path');
      return publicUrl;
    } catch (e) {
      _logger.e('File upload failed: $e');
      rethrow;
    }
  }

  /// Delete file from storage
  static Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    try {
      await supabase.storage.from(bucket).remove([path]);
      _logger.i('File deleted: $path');
    } catch (e) {
      _logger.e('File delete failed: $e');
      rethrow;
    }
  }

  /// Create a realtime subscription
  static RealtimeChannel subscribeToTable({
    required String table,
    String? filter,
    required void Function(PostgresChangePayload) onData,
  }) {
    try {
      final channel = supabase
          .channel('public:$table')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: filter != null ? PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: filter,
            ) : null,
            callback: onData,
          )
          .subscribe();

      _logger.i('Subscribed to table: $table');
      return channel;
    } catch (e) {
      _logger.e('Subscription failed: $e');
      rethrow;
    }
  }

  /// Remove a realtime subscription
  static Future<void> removeSubscription(RealtimeChannel channel) async {
    try {
      await supabase.removeChannel(channel);
      _logger.i('Subscription removed');
    } catch (e) {
      _logger.e('Failed to remove subscription: $e');
      rethrow;
    }
  }
}
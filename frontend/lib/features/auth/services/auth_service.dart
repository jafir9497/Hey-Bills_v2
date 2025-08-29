import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_error.dart';
import '../../../core/network/supabase_service.dart';
import '../../../shared/constants/app_constants.dart';
import '../../../shared/models/user_model.dart' as app_user;

class AuthService extends ChangeNotifier {
  static final Logger _logger = Logger();
  
  bool _isLoading = false;
  String? _errorMessage;
  app_user.User? _currentUser;

  // Getters
  bool get isLoading => _isLoading;
  bool get isAuthenticated => SupabaseService.isAuthenticated;
  String? get errorMessage => _errorMessage;
  app_user.User? get currentUser => _currentUser;

  /// Initialize auth service
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _clearError();

      // Check if user is already authenticated
      final supabaseUser = SupabaseService.getCurrentUser();
      if (supabaseUser != null) {
        await _loadUserProfile(supabaseUser.id);
      }

      // Listen to auth state changes
      SupabaseService.authStateChanges.listen(_onAuthStateChanged);
      
      _logger.i('Auth service initialized');
    } catch (e) {
      _setError(ErrorHandler.handleError(e));
      _logger.e('Auth initialization failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Handle auth state changes
  void _onAuthStateChanged(AuthState authState) async {
    _logger.i('Auth state changed: ${authState.event}');
    
    switch (authState.event) {
      case AuthChangeEvent.signedIn:
        if (authState.session?.user != null) {
          await _loadUserProfile(authState.session!.user.id);
        }
        break;
      case AuthChangeEvent.signedOut:
        _currentUser = null;
        notifyListeners();
        break;
      case AuthChangeEvent.userUpdated:
        if (authState.session?.user != null) {
          await _loadUserProfile(authState.session!.user.id);
        }
        break;
      default:
        break;
    }
  }

  /// Load user profile from database
  Future<void> _loadUserProfile(String userId) async {
    try {
      final profileData = await SupabaseService.getUserProfile(userId);
      
      if (profileData != null) {
        _currentUser = app_user.User.fromJson(profileData);
        notifyListeners();
      }
    } catch (e) {
      _logger.e('Failed to load user profile: $e');
      // Don't show error to user for profile loading failure
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await SupabaseService.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
        return true;
      }
      
      return false;
    } catch (e) {
      _setError(ErrorHandler.handleError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String businessType,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      // Sign up with Supabase Auth
      final response = await SupabaseService.signUpWithEmail(
        email: email,
        password: password,
        userData: {
          'full_name': fullName,
          'business_type': businessType,
        },
      );

      if (response.user != null) {
        // Create user profile in database
        await SupabaseService.upsertUserProfile(
          userId: response.user!.id,
          profileData: {
            'email': email,
            'full_name': fullName,
            'business_type': businessType,
          },
        );

        await _loadUserProfile(response.user!.id);
        return true;
      }
      
      return false;
    } catch (e) {
      _setError(ErrorHandler.handleError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      _clearError();

      final success = await SupabaseService.signInWithGoogle();
      return success;
    } catch (e) {
      _setError(ErrorHandler.handleError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _setLoading(true);
      _clearError();

      await SupabaseService.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      _setError(ErrorHandler.handleError(e));
    } finally {
      _setLoading(false);
    }
  }

  /// Reset password
  Future<bool> resetPassword({required String email}) async {
    try {
      _setLoading(true);
      _clearError();

      await SupabaseService.resetPassword(email: email);
      return true;
    } catch (e) {
      _setError(ErrorHandler.handleError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update password
  Future<bool> updatePassword({required String newPassword}) async {
    try {
      _setLoading(true);
      _clearError();

      await SupabaseService.updatePassword(newPassword: newPassword);
      return true;
    } catch (e) {
      _setError(ErrorHandler.handleError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update user profile
  Future<bool> updateProfile({
    String? fullName,
    String? businessType,
  }) async {
    if (_currentUser == null) return false;

    try {
      _setLoading(true);
      _clearError();

      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (businessType != null) updates['business_type'] = businessType;

      if (updates.isNotEmpty) {
        await SupabaseService.upsertUserProfile(
          userId: _currentUser!.id,
          profileData: updates,
        );
        
        await _loadUserProfile(_currentUser!.id);
      }

      return true;
    } catch (e) {
      _setError(ErrorHandler.handleError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Validate email format
  bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  /// Validate password strength
  bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Validate business type
  bool isValidBusinessType(String businessType) {
    return AppConstants.businessTypes.contains(businessType);
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(AppError error) {
    _errorMessage = error.message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _clearError();
  }
}
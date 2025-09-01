import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../features/auth/services/auth_service.dart';
import '../../features/auth/models/auth_state.dart';

/// Auth state provider using Riverpod
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

/// Auth notifier class
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthInitial()) {
    _initialize();
  }

  final Ref _ref;
  AuthService? _authService;

  /// Initialize auth service and listen to changes
  Future<void> _initialize() async {
    _authService = AuthService();
    await _authService!.initialize();
    
    // Listen to auth service changes and update state
    _authService!.addListener(_onAuthServiceChanged);
    _updateStateFromService();
  }

  /// Update state based on auth service
  void _onAuthServiceChanged() {
    _updateStateFromService();
  }

  /// Update Riverpod state from auth service
  void _updateStateFromService() {
    if (_authService == null) return;

    if (_authService!.isLoading) {
      state = const AuthLoading();
    } else if (_authService!.errorMessage != null) {
      state = AuthError(_authService!.errorMessage!);
    } else if (_authService!.isAuthenticated && _authService!.currentUser != null) {
      // TODO: Get session from Supabase when available
      state = AuthAuthenticated(
        user: Supabase.instance.client.auth.currentUser!,
        session: Supabase.instance.client.auth.currentSession!,
        profile: _authService!.currentUser!.toJson(),
      );
    } else {
      state = const AuthUnauthenticated();
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (_authService == null) return false;
    
    return await _authService!.signInWithEmail(
      email: email,
      password: password,
    );
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String businessType,
  }) async {
    if (_authService == null) return false;
    
    return await _authService!.signUpWithEmail(
      email: email,
      password: password,
      fullName: fullName,
      businessType: businessType,
    );
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    if (_authService == null) return false;
    return await _authService!.signInWithGoogle();
  }

  /// Sign out
  Future<void> signOut() async {
    if (_authService == null) return;
    await _authService!.signOut();
  }

  /// Reset password
  Future<bool> resetPassword({required String email}) async {
    if (_authService == null) return false;
    return await _authService!.resetPassword(email: email);
  }

  /// Clear error message
  void clearError() {
    _authService?.clearError();
  }

  /// Stream of auth state changes for GoRouter
  Stream<AuthState> get stream async* {
    yield state;
    yield* Stream.periodic(const Duration(milliseconds: 100), (_) => state)
        .distinct();
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAuthServiceChanged);
    super.dispose();
  }
}

/// Computed providers for convenience
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState is AuthAuthenticated;
});

final currentUserProvider = Provider((ref) {
  final authState = ref.watch(authProvider);
  if (authState is AuthAuthenticated) {
    return authState.user;
  }
  return null;
});

final isLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState is AuthLoading;
});
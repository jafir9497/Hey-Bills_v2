import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Authentication state
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Authenticated state
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.user,
    required this.session,
    this.profile,
  });

  final supabase.User user;
  final supabase.Session session;
  final Map<String, dynamic>? profile;

  @override
  List<Object?> get props => [user, session, profile];
}

/// Unauthenticated state
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// Error state
class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Password reset email sent
class AuthPasswordResetSent extends AuthState {
  const AuthPasswordResetSent(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}
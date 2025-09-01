import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/models/auth_state.dart';
import 'route_paths.dart';

/// Route guards for authentication and authorization
class RouteGuards {
  /// Check authentication and redirect accordingly
  static String? authRedirect(AuthState authState, GoRouterState state) {
    final isAuthRoute = state.matchedLocation == RoutePaths.login || 
                       state.matchedLocation == RoutePaths.register ||
                       state.matchedLocation == RoutePaths.splash;

    // If loading, stay on current route
    if (authState is AuthLoading) {
      return null;
    }

    // If authenticated and on auth route, redirect to dashboard
    if (authState is AuthAuthenticated && isAuthRoute) {
      return RoutePaths.dashboard;
    }

    // If not authenticated and not on auth route, redirect to login
    if (authState is! AuthAuthenticated && !isAuthRoute) {
      return RoutePaths.login;
    }

    // If on splash and authenticated, redirect to dashboard
    if (state.matchedLocation == RoutePaths.splash && authState is AuthAuthenticated) {
      return RoutePaths.dashboard;
    }

    // If on splash and not authenticated, redirect to login
    if (state.matchedLocation == RoutePaths.splash && authState is! AuthAuthenticated) {
      return RoutePaths.login;
    }

    // No redirect needed
    return null;
  }

  /// Check if route requires authentication
  static bool requiresAuth(String path) {
    final publicRoutes = [
      RoutePaths.splash,
      RoutePaths.login,
      RoutePaths.register,
    ];

    return !publicRoutes.contains(path);
  }

  /// Check if user has permission for route
  static bool hasPermission(AuthState authState, String path) {
    // For now, all authenticated users have access to all routes
    // This can be extended for role-based access control
    return authState is AuthAuthenticated;
  }
}
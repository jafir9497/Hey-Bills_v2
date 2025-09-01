import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/receipts/screens/receipt_list_screen.dart';
import '../../features/receipts/screens/add_receipt_screen.dart';
import '../../features/receipts/screens/receipt_detail_screen.dart';
import '../../features/receipts/screens/edit_receipt_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/warranties/screens/warranties_screen.dart';
import '../providers/auth_provider.dart';
import 'route_paths.dart';
import 'route_guards.dart';

/// Global router key for programmatic navigation
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>();

/// App router provider
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: RoutePaths.splash,
    redirect: (context, state) {
      return RouteGuards.authRedirect(authState, state);
    },
    refreshListenable: GoRouterRefreshStream(ref.read(authProvider.notifier).stream),
    routes: [
      // Splash Screen
      GoRoute(
        path: RoutePaths.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      
      // Auth Routes
      GoRoute(
        path: RoutePaths.login,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Dashboard Routes
      GoRoute(
        path: RoutePaths.dashboard,
        name: RouteNames.dashboard,
        builder: (context, state) => const DashboardScreen(),
        routes: [
          // Receipts Routes
          GoRoute(
            path: 'receipts',
            name: RouteNames.receipts,
            builder: (context, state) => const ReceiptListScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: RouteNames.addReceipt,
                builder: (context, state) => const AddReceiptScreen(),
              ),
              GoRoute(
                path: ':receiptId',
                name: RouteNames.receiptDetail,
                builder: (context, state) {
                  final receiptId = state.pathParameters['receiptId']!;
                  return ReceiptDetailScreen(receiptId: receiptId);
                },
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: RouteNames.editReceipt,
                    builder: (context, state) {
                      final receiptId = state.pathParameters['receiptId']!;
                      return EditReceiptScreen(receiptId: receiptId);
                    },
                  ),
                ],
              ),
            ],
          ),
          
          // Chat Route
          GoRoute(
            path: 'chat',
            name: RouteNames.chat,
            builder: (context, state) => const ChatScreen(),
          ),
          
          // Analytics Routes
          GoRoute(
            path: 'analytics',
            name: RouteNames.analytics,
            builder: (context, state) => const AnalyticsScreen(),
          ),
          
          // Warranties Routes
          GoRoute(
            path: 'warranties',
            name: RouteNames.warranties,
            builder: (context, state) => const WarrantiesScreen(),
            routes: [
              GoRoute(
                path: 'add',
                name: RouteNames.addWarranty,
                builder: (context, state) => const AddWarrantyScreen(),
              ),
              GoRoute(
                path: ':warrantyId',
                name: RouteNames.warrantyDetail,
                builder: (context, state) {
                  final warrantyId = state.pathParameters['warrantyId']!;
                  return WarrantyDetailScreen(warrantyId: warrantyId);
                },
              ),
            ],
          ),
          
          // Settings Routes
          GoRoute(
            path: 'settings',
            name: RouteNames.settings,
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                name: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'preferences',
                name: RouteNames.preferences,
                builder: (context, state) => const PreferencesScreen(),
              ),
            ],
          ),
        ],
      ),
      
      // Error Route
      GoRoute(
        path: '/error',
        name: 'error',
        builder: (context, state) => ErrorScreen(
          error: state.extra as String? ?? 'Unknown error occurred',
        ),
      ),
    ],
    
    // Error handling
    errorBuilder: (context, state) => ErrorScreen(
      error: 'Page not found: ${state.location}',
    ),
  );
});

/// Stream wrapper for GoRouter refresh
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  
  late final StreamSubscription<dynamic> _subscription;
  
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Placeholder screens for routes that don't exist yet

class AddWarrantyScreen extends StatelessWidget {
  const AddWarrantyScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Add Warranty Screen - Coming Soon')),
    );
  }
}

class WarrantyDetailScreen extends StatelessWidget {
  final String warrantyId;
  
  const WarrantyDetailScreen({super.key, required this.warrantyId});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Warranty Details')),
      body: Center(child: Text('Warranty Detail Screen - ID: $warrantyId')),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Settings Screen')),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Profile Screen')),
    );
  }
}

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Preferences Screen')),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, required this.error});
  
  final String error;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(RoutePaths.dashboard),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

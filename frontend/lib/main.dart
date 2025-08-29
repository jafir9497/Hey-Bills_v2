import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/config/app_config.dart';
import 'features/auth/services/auth_service.dart';
import 'shared/theme/app_theme.dart';
import 'features/auth/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Sentry for error tracking
  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN'; // Replace with actual DSN
      options.tracesSampleRate = 1.0;
      options.environment = AppConfig.supabaseUrl.contains('localhost') ? 'development' : 'production';
    },
    appRunner: () => runApp(const HeyBillsApp()),
  );
}

class HeyBillsApp extends StatelessWidget {
  const HeyBillsApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        // Add more providers as features are implemented
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light, // TODO: Add theme preference
        home: const SplashScreen(),
        builder: (context, child) {
          // Global error boundary
          return Builder(
            builder: (context) {
              ErrorWidget.builder = (FlutterErrorDetails details) {
                // Report to Sentry
                Sentry.captureException(
                  details.exception,
                  stackTrace: details.stack,
                );
                
                // Return custom error widget
                return Material(
                  child: Container(
                    color: Colors.red.shade100,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Something went wrong',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please restart the app',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              };
              
              return child ?? const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}


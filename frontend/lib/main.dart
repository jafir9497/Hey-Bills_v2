import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config/app_config.dart';
import 'core/config/supabase_config.dart';
import 'core/navigation/app_router.dart';
import 'shared/theme/app_theme.dart';
import 'shared/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load environment variables
    await dotenv.load(fileName: '.env');
    
    // Initialize app configuration
    await AppConfig.initialize();
    
    // Initialize Supabase
    await SupabaseConfig.initialize();
  } catch (error) {
    // If .env file doesn't exist or other initialization errors, 
    // continue with default values
    print('⚠️  Environment setup warning: $error');
    print('   Continuing with default configuration...');
  }
  
  // Initialize Sentry for error tracking
  await SentryFlutter.init(
    (options) {
      options.dsn = 'YOUR_SENTRY_DSN'; // Replace with actual DSN
      options.tracesSampleRate = 1.0;
      options.environment = AppConfig.supabaseUrl.contains('localhost') ? 'development' : 'production';
    },
    appRunner: () => runApp(
      const ProviderScope(
        child: HeyBillsApp(),
      ),
    ),
  );
}

class HeyBillsApp extends ConsumerWidget {
  const HeyBillsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light, // TODO: Add theme preference
      routerConfig: router,
      builder: (context, child) {
        // Global error boundary
        ErrorWidget.builder = (FlutterErrorDetails details) {
          // Report to Sentry
          Sentry.captureException(
            details.exception,
            stackTrace: details.stack,
          );
          
          AppLogger.error(
            'Flutter Error: ${details.exception}',
            details.exception,
            details.stack,
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
  }
}


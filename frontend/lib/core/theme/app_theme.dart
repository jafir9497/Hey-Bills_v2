import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Application theme configuration
class AppTheme {
  // Brand colors
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color primaryColorLight = Color(0xFF818CF8);
  static const Color primaryColorDark = Color(0xFF4338CA);
  
  static const Color secondaryColor = Color(0xFF10B981); // Emerald
  static const Color secondaryColorLight = Color(0xFF34D399);
  static const Color secondaryColorDark = Color(0xFF059669);
  
  static const Color accentColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color warningColor = Color(0xFFF97316); // Orange
  static const Color successColor = Color(0xFF10B981); // Emerald
  static const Color infoColor = Color(0xFF3B82F6); // Blue
  
  // Neutral colors
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  
  // Dark theme colors
  static const Color darkBackgroundColor = Color(0xFF111827);
  static const Color darkSurfaceColor = Color(0xFF1F2937);
  static const Color darkCardColor = Color(0xFF374151);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFFD1D5DB);
  static const Color darkTextTertiary = Color(0xFF9CA3AF);
  
  /// Light theme configuration
  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: primaryColor,
      onPrimary: textOnPrimary,
      secondary: secondaryColor,
      onSecondary: textOnPrimary,
      tertiary: accentColor,
      error: errorColor,
      onError: textOnPrimary,
      background: backgroundColor,
      onBackground: textPrimary,
      surface: surfaceColor,
      onSurface: textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Inter', // Add to pubspec.yaml if using custom font
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: textOnPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textOnPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      
      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
      ),
      
      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      
      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: textOnPrimary,
        elevation: 6,
      ),
      
      // Progress Indicator Theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      
      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: textOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      
      // Dialog Theme
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 16,
          color: textSecondary,
        ),
      ),
      
      // Text Theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textTertiary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textTertiary,
        ),
      ),
    );
  }

  /// Dark theme configuration
  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: primaryColor,
      onPrimary: textOnPrimary,
      secondary: secondaryColor,
      onSecondary: textOnPrimary,
      tertiary: accentColor,
      error: errorColor,
      onError: textOnPrimary,
      background: darkBackgroundColor,
      onBackground: darkTextPrimary,
      surface: darkSurfaceColor,
      onSurface: darkTextPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      
      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurfaceColor,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      
      // Card Theme
      cardTheme: CardTheme(
        color: darkCardColor,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      
      // Continue with dark theme adaptations...
    );
  }

  /// Custom text styles
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bodyText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
  );

  /// Custom button styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: textOnPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: const BorderSide(color: primaryColor),
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  /// Custom decorations
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration get primaryGradient => const BoxDecoration(
    gradient: LinearGradient(
      colors: [primaryColor, primaryColorLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  /// Spacing constants
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;
  static const double spacing48 = 48.0;

  /// Border radius constants
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 12.0;
  static const double radiusXLarge = 16.0;
}
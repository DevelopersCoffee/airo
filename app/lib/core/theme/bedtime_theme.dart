import 'package:flutter/material.dart';

/// Bedtime mode theme with AMOLED black, warm tint, and reduced motion
class BedtimeTheme {
  static const Color _amoledBlack = Color(0xFF000000);
  static const Color _warmTint = Color(0xFFFFE4B5); // Moccasin - warm beige
  static const Color _darkGray = Color(0xFF1A1A1A);
  static const Color _mediumGray = Color(0xFF2D2D2D);

  static ThemeData get bedtimeTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _amoledBlack,
      primaryColor: _warmTint,
      primaryColorDark: _darkGray,

      // Color scheme with warm tones
      colorScheme: const ColorScheme.dark(
        primary: _warmTint,
        onPrimary: _amoledBlack,
        secondary: Color(0xFFFFD699),
        onSecondary: _amoledBlack,
        surface: _darkGray,
        onSurface: _warmTint,
        background: _amoledBlack,
        onBackground: _warmTint,
        error: Color(0xFFCF6679),
        onError: _amoledBlack,
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkGray,
        foregroundColor: _warmTint,
        elevation: 0,
        centerTitle: true,
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: _mediumGray,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _warmTint,
          foregroundColor: _amoledBlack,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _warmTint,
          side: const BorderSide(color: _warmTint),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: _warmTint),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _mediumGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _mediumGray),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _mediumGray),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _warmTint),
        ),
        labelStyle: const TextStyle(color: _warmTint),
        hintStyle: const TextStyle(color: Color(0xFF999999)),
      ),

      // Text themes with warm tint
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: _warmTint,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: _warmTint,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: _warmTint,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: _warmTint,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: _warmTint,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: _warmTint,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: _warmTint,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: _warmTint,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        titleSmall: TextStyle(
          color: _warmTint,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: _warmTint, fontSize: 16),
        bodyMedium: TextStyle(color: _warmTint, fontSize: 14),
        bodySmall: TextStyle(color: Color(0xFFCCCCCC), fontSize: 12),
        labelLarge: TextStyle(
          color: _warmTint,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        labelMedium: TextStyle(
          color: _warmTint,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
        labelSmall: TextStyle(
          color: _warmTint,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Navigation bar theme
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkGray,
        indicatorColor: _warmTint,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: _warmTint, fontSize: 12),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _amoledBlack);
          }
          return const IconThemeData(color: _warmTint);
        }),
      ),

      // Slider theme
      sliderTheme: const SliderThemeData(
        activeTrackColor: _warmTint,
        inactiveTrackColor: _mediumGray,
        thumbColor: _warmTint,
        overlayColor: Color(0x29FFE4B5),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _warmTint;
          }
          return _mediumGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _warmTint.withOpacity(0.5);
          }
          return _mediumGray;
        }),
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _warmTint;
          }
          return _mediumGray;
        }),
      ),

      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _warmTint;
          }
          return _mediumGray;
        }),
      ),
    );
  }
}

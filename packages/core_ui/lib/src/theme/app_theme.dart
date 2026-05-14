import 'package:flutter/material.dart';

import 'airo_theme_tokens.dart';
import 'app_colors.dart';
import 'app_theme_definition.dart';
import 'app_theme_id.dart';
import 'app_typography.dart';
import 'bedtime_theme.dart';

/// Application theme configuration.
abstract final class AppTheme {
  static const AppThemeId defaultThemeId = AppThemeId.cyber;

  static AppThemeDefinition get defaultTheme => byId(defaultThemeId);

  static List<AppThemeDefinition> get themes => [
    _cyberDefinition,
    _classicDefinition,
    _bedtimeDefinition,
  ];

  static AppThemeDefinition byId(AppThemeId id) {
    return themes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => defaultTheme,
    );
  }

  /// Compatibility light theme for existing imports.
  static ThemeData get light => _classicLight;

  /// Compatibility dark theme for existing imports.
  static ThemeData get dark => _classicDark;

  static AppThemeDefinition get _cyberDefinition => AppThemeDefinition(
    id: AppThemeId.cyber,
    name: 'Airo Cyber',
    description: 'Futuristic dark grid interface with warm amber actions.',
    lightTheme: _cyberDark,
    darkTheme: _cyberDark,
    themeMode: ThemeMode.dark,
  );

  static AppThemeDefinition get _classicDefinition => AppThemeDefinition(
    id: AppThemeId.classic,
    name: 'Airo Classic',
    description: 'Original Material 3 theme with system light and dark modes.',
    lightTheme: _classicLight,
    darkTheme: _classicDark,
    themeMode: ThemeMode.system,
  );

  static AppThemeDefinition get _bedtimeDefinition => AppThemeDefinition(
    id: AppThemeId.bedtime,
    name: 'Bedtime',
    description: 'Warm AMOLED low-light theme.',
    lightTheme: BedtimeTheme.bedtimeTheme,
    darkTheme: BedtimeTheme.bedtimeTheme,
    themeMode: ThemeMode.dark,
  );

  static ThemeData get _classicLight => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      primaryContainer: AppColors.primaryContainer,
      onPrimary: AppColors.onPrimary,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondary: AppColors.onSecondary,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiary: AppColors.onTertiary,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      errorContainer: AppColors.errorContainer,
      onError: AppColors.onError,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.surfaceVariant,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
    ),
    textTheme: AppTypography.textTheme,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    extensions: const [
      AiroThemeTokens(
        gridLine: AppColors.outlineVariant,
        chromeSurface: AppColors.surfaceVariant,
        glow: Color(0x336750A4),
        success: AppColors.success,
        warning: AppColors.warning,
      ),
    ],
  );

  static ThemeData get _classicDark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryDark,
      primaryContainer: AppColors.onPrimaryDark,
      onPrimary: AppColors.onPrimaryDark,
      secondary: AppColors.secondary,
      error: AppColors.error,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.onSurfaceDark,
    ),
    textTheme: AppTypography.textTheme,
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    extensions: const [
      AiroThemeTokens(
        gridLine: AppColors.outline,
        chromeSurface: AppColors.surfaceDark,
        glow: Color(0x33D0BCFF),
        success: AppColors.success,
        warning: AppColors.warning,
      ),
    ],
  );

  static ThemeData get _cyberDark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.cyberPrimary,
        onPrimary: AppColors.cyberOnPrimary,
        primaryContainer: AppColors.cyberSurfaceHigh,
        onPrimaryContainer: AppColors.cyberText,
        secondary: AppColors.cyberSecondary,
        onSecondary: AppColors.cyberBackground,
        secondaryContainer: Color(0xFF123D3C),
        onSecondaryContainer: AppColors.cyberText,
        tertiary: AppColors.cyberTertiary,
        onTertiary: AppColors.cyberBackground,
        tertiaryContainer: Color(0xFF223C18),
        onTertiaryContainer: AppColors.cyberText,
        error: Color(0xFFFF6B6B),
        onError: Color(0xFF2A0000),
        errorContainer: Color(0xFF4B1111),
        onErrorContainer: Color(0xFFFFDAD6),
        surface: AppColors.cyberSurface,
        onSurface: AppColors.cyberText,
        surfaceContainerHighest: AppColors.cyberSurfaceHigh,
        onSurfaceVariant: AppColors.cyberMutedText,
        outline: AppColors.cyberOutline,
        outlineVariant: AppColors.cyberGridLine,
      ),
      scaffoldBackgroundColor: AppColors.cyberBackground,
      textTheme: AppTypography.textTheme.apply(
        bodyColor: AppColors.cyberText,
        displayColor: AppColors.cyberText,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.cyberChrome,
        foregroundColor: AppColors.cyberText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cyberSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.cyberGridLine),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.cyberGridLine,
        thickness: 1,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.cyberSurfaceHigh,
        selectedColor: AppColors.cyberPrimary,
        disabledColor: Color(0xFF102323),
        labelStyle: TextStyle(color: AppColors.cyberText),
        secondaryLabelStyle: TextStyle(color: AppColors.cyberOnPrimary),
        side: BorderSide(color: AppColors.cyberGridLine),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cyberChrome,
        indicatorColor: AppColors.cyberPrimary,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AppColors.cyberPrimary
              : AppColors.cyberMutedText;
          return TextStyle(color: color, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.cyberOnPrimary);
          }
          return const IconThemeData(color: AppColors.cyberMutedText);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyberPrimary,
          foregroundColor: AppColors.cyberOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cyberPrimary,
          side: const BorderSide(color: AppColors.cyberOutline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.cyberPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cyberSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.cyberGridLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.cyberGridLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.cyberPrimary),
        ),
        labelStyle: const TextStyle(color: AppColors.cyberMutedText),
        hintStyle: const TextStyle(color: AppColors.cyberMutedText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.cyberPrimary;
          }
          return AppColors.cyberMutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.cyberGlow;
          }
          return AppColors.cyberSurfaceHigh;
        }),
      ),
      extensions: const [
        AiroThemeTokens(
          gridLine: AppColors.cyberGridLine,
          chromeSurface: AppColors.cyberChrome,
          glow: AppColors.cyberGlow,
          success: AppColors.cyberTertiary,
          warning: AppColors.cyberPrimary,
        ),
      ],
    );

    return base.copyWith(
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.cyberSecondary,
        textColor: AppColors.cyberText,
        subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: AppColors.cyberMutedText,
        ),
      ),
    );
  }
}

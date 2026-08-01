import 'package:flutter/material.dart';

import 'airo_effects.dart';
import 'airo_domain.dart';
import 'airo_motion.dart';
import 'airo_theme_tokens.dart';
import 'airo_visual_tokens.dart';
import 'app_colors.dart';
import 'app_theme_definition.dart';
import 'app_theme_id.dart';
import 'app_typography.dart';
import 'bedtime_theme.dart';

/// Application theme configuration.
abstract final class AppTheme {
  static const AppThemeId defaultThemeId = AppThemeId.cyber;

  static AppThemeDefinition get defaultTheme => byId(defaultThemeId);

  static ThemeData get defaultLight => defaultTheme.lightTheme;

  static ThemeData get defaultDark => defaultTheme.darkTheme;

  static ThemeMode get defaultThemeMode => defaultTheme.themeMode;

  static List<AppThemeDefinition> get themes => [
    _cyberDefinition,
    _classicDefinition,
    _bedtimeDefinition,
    _airoTvDefinition,
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
    name: 'Airo Living Console',
    description: 'Calm dark surfaces with precise type and ambient color.',
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

  static AppThemeDefinition get _airoTvDefinition => AppThemeDefinition(
    id: AppThemeId.airoTv,
    name: 'Airo TV',
    description: 'Near-black streaming interface with a green accent.',
    lightTheme: _airoTvDark,
    darkTheme: _airoTvDark,
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
      AiroEffects.classic,
      AiroVisualTokens.classicLight,
      AiroDomainTokens(
        domain: AiroDomain.airo,
        accent: Color(0xFF6750A4),
        accentSecondary: Color(0xFF7D5260),
        onAccent: Color(0xFFFFFFFF),
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
      AiroEffects.classic,
      AiroVisualTokens.classicDark,
      AiroDomainTokens(
        domain: AiroDomain.airo,
        accent: Color(0xFFD0BCFF),
        accentSecondary: Color(0xFFEFB8C8),
        onAccent: Color(0xFF21182F),
      ),
    ],
  );

  static ThemeData get _cyberDark {
    const shapeSmall = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
    );
    const shapeMedium = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    );
    const shapeLarge = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
    );
    final textTheme = const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'AiroRulesExpanded',
        fontWeight: FontWeight.w700,
        fontSize: 56,
        height: 1,
      ),
      displayMedium: TextStyle(
        fontFamily: 'AiroRulesExpanded',
        fontWeight: FontWeight.w700,
        fontSize: 44,
        height: 1.05,
      ),
      displaySmall: TextStyle(
        fontFamily: 'AiroRulesExpanded',
        fontWeight: FontWeight.w700,
        fontSize: 34,
        height: 1.08,
      ),
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        height: 1.15,
        letterSpacing: -0.4,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 26,
        height: 1.2,
        letterSpacing: -0.2,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1.2,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        height: 1.25,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
        height: 1.35,
      ),
      titleSmall: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.35,
      ),
      bodyLarge: TextStyle(fontSize: 17, height: 1.5),
      bodyMedium: TextStyle(fontSize: 15, height: 1.5),
      bodySmall: TextStyle(fontSize: 13, height: 1.45),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.2,
      ),
      labelMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        height: 1.2,
      ),
      labelSmall: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 11,
        height: 1.2,
      ),
    ).apply(bodyColor: AppColors.cyberText, displayColor: AppColors.cyberText);
    final scheme = const ColorScheme.dark(
      primary: AppColors.cyberPrimary,
      onPrimary: AppColors.cyberOnPrimary,
      primaryContainer: Color(0xFF12282D),
      onPrimaryContainer: AppColors.cyberText,
      secondary: AppColors.cyberSecondary,
      onSecondary: Color(0xFF0C071C),
      secondaryContainer: Color(0xFF211D38),
      onSecondaryContainer: AppColors.cyberText,
      tertiary: AppColors.cyberTertiary,
      onTertiary: Color(0xFF03150E),
      tertiaryContainer: Color(0xFF102820),
      onTertiaryContainer: AppColors.cyberText,
      error: AppColors.cyberError,
      onError: Color(0xFF2A0000),
      errorContainer: Color(0xFF4B1111),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: AppColors.cyberSurface,
      onSurface: AppColors.cyberText,
      surfaceContainerLowest: AppColors.cyberBackground,
      surfaceContainerLow: AppColors.cyberSurface,
      surfaceContainer: AppColors.cyberSurfaceHigh,
      surfaceContainerHigh: AppColors.cyberSurfaceRaised,
      surfaceContainerHighest: Color(0xFF1D2A34),
      onSurfaceVariant: AppColors.cyberMutedText,
      outline: AppColors.cyberOutline,
      outlineVariant: AppColors.cyberGridLine,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cyberBackground,
      canvasColor: AppColors.cyberBackground,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AiroPageTransitionsBuilder(),
          TargetPlatform.iOS: AiroPageTransitionsBuilder(),
          TargetPlatform.macOS: AiroPageTransitionsBuilder(),
          TargetPlatform.windows: AiroPageTransitionsBuilder(),
          TargetPlatform.linux: AiroPageTransitionsBuilder(),
          TargetPlatform.fuchsia: AiroPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.cyberChrome.withValues(alpha: 0.94),
        foregroundColor: AppColors.cyberText,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.cyberText,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.cyberSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.cyberGridLine),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cyberSurfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shapeLarge.copyWith(
          side: const BorderSide(color: AppColors.cyberGridLine),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: AppColors.cyberMutedText,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cyberSurfaceRaised,
        modalBackgroundColor: AppColors.cyberSurfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: AppColors.cyberGridLine),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.cyberChrome.withValues(alpha: 0.96),
        indicatorColor: AppColors.cyberPrimary.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.cyberPrimary
                : AppColors.cyberMutedText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.cyberPrimary
                : AppColors.cyberMutedText,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.cyberChrome,
        indicatorColor: AppColors.cyberPrimary.withValues(alpha: 0.16),
        selectedIconTheme: const IconThemeData(color: AppColors.cyberPrimary),
        unselectedIconTheme: const IconThemeData(
          color: AppColors.cyberMutedText,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.cyberPrimary,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.cyberMutedText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.cyberPrimary,
          foregroundColor: AppColors.cyberOnPrimary,
          disabledBackgroundColor: AppColors.cyberSurfaceHigh,
          disabledForegroundColor: AppColors.cyberMutedText,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: shapeSmall,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.cyberPrimary,
          foregroundColor: AppColors.cyberOnPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: shapeSmall,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cyberPrimary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.cyberOutline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: shapeSmall,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cyberPrimary,
          minimumSize: const Size(48, 48),
          shape: shapeSmall,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.cyberPrimary,
        foregroundColor: AppColors.cyberOnPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: shapeMedium,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cyberSurfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.cyberGridLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.cyberGridLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.cyberPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.cyberError),
        ),
        labelStyle: TextStyle(color: AppColors.cyberMutedText),
        hintStyle: TextStyle(color: AppColors.cyberMutedText),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cyberSurfaceHigh,
        selectedColor: AppColors.cyberPrimary.withValues(alpha: 0.18),
        disabledColor: AppColors.cyberSurface,
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.cyberText),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.cyberPrimary,
        ),
        side: const BorderSide(color: AppColors.cyberGridLine),
        shape: shapeSmall,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.cyberMutedText,
        textColor: AppColors.cyberText,
        selectedColor: AppColors.cyberPrimary,
        selectedTileColor: AppColors.cyberPrimary.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: shapeSmall,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.cyberMutedText,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.cyberGridLine,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.cyberSurfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shapeMedium.copyWith(
          side: const BorderSide(color: AppColors.cyberGridLine),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.cyberSurfaceRaised,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: AppColors.cyberPrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: shapeSmall.copyWith(
          side: const BorderSide(color: AppColors.cyberGridLine),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: AppColors.cyberSurfaceRaised,
          shape: shapeSmall.copyWith(
            side: const BorderSide(color: AppColors.cyberGridLine),
          ),
        ),
        textStyle: textTheme.labelMedium,
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.cyberPrimary,
        linearTrackColor: AppColors.cyberSurfaceHigh,
        circularTrackColor: AppColors.cyberSurfaceHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.cyberOnPrimary
              : AppColors.cyberMutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.cyberPrimary
              : AppColors.cyberSurfaceHigh;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.cyberPrimary
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.cyberOnPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.cyberPrimary
              : AppColors.cyberMutedText;
        }),
      ),
      iconTheme: const IconThemeData(color: AppColors.cyberMutedText),
      extensions: const [
        AiroThemeTokens(
          gridLine: AppColors.cyberGridLine,
          chromeSurface: AppColors.cyberChrome,
          glow: AppColors.cyberGlow,
          success: AppColors.cyberTertiary,
          warning: Color(0xFFFFC857),
        ),
        AiroEffects.cyber,
        AiroVisualTokens.livingConsole,
        AiroDomainTokens(
          domain: AiroDomain.airo,
          accent: Color(0xFF5CE1E6),
          accentSecondary: Color(0xFF9B8CFF),
          onAccent: Color(0xFF041014),
        ),
      ],
    );

    return base;
  }

  static ThemeData get _airoTvDark {
    final textTheme = AppTypography.textTheme.apply(
      bodyColor: AppColors.airoTvText,
      displayColor: AppColors.airoTvText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.airoTvPrimary,
        onPrimary: AppColors.airoTvOnPrimary,
        primaryContainer: AppColors.airoTvPrimaryContainer,
        onPrimaryContainer: AppColors.airoTvText,
        secondary: AppColors.airoTvSecondary,
        onSecondary: AppColors.airoTvOnSecondary,
        error: AppColors.airoTvError,
        onError: AppColors.airoTvOnPrimary,
        surface: AppColors.airoTvSurface,
        onSurface: AppColors.airoTvText,
        surfaceContainerHighest: AppColors.airoTvSurfaceHigh,
        onSurfaceVariant: AppColors.airoTvMutedText,
        outline: AppColors.airoTvOutline,
        outlineVariant: AppColors.airoTvGridLine,
      ),
      scaffoldBackgroundColor: AppColors.airoTvBackground,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.airoTvChrome,
        foregroundColor: AppColors.airoTvText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.airoTvSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.airoTvBorder, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.airoTvBorder,
        thickness: 1,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.airoTvPrimary,
        disabledColor: AppColors.airoTvSurfaceHigh,
        labelStyle: TextStyle(color: AppColors.airoTvMutedText),
        secondaryLabelStyle: TextStyle(color: AppColors.airoTvOnPrimary),
        side: BorderSide(color: AppColors.airoTvBorder),
        shape: StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.airoTvSurface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AppColors.airoTvPrimary
              : AppColors.airoTvMutedText;
          return TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AppColors.airoTvPrimary
              : AppColors.airoTvMutedText;
          return IconThemeData(color: color);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.airoTvPrimary,
          foregroundColor: AppColors.airoTvOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.airoTvMutedText,
          side: const BorderSide(color: AppColors.airoTvBorder),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.airoTvPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.airoTvBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AppColors.airoTvBorder,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AppColors.airoTvBorder,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppColors.airoTvPrimary),
        ),
        labelStyle: const TextStyle(color: AppColors.airoTvMutedText),
        hintStyle: const TextStyle(color: AppColors.airoTvMutedText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.airoTvPrimary;
          }
          return AppColors.airoTvMutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.airoTvGlow;
          }
          return AppColors.airoTvSurfaceHigh;
        }),
      ),
      extensions: const [
        AiroThemeTokens(
          gridLine: AppColors.airoTvGridLine,
          chromeSurface: AppColors.airoTvChrome,
          glow: AppColors.airoTvGlow,
          success: AppColors.airoTvPrimary,
          warning: AppColors.airoTvSecondary,
        ),
        AiroEffects.cyber,
        AiroVisualTokens.airoTv,
        AiroDomainTokens(
          domain: AiroDomain.live,
          accent: AppColors.airoTvPrimary,
          accentSecondary: Color(0xFF5CE1E6),
          onAccent: AppColors.airoTvOnPrimary,
        ),
      ],
    );
  }
}

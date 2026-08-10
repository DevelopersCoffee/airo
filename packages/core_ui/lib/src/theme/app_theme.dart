import 'package:flutter/material.dart';

import 'airo_effects.dart';
import 'airo_domain.dart';
import 'airo_motion.dart';
import 'airo_theme_tokens.dart';
import 'airo_visual_tokens.dart';
import 'airo_colors.dart';
import 'app_theme_definition.dart';
import 'app_theme_id.dart';
import 'airo_typography.dart';
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
      primary: AiroColors.primary,
      primaryContainer: AiroColors.primaryContainer,
      onPrimary: AiroColors.onPrimary,
      onPrimaryContainer: AiroColors.onPrimaryContainer,
      secondary: AiroColors.secondary,
      secondaryContainer: AiroColors.secondaryContainer,
      onSecondary: AiroColors.onSecondary,
      onSecondaryContainer: AiroColors.onSecondaryContainer,
      tertiary: AiroColors.tertiary,
      tertiaryContainer: AiroColors.tertiaryContainer,
      onTertiary: AiroColors.onTertiary,
      onTertiaryContainer: AiroColors.onTertiaryContainer,
      error: AiroColors.error,
      errorContainer: AiroColors.errorContainer,
      onError: AiroColors.onError,
      onErrorContainer: AiroColors.onErrorContainer,
      surface: AiroColors.surface,
      onSurface: AiroColors.onSurface,
      surfaceContainerHighest: AiroColors.surfaceVariant,
      onSurfaceVariant: AiroColors.onSurfaceVariant,
      outline: AiroColors.outline,
      outlineVariant: AiroColors.outlineVariant,
    ),
    textTheme: AiroTypography.textTheme,
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
        gridLine: AiroColors.outlineVariant,
        chromeSurface: AiroColors.surfaceVariant,
        glow: Color(0x336750A4),
        success: AiroColors.success,
        warning: AiroColors.warning,
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
      primary: AiroColors.primaryDark,
      primaryContainer: AiroColors.onPrimaryDark,
      onPrimary: AiroColors.onPrimaryDark,
      secondary: AiroColors.secondary,
      error: AiroColors.error,
      surface: AiroColors.surfaceDark,
      onSurface: AiroColors.onSurfaceDark,
    ),
    textTheme: AiroTypography.textTheme,
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
        gridLine: AiroColors.outline,
        chromeSurface: AiroColors.surfaceDark,
        glow: Color(0x33D0BCFF),
        success: AiroColors.success,
        warning: AiroColors.warning,
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
    ).apply(bodyColor: AiroColors.cyberText, displayColor: AiroColors.cyberText);
    final scheme = const ColorScheme.dark(
      primary: AiroColors.cyberPrimary,
      onPrimary: AiroColors.cyberOnPrimary,
      primaryContainer: Color(0xFF12282D),
      onPrimaryContainer: AiroColors.cyberText,
      secondary: AiroColors.cyberSecondary,
      onSecondary: Color(0xFF0C071C),
      secondaryContainer: Color(0xFF211D38),
      onSecondaryContainer: AiroColors.cyberText,
      tertiary: AiroColors.cyberTertiary,
      onTertiary: Color(0xFF03150E),
      tertiaryContainer: Color(0xFF102820),
      onTertiaryContainer: AiroColors.cyberText,
      error: AiroColors.cyberError,
      onError: Color(0xFF2A0000),
      errorContainer: Color(0xFF4B1111),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: AiroColors.cyberSurface,
      onSurface: AiroColors.cyberText,
      surfaceContainerLowest: AiroColors.cyberBackground,
      surfaceContainerLow: AiroColors.cyberSurface,
      surfaceContainer: AiroColors.cyberSurfaceHigh,
      surfaceContainerHigh: AiroColors.cyberSurfaceRaised,
      surfaceContainerHighest: Color(0xFF1D2A34),
      onSurfaceVariant: AiroColors.cyberMutedText,
      outline: AiroColors.cyberOutline,
      outlineVariant: AiroColors.cyberGridLine,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AiroColors.cyberBackground,
      canvasColor: AiroColors.cyberBackground,
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
        backgroundColor: AiroColors.cyberChrome.withValues(alpha: 0.94),
        foregroundColor: AiroColors.cyberText,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AiroColors.cyberText,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AiroColors.cyberSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AiroColors.cyberGridLine),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AiroColors.cyberSurfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shapeLarge.copyWith(
          side: const BorderSide(color: AiroColors.cyberGridLine),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyLarge?.copyWith(
          color: AiroColors.cyberMutedText,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AiroColors.cyberSurfaceRaised,
        modalBackgroundColor: AiroColors.cyberSurfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: AiroColors.cyberGridLine),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AiroColors.cyberChrome.withValues(alpha: 0.96),
        indicatorColor: AiroColors.cyberPrimary.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? AiroColors.cyberPrimary
                : AiroColors.cyberMutedText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AiroColors.cyberPrimary
                : AiroColors.cyberMutedText,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AiroColors.cyberChrome,
        indicatorColor: AiroColors.cyberPrimary.withValues(alpha: 0.16),
        selectedIconTheme: const IconThemeData(color: AiroColors.cyberPrimary),
        unselectedIconTheme: const IconThemeData(
          color: AiroColors.cyberMutedText,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AiroColors.cyberPrimary,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: AiroColors.cyberMutedText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AiroColors.cyberPrimary,
          foregroundColor: AiroColors.cyberOnPrimary,
          disabledBackgroundColor: AiroColors.cyberSurfaceHigh,
          disabledForegroundColor: AiroColors.cyberMutedText,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: shapeSmall,
          textStyle: textTheme.labelLarge,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AiroColors.cyberPrimary,
          foregroundColor: AiroColors.cyberOnPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: shapeSmall,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AiroColors.cyberPrimary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AiroColors.cyberOutline),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: shapeSmall,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AiroColors.cyberPrimary,
          minimumSize: const Size(48, 48),
          shape: shapeSmall,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AiroColors.cyberPrimary,
        foregroundColor: AiroColors.cyberOnPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: shapeMedium,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AiroColors.cyberSurfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AiroColors.cyberGridLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AiroColors.cyberGridLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AiroColors.cyberPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AiroColors.cyberError),
        ),
        labelStyle: TextStyle(color: AiroColors.cyberMutedText),
        hintStyle: TextStyle(color: AiroColors.cyberMutedText),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AiroColors.cyberSurfaceHigh,
        selectedColor: AiroColors.cyberPrimary.withValues(alpha: 0.18),
        disabledColor: AiroColors.cyberSurface,
        labelStyle: textTheme.labelMedium?.copyWith(color: AiroColors.cyberText),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AiroColors.cyberPrimary,
        ),
        side: const BorderSide(color: AiroColors.cyberGridLine),
        shape: shapeSmall,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AiroColors.cyberMutedText,
        textColor: AiroColors.cyberText,
        selectedColor: AiroColors.cyberPrimary,
        selectedTileColor: AiroColors.cyberPrimary.withValues(alpha: 0.1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: shapeSmall,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: AiroColors.cyberMutedText,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AiroColors.cyberGridLine,
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AiroColors.cyberSurfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: shapeMedium.copyWith(
          side: const BorderSide(color: AiroColors.cyberGridLine),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AiroColors.cyberSurfaceRaised,
        contentTextStyle: textTheme.bodyMedium,
        actionTextColor: AiroColors.cyberPrimary,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: shapeSmall.copyWith(
          side: const BorderSide(color: AiroColors.cyberGridLine),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: AiroColors.cyberSurfaceRaised,
          shape: shapeSmall.copyWith(
            side: const BorderSide(color: AiroColors.cyberGridLine),
          ),
        ),
        textStyle: textTheme.labelMedium,
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AiroColors.cyberPrimary,
        linearTrackColor: AiroColors.cyberSurfaceHigh,
        circularTrackColor: AiroColors.cyberSurfaceHigh,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AiroColors.cyberOnPrimary
              : AiroColors.cyberMutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AiroColors.cyberPrimary
              : AiroColors.cyberSurfaceHigh;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AiroColors.cyberPrimary
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AiroColors.cyberOnPrimary),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AiroColors.cyberPrimary
              : AiroColors.cyberMutedText;
        }),
      ),
      iconTheme: const IconThemeData(color: AiroColors.cyberMutedText),
      extensions: const [
        AiroThemeTokens(
          gridLine: AiroColors.cyberGridLine,
          chromeSurface: AiroColors.cyberChrome,
          glow: AiroColors.cyberGlow,
          success: AiroColors.cyberTertiary,
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
    final textTheme = AiroTypography.textTheme.apply(
      bodyColor: AiroColors.airoTvText,
      displayColor: AiroColors.airoTvText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AiroColors.airoTvPrimary,
        onPrimary: AiroColors.airoTvOnPrimary,
        primaryContainer: AiroColors.airoTvPrimaryContainer,
        onPrimaryContainer: AiroColors.airoTvText,
        secondary: AiroColors.airoTvSecondary,
        onSecondary: AiroColors.airoTvOnSecondary,
        error: AiroColors.airoTvError,
        onError: AiroColors.airoTvOnPrimary,
        surface: AiroColors.airoTvSurface,
        onSurface: AiroColors.airoTvText,
        surfaceContainerHighest: AiroColors.airoTvSurfaceHigh,
        onSurfaceVariant: AiroColors.airoTvMutedText,
        outline: AiroColors.airoTvOutline,
        outlineVariant: AiroColors.airoTvGridLine,
      ),
      scaffoldBackgroundColor: AiroColors.airoTvBackground,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AiroColors.airoTvChrome,
        foregroundColor: AiroColors.airoTvText,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AiroColors.airoTvSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AiroColors.airoTvBorder, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AiroColors.airoTvBorder,
        thickness: 1,
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: AiroColors.airoTvPrimary,
        disabledColor: AiroColors.airoTvSurfaceHigh,
        labelStyle: TextStyle(color: AiroColors.airoTvMutedText),
        secondaryLabelStyle: TextStyle(color: AiroColors.airoTvOnPrimary),
        side: BorderSide(color: AiroColors.airoTvBorder),
        shape: StadiumBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AiroColors.airoTvSurface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AiroColors.airoTvPrimary
              : AiroColors.airoTvMutedText;
          return TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? AiroColors.airoTvPrimary
              : AiroColors.airoTvMutedText;
          return IconThemeData(color: color);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AiroColors.airoTvPrimary,
          foregroundColor: AiroColors.airoTvOnPrimary,
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
          foregroundColor: AiroColors.airoTvMutedText,
          side: const BorderSide(color: AiroColors.airoTvBorder),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AiroColors.airoTvPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AiroColors.airoTvBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AiroColors.airoTvBorder,
            width: 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(
            color: AiroColors.airoTvBorder,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AiroColors.airoTvPrimary),
        ),
        labelStyle: const TextStyle(color: AiroColors.airoTvMutedText),
        hintStyle: const TextStyle(color: AiroColors.airoTvMutedText),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 12,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AiroColors.airoTvPrimary;
          }
          return AiroColors.airoTvMutedText;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AiroColors.airoTvGlow;
          }
          return AiroColors.airoTvSurfaceHigh;
        }),
      ),
      extensions: const [
        AiroThemeTokens(
          gridLine: AiroColors.airoTvGridLine,
          chromeSurface: AiroColors.airoTvChrome,
          glow: AiroColors.airoTvGlow,
          success: AiroColors.airoTvPrimary,
          warning: AiroColors.airoTvSecondary,
        ),
        AiroEffects.cyber,
        AiroVisualTokens.airoTv,
        AiroDomainTokens(
          domain: AiroDomain.live,
          accent: AiroColors.airoTvPrimary,
          accentSecondary: Color(0xFF5CE1E6),
          onAccent: AiroColors.airoTvOnPrimary,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core_ui/core_ui.dart';

void main() {
  group('AppTheme', () {
    test('defaults to Airo Cyber', () {
      final defaultTheme = AppTheme.defaultTheme;

      expect(AppTheme.defaultThemeId, AppThemeId.cyber);
      expect(defaultTheme.id, AppThemeId.cyber);
      expect(defaultTheme.name, 'Airo Cyber');
      expect(defaultTheme.themeMode, ThemeMode.dark);
      expect(
        AppTheme.defaultLight.brightness,
        defaultTheme.lightTheme.brightness,
      );
      expect(
        AppTheme.defaultDark.brightness,
        defaultTheme.darkTheme.brightness,
      );
      expect(
        AppTheme.defaultLight.scaffoldBackgroundColor,
        defaultTheme.lightTheme.scaffoldBackgroundColor,
      );
      expect(
        AppTheme.defaultDark.scaffoldBackgroundColor,
        defaultTheme.darkTheme.scaffoldBackgroundColor,
      );
      expect(
        AppTheme.defaultLight.colorScheme.primary,
        defaultTheme.lightTheme.colorScheme.primary,
      );
      expect(
        AppTheme.defaultDark.colorScheme.primary,
        defaultTheme.darkTheme.colorScheme.primary,
      );
      expect(AppTheme.defaultThemeMode, defaultTheme.themeMode);
    });

    test('registry exposes all supported themes', () {
      expect(AppTheme.themes.map((theme) => theme.id), [
        AppThemeId.cyber,
        AppThemeId.classic,
        AppThemeId.bedtime,
      ]);
      expect(AppTheme.byId(AppThemeId.classic).name, 'Airo Classic');
      expect(AppTheme.byId(AppThemeId.bedtime).name, 'Bedtime');
    });

    test('cyber theme exposes Hermes-style editorial tokens', () {
      final theme = AppTheme.byId(AppThemeId.cyber).darkTheme;
      final tokens = theme.extension<AiroThemeTokens>();

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF041C1C));
      expect(theme.colorScheme.primary, const Color(0xFFFFE6CB));
      expect(theme.colorScheme.secondary, const Color(0xFFFFFF89));
      expect(theme.textTheme.bodyMedium?.fontFamily, 'AiroMondwest');
      expect(theme.textTheme.displayLarge?.fontFamily, 'AiroRulesExpanded');
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(tokens, isNotNull);
      expect(tokens!.gridLine, const Color(0x33FFE6CB));
      expect(tokens.chromeSurface, const Color(0xFF041C1C));
    });

    test('light theme returns valid ThemeData', () {
      final theme = AppTheme.light;
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme returns valid ThemeData', () {
      final theme = AppTheme.dark;
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
    });

    test('typography avoids negative letter spacing', () {
      expect(AppTypography.displayLarge.letterSpacing, 0);
      expect(AppTypography.displayMedium.letterSpacing, 0);
      expect(AppTypography.displaySmall.letterSpacing, 0);
    });
  });

  group('AppColors', () {
    test('color constants are defined', () {
      expect(AppColors.primary, const Color(0xFF6750A4));
      expect(AppColors.secondary, const Color(0xFF625B71));
      expect(AppColors.error, const Color(0xFFB3261E));
      expect(AppColors.surface, const Color(0xFFFFFBFE));
      expect(AppColors.background, const Color(0xFFFFFBFE));
    });
  });

  group('AppSpacing', () {
    test('spacing values are correct', () {
      expect(AppSpacing.unit, 4.0);
      expect(AppSpacing.xxs, 2.0);
      expect(AppSpacing.xs, 4.0);
      expect(AppSpacing.sm, 8.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppSpacing.xl, 32.0);
      expect(AppSpacing.xxl, 48.0);
    });

    test('padding presets have correct values', () {
      expect(AppSpacing.paddingXs, const EdgeInsets.all(4.0));
      expect(AppSpacing.paddingMd, const EdgeInsets.all(16.0));
      expect(AppSpacing.paddingLg, const EdgeInsets.all(24.0));
    });

    test('border radius values are defined', () {
      expect(AppSpacing.radiusXs, 4.0);
      expect(AppSpacing.radiusSm, 8.0);
      expect(AppSpacing.radiusMd, 12.0);
      expect(AppSpacing.radiusLg, 16.0);
      expect(AppSpacing.radiusXl, 24.0);
      expect(AppSpacing.radiusFull, 999.0);
    });
  });

  group('LoadingIndicator', () {
    testWidgets('renders without message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingIndicator())),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders with message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingIndicator(message: 'Loading...')),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });
  });

  group('ErrorView', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorView(message: 'Test error')),
        ),
      );
      expect(find.text('Test error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders with title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(message: 'Test error', title: 'Error Title'),
          ),
        ),
      );
      expect(find.text('Error Title'), findsOneWidget);
      expect(find.text('Test error'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry provided', (tester) async {
      var retryPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              message: 'Test error',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retryPressed, isTrue);
    });
  });
}

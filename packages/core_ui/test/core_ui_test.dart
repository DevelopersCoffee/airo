import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core_ui/core_ui.dart';

void main() {
  group('AppTheme', () {
    test('defaults to Airo Living Console with stable cyber id', () {
      final defaultTheme = AppTheme.defaultTheme;

      expect(AppTheme.defaultThemeId, AppThemeId.cyber);
      expect(defaultTheme.id, AppThemeId.cyber);
      expect(defaultTheme.name, 'Airo Living Console');
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
        AppThemeId.airoTv,
      ]);
      expect(AppTheme.byId(AppThemeId.classic).name, 'Airo Classic');
      expect(AppTheme.byId(AppThemeId.bedtime).name, 'Bedtime');
      expect(AppTheme.byId(AppThemeId.airoTv).name, 'Airo TV');
    });

    test('living console exposes ambient precision tokens', () {
      final theme = AppTheme.byId(AppThemeId.cyber).darkTheme;
      final tokens = theme.extension<AiroThemeTokens>();
      final visual = theme.extension<AiroVisualTokens>();
      final domain = theme.extension<AiroDomainTokens>();

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF05080B));
      expect(theme.colorScheme.primary, const Color(0xFF5CE1E6));
      expect(theme.colorScheme.secondary, const Color(0xFF9B8CFF));
      expect(theme.textTheme.bodyMedium?.fontFamily, isNot('AiroMondwest'));
      expect(theme.textTheme.displayLarge?.fontFamily, 'AiroRulesExpanded');
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(tokens, isNotNull);
      expect(tokens!.gridLine, const Color(0x24FFFFFF));
      expect(tokens.chromeSurface, const Color(0xFF080C10));
      expect(visual, AiroVisualTokens.livingConsole);
      expect(visual!.radiusMedium, 16);
      expect(domain!.domain, AiroDomain.airo);
      expect(domain.accent, theme.colorScheme.primary);
      expect(theme.cardTheme.margin, EdgeInsets.zero);
    });

    test('domain accents retain accessible foreground contrast', () {
      for (final domain in AiroDomain.values) {
        final tokens = AiroDomainTokens.forDomain(domain);
        expect(
          _contrastRatio(tokens.accent, tokens.onAccent),
          greaterThanOrEqualTo(4.5),
          reason: '${domain.name} accent contrast',
        );
      }
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
      expect(AiroTypography.displayLarge.letterSpacing, 0);
      expect(AiroTypography.displayMedium.letterSpacing, 0);
      expect(AiroTypography.displaySmall.letterSpacing, 0);
    });
  });

  group('AiroColors', () {
    test('color constants are defined', () {
      expect(AiroColors.primary, const Color(0xFF6750A4));
      expect(AiroColors.secondary, const Color(0xFF625B71));
      expect(AiroColors.error, const Color(0xFFB3261E));
      expect(AiroColors.surface, const Color(0xFFFFFBFE));
      expect(AiroColors.background, const Color(0xFFFFFBFE));
    });
  });

  group('AiroSpacing', () {
    test('spacing values are correct', () {
      expect(AiroSpacing.unit, 4.0);
      expect(AiroSpacing.xxs, 2.0);
      expect(AiroSpacing.xs, 4.0);
      expect(AiroSpacing.sm, 8.0);
      expect(AiroSpacing.md, 16.0);
      expect(AiroSpacing.lg, 24.0);
      expect(AiroSpacing.xl, 32.0);
      expect(AiroSpacing.xxl, 48.0);
    });

    test('padding presets have correct values', () {
      expect(AiroSpacing.paddingXs, const EdgeInsets.all(4.0));
      expect(AiroSpacing.paddingMd, const EdgeInsets.all(16.0));
      expect(AiroSpacing.paddingLg, const EdgeInsets.all(24.0));
    });

    test('border radius values are defined', () {
      expect(AiroSpacing.radiusXs, 4.0);
      expect(AiroSpacing.radiusSm, 8.0);
      expect(AiroSpacing.radiusMd, 12.0);
      expect(AiroSpacing.radiusLg, 16.0);
      expect(AiroSpacing.radiusXl, 24.0);
      expect(AiroSpacing.radiusFull, 999.0);
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

  group('Living Console widgets', () {
    testWidgets('domain theme applies its accessible accent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.defaultDark,
          home: const AiroDomainTheme(
            domain: AiroDomain.money,
            child: Builder(builder: _domainProbe),
          ),
        ),
      );

      final context = tester.element(find.byKey(const ValueKey('probe')));
      expect(AiroDomainTokens.of(context).domain, AiroDomain.money);
      expect(
        Theme.of(context).colorScheme.primary,
        AiroDomainTokens.forDomain(AiroDomain.money).accent,
      );
    });

    testWidgets('surface exposes button semantics and shared geometry', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.defaultDark,
          home: Scaffold(
            body: AiroSurface(
              onTap: () {},
              semanticLabel: 'Open money',
              child: const Text('Money'),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Money')),
        matchesSemantics(
          label: 'Open money',
          isButton: true,
          hasTapAction: true,
        ),
      );
      final material = tester.widget<Material>(find.byType(Material).last);
      expect(material.shape, isA<RoundedRectangleBorder>());
    });

    testWidgets('reduced motion resolves transitions immediately', (
      tester,
    ) async {
      late Duration resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Builder(
              builder: (context) {
                resolved = AiroMotion.resolve(context, AiroMotion.spatial);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolved, Duration.zero);
    });
  });
}

Widget _domainProbe(BuildContext context) {
  return const SizedBox(key: ValueKey('probe'));
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}

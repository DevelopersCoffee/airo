import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:core_ui/core_ui.dart';

void main() {
  group('AppTheme', () {
    test('lightTheme returns valid ThemeData', () {
      final theme = AppTheme.lightTheme;
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
    });

    test('darkTheme returns valid ThemeData', () {
      final theme = AppTheme.darkTheme;
      expect(theme, isA<ThemeData>());
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
    });

    test('color constants are defined', () {
      expect(AppTheme.primaryColor, const Color(0xFF2196F3));
      expect(AppTheme.secondaryColor, const Color(0xFF03DAC6));
      expect(AppTheme.errorColor, const Color(0xFFB00020));
      expect(AppTheme.surfaceColor, const Color(0xFFFAFAFA));
      expect(AppTheme.backgroundColor, const Color(0xFFFFFFFF));
    });
  });

  group('AppSpacing', () {
    test('spacing values are correct multiples of unit', () {
      expect(AppSpacing.unit, 4.0);
      expect(AppSpacing.xxs, 4.0);
      expect(AppSpacing.xs, 8.0);
      expect(AppSpacing.sm, 12.0);
      expect(AppSpacing.md, 16.0);
      expect(AppSpacing.lg, 24.0);
      expect(AppSpacing.xl, 32.0);
      expect(AppSpacing.xxl, 48.0);
    });

    test('padding presets have correct values', () {
      expect(AppSpacing.paddingXs, const EdgeInsets.all(8.0));
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

  group('LoadingWidget', () {
    testWidgets('renders without message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingWidget())),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders with message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingWidget(message: 'Loading...')),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });
  });

  group('ErrorDisplayWidget', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorDisplayWidget(message: 'Test error')),
        ),
      );
      expect(find.text('Test error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders with title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ErrorDisplayWidget(
              message: 'Test error',
              title: 'Error Title',
            ),
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
            body: ErrorDisplayWidget(
              message: 'Test error',
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );
      expect(find.text('Try Again'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      expect(retryPressed, isTrue);
    });
  });

  group('EmptyStateWidget', () {
    testWidgets('renders message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyStateWidget(message: 'No items')),
        ),
      );
      expect(find.text('No items'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('renders with custom icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(message: 'No items', icon: Icons.search),
          ),
        ),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}

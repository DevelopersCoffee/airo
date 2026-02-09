import 'package:airo_app/features/media_hub/presentation/utils/accessibility_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MH-017: Accessibility Compliance', () {
    group('MediaHubAccessibility constants', () {
      test('minTouchTarget is at least 44px (WCAG AA)', () {
        expect(
          MediaHubAccessibility.minTouchTarget,
          greaterThanOrEqualTo(44.0),
        );
      });

      test('recommendedTouchTarget is at least 48px', () {
        expect(
          MediaHubAccessibility.recommendedTouchTarget,
          greaterThanOrEqualTo(48.0),
        );
      });

      test('minContrastRatio is at least 4.5:1 (WCAG AA)', () {
        expect(
          MediaHubAccessibility.minContrastRatio,
          greaterThanOrEqualTo(4.5),
        );
      });

      test('minLargeTextContrastRatio is at least 3:1 (WCAG AA)', () {
        expect(
          MediaHubAccessibility.minLargeTextContrastRatio,
          greaterThanOrEqualTo(3.0),
        );
      });

      test('focusIndicatorWidth is positive', () {
        expect(MediaHubAccessibility.focusIndicatorWidth, greaterThan(0));
      });
    });

    group('Contrast ratio calculations', () {
      test('black on white has maximum contrast (21:1)', () {
        final ratio = MediaHubAccessibility.getContrastRatio(
          Colors.black,
          Colors.white,
        );
        expect(ratio, closeTo(21.0, 0.1));
      });

      test('white on black has maximum contrast (21:1)', () {
        final ratio = MediaHubAccessibility.getContrastRatio(
          Colors.white,
          Colors.black,
        );
        expect(ratio, closeTo(21.0, 0.1));
      });

      test('same color has minimum contrast (1:1)', () {
        final ratio = MediaHubAccessibility.getContrastRatio(
          Colors.blue,
          Colors.blue,
        );
        expect(ratio, closeTo(1.0, 0.01));
      });

      test('meetsContrastRequirements returns true for high contrast', () {
        expect(
          MediaHubAccessibility.meetsContrastRequirements(
            Colors.black,
            Colors.white,
          ),
          isTrue,
        );
      });

      test('meetsContrastRequirements returns false for low contrast', () {
        // Light gray on white has low contrast
        expect(
          MediaHubAccessibility.meetsContrastRequirements(
            Colors.grey.shade300,
            Colors.white,
          ),
          isFalse,
        );
      });

      test(
        'meetsLargeTextContrastRequirements returns true for medium contrast',
        () {
          // 3:1 is acceptable for large text
          expect(
            MediaHubAccessibility.meetsLargeTextContrastRequirements(
              Colors.grey.shade600,
              Colors.white,
            ),
            isTrue,
          );
        },
      );
    });

    group('Focus decoration', () {
      test('returns BoxDecoration with border', () {
        final decoration = MediaHubAccessibility.getFocusDecoration(
          Colors.blue,
        );
        expect(decoration, isA<BoxDecoration>());
        expect(decoration.border, isNotNull);
        expect(decoration.borderRadius, isNotNull);
      });
    });

    group('ensureMinTouchTarget', () {
      testWidgets('wraps child with minimum size constraints', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaHubAccessibility.ensureMinTouchTarget(
                child: const Text('Test'),
              ),
            ),
          ),
        );

        // Find the ConstrainedBox that is ancestor of the Text
        final constrainedBox = tester.widget<ConstrainedBox>(
          find
              .ancestor(
                of: find.text('Test'),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(
          constrainedBox.constraints.minWidth,
          MediaHubAccessibility.minTouchTarget,
        );
        expect(
          constrainedBox.constraints.minHeight,
          MediaHubAccessibility.minTouchTarget,
        );
      });

      testWidgets('accepts custom minimum size', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaHubAccessibility.ensureMinTouchTarget(
                child: const Text('CustomTest'),
                minSize: 56.0,
              ),
            ),
          ),
        );

        final constrainedBox = tester.widget<ConstrainedBox>(
          find
              .ancestor(
                of: find.text('CustomTest'),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(constrainedBox.constraints.minWidth, 56.0);
        expect(constrainedBox.constraints.minHeight, 56.0);
      });
    });

    group('AccessibleButton', () {
      testWidgets('renders with semantic label', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AccessibleButton(
                semanticLabel: 'Test button',
                onTap: () {},
                child: const Icon(Icons.play_arrow),
              ),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Test button'), findsOneWidget);
      });
    });
  });
}

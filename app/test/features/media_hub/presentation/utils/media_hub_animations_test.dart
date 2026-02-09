import 'package:airo_app/features/media_hub/presentation/utils/media_hub_animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaHubAnimations', () {
    test('playerCollapse duration is 300ms', () {
      expect(
        MediaHubAnimations.playerCollapse,
        const Duration(milliseconds: 300),
      );
    });

    test('chipSelection duration is 200ms', () {
      expect(
        MediaHubAnimations.chipSelection,
        const Duration(milliseconds: 200),
      );
    });

    test('modeSwitch duration is 300ms', () {
      expect(MediaHubAnimations.modeSwitch, const Duration(milliseconds: 300));
    });

    test('controlsFade duration is 300ms', () {
      expect(
        MediaHubAnimations.controlsFade,
        const Duration(milliseconds: 300),
      );
    });

    test('thumbnailFade duration is 200ms', () {
      expect(
        MediaHubAnimations.thumbnailFade,
        const Duration(milliseconds: 200),
      );
    });

    test('playerCollapseCurve is easeOutCubic', () {
      expect(MediaHubAnimations.playerCollapseCurve, Curves.easeOutCubic);
    });

    test('chipSelectionCurve is easeOut', () {
      expect(MediaHubAnimations.chipSelectionCurve, Curves.easeOut);
    });

    test('modeSwitchCurve is easeInOut', () {
      expect(MediaHubAnimations.modeSwitchCurve, Curves.easeInOut);
    });
  });

  group('PressableScale', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PressableScale(child: Text('Test'))),
        ),
      );

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableScale(
              onTap: () => tapped = true,
              child: const Text('Tap me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('does not call onTap when disabled', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableScale(
              onTap: () => tapped = true,
              enabled: false,
              child: const Text('Tap me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      await tester.pump();

      expect(tapped, isFalse);
    });

    testWidgets('scales down on tap down', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableScale(onTap: () {}, child: const Text('Scale me')),
          ),
        ),
      );

      // Verify initial scale is 1.0
      var scaleTransition = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(PressableScale),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scaleTransition.scale.value, 1.0);

      // Start tap
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Scale me')),
      );

      // Let the animation complete (100ms duration)
      await tester.pumpAndSettle();

      // Find the ScaleTransition that is a descendant of PressableScale
      scaleTransition = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(PressableScale),
          matching: find.byType(ScaleTransition),
        ),
      );
      // After animation completes, scale should be 0.95 (the scaleDown value)
      expect(scaleTransition.scale.value, 0.95);

      // Release
      await gesture.up();
      await tester.pumpAndSettle();

      // Scale should return to 1.0
      scaleTransition = tester.widget<ScaleTransition>(
        find.descendant(
          of: find.byType(PressableScale),
          matching: find.byType(ScaleTransition),
        ),
      );
      expect(scaleTransition.scale.value, 1.0);
    });
  });

  group('FadeInWidget', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FadeInWidget(child: Text('Fade in'))),
        ),
      );

      expect(find.text('Fade in'), findsOneWidget);
    });

    testWidgets('animates opacity from 0 to 1', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FadeInWidget(child: Text('Fade in'))),
        ),
      );

      // Initially should be animating
      final fadeTransition = tester.widget<FadeTransition>(
        find.byType(FadeTransition),
      );
      expect(fadeTransition.opacity.value, greaterThanOrEqualTo(0.0));

      // After animation completes
      await tester.pumpAndSettle();
      final fadeTransitionAfter = tester.widget<FadeTransition>(
        find.byType(FadeTransition),
      );
      expect(fadeTransitionAfter.opacity.value, equals(1.0));
    });
  });
}

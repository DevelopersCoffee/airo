import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/collapsible_player_container.dart';
import 'package:airo_app/features/media_hub/application/providers/media_hub_providers.dart';
import 'package:airo_app/features/media_hub/domain/models/player_display_mode.dart';

void main() {
  Widget createTestWidget({
    PlayerDisplayMode initialMode = PlayerDisplayMode.collapsed,
    double screenWidth = 400.0,
    VoidCallback? onFullscreenToggle,
  }) {
    return ProviderScope(
      overrides: [playerDisplayModeProvider.overrideWith((ref) => initialMode)],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(screenWidth, 800)),
          child: Scaffold(
            body: CollapsiblePlayerContainer(
              onFullscreenToggle: onFullscreenToggle,
              child: const ColoredBox(
                color: Colors.blue,
                child: Center(child: Text('Player Content')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('CollapsiblePlayerContainer', () {
    group('Height calculations', () {
      testWidgets('uses mobile collapsed height on narrow screens', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget(screenWidth: 400));
        await tester.pumpAndSettle();

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(
          container.constraints?.maxHeight,
          CollapsiblePlayerContainer.mobileCollapsedHeight,
        );
      });

      testWidgets('uses tablet collapsed height on wide screens', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget(screenWidth: 700));
        await tester.pumpAndSettle();

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        expect(
          container.constraints?.maxHeight,
          CollapsiblePlayerContainer.tabletCollapsedHeight,
        );
      });

      testWidgets('expanded mode uses multiplied height', (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialMode: PlayerDisplayMode.expanded),
        );
        await tester.pumpAndSettle();

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final expectedHeight =
            CollapsiblePlayerContainer.mobileCollapsedHeight *
            CollapsiblePlayerContainer.expandedMultiplier;
        expect(container.constraints?.maxHeight, expectedHeight);
      });

      testWidgets('hidden mode renders nothing', (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialMode: PlayerDisplayMode.hidden),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedContainer), findsNothing);
        expect(find.byType(SizedBox), findsWidgets);
      });
    });

    group('Display mode transitions', () {
      testWidgets('expand button switches from collapsed to expanded', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Find and tap the expand button (unfold_more icon)
        await tester.tap(find.byIcon(Icons.unfold_more));
        await tester.pumpAndSettle();

        // Check that the mode changed to expanded
        final container = tester
            .firstElement(find.byType(CollapsiblePlayerContainer))
            .findAncestorWidgetOfExactType<ProviderScope>();
        // Note: We verify the UI changed, not the internal state directly
        expect(find.byIcon(Icons.unfold_less), findsOneWidget);
      });

      testWidgets('collapse button switches from expanded to collapsed', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(initialMode: PlayerDisplayMode.expanded),
        );
        await tester.pumpAndSettle();

        // Find and tap the collapse button (unfold_less icon)
        await tester.tap(find.byIcon(Icons.unfold_less));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.unfold_more), findsOneWidget);
      });

      testWidgets('fullscreen button triggers callback', (tester) async {
        bool callbackCalled = false;
        await tester.pumpWidget(
          createTestWidget(onFullscreenToggle: () => callbackCalled = true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.fullscreen));
        await tester.pumpAndSettle();

        expect(callbackCalled, isTrue);
      });
    });

    group('Child content', () {
      testWidgets('renders child widget', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Player Content'), findsOneWidget);
      });
    });

    group('Constants', () {
      test('mobileCollapsedHeight is 200', () {
        expect(CollapsiblePlayerContainer.mobileCollapsedHeight, 200.0);
      });

      test('tabletCollapsedHeight is 280', () {
        expect(CollapsiblePlayerContainer.tabletCollapsedHeight, 280.0);
      });

      test('expandedMultiplier is 1.54', () {
        expect(CollapsiblePlayerContainer.expandedMultiplier, 1.54);
      });

      test('animationDuration is 300ms', () {
        expect(
          CollapsiblePlayerContainer.animationDuration,
          const Duration(milliseconds: 300),
        );
      });

      test('animationCurve is easeOutCubic', () {
        expect(CollapsiblePlayerContainer.animationCurve, Curves.easeOutCubic);
      });
    });
  });
}

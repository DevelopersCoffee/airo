import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airo_app/features/media_hub/presentation/widgets/player_overlay_controls.dart';
import 'package:airo_app/features/media_hub/application/providers/media_hub_providers.dart';
import 'package:airo_app/features/media_hub/domain/models/player_display_mode.dart';

void main() {
  Widget createTestWidget({
    bool isPlaying = false,
    bool isFavorite = false,
    VoidCallback? onPlayPause,
    VoidCallback? onFavorite,
    VoidCallback? onFullscreen,
    VoidCallback? onSettings,
    String? title,
    String? subtitle,
    PlayerDisplayMode initialMode = PlayerDisplayMode.collapsed,
  }) {
    return ProviderScope(
      overrides: [
        playerDisplayModeProvider.overrideWith((ref) => initialMode),
        controlsVisibleProvider.overrideWith((ref) => true),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: PlayerOverlayControls(
              isPlaying: isPlaying,
              isFavorite: isFavorite,
              onPlayPause: onPlayPause,
              onFavorite: onFavorite,
              onFullscreen: onFullscreen,
              onSettings: onSettings,
              title: title,
              subtitle: subtitle,
            ),
          ),
        ),
      ),
    );
  }

  group('PlayerOverlayControls', () {
    group('Rendering', () {
      testWidgets('renders play button when not playing', (tester) async {
        await tester.pumpWidget(createTestWidget(isPlaying: false));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsNothing);
      });

      testWidgets('renders pause button when playing', (tester) async {
        await tester.pumpWidget(createTestWidget(isPlaying: true));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
      });

      testWidgets('renders favorite outline when not favorited', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget(isFavorite: false));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.byIcon(Icons.favorite), findsNothing);
      });

      testWidgets('renders filled favorite when favorited', (tester) async {
        await tester.pumpWidget(createTestWidget(isFavorite: true));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsNothing);
      });

      testWidgets('renders fullscreen button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      });

      testWidgets('renders fullscreen_exit in fullscreen mode', (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialMode: PlayerDisplayMode.fullscreen),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
      });

      testWidgets('renders settings button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.settings), findsOneWidget);
      });

      testWidgets('renders title when provided', (tester) async {
        await tester.pumpWidget(createTestWidget(title: 'Test Title'));
        await tester.pumpAndSettle();

        expect(find.text('Test Title'), findsOneWidget);
      });

      testWidgets('renders subtitle when provided', (tester) async {
        await tester.pumpWidget(
          createTestWidget(title: 'Title', subtitle: 'Test Subtitle'),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Subtitle'), findsOneWidget);
      });
    });

    group('Callbacks', () {
      testWidgets('calls onPlayPause when play button tapped', (tester) async {
        bool called = false;
        await tester.pumpWidget(
          createTestWidget(onPlayPause: () => called = true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();

        expect(called, isTrue);
      });

      testWidgets('calls onFavorite when favorite button tapped', (
        tester,
      ) async {
        bool called = false;
        await tester.pumpWidget(
          createTestWidget(onFavorite: () => called = true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.favorite_border));
        await tester.pump();

        expect(called, isTrue);
      });

      testWidgets('calls onFullscreen when fullscreen button tapped', (
        tester,
      ) async {
        bool called = false;
        await tester.pumpWidget(
          createTestWidget(onFullscreen: () => called = true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.fullscreen));
        await tester.pump();

        expect(called, isTrue);
      });

      testWidgets('calls onSettings when settings button tapped', (
        tester,
      ) async {
        bool called = false;
        await tester.pumpWidget(
          createTestWidget(onSettings: () => called = true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.settings));
        await tester.pump();

        expect(called, isTrue);
      });
    });

    group('Auto-hide behavior', () {
      testWidgets('controls are initially visible', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // AnimatedOpacity should have opacity 1.0
        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });

      testWidgets('controls hide after delay', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Wait for auto-hide delay (4 seconds + animation)
        await tester.pump(PlayerOverlayControls.autoHideDelay);
        await tester.pump(PlayerOverlayControls.fadeAnimationDuration);

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.0);
      });

      testWidgets('tapping shows controls again', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Wait for auto-hide
        await tester.pump(PlayerOverlayControls.autoHideDelay);
        await tester.pump(PlayerOverlayControls.fadeAnimationDuration);

        // Tap to show controls
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });
    });

    group('Gradient background', () {
      testWidgets('has gradient decoration', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(AnimatedOpacity),
                matching: find.byType(Container),
              )
              .first,
        );

        expect(container.decoration, isA<BoxDecoration>());
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.gradient, isA<LinearGradient>());
      });
    });

    group('Constants', () {
      test('autoHideDelay is 4 seconds', () {
        expect(PlayerOverlayControls.autoHideDelay, const Duration(seconds: 4));
      });

      test('fadeAnimationDuration is 300ms', () {
        expect(
          PlayerOverlayControls.fadeAnimationDuration,
          const Duration(milliseconds: 300),
        );
      });
    });

    group('Accessibility', () {
      testWidgets('play button has semantic label', (tester) async {
        await tester.pumpWidget(createTestWidget(isPlaying: false));
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.play_arrow));
        expect(icon.semanticLabel, 'Play');
      });

      testWidgets('pause button has semantic label', (tester) async {
        await tester.pumpWidget(createTestWidget(isPlaying: true));
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.pause));
        expect(icon.semanticLabel, 'Pause');
      });

      testWidgets('favorite button has semantic label', (tester) async {
        await tester.pumpWidget(createTestWidget(isFavorite: false));
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.favorite_border));
        expect(icon.semanticLabel, 'Add to favorites');
      });

      testWidgets('settings button has semantic label', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final icon = tester.widget<Icon>(find.byIcon(Icons.settings));
        expect(icon.semanticLabel, 'Settings');
      });
    });
  });
}

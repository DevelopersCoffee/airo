import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The compact inline layout (phone-width viewports, <600 shortest side) had
// no fullscreen affordance at all -- the expanded layout's
// 'iptv-player-fullscreen-button' only renders when _usesCompactInlinePlayer
// returns false, so every real phone silently lost the one-tap toggle (the
// "more" sheet still had a menu entry, but nothing visible in the control
// row). This adds a matching compact-layout button.
void main() {
  Future<void> pumpPlayer(
    WidgetTester tester, {
    bool showFullscreenButton = true,
    VoidCallback? onFullscreenToggle,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const size = Size(360, 800);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: size),
        child: ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            streamingStateProvider.overrideWith(
              (ref) => Stream.value(
                StreamingState(
                  playbackState: PlaybackState.playing,
                  isLiveStream: true,
                  currentChannel: const IPTVChannel(
                    id: 'news-1',
                    name: 'City News Live',
                    streamUrl: 'https://example.com/news.m3u8',
                    group: 'News',
                  ),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayerWidget(
                  showFullscreenButton: showFullscreenButton,
                  onFullscreenToggle: onFullscreenToggle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Bounded pumps only: the state stream and overlay auto-hide timer keep
    // frames scheduled indefinitely (same pattern as the sibling layout
    // tests for this widget).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'phone-sized viewport shows a compact fullscreen button',
    (tester) async {
      await pumpPlayer(tester);

      expect(
        find.byKey(const ValueKey('iptv-player-fullscreen-button-compact')),
        findsOneWidget,
      );
      // The expanded layout's own button must not also render.
      expect(
        find.byKey(const ValueKey('iptv-player-fullscreen-button')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'tapping the compact fullscreen button flips the icon/tooltip and '
    'notifies the host',
    (tester) async {
      var toggleCount = 0;
      await pumpPlayer(tester, onFullscreenToggle: () => toggleCount++);

      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_exit), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('iptv-player-fullscreen-button-compact')),
      );
      await tester.pump();

      expect(toggleCount, 1);
      expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen), findsNothing);
    },
  );

  testWidgets(
    'showFullscreenButton: false suppresses the compact button too',
    (tester) async {
      await pumpPlayer(tester, showFullscreenButton: false);

      expect(
        find.byKey(const ValueKey('iptv-player-fullscreen-button-compact')),
        findsNothing,
      );
    },
  );
}

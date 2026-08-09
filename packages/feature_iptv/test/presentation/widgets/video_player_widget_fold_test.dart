import 'dart:ui';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// #1462: a hinge straddling the player's bounds must force the compact,
// single-pane control layout — the expanded layout's controls (e.g. the
// fullscreen toggle, positioned near a corner) would otherwise be split
// across the fold.
void main() {
  Future<void> pumpPlayer(
    WidgetTester tester, {
    required List<DisplayFeature> displayFeatures,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: const Size(900, 600),
          displayFeatures: displayFeatures,
        ),
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
              body: SizedBox(width: 900, height: 600, child: VideoPlayerWidget()),
            ),
          ),
        ),
      ),
    );
    // Bounded pumps only: the state stream and overlay auto-hide timer keep
    // frames scheduled indefinitely (same pattern as the PiP layout test).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'no hinge at a wide, non-fullscreen size uses the expanded control layout',
    (tester) async {
      await pumpPlayer(tester, displayFeatures: const []);

      expect(
        find.byKey(const ValueKey('iptv-player-fullscreen-button')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a hinge straddling the player forces the compact control layout even '
    'at a width that would otherwise be expanded',
    (tester) async {
      await pumpPlayer(
        tester,
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(436, 0, 28, 600),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureHalfOpened,
          ),
        ],
      );

      expect(
        find.byKey(const ValueKey('iptv-player-fullscreen-button')),
        findsNothing,
        reason: 'the expanded layout must not render split across the hinge',
      );
      expect(
        find.byKey(const ValueKey('iptv-player-mute-button')),
        findsOneWidget,
        reason: 'the compact layout should still render its own controls',
      );
    },
  );
}

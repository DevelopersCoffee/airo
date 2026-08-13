import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// #1025 / #1600: the hover-chrome overlay must render in distinct,
// non-overlapping zones -- a top-left row (fullscreen/PiP/random), a center
// transport row (rewind/play-pause/mute), and (when the VOL/CH remote-hint
// pillars are shown) a trailing-edge zone clear of the other two. Before the
// fix, the VOL/CH pillars sat inline in the center row and visually crowded
// the transport buttons, and a host screen that renders its own fullscreen
// affordance next to an embedded preview had no way to suppress this
// widget's own duplicate fullscreen button.
void main() {
  Future<void> pumpPlayer(
    WidgetTester tester, {
    required Size size,
    bool enableSwipeChannelChange = true,
    bool showFullscreenButton = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
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
                  enableSwipeChannelChange: enableSwipeChannelChange,
                  showFullscreenButton: showFullscreenButton,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Bounded pumps only: the state stream and overlay auto-hide timer keep
    // frames scheduled indefinitely (same pattern as the sibling PiP/fold
    // layout tests for this widget).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Desktop/TV-sized viewports (>= 600 shortest side, not fullscreen) use
  // the expanded layout, which is the one that carries the VOL/CH pillars.
  const tabletSize = Size(800, 600);
  const tvDesktopSize = Size(1920, 1080);

  for (final size in [tabletSize, tvDesktopSize]) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('renders exactly one fullscreen affordance', (
        tester,
      ) async {
        await pumpPlayer(tester, size: size);

        expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      });

      testWidgets(
        'showFullscreenButton: false suppresses the internal fullscreen '
        'button entirely, for hosts that render their own',
        (tester) async {
          await pumpPlayer(tester, size: size, showFullscreenButton: false);

          expect(find.byIcon(Icons.fullscreen), findsNothing);
          expect(find.byIcon(Icons.fullscreen_exit), findsNothing);
        },
      );

      testWidgets(
        'VOL/CH remote-hint pillars do not overlap the center transport row',
        (tester) async {
          await pumpPlayer(tester, size: size);

          final transportKeys = [
            'iptv-player-dvr-rewind-button',
            'iptv-player-mute-button',
          ];
          final sideKeys = [
            'iptv-player-volume-up-button',
            'iptv-player-volume-down-button',
            'iptv-player-channel-next-button',
            'iptv-player-channel-previous-button',
          ];

          final transportRects = transportKeys
              .map((key) => tester.getRect(find.byKey(ValueKey(key))))
              .toList();
          final sideRects = sideKeys
              .map((key) => tester.getRect(find.byKey(ValueKey(key))))
              .toList();

          for (final transportRect in transportRects) {
            for (final sideRect in sideRects) {
              expect(
                transportRect.overlaps(sideRect),
                isFalse,
                reason:
                    'transport control $transportRect must not overlap '
                    'VOL/CH pillar $sideRect',
              );
            }
          }
        },
      );

      testWidgets(
        'top-left row (fullscreen/PiP/random) does not overlap the VOL/CH '
        'trailing-edge zone',
        (tester) async {
          await pumpPlayer(tester, size: size);

          final topLeftRect = tester.getRect(
            find.byKey(const ValueKey('iptv-player-fullscreen-button')),
          );
          final volRect = tester.getRect(
            find.byKey(const ValueKey('iptv-player-volume-up-button')),
          );

          expect(topLeftRect.overlaps(volRect), isFalse);
        },
      );
    });
  }

  testWidgets(
    'phone-sized viewport (compact inline layout) keeps the VOL cluster and '
    'the channel/random cluster in separate corners',
    (tester) async {
      await pumpPlayer(tester, size: const Size(360, 800));

      final volRect = tester.getRect(
        find.byKey(const ValueKey('iptv-player-volume-up-button')),
      );
      final randomRect = tester.getRect(
        find.byKey(const ValueKey('iptv-player-random-channel-button')),
      );

      expect(volRect.overlaps(randomRect), isFalse);
    },
  );
}

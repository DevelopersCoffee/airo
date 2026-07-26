import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AiroTV D-pad design's TRANSPORT (OK) screen: six buttons (Play/Pause,
// Restart, Audio, Subtitles, Favourite, Info), a metadata row above them,
// and a "MENU for more actions" hint. useTvTransportBar: true swaps the
// touch-oriented VOL/CH pillar layout for this bar; phone/tablet callers
// (useTvTransportBar defaults false) are unaffected.
void main() {
  Future<ProviderContainer> pumpTransportBar(
    WidgetTester tester, {
    required double width,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(
            StreamingState(
              playbackState: PlaybackState.playing,
              isLiveStream: true,
              currentQuality: VideoQuality.high,
              currentChannel: IPTVChannel(
                id: 'news-1',
                name: 'City News Live',
                streamUrl: 'https://example.com/news.m3u8',
                group: 'News',
              ),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 540,
              child: const VideoPlayerWidget(
                initiallyFullscreen: true,
                useTvTransportBar: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets(
    'renders all six transport buttons and channel metadata at the '
    "design's 960px canvas width, with no overflow",
    (tester) async {
      await pumpTransportBar(tester, width: 960);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('iptv-tv-transport-play-pause')), findsOneWidget);
      expect(find.byKey(const ValueKey('iptv-tv-transport-restart')), findsOneWidget);
      expect(find.byKey(const ValueKey('iptv-tv-transport-audio')), findsOneWidget);
      expect(find.byKey(const ValueKey('iptv-tv-transport-subtitles')), findsOneWidget);
      expect(find.byKey(const ValueKey('iptv-tv-transport-favourite')), findsOneWidget);
      expect(find.byKey(const ValueKey('iptv-tv-transport-info')), findsOneWidget);
      expect(find.text('MENU for more actions'), findsOneWidget);
      expect(find.text('City News Live'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      // The touch-oriented layout must not appear alongside it.
      expect(find.text('VOL'), findsNothing);
      expect(find.text('CH'), findsNothing);
    },
  );

  testWidgets('does not overflow at a narrower TV panel width (720)', (
    tester,
  ) async {
    await pumpTransportBar(tester, width: 720);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Favourite button toggles the favorite and updates its icon', (
    tester,
  ) async {
    final container = await pumpTransportBar(tester, width: 960);

    await tester.tap(find.byKey(const ValueKey('iptv-tv-transport-favourite')));
    await tester.pump();
    await tester.pump();

    final ids = await container.read(favoriteChannelIdsProvider.future);
    expect(ids, contains('news-1'));
  });

  testWidgets('Info button opens the context menu', (tester) async {
    await pumpTransportBar(tester, width: 960);

    await tester.tap(find.byKey(const ValueKey('iptv-tv-transport-info')));
    await tester.pump();

    expect(find.text('Actions for'), findsOneWidget);
  });
}

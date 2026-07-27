import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AiroTV D-pad design's "RECENT CHANNELS (DOWN)" screen.
void main() {
  Future<ProviderContainer> pumpPlayer(
    WidgetTester tester, {
    required List<IPTVChannel> recent,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recentlyWatchedChannelsProvider.overrideWith((ref) async => recent),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(
            StreamingState(
              playbackState: PlaybackState.playing,
              isLiveStream: true,
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
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 960, height: 540, child: VideoPlayerWidget()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('DOWN opens Recent Channels, and BACK closes it again', (
    tester,
  ) async {
    await pumpPlayer(
      tester,
      recent: const [
        IPTVChannel(
          id: 'sports-1',
          name: 'Stadium Sports',
          streamUrl: 'https://example.com/sports.m3u8',
          group: 'Sports',
        ),
      ],
    );

    expect(find.text('Recently watched'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();

    expect(find.text('Recently watched'), findsOneWidget);
    expect(find.text('Stadium Sports'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.text('Recently watched'), findsNothing);
  });

  testWidgets('DOWN with no recent channels renders nothing', (tester) async {
    await pumpPlayer(tester, recent: const []);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();

    expect(find.text('Recently watched'), findsNothing);
  });
}

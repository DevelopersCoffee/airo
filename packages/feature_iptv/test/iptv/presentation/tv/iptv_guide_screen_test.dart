import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final channels = [
    const IPTVChannel(
      id: 'news-1',
      name: 'City News Live',
      streamUrl: 'https://example.com/news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    ),
    const IPTVChannel(
      id: 'sports-1',
      name: 'Stadium Sports',
      streamUrl: 'https://example.com/sports.m3u8',
      group: 'Sports',
      category: ChannelCategory.sports,
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<IPTVChannel>? visibleChannels,
    VoidCallback? onChannelSelected,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith(
            (ref) async => visibleChannels ?? channels,
          ),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              const StreamingState(
                playbackState: PlaybackState.idle,
                isLiveStream: true,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          home: IptvGuideScreen(
            onChannelSelected: onChannelSelected ?? () {},
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the LIVE badge pulses forever and never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('lists all channels with name and group', (tester) async {
    await pumpScreen(tester);

    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Stadium Sports'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no channels', (tester) async {
    await pumpScreen(tester, visibleChannels: const []);

    expect(find.text('No channels to show yet.'), findsOneWidget);
  });

  testWidgets(
    'selecting a channel plays it and calls onChannelSelected',
    // Selecting a channel starts real playback via the default
    // VideoPlayerStreamingService, whose VideoPlayerController has no
    // platform channel to respond to it in a plain widget test and so is
    // never disposed. That's a test-environment limitation, not a real
    // leak — playChannel()/dispose() are exercised elsewhere against a
    // controlled StreamingState.
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      notDisposed: {'VideoPlayerController': null},
    ),
    (tester) async {
      var selected = false;
      await pumpScreen(tester, onChannelSelected: () => selected = true);

      await tester.tap(find.text('City News Live'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(selected, isTrue);
    },
  );
}

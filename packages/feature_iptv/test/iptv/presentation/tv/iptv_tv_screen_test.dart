import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    const IPTVChannel(
      id: 'music-1',
      name: 'Music India',
      streamUrl: 'https://example.com/music.m3u8',
      group: 'Music',
      category: ChannelCategory.music,
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<IPTVChannel>? visibleChannels,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith(
            (ref) async => visibleChannels ?? channels,
          ),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              const StreamingState(
                playbackState: PlaybackState.idle,
                isLiveStream: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: IptvTvScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders TV browsing surface with categories and actions', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Live channels'), findsOneWidget);
    expect(find.text('Airo TV Lite Receiver'), findsOneWidget);
    expect(find.text('Compatible profile'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Recent'), findsWidgets);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Guide'), findsNothing);
    expect(find.textContaining('Profile-limited:'), findsOneWidget);
    expect(find.text('3 of 3 live channels'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    expect(find.text('News'), findsWidgets);
    expect(find.text('Sports'), findsWidgets);
    expect(find.text('Music'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('Music India'), findsOneWidget);
  });

  testWidgets('shows TV empty playlist state', (tester) async {
    await pumpScreen(tester, visibleChannels: const []);

    expect(find.text('Airo TV Lite Receiver'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Guide'), findsNothing);
    expect(find.text('Add your playlist'), findsOneWidget);
    expect(find.text('Import playlist URL'), findsOneWidget);
    expect(find.text('How to add'), findsOneWidget);
  });
}

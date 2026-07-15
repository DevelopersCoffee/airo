import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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
    const IPTVChannel(
      id: 'news-2',
      name: 'Global News',
      streamUrl: 'https://example.com/global-news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    ),
    const IPTVChannel(
      id: 'sports-2',
      name: 'Match Center',
      streamUrl: 'https://example.com/match-center.m3u8',
      group: 'Sports',
      category: ChannelCategory.sports,
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<IPTVChannel>? visibleChannels,
    CompactEpgRepository? compactEpgRepository,
    DateTime? compactEpgNow,
    Size surfaceSize = const Size(1280, 720),
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize);
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
          if (compactEpgRepository != null)
            compactEpgRepositoryProvider.overrideWithValue(
              compactEpgRepository,
            ),
          if (compactEpgNow != null)
            compactEpgReferenceTimeProvider.overrideWithValue(compactEpgNow),
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
    expect(find.text('5 of 5 live channels'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('All'), findsWidgets);
    expect(find.text('News'), findsWidgets);
    expect(find.text('Sports'), findsWidgets);
    expect(find.text('Music'), findsWidgets);
    expect(find.text('Business'), findsNothing);
    expect(find.text('General'), findsNothing);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('Music India'), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
    expect(find.bySemanticsLabel('Search'), findsWidgets);
    expect(find.bySemanticsLabel('City News Live'), findsOneWidget);
  });

  testWidgets('renders compact current EPG from platform repository', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 15, 9);
    final repository = InMemoryCompactEpgRepository(
      seed: CompactEpgSlice(
        entries: [
          CompactEpgEntry.fromPrograms(
            channelId: 'news-1',
            channelName: 'City News Live',
            now: now,
            programs: [
              CompactEpgProgram(
                programId: 'morning-news',
                title: 'Morning Bulletin',
                startsAt: now.subtract(const Duration(minutes: 10)),
                endsAt: now.add(const Duration(minutes: 20)),
              ),
            ],
          ),
        ],
        generatedAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
        source: CompactEpgSliceSource.localCache,
      ),
    );

    await pumpScreen(
      tester,
      compactEpgRepository: repository,
      compactEpgNow: now,
    );

    expect(find.text('Now: Morning Bulletin'), findsOneWidget);
  });

  testWidgets('keeps compact TV viewport browse controls reachable', (
    tester,
  ) async {
    await pumpScreen(tester, surfaceSize: const Size(1024, 576));

    expect(find.text('Live channels'), findsOneWidget);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
  });

  testWidgets('shows readable playlist guide with primary dismissal', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('How to add a playlist'), findsOneWidget);
    expect(find.text('Find your playlist URL'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
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

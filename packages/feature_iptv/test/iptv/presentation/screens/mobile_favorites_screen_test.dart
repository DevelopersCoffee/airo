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
  ];

  Future<VideoPlayerStreamingService> pumpScreen(
    WidgetTester tester, {
    Set<String> favoriteIds = const {},
    VoidCallback? onChannelSelected,
  }) async {
    SharedPreferences.setMockInitialValues({
      'iptv_favorite_channel_ids': favoriteIds.toList(),
    });
    final prefs = await SharedPreferences.getInstance();
    final engine = FakeAiroPlaybackEngine(tracks: const []);
    final service = VideoPlayerStreamingService(engine: engine);
    addTearDown(service.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => channels),
          iptvStreamingServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: MobileFavoritesScreen(
            onChannelSelected: onChannelSelected ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('shows empty state when there are no favorites', (tester) async {
    await pumpScreen(tester);

    expect(find.text('No favorite channels yet'), findsOneWidget);
  });

  testWidgets(
    'shows the favorite-reimport review banner when a candidate is pending (CV-017)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final engine = FakeAiroPlaybackEngine(tracks: const []);
      final service = VideoPlayerStreamingService(engine: engine);
      addTearDown(service.dispose);

      const oldChannel = IPTVChannel(
        id: 'a1',
        name: 'BBC One HD',
        streamUrl: 'https://example.com/a1.m3u8',
      );
      const candidateChannel = IPTVChannel(
        id: 'b9',
        name: 'bbc-one',
        streamUrl: 'https://example.com/b9.m3u8',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => const []),
          iptvStreamingServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(favoriteReimportReviewCandidatesProvider.notifier)
          .state = [
        const FavoriteReviewCandidate(
          oldChannel: oldChannel,
          candidate: candidateChannel,
        ),
      ];

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MobileFavoritesScreen(onChannelSelected: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('looks like'), findsOneWidget);
      await service.stop();
    },
  );

  testWidgets('renders favorited channels with name and group', (tester) async {
    await pumpScreen(tester, favoriteIds: {'news-1', 'sports-1'});

    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);
    expect(find.text('Stadium Sports'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('No favorite channels yet'), findsNothing);
  });

  testWidgets('tapping a favorite plays it and calls onChannelSelected', (
    tester,
  ) async {
    var selected = false;
    final service = await pumpScreen(
      tester,
      favoriteIds: {'news-1'},
      onChannelSelected: () => selected = true,
    );

    await tester.tap(find.text('City News Live'));
    await tester.pumpAndSettle();

    expect(selected, isTrue);
    await service.stop();
  });

  testWidgets('tapping the favorite icon removes the channel from the list', (
    tester,
  ) async {
    await pumpScreen(tester, favoriteIds: {'news-1', 'sports-1'});
    expect(find.text('City News Live'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'City News Live'),
        matching: find.byIcon(Icons.favorite),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('City News Live'), findsNothing);
    expect(find.text('Stadium Sports'), findsOneWidget);
  });
}

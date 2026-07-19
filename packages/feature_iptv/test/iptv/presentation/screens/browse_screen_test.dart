import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const channels = [
    IPTVChannel(
      id: 'news-1',
      name: 'City News Live',
      streamUrl: 'https://example.com/news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    ),
  ];

  testWidgets('long-pressing a card toggles the channel favorite', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => channels),
        recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: BrowseScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(MediaCard).first);
    await tester.pumpAndSettle();

    expect(find.text('City News Live added to favorites'), findsOneWidget);
    final ids = await container.read(favoriteChannelIdsProvider.future);
    expect(ids, contains('news-1'));
  });
}

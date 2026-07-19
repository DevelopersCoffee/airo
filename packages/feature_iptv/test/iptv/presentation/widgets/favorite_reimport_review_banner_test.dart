import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/widgets/favorite_reimport_review_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
  const candidate = FavoriteReviewCandidate(
    oldChannel: oldChannel,
    candidate: candidateChannel,
  );

  Future<ProviderContainer> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  Future<void> pumpBanner(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: FavoriteReimportReviewBanner()),
        ),
      ),
    );
  }

  testWidgets('renders nothing when there are no review candidates', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await pumpBanner(tester, container);

    expect(find.byType(FavoriteReimportReviewBanner), findsOneWidget);
    expect(find.textContaining('looks like'), findsNothing);
  });

  testWidgets('shows a prompt for each pending review candidate', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    container.read(favoriteReimportReviewCandidatesProvider.notifier).state = [
      candidate,
    ];

    await pumpBanner(tester, container);

    expect(find.textContaining('BBC One HD'), findsOneWidget);
    expect(find.textContaining('bbc-one'), findsOneWidget);
  });

  testWidgets(
    'tapping Keep favorites the new channel, unfavorites the old one, and clears the prompt',
    (tester) async {
      final container = await buildContainer();
      addTearDown(container.dispose);
      final storage = container.read(favoriteChannelsStorageProvider);
      await storage.addFavorite(oldChannel.id);
      container.read(favoriteReimportReviewCandidatesProvider.notifier).state =
          [candidate];

      await pumpBanner(tester, container);
      await tester.tap(
        find.byKey(const ValueKey('favorite-reimport-accept-a1')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(favoriteReimportReviewCandidatesProvider), isEmpty);
      final favoriteIds = await storage.getFavoriteChannelIds();
      expect(favoriteIds, {'b9'});
    },
  );

  testWidgets('tapping Dismiss clears the prompt without changing favorites', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    final storage = container.read(favoriteChannelsStorageProvider);
    await storage.addFavorite(oldChannel.id);
    container.read(favoriteReimportReviewCandidatesProvider.notifier).state = [
      candidate,
    ];

    await pumpBanner(tester, container);
    await tester.tap(
      find.byKey(const ValueKey('favorite-reimport-dismiss-a1')),
    );
    await tester.pump();

    expect(container.read(favoriteReimportReviewCandidatesProvider), isEmpty);
    final favoriteIds = await storage.getFavoriteChannelIds();
    expect(favoriteIds, {'a1'});
  });
}

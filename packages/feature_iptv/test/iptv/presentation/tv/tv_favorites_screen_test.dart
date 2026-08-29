import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:feature_iptv/feature_iptv.dart';
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

  testWidgets(
    'shows the favorite-reimport review banner when a candidate is pending (CV-017)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => const []),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(StreamingState()),
          ),
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
          child: const MaterialApp(home: TvFavoritesScreen()),
        ),
      );
      await tester.pump();

      expect(find.textContaining('looks like'), findsOneWidget);
    },
  );

  testWidgets('hides the review banner when there is nothing pending', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvChannelsProvider.overrideWith((ref) async => const []),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(StreamingState()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TvFavoritesScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('looks like'), findsNothing);
  });

  testWidgets(
    'selecting a favorite plays it and calls onChannelSelected',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => const [oldChannel]),
          favoriteChannelsProvider.overrideWith(
            (ref) async => const [oldChannel],
          ),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(StreamingState()),
          ),
        ],
      );
      addTearDown(container.dispose);

      var closed = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: TvFavoritesScreen(onChannelSelected: () => closed++),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('BBC One HD'));
      await tester.pump();

      // Without this the shell keeps the favorites grid painted over the
      // retained live surface, so playback starts behind an opaque overlay.
      expect(closed, 1);
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      notDisposed: {'VideoPlayerController': null},
    ),
  );
}

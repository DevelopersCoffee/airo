import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/vod_providers.dart';

void main() {
  testWidgets(
    'subtitle-URL entry attaches the subtitle before playback starts',
    (tester) async {
      final engine = FakeAiroPlaybackEngine(tracks: const []);
      final service = VideoPlayerStreamingService(engine: engine);
      addTearDown(service.dispose);

      const item = VodItem(
        id: 'vod-1',
        title: 'Test Movie',
        streamUrl: 'https://example.com/movie.mp4',
        group: 'Movies',
        kind: VodContentKind.movie,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvStreamingServiceProvider.overrideWithValue(service),
            vodContinueWatchingProvider.overrideWith((ref) async => []),
            filteredVodMoviesProvider.overrideWithValue([item]),
            filteredVodSeriesGroupsProvider.overrideWithValue([]),
            addToVodWatchHistoryProvider(item).overrideWith((ref) async {}),
          ],
          child: const MaterialApp(home: VodScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('vod-add-subtitle-button-vod-1')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('vod-subtitle-url-field')),
        'https://example.com/en.vtt',
      );
      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Movie'));
      await tester.pumpAndSettle();

      expect(service.currentState.tracks, hasLength(1));
      expect(service.currentState.tracks.single.isExternal, isTrue);

      // playChannel() starts periodic timers (buffer monitor, live-edge
      // detector). testWidgets' pending-timer invariant check runs before
      // addTearDown callbacks fire, so those timers must be stopped inside
      // the test body itself — addTearDown(service.dispose) alone isn't
      // enough here (see VideoPlayerStreamingService.stop()).
      await service.stop();
    },
  );

  testWidgets(
    'a non-http/https subtitle URL is rejected and never attached',
    (tester) async {
      final engine = FakeAiroPlaybackEngine(tracks: const []);
      final service = VideoPlayerStreamingService(engine: engine);
      addTearDown(service.dispose);

      const item = VodItem(
        id: 'vod-1',
        title: 'Test Movie',
        streamUrl: 'https://example.com/movie.mp4',
        group: 'Movies',
        kind: VodContentKind.movie,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvStreamingServiceProvider.overrideWithValue(service),
            vodContinueWatchingProvider.overrideWith((ref) async => []),
            filteredVodMoviesProvider.overrideWithValue([item]),
            filteredVodSeriesGroupsProvider.overrideWithValue([]),
            addToVodWatchHistoryProvider(item).overrideWith((ref) async {}),
          ],
          child: const MaterialApp(home: VodScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('vod-add-subtitle-button-vod-1')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('vod-subtitle-url-field')),
        'file:///etc/passwd',
      );
      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();

      // Rejected: a SnackBar error appears and no subtitle is stored, so
      // playing the item afterward shows no external subtitle track.
      expect(
        find.text('Enter a valid http:// or https:// subtitle URL.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Test Movie'));
      await tester.pumpAndSettle();

      expect(service.currentState.tracks, isEmpty);

      // See the timer-teardown note in the test above.
      await service.stop();
    },
  );
}

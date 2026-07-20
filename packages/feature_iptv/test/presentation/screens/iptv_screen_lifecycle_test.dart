import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/feature_iptv.dart';

// Regression test for the "Immediate Action Player" final review finding:
// appLifecycleStateProvider was never actually updated in production —
// PlayerBackgroundingCoordinator's unit tests call the coordinator
// directly, bypassing the real WidgetsBindingObserver wiring, so they
// passed even though the observer was never registered in IPTVScreen.
// This test drives a *real* app lifecycle transition through
// WidgetsBinding and asserts appLifecycleStateProvider's value actually
// changes, proving the observer -> provider wire is live.
final _channels = [
  const IPTVChannel(
    id: 'c1',
    name: 'Channel One',
    streamUrl: 'https://example.com/c1.m3u8',
    group: 'News',
    category: ChannelCategory.news,
  ),
];

/// Streaming service double mirroring the pattern in
/// iptv_screen_default_to_live_test.dart — the real service constructs an
/// actual VideoPlayerController against a fake URL, which never finishes
/// initializing and leaks past test teardown.
class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService() : super(engine: FakeAiroPlaybackEngine());
}

void main() {
  testWidgets(
    'a real AppLifecycleState transition updates appLifecycleStateProvider '
    'while IPTVScreen is mounted',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvChannelsProvider.overrideWith((ref) async => _channels),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            // No currentChannel set: this test only needs to prove the
            // WidgetsBindingObserver -> appLifecycleStateProvider wire is
            // live, not exercise real video playback (which would pull in
            // VideoPlayerWidget's real player controller and hang
            // pumpAndSettle, per the pattern already established in
            // iptv_screen_default_to_live_test.dart's
            // _RecordingStreamingService comment).
            streamingStateProvider.overrideWith(
              (ref) => Stream.value(
                StreamingState(
                  playbackState: PlaybackState.idle,
                  isLiveStream: true,
                  liveDelay: const Duration(seconds: 1),
                ),
              ),
            ),
            iptvStreamingServiceProvider.overrideWith((ref) {
              final service = _RecordingStreamingService();
              ref.onDispose(service.dispose);
              return service;
            }),
          ],
          child: const MaterialApp(home: IPTVScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(IPTVScreen)),
      );

      // Sanity check: the seeded default before any lifecycle event fires.
      expect(
        container.read(appLifecycleStateProvider),
        AppLifecycleState.resumed,
      );

      // Drive a real app-backgrounding transition through the same
      // WidgetsBinding API the platform uses, rather than calling
      // IPTVScreen's didChangeAppLifecycleState directly — that would only
      // prove the override method works, not that it's wired up as a
      // registered observer.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(
        container.read(appLifecycleStateProvider),
        AppLifecycleState.paused,
        reason:
            'IPTVScreen must register itself as a WidgetsBindingObserver '
            'and forward real lifecycle changes into '
            'appLifecycleStateProvider, or PlayerBackgroundingCoordinator '
            'never fires in production',
      );

      // Resume too, to confirm the wiring works both directions.
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();

      expect(
        container.read(appLifecycleStateProvider),
        AppLifecycleState.resumed,
      );
    },
  );
}

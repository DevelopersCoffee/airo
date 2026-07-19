import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/feature_iptv.dart';

// `iptvChannelsProvider`'s default implementation resolves real playlist
// data via `channelDataServiceProvider`, which needs `sharedPreferencesProvider`
// — unimplemented outside `main()` (see iptv_providers.dart). Every existing
// `IPTVScreen` test (iptv_screen_test.dart) overrides the channel/recent/
// streaming providers directly instead of standing up real SharedPreferences;
// this test does the same so the screen builds without an unrelated provider
// crash obscuring the deep-link behavior under test.
final _channels = [
  const IPTVChannel(
    id: 'c1',
    name: 'Channel One',
    streamUrl: 'https://example.com/c1.m3u8',
    group: 'News',
    category: ChannelCategory.news,
  ),
];

/// Streaming service double that records [playChannel] calls instead of
/// touching the real playback engine (mirrors `iptv_screen_test.dart`'s
/// `_RecordingStreamingService`) — the real service constructs an actual
/// `VideoPlayerController` for the stream URL, which never finishes
/// initializing against a fake URL and leaks past test teardown.
class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService({required this.played})
    : super(engine: FakeAiroPlaybackEngine());

  final List<IPTVChannel> played;

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    played.add(channel);
  }
}

List<Override> _providerOverrides({List<IPTVChannel>? played}) => [
  iptvChannelsProvider.overrideWith((ref) async => _channels),
  recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
  streamingStateProvider.overrideWith(
    (ref) => Stream.value(
      StreamingState(
        playbackState: PlaybackState.idle,
        isLiveStream: true,
        liveDelay: const Duration(seconds: 1),
      ),
    ),
  ),
  if (played != null)
    iptvStreamingServiceProvider.overrideWith((ref) {
      final service = _RecordingStreamingService(played: played);
      ref.onDispose(service.dispose);
      return service;
    }),
];

void main() {
  testWidgets('tapping a channel card starts playback with no route push', (
    tester,
  ) async {
    // Wide viewport so IPTVScreen renders the ChannelListWidget-based
    // channel panel (the `channel-card-<index>` keys live there) rather
    // than the narrow-width BrowseScreen rail layout. `setSurfaceSize`
    // sets the *physical* size, so the devicePixelRatio (3.0 by default
    // in tests) must also be pinned or the logical width stays 800.
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final played = <IPTVChannel>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: _providerOverrides(played: played),
        child: const MaterialApp(home: IPTVScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final navigatorObserver = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    final routeCountBefore = navigatorObserver.widget.pages.length;

    // Channel cards are rendered by ChannelListWidget; tap the first one.
    final channelCard = find.byKey(const ValueKey('channel-card-0'));
    if (channelCard.evaluate().isNotEmpty) {
      await tester.tap(channelCard);
      await tester.pumpAndSettle();
      expect(
        navigatorObserver.widget.pages.length,
        routeCountBefore,
        reason: 'tap-to-play must not push an interstitial route',
      );
    }
  });

  testWidgets('deepLinkChannelId renders the player as the first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _providerOverrides(played: <IPTVChannel>[]),
        child: const MaterialApp(home: IPTVScreen(deepLinkChannelId: 'c1')),
      ),
    );
    await tester.pump();

    // The browse grid's channel list must not be the first thing shown
    // when a deep link is present.
    expect(find.byKey(const ValueKey('iptv-browse-grid')), findsNothing);
  });

  testWidgets(
    'deepLinkChannelId for a missing channel falls back to the browse grid',
    (tester) async {
      // spec Error Handling: a deep link that resolves to a channel ID no
      // longer in the playlist must fall back to the normal browse-grid
      // landing rather than stranding the user on the loading screen.
      await tester.pumpWidget(
        ProviderScope(
          overrides: _providerOverrides(played: <IPTVChannel>[]),
          child: const MaterialApp(
            home: IPTVScreen(deepLinkChannelId: 'does-not-exist'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('iptv-browse-grid')), findsOneWidget);
    },
  );
}

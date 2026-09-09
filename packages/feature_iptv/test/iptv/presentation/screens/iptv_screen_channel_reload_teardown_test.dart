import "package:feature_iptv/application/channel_metadata_enrichment.dart";
import "package:feature_iptv/feature_iptv.dart";
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auto Scan's real transport makes actual HTTP requests, which flutter
/// test's binding rejects -- see iptv_screen_test.dart / airo_tv_shell_test.dart.
class _FakeProbeTransport implements StreamProbeTransport {
  @override
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  }) async => const StreamProbeHttpResponse(statusCode: 206);
}

void main() {
  testWidgets(
    'AiroTvShellState survives a channel-list reload triggered by one of '
    "iptvChannelsProvider's own watched dependencies (not just an "
    'invalidate/refresh)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final reloadTrigger = StateProvider<int>((ref) => 0);
      const channels = [
        IPTVChannel(
          id: 'news-1',
          name: 'City News Live',
          streamUrl: 'https://example.com/news.m3u8',
          group: 'News',
          category: ChannelCategory.news,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamProbeTransportProvider.overrideWithValue(
            _FakeProbeTransport(),
          ),
          channelBrowseMetadataProvider.overrideWith(
            (ref) async => const <String, ChannelBrowseMetadata>{},
          ),
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
          // Stands in for any of iptvChannelsProvider's real dependencies
          // (auto-scan availability, favorites, personal channels, the
          // channel data service) recomputing. Using ref.watch -- not
          // ref.invalidate -- is what makes this a "reload" rather than a
          // "refresh" in Riverpod's AsyncValue vocabulary: only reload skips
          // the loading branch by default.
          iptvChannelsProvider.overrideWith((ref) async {
            ref.watch(reloadTrigger);
            return channels;
          }),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: IPTVScreen(tenFootMode: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AiroTvShell), findsOneWidget);
      final shellStateBefore = tester.state(find.byType(AiroTvShell));

      // Simulates the real-world trigger: some provider iptvChannelsProvider
      // transitively watches changes value as a side effect of an ordinary
      // interaction elsewhere on screen.
      container.read(reloadTrigger.notifier).state++;
      await tester.pump();

      // A background reload of a provider that already has cached data must
      // not blank the whole browse UI -- AiroTvShell should stay mounted,
      // not get replaced by the full-screen loading state.
      expect(
        find.byType(AiroTvShell),
        findsOneWidget,
        reason:
            'iptvChannelsProvider reloading (with cached data available) '
            'must not swap AiroTvShell out for the full-screen loading state',
      );

      await tester.pumpAndSettle();

      final shellStateAfter = tester.state(find.byType(AiroTvShell));
      expect(
        identical(shellStateBefore, shellStateAfter),
        isTrue,
        reason:
            'AiroTvShellState must survive a dependency-driven channel-list '
            'reload -- widgets holding a ref captured before the reload '
            '(e.g. a pending _toggleMultiview call) must not find it torn '
            'down underneath them',
      );

      // Drains AiroTvShell's own visible-channel-scan debounce timer (up to
      // ~450ms, see channel_warmup_policy.dart) so its dispose() gets a
      // chance to cancel it before teardown -- unrelated to the assertion
      // above, just this screen's normal background behavior.
      await tester.pump(const Duration(milliseconds: 500));
      // Unmount and dispose the container explicitly, in that order and
      // before the test body returns, so every State.dispose() and every
      // provider's ref.onDispose() (and the Timers each cancels) run before
      // the test binding's end-of-test "no pending timers" invariant check.
      // addTearDown callbacks run too late for that check.
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );
}

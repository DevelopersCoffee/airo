import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import 'package:feature_iptv/feature_iptv.dart';

void main() {
  testWidgets(
    'VideoPlayerWidget renders the loading placeholder when no video view is available',
    (tester) async {
      final service = VideoPlayerStreamingService(
        engine: FakeAiroPlaybackEngine(),
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvStreamingServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(home: VideoPlayerWidget()),
        ),
      );
      await tester.pump();

      // No channel played yet — buildVideoView() is null, so the widget
      // must fall back to its placeholder/loading branch instead of
      // crashing on a null video surface.
      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    },
  );

  testWidgets(
    'subtitle button is hidden when there are no tracks',
    (tester) async {
      final engine = FakeAiroPlaybackEngine(tracks: const []);
      final service = VideoPlayerStreamingService(engine: engine);
      addTearDown(service.dispose);

      // Pump the widget (and subscribe to service.stateStream via
      // streamingStateProvider) BEFORE calling playChannel(). The service's
      // state stream is a plain broadcast stream with no replay, so a
      // listener that subscribes after playChannel() has already emitted
      // would miss those events entirely and stay stuck in the loading
      // branch — which would make this assertion trivially true regardless
      // of tracks. Wrapping in a Scaffold matches how VideoPlayerWidget is
      // actually embedded in production (see AiroResponsiveScaffold usage
      // in iptv_screen.dart) — the control bar's volume Slider needs a
      // Material ancestor once the widget reaches its "player" state.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [iptvStreamingServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: Scaffold(body: VideoPlayerWidget()),
          ),
        ),
      );
      await tester.pump();

      await service.playChannel(
        IPTVChannel(id: 'c1', name: 'Chan', streamUrl: 'https://x/y.m3u8'),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('iptv-player-subtitle-button')),
        findsNothing,
      );

      // playChannel() starts periodic timers (buffer monitor, live-edge
      // detector). testWidgets' pending-timer invariant check runs before
      // addTearDown callbacks fire, so those timers must be stopped inside
      // the test body itself — addTearDown(service.dispose) alone isn't
      // enough here (see VideoPlayerStreamingService.stop()).
      await service.stop();
    },
  );

  testWidgets(
    'subtitle button is visible and calls selectTrack when tracks exist',
    (tester) async {
      // Two subtitle tracks are configured (not one) so the auto-selected
      // default (the first track, per FakeAiroPlaybackEngine's
      // _initialTrackSelection) is provably different from the track the
      // test taps (the second one). With only one track, the post-tap
      // assertion would pass identically whether or not the tap actually
      // drove service.selectTrack() — it would pass even if the sheet's
      // onTap only called Navigator.pop().
      final engine = FakeAiroPlaybackEngine(
        tracks: const [
          AiroPlaybackTrackOption(
            id: 'external_sub_0',
            kind: AiroPlaybackTrackKind.subtitle,
            label: 'English',
            isExternal: true,
          ),
          AiroPlaybackTrackOption(
            id: 'external_sub_1',
            kind: AiroPlaybackTrackKind.subtitle,
            label: 'French',
            isExternal: true,
          ),
        ],
      );
      final service = VideoPlayerStreamingService(engine: engine);
      addTearDown(service.dispose);

      // See comment in the test above — pump before playChannel() so the
      // widget's stream subscription is live in time to observe the
      // tracks-populated state, and wrap in a Scaffold for the Material
      // ancestor the control bar's volume Slider requires.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [iptvStreamingServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(
            home: Scaffold(body: VideoPlayerWidget()),
          ),
        ),
      );
      await tester.pump();

      await service.playChannel(
        IPTVChannel(id: 'c1', name: 'Chan', streamUrl: 'https://x/y.m3u8'),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('iptv-player-subtitle-button')),
        findsOneWidget,
      );

      // Make the pre-tap state explicit: the engine auto-selects the first
      // track of each kind on open, so at this point the subtitle selection
      // is already 'external_sub_0' — before the test has tapped anything.
      expect(
        service.currentState.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
        'external_sub_0',
      );

      // A fixed-duration pump — not pumpAndSettle() — because playChannel()
      // leaves a 1s periodic buffer-monitor timer running, which would
      // otherwise keep scheduling frames forever and make pumpAndSettle()
      // time out. This is enough to let the bottom-sheet's route transition
      // animation finish.
      await tester.tap(find.byKey(const ValueKey('iptv-player-subtitle-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('English'), findsOneWidget);
      expect(find.text('French'), findsOneWidget);

      // Tap the track that is NOT already auto-selected ('French'). Tapping
      // the already-selected 'English' track wouldn't prove the tap drove a
      // real state transition, since selectedTrackIds would already read
      // 'external_sub_0' regardless of whether the tap did anything.
      await tester.tap(find.text('French'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        service.currentState.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
        'external_sub_1',
      );

      // See comment in the test above — stop the periodic timers before
      // the test body returns so the pending-timer invariant check passes.
      await service.stop();
    },
  );
}

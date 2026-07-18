import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/widgets/player_brightness_controller.dart';
import 'package:feature_iptv/presentation/widgets/player_lock_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ===========================================================================
  // Gesture / lock / brightness / VOD seek bar (PR #868). These drive the
  // widget through a fixed streamingStateProvider override and exercise the
  // control-chrome layer that sits on top of the engine-driven video surface.
  // ===========================================================================
  Future<void> pumpPlayer(
    WidgetTester tester, {
    bool enableSwipeChannelChange = false,
    PlayerBrightnessController? brightnessController,
    StreamingState? state,
    List<IPTVChannel>? channels,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (channels != null)
            iptvChannelsProvider.overrideWith((ref) async => channels),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              state ??
                  StreamingState(
                    playbackState: PlaybackState.idle,
                    isLiveStream: true,
                    currentChannel: const IPTVChannel(
                      id: 'news-1',
                      name: 'City News Live',
                      streamUrl: 'https://example.com/news.m3u8',
                      group: 'News',
                      category: ChannelCategory.news,
                    ),
                  ),
            ),
          ),
        ],
        child: MaterialApp(
          home: VideoPlayerWidget(
            enableSwipeChannelChange: enableSwipeChannelChange,
            brightnessController: brightnessController,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets(
    'D-pad down surfs to the next channel while playback stays primary (CV-008 UC-002)',
    (tester) async {
      const current = IPTVChannel(
        id: 'news-1',
        name: 'City News Live',
        streamUrl: 'https://example.com/news.m3u8',
        group: 'News',
        category: ChannelCategory.news,
      );
      const next = IPTVChannel(
        id: 'sports-1',
        name: 'Stadium Sports',
        streamUrl: 'https://example.com/sports.m3u8',
        group: 'Sports',
        category: ChannelCategory.sports,
      );

      // Real service backed by a fake engine (not a real VideoPlayerController)
      // -- same pattern the subtitle-selector tests below use, since a real
      // controller here would leak (VideoPlayerStreamingService.dispose()
      // does not resolve promptly once real playback has started).
      final service = VideoPlayerStreamingService(
        engine: FakeAiroPlaybackEngine(),
      );
      addTearDown(service.dispose);

      final container = ProviderContainer(
        overrides: [
          iptvStreamingServiceProvider.overrideWithValue(service),
          iptvChannelsProvider.overrideWith(
            (ref) async => const [current, next],
          ),
        ],
      );
      addTearDown(container.dispose);
      // Pre-warm so nextChannelProvider sees both channels the moment the
      // key event fires, instead of starting from AsyncLoading (nothing
      // else reads iptvChannelsProvider until then).
      await container.read(iptvChannelsProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
        ),
      );
      await tester.pump();

      await service.playChannel(current);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(find.text('Stadium Sports'), findsWidgets);

      // Pending timers (buffer monitor, live-edge detector) must be stopped
      // inside the test body -- the pending-timer check runs before
      // addTearDown(service.dispose) fires.
      await service.stop();
    },
  );

  testWidgets(
    'locking hides playback controls but keeps the lock button interactive',
    (tester) async {
      await pumpPlayer(tester, enableSwipeChannelChange: true);

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);

      await tester.tap(find.byType(PlayerLockButton));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.byIcon(Icons.skip_previous), findsNothing);
      expect(find.byIcon(Icons.skip_next), findsNothing);
      expect(find.byType(PlayerLockButton), findsOneWidget);
    },
  );

  testWidgets('tapping the lock button again unlocks and restores controls', (
    tester,
  ) async {
    await pumpPlayer(tester);

    await tester.tap(find.byType(PlayerLockButton));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    await tester.tap(find.byType(PlayerLockButton));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('resets brightness via the injected controller on dispose', (
    tester,
  ) async {
    final controller = FakePlayerBrightnessController(initial: 0.6);
    await pumpPlayer(tester, brightnessController: controller);
    expect(controller.resetCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(controller.resetCalls, 1);
  });

  testWidgets('shows a VOD seek bar with resume position when not live', (
    tester,
  ) async {
    await pumpPlayer(
      tester,
      state: StreamingState(
        playbackState: PlaybackState.playing,
        isLiveStream: false,
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 120),
        currentChannel: const IPTVChannel(
          id: 'movie-1',
          name: 'Sample Movie',
          streamUrl: 'https://example.com/movie.m3u8',
          group: 'Movies',
          category: ChannelCategory.movies,
        ),
      ),
    );

    final seekBar = find.byKey(const ValueKey('iptv-player-vod-seek-bar'));
    expect(seekBar, findsOneWidget);

    final slider = tester.widget<Slider>(seekBar);
    expect(slider.max, 120.0);
    expect(slider.value, 30.0);
  });

  testWidgets('hides the VOD seek bar for live streams', (tester) async {
    await pumpPlayer(tester);

    expect(
      find.byKey(const ValueKey('iptv-player-vod-seek-bar')),
      findsNothing,
    );
  });

  // ===========================================================================
  // Engine-driven playback + subtitle/track selector (CV-016 migration). These
  // drive the widget through a real VideoPlayerStreamingService backed by a
  // FakeAiroPlaybackEngine, so buildVideoView() and the track catalog flow
  // through the production state pipeline.
  // ===========================================================================
  testWidgets(
    'VideoPlayerWidget renders the loading placeholder when no video view is available',
    (tester) async {
      final service = VideoPlayerStreamingService(
        engine: FakeAiroPlaybackEngine(),
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [iptvStreamingServiceProvider.overrideWithValue(service)],
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

  testWidgets('subtitle button is hidden when there are no tracks', (
    tester,
  ) async {
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
        child: const MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
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
  });

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
          child: const MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
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
      await tester.tap(
        find.byKey(const ValueKey('iptv-player-subtitle-button')),
      );
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

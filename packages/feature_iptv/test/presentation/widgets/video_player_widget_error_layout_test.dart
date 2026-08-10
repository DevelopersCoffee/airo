import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The playback error/diagnostic message and the transport controls overlay
// (play/pause, scrub bar) render in the same Stack, and the controls are
// only opacity-toggled, never removed. A vertically-centered error message
// can grow tall enough to sit under the bottom control bar. The fix anchors
// the error to the upper band so the two can never collide.
void main() {
  const viewportHeight = 540.0;

  Future<ProviderContainer> pumpErrorPlayer(
    WidgetTester tester, {
    int retryCount = 0,
    List<IPTVChannel>? channels,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const mapper = AiroPlaybackDiagnosticMapper();
    final diagnostic = mapper.map(
      const AiroPlaybackFailureEvent(
        overrideCode: AiroPlaybackDiagnosticCode.providerAuthDenied,
      ),
    );
    const currentChannel = IPTVChannel(
      id: 'news-1',
      name: 'City News Live',
      streamUrl: 'https://example.com/news.m3u8',
      group: 'News',
    );
    // A fake engine, not the real service default: Skip channel drives a
    // real playChannel() call, which would otherwise stand up a genuine
    // VideoPlayerController that never gets disposed once the test ends.
    final service = _RecoveryRecordingService();
    addTearDown(() async {
      await service.stop();
      service.dispose();
    });

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvStreamingServiceProvider.overrideWithValue(service),
        if (channels != null)
          iptvChannelsProvider.overrideWith((ref) async => channels),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(
            StreamingState(
              playbackState: PlaybackState.error,
              isLiveStream: true,
              diagnostic: diagnostic,
              retryCount: retryCount,
              currentChannel: currentChannel,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 960,
              height: viewportHeight,
              child: VideoPlayerWidget(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('diagnostic error message stays in the upper band, clear of the '
      'bottom transport controls', (tester) async {
    await pumpErrorPlayer(tester);

    expect(
      find.text(
        'Your provider rejected this stream. Check your playlist credentials.',
      ),
      findsOneWidget,
    );

    final messageTop = tester
        .getTopLeft(
          find.text(
            'Your provider rejected this stream. Check your playlist credentials.',
          ),
        )
        .dy;

    // Upper-band placement: the message must start well above vertical
    // center, leaving the whole bottom half clear for transport controls.
    expect(messageTop, lessThan(viewportHeight * 0.3));
  });

  testWidgets(
    'diagnostic error replaces a retained video view and all player chrome',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const mapper = AiroPlaybackDiagnosticMapper();
      final service = _RetainedVideoViewService();
      addTearDown(service.dispose);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvStreamingServiceProvider.overrideWithValue(service),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              StreamingState(
                currentChannel: const IPTVChannel(
                  id: 'news-1',
                  name: 'City News Live',
                  streamUrl: 'https://example.com/news.m3u8',
                ),
                playbackState: PlaybackState.error,
                diagnostic: mapper.map(
                  const AiroPlaybackFailureEvent(
                    overrideCode: AiroPlaybackDiagnosticCode.providerAuthDenied,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('retained-video-view')), findsNothing);
      expect(
        find.byKey(const ValueKey('diagnostic-error-retry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('iptv-player-controls-opacity')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('iptv-player-lock-button')),
        findsNothing,
      );
      // issues/1025: the idle center play button and hover chrome (volume,
      // buffer label, PiP/track/fullscreen) must never composite on top of
      // the error overlay — not just be faded out.
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(find.textContaining('Buffer:'), findsNothing);
    },
  );

  testWidgets('loading replaces a retained video view and player controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _RetainedVideoViewService();
    addTearDown(service.dispose);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvStreamingServiceProvider.overrideWithValue(service),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(
            StreamingState(playbackState: PlaybackState.loading),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('retained-video-view')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey('iptv-player-controls-opacity')),
      findsNothing,
    );
  });

  testWidgets(
    'desktop controls stay visible while hovered and fade after pointer exit',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = _RetainedVideoViewService();
      addTearDown(service.dispose);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvStreamingServiceProvider.overrideWithValue(service),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              StreamingState(playbackState: PlaybackState.playing),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 960,
                height: viewportHeight,
                child: VideoPlayerWidget(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      AnimatedOpacity controls() => tester.widget(
        find.byKey(const ValueKey('iptv-player-controls-opacity')),
      );
      expect(controls().opacity, 0);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: const Offset(1100, 700));
      // (700, 400) is dead space in the expanded hover-chrome layout --
      // clear of the top-left row, the center transport row, the trailing
      // VOL/CH zone, and the bottom timeline bar. The video's exact
      // geometric center (480, 270) now lands on the play/pause button
      // itself (#1025/#1600 straightened out the center row so it's no
      // longer skewed off-center by an inline VOL pillar), and hovering a
      // TvFocusable focuses it on pointer-enter -- which is correct,
      // deliberate behavior this test isn't exercising, and would otherwise
      // hold the overlay open forever via the "never hide a focused
      // control" rule this test doesn't want to invoke.
      await pointer.moveTo(const Offset(700, 400));
      await tester.pump();
      expect(controls().opacity, 1);

      await tester.pump(const Duration(seconds: 5));
      expect(
        controls().opacity,
        1,
        reason: 'hovered desktop controls must not disappear under the pointer',
      );

      await pointer.moveTo(const Offset(1100, 700));
      await tester.pump(const Duration(milliseconds: 2900));
      expect(controls().opacity, 1);
      await tester.pump(const Duration(milliseconds: 200));
      expect(controls().opacity, 0);
      await pointer.removePointer();
    },
  );

  // issues/04-recovery-states.md acceptance criterion 1: three distinct
  // outcomes, all D-pad reachable (the old ElevatedButton had no
  // TvFocusable at all).
  testWidgets('offers Try Again, Skip channel, and Report dead link, each a '
      'D-pad-reachable TvFocusable', (tester) async {
    await pumpErrorPlayer(tester);

    for (final key in [
      'diagnostic-error-retry',
      'diagnostic-error-skip',
      'diagnostic-error-report',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(TvFocusable),
        ),
        findsOneWidget,
        reason: '$key must be a TvFocusable so a remote can reach it',
      );
    }
  });

  testWidgets(
    'diagnostic recovery visibly owns focus and traverses every action',
    (tester) async {
      await pumpErrorPlayer(tester);

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Try Again',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Skip channel',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Report dead link',
      );

      // Fire TV must not let the recovery row's edge escape to an unrelated
      // player control. On-device this also catches a single RIGHT press
      // being interpreted as two geometric traversal steps.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Report dead link',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Skip channel',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Try Again',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Try Again',
      );
    },
  );

  testWidgets(
    'rebuilds preserve user focus and a failed retry remount refocuses Try Again',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final states = StreamController<StreamingState>.broadcast();
      addTearDown(states.close);
      final service = VideoPlayerStreamingService(
        engine: FakeAiroPlaybackEngine(),
      );
      addTearDown(service.dispose);
      const mapper = AiroPlaybackDiagnosticMapper();
      final diagnostic = mapper.map(
        const AiroPlaybackFailureEvent(
          overrideCode: AiroPlaybackDiagnosticCode.providerAuthDenied,
        ),
      );
      const channel = IPTVChannel(
        id: 'news-1',
        name: 'City News Live',
        streamUrl: 'https://example.com/news.m3u8',
      );
      StreamingState failed() => StreamingState(
        playbackState: PlaybackState.error,
        isLiveStream: true,
        diagnostic: diagnostic,
        currentChannel: channel,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            iptvStreamingServiceProvider.overrideWithValue(service),
            streamingStateProvider.overrideWith((ref) => states.stream),
          ],
          child: const MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
        ),
      );
      states.add(failed());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Try Again',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Skip channel',
      );

      states.add(failed());
      await tester.pump(const Duration(seconds: 5));
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Skip channel',
        reason:
            'same-error rebuilds and the old controls timer must not steal focus',
      );

      states.add(
        StreamingState(
          playbackState: PlaybackState.loading,
          isLiveStream: true,
          currentChannel: channel,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      states.add(failed());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player recovery Try Again',
      );
    },
  );

  testWidgets('closing player actions restores diagnostic recovery focus', (
    tester,
  ) async {
    await pumpErrorPlayer(tester);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player recovery Try Again',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    expect(find.text('Player actions'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player action Listen only',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Player actions'), findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player recovery Try Again',
    );
  });

  testWidgets('Report dead link saves a local report and confirms it', (
    tester,
  ) async {
    final container = await pumpErrorPlayer(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();

    final reports = container.read(deadLinkReportStorageProvider).readAll();
    expect(reports, hasLength(1));
    expect(reports.single.channelName, 'City News Live');
    expect(find.text('Saved locally — nothing was sent'), findsOneWidget);
  });

  testWidgets('Skip channel moves to the next channel in the playlist', (
    tester,
  ) async {
    const nextChannel = IPTVChannel(
      id: 'sports-1',
      name: 'Stadium Sports',
      streamUrl: 'https://example.com/sports.m3u8',
      group: 'Sports',
    );
    final container = await pumpErrorPlayer(
      tester,
      channels: const [
        IPTVChannel(
          id: 'news-1',
          name: 'City News Live',
          streamUrl: 'https://example.com/news.m3u8',
          group: 'News',
        ),
        nextChannel,
      ],
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(tester.takeException(), isNull);
    final service =
        container.read(iptvStreamingServiceProvider)
            as _RecoveryRecordingService;
    expect(service.playedChannels, [nextChannel]);

    await service.stop();
  });

  testWidgets('Try Again activates exactly once from CENTER', (tester) async {
    final container = await pumpErrorPlayer(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    final service =
        container.read(iptvStreamingServiceProvider)
            as _RecoveryRecordingService;
    expect(service.retryCalls, 1);
  });
}

class _RecoveryRecordingService extends VideoPlayerStreamingService {
  _RecoveryRecordingService() : super(engine: FakeAiroPlaybackEngine());

  int retryCalls = 0;
  final List<IPTVChannel> playedChannels = [];

  @override
  Future<void> retry() async {
    retryCalls++;
  }

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    playedChannels.add(channel);
  }
}

class _RetainedVideoViewService extends _RecoveryRecordingService {
  @override
  Widget? buildVideoView() {
    return const ColoredBox(
      key: ValueKey('retained-video-view'),
      color: Colors.green,
    );
  }
}

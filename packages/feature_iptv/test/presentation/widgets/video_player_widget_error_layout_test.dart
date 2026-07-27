import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
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
      const AiroPlaybackFailureEvent(httpStatusCode: 403),
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
    final service = VideoPlayerStreamingService(
      engine: FakeAiroPlaybackEngine(),
    );
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
        const AiroPlaybackFailureEvent(httpStatusCode: 403),
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

  testWidgets('Report dead link saves a local report and confirms it', (
    tester,
  ) async {
    final container = await pumpErrorPlayer(tester);

    await tester.tap(find.text('Report dead link'));
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

    await tester.tap(find.text('Skip channel'));
    await tester.pump();

    expect(tester.takeException(), isNull);

    // Pending timers (buffer monitor, live-edge detector) must be stopped
    // inside the test body -- the pending-timer check runs before
    // addTearDown(service.dispose) fires.
    await container.read(iptvStreamingServiceProvider).stop();
  });
}

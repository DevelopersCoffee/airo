import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// AiroTV D-pad design's TRANSPORT (OK) screen: player controls plus a
// discoverable More actions target, a metadata row above them, and a
// "MENU for more actions" hint. useTvTransportBar: true swaps the
// touch-oriented VOL/CH pillar layout for this bar; phone/tablet callers
// (useTvTransportBar defaults false) are unaffected.
void main() {
  Future<ProviderContainer> pumpTransportBar(
    WidgetTester tester, {
    required double width,
    Duration liveDelay = Duration.zero,
    VideoPlayerStreamingService? service,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (service != null)
          iptvStreamingServiceProvider.overrideWithValue(service),
        streamingStateProvider.overrideWith(
          (ref) => Stream.value(
            StreamingState(
              playbackState: PlaybackState.playing,
              isLiveStream: true,
              liveDelay: liveDelay,
              currentQuality: VideoQuality.high,
              currentChannel: IPTVChannel(
                id: 'news-1',
                name: 'City News Live',
                streamUrl: 'https://example.com/news.m3u8',
                group: 'News',
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
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              height: 540,
              child: const VideoPlayerWidget(
                initiallyFullscreen: true,
                useTvTransportBar: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('renders all transport buttons and channel metadata at the '
      "design's 960px canvas width, with no overflow", (tester) async {
    await pumpTransportBar(tester, width: 960);

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('iptv-tv-transport-play-pause')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-tv-transport-restart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-tv-transport-audio')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-tv-transport-subtitles')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-tv-transport-favourite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-tv-transport-info')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-player-more-button')),
      findsOneWidget,
    );
    expect(find.text('MENU for more actions'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    // The touch-oriented layout must not appear alongside it.
    expect(find.text('VOL'), findsNothing);
    expect(find.text('CH'), findsNothing);
  });

  testWidgets('does not overflow at a narrower TV panel width (720)', (
    tester,
  ) async {
    await pumpTransportBar(tester, width: 720);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Favourite button toggles the favorite and updates its icon', (
    tester,
  ) async {
    final container = await pumpTransportBar(tester, width: 960);

    await tester.tap(find.byKey(const ValueKey('iptv-tv-transport-favourite')));
    await tester.pump();
    await tester.pump();

    final ids = await container.read(favoriteChannelIdsProvider.future);
    expect(ids, contains('news-1'));
  });

  testWidgets('Info button opens the context menu', (tester) async {
    await pumpTransportBar(tester, width: 960);

    await tester.tap(find.byKey(const ValueKey('iptv-tv-transport-info')));
    await tester.pump();

    expect(find.text('Actions for'), findsOneWidget);
  });

  testWidgets(
    'transport stays visible beyond auto-hide while a D-pad control is focused',
    (tester) async {
      await pumpTransportBar(tester, width: 960);

      final more = find.byKey(const ValueKey('iptv-player-more-button'));
      final moreFocus = tester.widget<Focus>(
        find.descendant(of: more, matching: find.byType(Focus)).first,
      );
      moreFocus.focusNode!.requestFocus();
      await tester.pump();

      await tester.pump(const Duration(seconds: 5));

      final opacity = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('iptv-player-controls-opacity')),
      );
      expect(opacity.opacity, 1);
      expect(moreFocus.focusNode!.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets(
    'Pause transport action pauses instead of seeking live when behind',
    (tester) async {
      final service = _TransportRecordingService();
      addTearDown(service.dispose);
      await pumpTransportBar(
        tester,
        width: 960,
        liveDelay: const Duration(seconds: 10),
        service: service,
      );

      final wrapper = find.byKey(
        const ValueKey('iptv-tv-transport-play-pause'),
      );
      final focus = tester.widget<Focus>(
        find.descendant(of: wrapper, matching: find.byType(Focus)).first,
      );
      focus.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();

      expect(service.pauseCalls, 1);
      expect(service.goLiveCalls, 0);
    },
  );

  testWidgets('transport focus movement refreshes the controls hide timer', (
    tester,
  ) async {
    await pumpTransportBar(tester, width: 960);

    await tester.pump(const Duration(seconds: 3));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.byKey(const ValueKey('iptv-tv-transport-restart')),
      findsOneWidget,
    );
    expect(
      FocusManager.instance.primaryFocus?.hasFocus,
      isTrue,
      reason:
          'focus movement must keep the controls visible beyond the '
          'original four-second deadline',
    );
    expect(
      FocusManager.instance.primaryFocus,
      isNot(
        predicate<FocusNode>(
          (node) => node.debugLabel == 'IPTV player surface',
        ),
      ),
    );
  });

  testWidgets('MENU opens player actions and visibly focuses Listen only', (
    tester,
  ) async {
    await pumpTransportBar(tester, width: 960);

    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();

    expect(find.text('Player actions'), findsOneWidget);
    expect(find.text('Actions for'), findsNothing);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player action Listen only',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });

  testWidgets('six RIGHT presses and CENTER open Player actions from Pause', (
    tester,
  ) async {
    await pumpTransportBar(tester, width: 960);

    final pauseWrapper = find.byKey(
      const ValueKey('iptv-tv-transport-play-pause'),
    );
    final pauseFocus = tester.widget<Focus>(
      find.descendant(of: pauseWrapper, matching: find.byType(Focus)).first,
    );
    pauseFocus.focusNode!.requestFocus();
    await tester.pump();

    for (var index = 0; index < 6; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player more actions',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();

    expect(find.text('Player actions'), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player action Listen only',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });
}

class _TransportRecordingService extends VideoPlayerStreamingService {
  _TransportRecordingService() : super(engine: FakeAiroPlaybackEngine());

  int pauseCalls = 0;
  int goLiveCalls = 0;

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> goLive() async {
    goLiveCalls++;
  }
}

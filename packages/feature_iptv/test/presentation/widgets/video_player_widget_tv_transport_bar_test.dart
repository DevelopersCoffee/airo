import 'dart:async';

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
const _titleSafeFraction = 0.05;
const _transportPanelMaxFraction = 0.80;

void main() {
  Future<ProviderContainer> pumpTransportBar(
    WidgetTester tester, {
    required double width,
    double height = 540,
    Duration liveDelay = Duration.zero,
    VideoPlayerStreamingService? service,
    Stream<StreamingState>? states,
    FocusNode? retainedFocusNode,
    List<String> favoriteIds = const [],
    List<AiroPlaybackTrackOption> tracks = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      if (favoriteIds.isNotEmpty) 'iptv_favorite_channel_ids': favoriteIds,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (service != null)
          iptvStreamingServiceProvider.overrideWithValue(service),
        streamingStateProvider.overrideWith(
          (ref) =>
              states ??
              Stream.value(
                StreamingState(
                  playbackState: PlaybackState.playing,
                  isLiveStream: true,
                  liveDelay: liveDelay,
                  currentQuality: VideoQuality.high,
                  tracks: tracks,
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

    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SizedBox(
                  width: width,
                  height: height,
                  child: const VideoPlayerWidget(
                    initiallyFullscreen: true,
                    useTvTransportBar: true,
                    enableTouchGestures: false,
                  ),
                ),
                if (retainedFocusNode != null)
                  Focus(
                    focusNode: retainedFocusNode,
                    child: const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  final playPause = find.byKey(const ValueKey('iptv-tv-transport-play-pause'));

  const actionKeys = [
    ValueKey('iptv-tv-transport-play-pause'),
    ValueKey('iptv-tv-transport-restart'),
    ValueKey('iptv-tv-transport-audio'),
    ValueKey('iptv-tv-transport-subtitles'),
    ValueKey('iptv-tv-transport-favourite'),
    ValueKey('iptv-tv-transport-info'),
    ValueKey('iptv-player-more-button'),
  ];

  void expectBoundedSingleActionRow(WidgetTester tester, Size viewport) {
    expect(playPause, findsOneWidget);
    expect(
      find.ancestor(of: playPause, matching: find.byType(Wrap)),
      findsNothing,
      reason: 'TV transport actions must be a single row, not a Wrap',
    );

    final actionRow = find.ancestor(
      of: playPause,
      matching: find.byWidgetPredicate(
        (widget) => widget is Row || widget is ListView,
      ),
    );
    expect(actionRow, findsWidgets);

    final visibleActionKeys = actionKeys
        .where((key) => find.byKey(key).evaluate().isNotEmpty)
        .toList();
    expect(visibleActionKeys, isNotEmpty);
    final actionYs = {
      for (final key in visibleActionKeys) tester.getCenter(find.byKey(key)).dy,
    };
    expect(
      actionYs,
      hasLength(1),
      reason: 'all visible transport actions must share one row',
    );

    final titleSafeWidth = viewport.width * (1 - 2 * _titleSafeFraction);
    final panel = find.byKey(const ValueKey('iptv-tv-transport-panel'));
    expect(panel, findsOneWidget);
    expect(
      tester.getSize(panel).width,
      lessThanOrEqualTo(titleSafeWidth * _transportPanelMaxFraction + 0.5),
    );
    expect(
      tester.getSize(panel).width,
      lessThan(viewport.width * 0.90),
      reason: 'transport panel must not be full-bleed',
    );
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

  testWidgets(
    'overflowed unique actions move into the More sheet at a narrow width',
    (tester) async {
      // 7 × 64dp + 6 gaps = 496dp. A 480-wide panel's title-safe 80% cap
      // cannot fit that row, so unique trailing actions must leave the bar.
      await pumpTransportBar(tester, width: 480, height: 720);

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('iptv-player-more-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('iptv-tv-transport-play-pause')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('iptv-tv-transport-info')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('iptv-tv-transport-favourite')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('iptv-player-more-button')));
      await tester.pumpAndSettle();

      expect(find.text('Player actions'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('iptv-player-info-menu-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('iptv-player-favourite-menu-action')),
        findsOneWidget,
      );
    },
  );

  testWidgets('transport actions stay on one width-capped row at 1280x720', (
    tester,
  ) async {
    const viewport = Size(1280, 720);
    await pumpTransportBar(
      tester,
      width: viewport.width,
      height: viewport.height,
    );

    expect(tester.takeException(), isNull);
    expectBoundedSingleActionRow(tester, viewport);
  });

  testWidgets('transport actions stay on one width-capped row at 1920x1080', (
    tester,
  ) async {
    const viewport = Size(1920, 1080);
    await pumpTransportBar(
      tester,
      width: viewport.width,
      height: viewport.height,
    );

    expect(tester.takeException(), isNull);
    expectBoundedSingleActionRow(tester, viewport);
  });

  testWidgets('first focus lands on Pause/Play', (tester) async {
    await pumpTransportBar(tester, width: 1280, height: 720);

    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player center control',
    );
  });

  testWidgets('transport action height stays between 56 and 72', (
    tester,
  ) async {
    await pumpTransportBar(tester, width: 1280, height: 720);

    final size = tester.getSize(playPause);
    expect(size.height, inInclusiveRange(56, 72));
  });

  testWidgets(
    'Audio and Subtitles stay visible and ignore select without tracks',
    (tester) async {
      await pumpTransportBar(tester, width: 1280, height: 720);

      expect(
        find.byKey(const ValueKey('iptv-tv-transport-audio')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('iptv-tv-transport-subtitles')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('iptv-tv-transport-audio')));
      await tester.pump();
      expect(find.text('English audio'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('iptv-tv-transport-subtitles')),
      );
      await tester.pump();
      expect(find.text('Off'), findsNothing);
    },
  );

  testWidgets('Favourite reflects stored favorite state', (tester) async {
    await pumpTransportBar(
      tester,
      width: 1280,
      height: 720,
      favoriteIds: const ['news-1'],
    );

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
  });

  testWidgets('chrome auto-hides after 5s idle and D-pad shows it again', (
    tester,
  ) async {
    await pumpTransportBar(tester, width: 1280, height: 720);

    await tester.pump(const Duration(milliseconds: 300));
    final surface = FocusManager.instance.rootScope.descendants.firstWhere(
      (node) => node.debugLabel == 'player surface',
    );
    surface.requestFocus();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 4999));
    var opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('iptv-player-controls-opacity')),
    );
    expect(opacity.opacity, 1);

    await tester.pump(const Duration(milliseconds: 1));
    opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('iptv-player-controls-opacity')),
    );
    expect(opacity.opacity, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('iptv-player-controls-opacity')),
    );
    expect(opacity.opacity, 1);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'player center control',
    );
  });

  testWidgets('TV transport bar has no on-screen Back button', (tester) async {
    await pumpTransportBar(tester, width: 1280, height: 720);

    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(find.byTooltip('Back'), findsNothing);
    expect(find.text('Back'), findsNothing);
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
    'playing channel reclaims transport focus after retained-grid restore',
    (tester) async {
      final states = StreamController<StreamingState>();
      final retainedFocusNode = FocusNode(debugLabel: 'retained channel card');
      addTearDown(states.close);
      addTearDown(retainedFocusNode.dispose);
      await pumpTransportBar(
        tester,
        width: 960,
        states: states.stream,
        retainedFocusNode: retainedFocusNode,
      );
      retainedFocusNode.requestFocus();
      await tester.pump();

      states.add(
        StreamingState(
          playbackState: PlaybackState.playing,
          isLiveStream: true,
          currentChannel: IPTVChannel(
            id: 'news-1',
            name: 'City News Live',
            streamUrl: 'https://example.com/news.m3u8',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      retainedFocusNode.requestFocus();
      await tester.pump();
      expect(retainedFocusNode.hasPrimaryFocus, isTrue);

      await tester.pump(const Duration(milliseconds: 150));

      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        'player center control',
      );
    },
  );

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

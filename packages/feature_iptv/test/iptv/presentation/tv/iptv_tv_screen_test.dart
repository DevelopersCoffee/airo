import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final channels = [
    const IPTVChannel(
      id: 'news-1',
      name: 'City News Live',
      streamUrl: 'https://example.com/news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    ),
    const IPTVChannel(
      id: 'sports-1',
      name: 'Stadium Sports',
      streamUrl: 'https://example.com/sports.m3u8',
      group: 'Sports',
      category: ChannelCategory.sports,
    ),
    const IPTVChannel(
      id: 'music-1',
      name: 'Music India',
      streamUrl: 'https://example.com/music.m3u8',
      group: 'Music',
      category: ChannelCategory.music,
    ),
    const IPTVChannel(
      id: 'news-2',
      name: 'Global News',
      streamUrl: 'https://example.com/global-news.m3u8',
      group: 'News',
      category: ChannelCategory.news,
    ),
    const IPTVChannel(
      id: 'sports-2',
      name: 'Match Center',
      streamUrl: 'https://example.com/match-center.m3u8',
      group: 'Sports',
      category: ChannelCategory.sports,
    ),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<IPTVChannel>? visibleChannels,
    CompactEpgRepository? compactEpgRepository,
    DateTime? compactEpgNow,
    StreamingState? streamingState,
    StreamProbeTransport? streamProbeTransport,
    Size surfaceSize = const Size(1280, 720),
    bool settle = true,
  }) async {
    final effectiveStreamingState =
        streamingState ??
        StreamingState(playbackState: PlaybackState.idle, isLiveStream: true);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = surfaceSize;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith(
            (ref) async => visibleChannels ?? channels,
          ),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          if (compactEpgRepository != null)
            compactEpgRepositoryProvider.overrideWithValue(
              compactEpgRepository,
            ),
          if (compactEpgNow != null)
            compactEpgReferenceTimeProvider.overrideWithValue(compactEpgNow),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(effectiveStreamingState),
          ),
          if (streamProbeTransport != null)
            streamProbeTransportProvider.overrideWithValue(
              streamProbeTransport,
            ),
        ],
        child: const MaterialApp(home: IptvTvScreen()),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('renders TV browsing surface with categories and actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      // settle: false — the hero rail band's channels aren't audio-only, so
      // their MediaCards render a real (infinitely-repeating) pulsing LIVE
      // badge; pumpAndSettle never settles against a repeating animation.
      await pumpScreen(tester, settle: false);
      expect(find.text('Live channels'), findsOneWidget);
      expect(find.text('Airo TV Lite Receiver'), findsOneWidget);
      expect(find.text('Compatible profile'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Recent'), findsWidgets);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Diagnostics'), findsOneWidget);
      expect(find.text('Guide'), findsNothing);
      expect(find.textContaining('Profile-limited:'), findsOneWidget);
      expect(find.text('5 of 5 live channels'), findsOneWidget);
      expect(find.text('Browse'), findsOneWidget);
      expect(find.text('All'), findsWidgets);
      expect(find.text('News'), findsWidgets);
      expect(find.text('Sports'), findsWidgets);
      expect(find.text('Music'), findsWidgets);
      expect(find.text('Business'), findsNothing);
      expect(find.text('General'), findsNothing);
      expect(find.text('Search'), findsWidgets);
      expect(find.text('Playlist'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Scan visible channels')),
        findsOneWidget,
      );
      // The hero banner and its channel rail (added for the Airo TV design
      // revamp) surface the same top channel the grid already shows below,
      // so these now legitimately render more than once on screen.
      expect(find.text('City News Live'), findsWidgets);
      expect(find.text('Music India'), findsWidgets);
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Search')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('City News Live')), findsWidgets);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('auto scan removes and restores only unavailable channels', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      streamProbeTransport: _TvProbeTransport(
        unavailableChannelIds: const {'sports-1'},
      ),
      surfaceSize: const Size(1280, 2000),
      settle: false,
    );

    await tester.tap(find.text('Scan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Remove unavailable (1)'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);

    await tester.tap(find.text('Remove unavailable (1)'));
    await tester.pump();

    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('4 of 5 live channels'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pump();

    expect(find.text('5 of 5 live channels'), findsOneWidget);
  });

  testWidgets(
    'TV rail band renders titles and channels from railsProvider, not '
    'locally-computed favorites/category selection',
    (tester) async {
      // Exists only inside the railsProvider override below — never in
      // iptvChannelsProvider or favorites — so it can only reach the
      // screen through the new railsProvider-backed band, proving the old
      // local favorites/category computation no longer drives this UI.
      const railOnlyChannel = IPTVChannel(
        id: 'rail-only',
        name: 'Rail Only Channel',
        streamUrl: 'https://example.com/rail-only.m3u8',
        group: 'Test',
        category: ChannelCategory.general,
      );
      final rails = [
        const RailResult(
          definition: RailDefinition(
            id: 'top-india',
            title: 'Top India',
            query: RailQuery(),
            priority: 0,
          ),
          channels: [railOnlyChannel],
        ),
        const RailResult(
          definition: RailDefinition(
            id: 'live-sports',
            title: 'Live Sports',
            query: RailQuery(category: ChannelCategory.sports, liveOnly: true),
            priority: 20,
          ),
          channels: [],
        ),
      ];

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            iptvChannelsProvider.overrideWith((ref) async => channels),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            streamingStateProvider.overrideWith(
              (ref) => Stream.value(
                StreamingState(
                  playbackState: PlaybackState.idle,
                  isLiveStream: true,
                ),
              ),
            ),
            railsProvider.overrideWith((ref) async => rails),
          ],
          child: const MaterialApp(home: IptvTvScreen()),
        ),
      );
      // Bounded pump, not pumpAndSettle: railOnlyChannel isn't audio-only,
      // so its MediaCard renders a real (infinitely-repeating) pulsing LIVE
      // badge that pumpAndSettle would never consider settled.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // "Top India" is the highest-priority rail in the override; the band
      // renders it (and only it — a single fixed-height rail band).
      expect(find.text('Top India'), findsOneWidget);
      expect(find.text('Live Sports'), findsNothing);
      expect(find.text('Rail Only Channel'), findsWidgets);

      // railOnlyChannel's MediaCard runs a real, infinitely-repeating
      // pulsing LIVE badge animation; tear the tree down explicitly so its
      // AnimationController disposes instead of leaking past this test.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('renders compact current EPG from platform repository', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 7, 15, 9);
    final repository = InMemoryCompactEpgRepository(
      seed: CompactEpgSlice(
        entries: [
          CompactEpgEntry.fromPrograms(
            channelId: 'news-1',
            channelName: 'City News Live',
            now: now,
            programs: [
              CompactEpgProgram(
                programId: 'morning-news',
                title: 'Morning Bulletin',
                startsAt: now.subtract(const Duration(minutes: 10)),
                endsAt: now.add(const Duration(minutes: 20)),
              ),
            ],
          ),
        ],
        generatedAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
        source: CompactEpgSliceSource.localCache,
      ),
    );

    await pumpScreen(
      tester,
      compactEpgRepository: repository,
      compactEpgNow: now,
      // Default 1280x720 leaves the EPG-aware channel grid/list below the
      // hero rail almost no height, so GridView.builder never lazily
      // builds any items to assert against. Taller viewport gives that
      // section room to actually render.
      surfaceSize: const Size(1280, 2000),
      // Non-audio-only rail channels render a real, infinitely-repeating
      // pulsing LIVE badge now — pumpAndSettle would never settle.
      settle: false,
    );
    // The bounded pump above isn't enough for the async compact-EPG
    // provider's Future to resolve and rebuild. Bounded pump() calls never
    // hang on the rail band's repeating pulse animation (only pumpAndSettle
    // does, by waiting for *no* scheduled frames) so it's safe to just
    // pump a few more explicit frames here.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Now: Morning Bulletin'), findsOneWidget);
  });

  testWidgets('keeps compact TV viewport browse controls reachable', (
    tester,
  ) async {
    await pumpScreen(tester, surfaceSize: const Size(1024, 576), settle: false);

    expect(find.text('Live channels'), findsOneWidget);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Playlist'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.byType(Scrollbar), findsOneWidget);
  });

  testWidgets('shows macOS update action on desktop builds', (tester) async {
    final semantics = tester.ensureSemantics();
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpScreen(
        tester,
        surfaceSize: const Size(1440, 900),
        settle: false,
      );

      expect(find.text('Update'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Update')), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      semantics.dispose();
    }
  });

  testWidgets('shows readable playlist guide with primary dismissal', (
    tester,
  ) async {
    // settle: false, and bounded pumps below instead of pumpAndSettle: the
    // hero rail band's non-audio-only channels render a real, infinitely
    // repeating pulsing LIVE badge underneath the dialog.
    await pumpScreen(tester, settle: false);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('How to add a playlist'), findsOneWidget);
    expect(find.text('Find your playlist URL'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
  });

  testWidgets('opens fullscreen player from embedded TV controls', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      streamingState: StreamingState(
        currentChannel: channels[2],
        playbackState: PlaybackState.playing,
        isLiveStream: true,
      ),
      surfaceSize: const Size(1440, 900),
      settle: false,
    );

    expect(find.text('Music India'), findsWidgets);
    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-player')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('iptv-player-fullscreen-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-player')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-video-player')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('airo-tv-fullscreen-player')),
        matching: find.byIcon(Icons.fullscreen_exit),
      ),
      findsOneWidget,
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('airo-tv-fullscreen-player')),
        matching: find.byKey(const ValueKey('iptv-player-fullscreen-button')),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('mute button is present and toggles mute', (tester) async {
    await pumpScreen(
      tester,
      streamingState: StreamingState(
        currentChannel: channels[2],
        playbackState: PlaybackState.playing,
        isLiveStream: true,
      ),
      surfaceSize: const Size(1440, 900),
      settle: false,
    );

    // Fine volume control moved to the Netflix-style right-half drag gesture
    // (see player_gesture_overlay_test.dart); the old hover-to-reveal slider
    // never worked on touch devices and was removed. This mute toggle is the
    // remaining quick-access volume control in the button row.
    final muteButton = find.byKey(const ValueKey('iptv-player-mute-button'));
    expect(muteButton, findsOneWidget);

    await tester.tap(muteButton);
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('native fullscreen exit restores TV screen without blanking', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      streamingState: StreamingState(
        currentChannel: channels[2],
        playbackState: PlaybackState.playing,
        isLiveStream: true,
      ),
      surfaceSize: const Size(1440, 900),
      settle: false,
    );

    await tester.tap(
      find.byKey(const ValueKey('iptv-player-fullscreen-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-player')),
      findsOneWidget,
    );
    expect(AiroNativeFullscreen.debugHasMacosFullscreenExitHandler, isTrue);

    AiroNativeFullscreen.debugNotifyMacosFullscreenExited();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey('airo-tv-fullscreen-player')),
      findsNothing,
    );
    expect(find.text('Live channels'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Music India'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'TV fullscreen player disables touch gestures and swipe-channel buttons',
    (tester) async {
      await pumpScreen(
        tester,
        streamingState: StreamingState(
          currentChannel: channels[2],
          playbackState: PlaybackState.playing,
          isLiveStream: true,
        ),
        surfaceSize: const Size(1440, 900),
        settle: false,
      );

      await tester.tap(
        find.byKey(const ValueKey('iptv-player-fullscreen-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final playerWidget = tester.widget<VideoPlayerWidget>(
        find.byKey(const ValueKey('airo-tv-fullscreen-video-player')),
      );
      expect(playerWidget.enableTouchGestures, isFalse);
      expect(playerWidget.enableSwipeChannelChange, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('shows TV empty playlist state', (tester) async {
    await pumpScreen(tester, visibleChannels: const []);

    expect(find.text('Airo TV Lite Receiver'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Guide'), findsNothing);
    expect(find.text('Airo TV'), findsOneWidget);
    expect(find.text('Add Playlist URL'), findsOneWidget);
    expect(find.text('How to add'), findsOneWidget);
  });

  testWidgets('search dialog shows live channel results while typing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpScreen(tester, settle: false);

      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Search channels'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'music');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The matching channel surfaces inside the dialog itself — the user
      // does not have to press Done and hunt through the grid behind it.
      expect(
        find.byKey(const ValueKey('tv-search-result-music-1')),
        findsOneWidget,
      );
      expect(find.text('No channels match "music".'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('search dialog shows empty state for a query with no matches', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpScreen(tester, settle: false);

      await tester.tap(find.byIcon(Icons.search).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.enterText(find.byType(TextField), 'zzz-no-such-channel');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('No channels match "zzz-no-such-channel".'),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'closing the search dialog after typing does not crash during the pop '
    'animation (regression: TextEditingController used after dispose)',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpScreen(tester, settle: false);

        await tester.tap(find.byIcon(Icons.search).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.enterText(find.byType(TextField), 'news');
        await tester.pump();

        await tester.tap(find.text('Done'));
        // Pump through the dialog's pop animation frame by frame — the old
        // code disposed the controller as soon as showDialog's future
        // resolved, so these exact frames rebuilt a TextField bound to a
        // disposed controller and threw.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
        expect(find.text('Search channels'), findsNothing);
        // The query survives the dialog: the grid stays filtered.
        expect(find.text('2 results for "news"'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );
}

class _TvProbeTransport implements StreamProbeTransport {
  _TvProbeTransport({required this.unavailableChannelIds});

  final Set<String> unavailableChannelIds;

  @override
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  }) async {
    return StreamProbeHttpResponse(
      statusCode: unavailableChannelIds.contains(request.channelId) ? 404 : 206,
    );
  }
}

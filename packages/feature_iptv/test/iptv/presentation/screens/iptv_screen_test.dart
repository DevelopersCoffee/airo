import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import "package:feature_iptv/application/channel_metadata_enrichment.dart";
import "package:feature_iptv/application/providers/multiview_provider.dart"
    show multiviewDecoderBudgetProvider;
import "package:feature_iptv/feature_iptv.dart";
import 'package:feature_iptv/presentation/tv_ux/sections/bottom_nav_bar.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Auto Scan's real transport makes actual HTTP requests, which flutter
/// test's binding rejects with a blanket 400 -- silently marking every
/// fake channel here "unavailable" and blocking tap-to-play (see
/// airo_tv_shell_test.dart, which fakes this the same way).
class _FakeProbeTransport implements StreamProbeTransport {
  @override
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  }) async {
    return const StreamProbeHttpResponse(statusCode: 206);
  }
}

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
      name: 'Music Box',
      streamUrl: 'https://example.com/music.m3u8',
      group: 'Music',
      category: ChannelCategory.music,
    ),
  ];

  Widget createWidget({
    StreamingState? streamingState,
    VoidCallback? onOpenVod,
    VoidCallback? onSettings,
    Future<PhoneLocalMediaItem?> Function()? onPickLocalMediaForTv,
    Map<String, Object> initialPreferences = const {},
    List<IPTVChannel> Function()? channelLoader,
    List<Override> extraOverrides = const [],
    bool tenFootMode = false,
  }) {
    SharedPreferences.setMockInitialValues(initialPreferences);
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: CircularProgressIndicator()),
          );
        }

        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(snapshot.data!),
            streamProbeTransportProvider.overrideWithValue(
              _FakeProbeTransport(),
            ),
            iptvChannelsProvider.overrideWith(
              (ref) async => channelLoader?.call() ?? channels,
            ),
            channelBrowseMetadataProvider.overrideWith(
              (ref) async => const <String, ChannelBrowseMetadata>{},
            ),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            streamingStateProvider.overrideWith(
              (ref) => Stream.value(
                streamingState ??
                    StreamingState(
                      playbackState: PlaybackState.idle,
                      isLiveStream: true,
                      liveDelay: Duration(seconds: 1),
                    ),
              ),
            ),
            ...extraOverrides,
          ],
          child: MaterialApp(
            home: IPTVScreen(
              onOpenVod: onOpenVod,
              onSettings: onSettings,
              onPickLocalMediaForTv: onPickLocalMediaForTv,
              tenFootMode: tenFootMode,
            ),
          ),
        );
      },
    );
  }

  Widget createEmptyWidget({
    bool tenFootMode = false,
    List<Override> extraOverrides = const [],
  }) {
    SharedPreferences.setMockInitialValues({});
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: CircularProgressIndicator()),
          );
        }

        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(snapshot.data!),
            iptvChannelsProvider.overrideWith((ref) async => const []),
            channelBrowseMetadataProvider.overrideWith(
              (ref) async => const <String, ChannelBrowseMetadata>{},
            ),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            streamingStateProvider.overrideWith(
              (ref) => Stream.value(
                StreamingState(
                  playbackState: PlaybackState.idle,
                  isLiveStream: true,
                  liveDelay: Duration(seconds: 1),
                ),
              ),
            ),
            ...extraOverrides,
          ],
          child: MaterialApp(home: IPTVScreen(tenFootMode: tenFootMode)),
        );
      },
    );
  }

  Future<void> tapBottomNavDestination(
    WidgetTester tester,
    String label,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.byType(IptvBottomNavBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMyAikaSheet(WidgetTester tester) =>
      tapBottomNavDestination(tester, 'My Aika');

  Future<void> selectMyAikaTile(
    WidgetTester tester,
    ValueKey<String> key,
  ) async {
    tester.widget<ListTile>(find.byKey(key)).onTap?.call();
    await tester.pumpAndSettle();
  }

  testWidgets('renders Airo TV app bar and responsive live list', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Search channels'), findsNothing);
      expect(find.byTooltip('Playlist source'), findsNothing);
      expect(find.byTooltip('Guide URL'), findsNothing);
      expect(find.byTooltip('Movies & Shows'), findsNothing);
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(IptvBottomNavBar), findsOneWidget);
      expect(find.byTooltip('Cast'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('filter-chip-category')),
        findsOneWidget,
      );
      expect(find.text('Featured Player'), findsNothing);
      expect(find.text('Play media from your saved playlist.'), findsNothing);
      expect(find.text('Select a channel to start watching'), findsOneWidget);
      expect(
        find.text('Choose a channel from your playlist to begin streaming.'),
        findsNothing,
      );

      expect(find.text('Sort: Name'), findsOneWidget);
      expect(find.text('City News Live'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'ten-foot width: no bottom nav, no app bar, no drawer regression',
    (tester) async {
      await tester.pumpWidget(createWidget(tenFootMode: true));
      await tester.pumpAndSettle();

      expect(find.byType(IptvBottomNavBar), findsNothing);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(Drawer), findsNothing);
    },
  );

  testWidgets('Home resets active filters to their default state', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(IPTVScreen)),
    );
    container.read(channelFiltersProvider.notifier).setCategory('News');
    await tester.pump();
    expect(container.read(channelFiltersProvider).isActive, isTrue);

    await tapBottomNavDestination(tester, 'Home');

    expect(container.read(channelFiltersProvider).isActive, isFalse);
  });

  testWidgets('hides Cast action on macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Aika Stream'), findsOneWidget);
      expect(find.byTooltip('Cast'), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('shows only the video surface while Android PiP is active', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    AiroNativePictureInPicture.debugNotifyStateChanged(true);
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Aika Stream'), findsNothing);
    expect(find.byType(VideoPlayerWidget), findsOneWidget);

    AiroNativePictureInPicture.debugNotifyStateChanged(false);
    await tester.pump();

    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets(
    'ten-foot mode suppresses touch-only player chrome',
    (tester) async {
      // Brightness/volume drag zones and the lock button are touch concepts
      // with no remote equivalent. VideoPlayerWidget already hides them when
      // enableTouchGestures is false, and its doc comment cited "TV/remote
      // input" as the reason — but nothing in production ever passed false, so
      // every Fire TV build shipped the touch chrome anyway.
      await tester.pumpWidget(createWidget(tenFootMode: true));
      await tester.pumpAndSettle();

      // A player only mounts once something is playing.
      await tester.tap(find.text('City News Live').first);
      await tester.pumpAndSettle();

      final players = tester.widgetList<VideoPlayerWidget>(
        find.byType(VideoPlayerWidget),
      );
      expect(players, isNotEmpty, reason: 'expected a player to be mounted');
      for (final player in players) {
        expect(player.enableTouchGestures, isFalse);
      }
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnored(
      notDisposed: {'VideoPlayerController': null},
    ),
  );

  testWidgets('browse preview exposes a full player entry point', (
    tester,
  ) async {
    await tester.pumpWidget(
      createWidget(
        streamingState: StreamingState(
          playbackState: PlaybackState.playing,
          isLiveStream: true,
          liveDelay: const Duration(seconds: 1),
          currentChannel: channels.first,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final fullscreenButton = find.byKey(
      const ValueKey('iptv-player-fullscreen-button'),
    );
    expect(fullscreenButton, findsOneWidget);
    expect(
      tester
          .widget<VideoPlayerWidget>(find.byType(VideoPlayerWidget))
          .initiallyFullscreen,
      isFalse,
    );

    await tester.tap(fullscreenButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(fullscreenButton, findsOneWidget);
    expect(
      tester
          .widget<VideoPlayerWidget>(find.byType(VideoPlayerWidget))
          .initiallyFullscreen,
      isTrue,
    );
  });

  testWidgets(
    'macOS full player owns one native transition and restores on native exit',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      const fullscreenChannel = MethodChannel(
        'com.developerscoffee.airo.window/fullscreen',
      );
      final nativeCalls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        fullscreenChannel,
        (call) async {
          nativeCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          fullscreenChannel,
          null,
        ),
      );
      try {
        await tester.pumpWidget(
          createWidget(
            streamingState: StreamingState(
              playbackState: PlaybackState.playing,
              isLiveStream: true,
              liveDelay: const Duration(seconds: 1),
              currentChannel: channels.first,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          tester
              .widget<VideoPlayerWidget>(find.byType(VideoPlayerWidget))
              .handleNativeFullscreen,
          isFalse,
        );
        await tester.tap(
          find.byKey(const ValueKey('iptv-player-fullscreen-button')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          nativeCalls.where((call) => call.method == 'enterFullscreen'),
          hasLength(1),
        );
        expect(
          find.byKey(const ValueKey('iptv-player-fullscreen-button')),
          findsOneWidget,
        );

        AiroNativeFullscreen.debugNotifyMacosFullscreenExited();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byKey(const ValueKey('iptv-player-fullscreen-button')),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('restored native macOS fullscreen synchronizes player state', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    const fullscreenChannel = MethodChannel(
      'com.developerscoffee.airo.window/fullscreen',
    );
    final nativeCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      fullscreenChannel,
      (call) async {
        nativeCalls.add(call);
        if (call.method != 'isFullscreen') return null;
        return nativeCalls
                .where((nativeCall) => nativeCall.method == 'isFullscreen')
                .length >
            1;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        fullscreenChannel,
        null,
      ),
    );
    try {
      await tester.pumpWidget(
        createWidget(
          streamingState: StreamingState(
            playbackState: PlaybackState.playing,
            isLiveStream: true,
            liveDelay: const Duration(seconds: 1),
            currentChannel: channels.first,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('iptv-player-fullscreen-button')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        nativeCalls.where((call) => call.method == 'isFullscreen'),
        hasLength(2),
      );
      expect(
        nativeCalls.where((call) => call.method == 'enterFullscreen'),
        isEmpty,
      );
      expect(
        find.byKey(const ValueKey('iptv-player-fullscreen-button')),
        findsOneWidget,
      );

      AiroNativeFullscreen.debugNotifyMacosFullscreenExited();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byKey(const ValueKey('iptv-player-fullscreen-button')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('portrait preview exposes usable compact player controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidget(
        streamingState: StreamingState(
          playbackState: PlaybackState.playing,
          isLiveStream: true,
          liveDelay: const Duration(seconds: 1),
          currentChannel: channels.first,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Compact mode's floating control bar deliberately omits a dedicated
    // fullscreen icon to stay uncluttered -- Fullscreen is still reachable
    // via the "more" sheet's unconditional entry (see iptv-player-more-button
    // below and video_player_widget.dart's _showPlayerActionsSheet).
    expect(
      find.byKey(const ValueKey('iptv-player-mute-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-player-volume-down-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-player-volume-up-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-player-channel-previous-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-player-channel-next-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('iptv-player-more-button')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Back exits fullscreen playback before popping the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      createWidget(
        streamingState: StreamingState(
          playbackState: PlaybackState.playing,
          isLiveStream: true,
          liveDelay: const Duration(seconds: 1),
          currentChannel: channels.first,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(
      find.byKey(const ValueKey('iptv-player-fullscreen-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('iptv-player-fullscreen-button')),
      findsOneWidget,
    );

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(handled, isTrue);
    expect(find.text('Aika Stream'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('iptv-player-fullscreen-button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'My Aika sheet Favorites entry pushes the mobile favorites screen',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await openMyAikaSheet(tester);

      expect(find.text('Favorites'), findsOneWidget);

      await selectMyAikaTile(tester, const ValueKey('iptv-my-aika-favorites'));

      expect(find.widgetWithText(AppBar, 'Favorites'), findsOneWidget);
    },
  );

  testWidgets(
    'My Aika sheet lists Settings, Movies & Shows, Favorites, and Play '
    'local file on TV when every callback is provided',
    (tester) async {
      await tester.pumpWidget(
        createWidget(
          onSettings: () {},
          onOpenVod: () {},
          onPickLocalMediaForTv: () async => null,
        ),
      );
      await tester.pumpAndSettle();

      await openMyAikaSheet(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Movies & Shows'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Play local file on TV'), findsOneWidget);
    },
  );

  testWidgets('My Aika sheet Settings entry invokes the app callback', (
    tester,
  ) async {
    var openedSettings = false;
    await tester.pumpWidget(
      createWidget(onSettings: () => openedSettings = true),
    );
    await tester.pumpAndSettle();

    await openMyAikaSheet(tester);

    expect(find.text('Settings'), findsOneWidget);

    await selectMyAikaTile(tester, const ValueKey('iptv-my-aika-settings'));

    expect(openedSettings, isTrue);
  });

  testWidgets('My Aika sheet hides Settings when onSettings is not provided', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await openMyAikaSheet(tester);

    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('opens search sheet from the bottom nav', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tapBottomNavDestination(tester, 'Search');

    expect(find.text('Search channels'), findsOneWidget);
    expect(
      find.text('Find live channels by name, group, or request.'),
      findsOneWidget,
    );
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets(
    'adding a second playlist source via the in-player Settings dialog and '
    'reloading does not clobber an existing favorite',
    (tester) async {
      // The AppBar's dedicated "Playlist source" icon was removed by this
      // task (relocated into AiroTvShellSettingsDialog by Task 10). The only
      // surviving phone entry point once a channel is already playing is:
      // in-player "more" sheet -> App settings -> Playlist source row. This
      // test drives that real chain, then simulates the channel-list reload
      // it triggers elsewhere (video_player_widget.dart's
      // _refreshPlaylistFromContextMenu calls the same refreshChannelsProvider)
      // and asserts the reload's favorite remap
      // (applyFavoriteRemapOnReimport, iptv_providers.dart:608-640) does not
      // wipe an already-persisted favorite.
      //
      // The fake M3U source parser below stands in for the real network
      // fetch a newly-added source would trigger -- this suite already
      // blocks real HTTP in the test binding (see _FakeProbeTransport above),
      // and the point of this test is the reload/remap path, not playlist
      // parsing.
      SharedPreferences.setMockInitialValues({});
      final parserPrefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        createWidget(
          initialPreferences: const {
            'iptv_favorite_channel_ids': ['news-1'],
          },
          streamingState: StreamingState(
            playbackState: PlaybackState.playing,
            isLiveStream: true,
            liveDelay: const Duration(seconds: 1),
            currentChannel: channels.first,
          ),
          extraOverrides: [
            m3uSourceParserFactoryProvider.overrideWithValue(
              (sourceId) => _ImmediateM3uSourceParser(
                prefs: parserPrefs,
                sourceId: sourceId,
                channels: const [
                  IPTVChannel(
                    id: 'news-1',
                    name: 'City News Live',
                    streamUrl: 'https://example.com/news.m3u8',
                    group: 'News',
                    category: ChannelCategory.news,
                  ),
                  IPTVChannel(
                    id: 'country-1',
                    name: 'Country One',
                    streamUrl: 'https://example.com/country-1.m3u8',
                    group: 'Country',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(IPTVScreen)),
      );
      expect(
        await container
            .read(favoriteChannelsStorageProvider)
            .getFavoriteChannelIds(),
        {'news-1'},
      );

      // Open the in-player "more" sheet -> App settings -> Playlist source.
      await tester.tap(find.byKey(const ValueKey('iptv-player-more-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // The sheet's ListView overflows the default test surface height, so
      // the "App settings" tile starts out below the visible viewport --
      // scroll it into view before tapping (same pattern as
      // video_player_widget_test.dart's other sheet-item taps).
      // skipOffstage: false is required here because ensureVisible has to
      // locate the (currently offstage) element before it can scroll it in.
      final appSettingsTile = find.byKey(
        const ValueKey('iptv-player-settings-menu-action'),
        skipOffstage: false,
      );
      await tester.ensureVisible(appSettingsTile);
      await tester.pump();
      await tester.tap(appSettingsTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Playlist source'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('shell-settings-playlist-source')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Add a second, unrelated playlist source through the real sheet.
      await tester.tap(
        find.byKey(const ValueKey('playlist-source-add-button')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('playlist-source-label-field')),
        'Country list',
      );
      await tester.enterText(
        find.byKey(const ValueKey('playlist-source-url-field')),
        'https://example.com/country.m3u',
      );
      final saveButton = find.byKey(
        const ValueKey('playlist-source-save-button'),
      );
      await tester.ensureVisible(saveButton);
      await tester.pump();
      await tester.tap(saveButton);
      // Not pumpAndSettle: the streaming state above is actively "playing",
      // which keeps periodic position/buffer timers running that never
      // settle (see video_player_widget_test.dart's playChannel() comment).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Country list'), findsOneWidget);

      // Simulate the resulting channel-list reload (the same provider the
      // in-player "Refresh playlist" context menu action calls).
      final reloadedChannels = await container.read(
        refreshChannelsProvider(true).future,
      );
      expect(
        reloadedChannels.map((channel) => channel.id),
        containsAll(['news-1', 'country-1']),
      );

      expect(
        await container
            .read(favoriteChannelsStorageProvider)
            .getFavoriteChannelIds(),
        {'news-1'},
        reason:
            'adding a second playlist source and reloading must not clobber '
            'an already-persisted favorite',
      );
    },
  );

  testWidgets('fresh install shows bring-your-own playlist state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(createEmptyWidget());
    await tester.pumpAndSettle();

    expect(find.text('Aika Stream'), findsOneWidget);
    expect(find.byTooltip('Playlist source'), findsNothing);
    expect(find.text('Add your playlist'), findsOneWidget);
    expect(
      find.textContaining(
        'does not provide channels, playlists, or program guide data',
      ),
      findsOneWidget,
    );
    expect(find.text('Add playlist URL'), findsOneWidget);
    expect(find.bySemanticsLabel('Playlist setup'), findsOneWidget);
    expect(find.bySemanticsLabel('Add a playlist URL'), findsOneWidget);
    expect(find.text('Add a playlist to start watching'), findsNothing);
    expect(find.text('Live Channels'), findsNothing);
    expect(find.byKey(const ValueKey('iptv-empty-browse-usb')), findsNothing);
    semantics.dispose();
  });

  testWidgets('TV onboarding shows QR and USB only when capability is real', (
    tester,
  ) async {
    await tester.pumpWidget(
      createEmptyWidget(
        tenFootMode: true,
        extraOverrides: [
          localMediaLibraryCapabilitiesProvider.overrideWith(
            (ref) async => const LocalMediaLibraryCapabilities(
              removableStorage: true,
              dlnaUpnp: false,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('iptv-empty-scan-phone')), findsOneWidget);
    expect(find.byKey(const ValueKey('iptv-empty-browse-usb')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('iptv-empty-browse-network')),
      findsNothing,
    );
  });

  testWidgets(
    'TV network browse owns focus and launches discovered DLNA media',
    (tester) async {
      final playedChannels = <IPTVChannel>[];
      final fakeService = _RecordingStreamingService(played: playedChannels);
      final fakeDlna = _FakeDlnaLibraryAdapter();
      await tester.pumpWidget(
        createEmptyWidget(
          tenFootMode: true,
          extraOverrides: [
            localMediaLibraryCapabilitiesProvider.overrideWith(
              (ref) async => const LocalMediaLibraryCapabilities(
                removableStorage: false,
                dlnaUpnp: true,
              ),
            ),
            dlnaUpnpLibraryAdapterProvider.overrideWithValue(fakeDlna),
            iptvStreamingServiceProvider.overrideWith((ref) {
              ref.onDispose(() => fakeService.dispose());
              return fakeService;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('iptv-empty-browse-network')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('iptv-empty-browse-usb')), findsNothing);

      _focusTvFocusable(
        tester,
        find.byKey(const ValueKey('iptv-empty-browse-network')),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Living room server'), findsOneWidget);
      final serverFocus = _focusTvFocusable(
        tester,
        find.byKey(const ValueKey('local-media-entry-opaque-server')),
      );
      expect(serverFocus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('Remote movie'), findsOneWidget);
      final movieFocus = _focusTvFocusable(
        tester,
        find.byKey(const ValueKey('local-media-entry-opaque-movie')),
      );
      expect(movieFocus.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(fakeDlna.discoverCalls, 1);
      expect(fakeDlna.browseCalls, ['dlna://server/opaque/root']);
      expect(playedChannels, hasLength(1));
      expect(playedChannels.single.name, 'Remote movie');
      expect(playedChannels.single.streamUrl, 'http://192.168.1.2/movie.mp4');
      expect(
        playedChannels.single.id,
        stableLocalMediaChannelId('opaque-movie'),
      );
    },
  );

  testWidgets(
    'TV network browse offers a focused retry after discovery fails',
    (tester) async {
      final adapter = _RecoveringDlnaLibraryAdapter();
      await tester.pumpWidget(
        createEmptyWidget(
          tenFootMode: true,
          extraOverrides: [
            localMediaLibraryCapabilitiesProvider.overrideWith(
              (ref) async => const LocalMediaLibraryCapabilities(
                removableStorage: false,
                dlnaUpnp: true,
              ),
            ),
            dlnaUpnpLibraryAdapterProvider.overrideWithValue(adapter),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Browse network'));
      await tester.pumpAndSettle();

      expect(find.textContaining('could not be reached'), findsOneWidget);
      final retryFocus = _focusTvFocusable(
        tester,
        find.ancestor(
          of: find.text('Try again'),
          matching: find.byType(TvFocusable),
        ),
      );
      expect(retryFocus.hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(adapter.discoverCalls, 2);
      expect(find.text('Recovered server'), findsOneWidget);
    },
  );

  testWidgets('TV USB permission denial shows a bounded recovery message', (
    tester,
  ) async {
    await tester.pumpWidget(
      createEmptyWidget(
        tenFootMode: true,
        extraOverrides: [
          localMediaLibraryCapabilitiesProvider.overrideWith(
            (ref) async => const LocalMediaLibraryCapabilities(
              removableStorage: true,
              dlnaUpnp: false,
            ),
          ),
          localMediaLibraryAdapterProvider.overrideWithValue(
            const _DeniedLocalMediaLibraryAdapter(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Browse USB'));
    await tester.pump();

    expect(find.textContaining('allow read access'), findsOneWidget);
  });

  testWidgets('keeps selected TV channel row metadata readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidget(
        streamingState: StreamingState(
          currentChannel: channels.first,
          playbackState: PlaybackState.playing,
          isLiveStream: true,
          liveDelay: const Duration(seconds: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Sort: Name'), findsOneWidget);
    expect(find.text('City News Live'), findsWidgets);
    expect(find.text('News'), findsWidgets);
    // The LIVE pill and the live_tv logo placeholder both came from
    // AiroTvShell's always-visible ChannelInfoBar row. That row is gone:
    // live identity now lives in ChannelNameOverlay on the shell's own
    // video stage, which this layout (a real VideoPlayerWidget, so
    // `videoStageHasOwnActions`) does not draw. What this test still
    // guards -- that the selected channel's name and group stay legible in
    // the grid -- is asserted above; the badge itself is covered by
    // channel_name_overlay_test.dart and airo_tv_shell_test.dart.
    expect(find.text('Play on TV'), findsNothing);
    expect(
      find.text('Send this channel to a Chromecast-enabled TV.'),
      findsNothing,
    );
  });

  testWidgets(
    'My Aika sheet hides Movies & Shows when onOpenVod is not provided',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await openMyAikaSheet(tester);

      expect(find.text('Movies & Shows'), findsNothing);
    },
  );

  testWidgets('My Aika sheet opens VOD via the Movies & Shows entry', (
    tester,
  ) async {
    var openVodCalled = false;
    await tester.pumpWidget(
      createWidget(onOpenVod: () => openVodCalled = true),
    );
    await tester.pumpAndSettle();

    await openMyAikaSheet(tester);

    expect(find.text('Movies & Shows'), findsOneWidget);

    await selectMyAikaTile(tester, const ValueKey('iptv-my-aika-movies'));

    expect(openVodCalled, isTrue);
  });

  testWidgets(
    'My Aika sheet hides Play local file on TV when onPickLocalMediaForTv is '
    'not provided',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await openMyAikaSheet(tester);

      expect(find.text('Play local file on TV'), findsNothing);
    },
  );

  testWidgets(
    'My Aika sheet Play local file on TV entry opens the handoff sheet for '
    'the picked file',
    (tester) async {
      const item = PhoneLocalMediaItem(
        filePath: '/tmp/movie.mp4',
        title: 'Movie Night',
        container: 'mp4',
      );
      final castController = FakeAiroCastController();
      addTearDown(castController.dispose);
      await tester.pumpWidget(
        createWidget(
          onPickLocalMediaForTv: () async => item,
          extraOverrides: [
            airoCastControllerProvider.overrideWithValue(castController),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await openMyAikaSheet(tester);

      expect(find.text('Play local file on TV'), findsOneWidget);

      await selectMyAikaTile(tester, const ValueKey('iptv-my-aika-play-on-tv'));

      expect(find.text('Movie Night'), findsOneWidget);
      expect(
        find.textContaining('Choose a Chromecast-enabled TV'),
        findsOneWidget,
      );
      expect(find.text('Play on TV'), findsNothing);
    },
  );

  testWidgets(
    'My Aika sheet Play local file on TV entry does nothing when the picker '
    'is cancelled',
    (tester) async {
      await tester.pumpWidget(
        createWidget(onPickLocalMediaForTv: () async => null),
      );
      await tester.pumpAndSettle();

      await openMyAikaSheet(tester);
      await selectMyAikaTile(tester, const ValueKey('iptv-my-aika-play-on-tv'));

      expect(find.text('Play on TV'), findsNothing);
    },
  );

  testWidgets(
    'searching lists matching channels in the sheet instead of auto-playing '
    'the single match; tapping a result plays it',
    (tester) async {
      final playedChannels = <IPTVChannel>[];
      final fakeService = _RecordingStreamingService(played: playedChannels);

      await tester.pumpWidget(
        createWidget(
          extraOverrides: [
            // overrideWith (not overrideWithValue) so ref.onDispose cancels
            // the periodic metrics timer started by initialize() before the
            // pending-timer invariant check runs.
            iptvStreamingServiceProvider.overrideWith((ref) {
              ref.onDispose(() => fakeService.dispose());
              return fakeService;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tapBottomNavDestination(tester, 'Search');

      await tester.enterText(find.byType(TextField).last, 'City News');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Single name match must NOT auto-play; the sheet stays open and
      // lists the matching channel instead.
      expect(playedChannels, isEmpty);
      expect(find.text('Search channels'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'City News Live'), findsOneWidget);

      await tester.tap(find.widgetWithText(ListTile, 'City News Live'));
      await tester.pumpAndSettle();

      expect(playedChannels, hasLength(1));
      expect(playedChannels.single.id, 'news-1');
      expect(find.text('Search channels'), findsNothing);
    },
  );

  testWidgets('search sheet Play button still plays the single match', (
    tester,
  ) async {
    final playedChannels = <IPTVChannel>[];
    final fakeService = _RecordingStreamingService(played: playedChannels);

    await tester.pumpWidget(
      createWidget(
        extraOverrides: [
          iptvStreamingServiceProvider.overrideWith((ref) {
            ref.onDispose(() => fakeService.dispose());
            return fakeService;
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tapBottomNavDestination(tester, 'Search');

    await tester.enterText(find.byType(TextField).last, 'City News');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(playedChannels, hasLength(1));
    expect(playedChannels.single.id, 'news-1');
  });

  group('split view — cast one channel, watch another locally (#1047)', () {
    const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');

    testWidgets('a plain channel tap while casting plays it locally instead of '
        'redirecting to the cast target', (tester) async {
      final playedChannels = <IPTVChannel>[];
      final fakeService = _RecordingStreamingService(played: playedChannels);
      final castNotifier = _MutableCastNotifier();

      await tester.pumpWidget(
        createWidget(
          extraOverrides: [
            iptvStreamingServiceProvider.overrideWith((ref) {
              ref.onDispose(() => fakeService.dispose());
              return fakeService;
            }),
            multiviewDecoderBudgetProvider.overrideWithValue(2),
            iptvCastProvider.overrideWith((ref) => castNotifier),
          ],
        ),
      );
      await tester.pumpAndSettle();

      castNotifier.setCasting(true, device: tv);
      await tester.pump();

      await tapBottomNavDestination(tester, 'Search');
      await tester.enterText(find.byType(TextField).last, 'City News');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'City News Live'));
      await tester.pumpAndSettle();

      expect(playedChannels, hasLength(1));
      expect(playedChannels.single.id, 'news-1');
      expect(fakeService.calls, isNot(contains('pause')));
    });

    testWidgets(
      'a channel tap while casting on a device without decoder headroom '
      'shows a capacity message and does not start a second local stream',
      (tester) async {
        final playedChannels = <IPTVChannel>[];
        final fakeService = _RecordingStreamingService(played: playedChannels);
        final castNotifier = _MutableCastNotifier();

        await tester.pumpWidget(
          createWidget(
            extraOverrides: [
              iptvStreamingServiceProvider.overrideWith((ref) {
                ref.onDispose(() => fakeService.dispose());
                return fakeService;
              }),
              multiviewDecoderBudgetProvider.overrideWithValue(1),
              iptvCastProvider.overrideWith((ref) => castNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        castNotifier.setCasting(true, device: tv);
        await tester.pump();

        await tapBottomNavDestination(tester, 'Search');
        await tester.enterText(find.byType(TextField).last, 'City News');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'City News Live'));
        await tester.pumpAndSettle();

        expect(playedChannels, isEmpty);
        expect(
          find.text("This device can't play a second stream while casting."),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'starting a cast session no longer pauses local playback when the '
      'device has decoder headroom for both',
      (tester) async {
        final playedChannels = <IPTVChannel>[];
        final fakeService = _RecordingStreamingService(played: playedChannels);
        final castNotifier = _MutableCastNotifier();

        await tester.pumpWidget(
          createWidget(
            extraOverrides: [
              iptvStreamingServiceProvider.overrideWith((ref) {
                ref.onDispose(() => fakeService.dispose());
                return fakeService;
              }),
              multiviewDecoderBudgetProvider.overrideWithValue(2),
              iptvCastProvider.overrideWith((ref) => castNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        castNotifier.setCasting(true, device: tv);
        await tester.pump();

        expect(fakeService.calls, isNot(contains('pause')));
        // Default-muted while casting, with a real mute toggle applied.
        expect(fakeService.calls, contains('toggleMute'));
        expect(fakeService.currentState.isMuted, isTrue);

        castNotifier.setCasting(false);
        await tester.pump();

        // Never paused for cast, so ending the session must not resume it.
        expect(fakeService.calls, isNot(contains('resume')));
      },
    );

    testWidgets(
      'starting a cast session still pauses local playback when the device '
      'cannot sustain a second decoder, and resumes it when casting ends',
      (tester) async {
        final playedChannels = <IPTVChannel>[];
        final fakeService = _RecordingStreamingService(played: playedChannels);
        final castNotifier = _MutableCastNotifier();

        await tester.pumpWidget(
          createWidget(
            extraOverrides: [
              iptvStreamingServiceProvider.overrideWith((ref) {
                ref.onDispose(() => fakeService.dispose());
                return fakeService;
              }),
              multiviewDecoderBudgetProvider.overrideWithValue(1),
              iptvCastProvider.overrideWith((ref) => castNotifier),
            ],
          ),
        );
        await tester.pumpAndSettle();

        castNotifier.setCasting(true, device: tv);
        await tester.pump();

        expect(fakeService.calls, contains('pause'));

        castNotifier.setCasting(false);
        await tester.pump();

        expect(fakeService.calls, contains('resume'));
      },
    );
  });
}

FocusNode _focusTvFocusable(WidgetTester tester, Finder root) {
  final focusWidgets = tester.widgetList<Focus>(
    find.descendant(of: root.first, matching: find.byType(Focus)),
  );
  for (final focus in focusWidgets) {
    final node = focus.focusNode;
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return node;
    }
  }
  throw StateError('No requestable Focus node under the TV control.');
}

/// Streaming service double that records [playChannel] calls without touching
/// the real playback engine.
class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService({required this.played})
    : super(engine: FakeAiroPlaybackEngine());

  final List<IPTVChannel> played;
  final List<String> calls = [];
  StreamingState _state = StreamingState();

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    played.add(channel);
  }

  @override
  StreamingState get currentState => _state;

  @override
  Future<void> pause() async {
    calls.add('pause');
    _state = _state.copyWith(playbackState: PlaybackState.paused);
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
    _state = _state.copyWith(playbackState: PlaybackState.playing);
  }

  @override
  Future<void> toggleMute() async {
    calls.add('toggleMute');
    _state = _state.copyWith(isMuted: !_state.isMuted);
  }
}

/// Cast notifier a test can drive directly, without a real [AiroCastController]
/// session, to simulate a cast session starting/ending.
class _MutableCastNotifier extends IptvCastNotifier {
  _MutableCastNotifier()
    : super(
        controller: FakeAiroCastController(),
        adapter: const IptvCastMediaAdapter(),
      );

  void setCasting(bool casting, {AiroCastDevice? device}) {
    state = state.copyWith(
      session: casting
          ? AiroCastSessionSnapshot.connected(
              device ?? const AiroCastDevice(id: 'tv-1', name: 'Sony Bravia'),
            )
          : AiroCastSessionSnapshot.idle(),
    );
  }
}

class _FakeDlnaLibraryAdapter implements DlnaUpnpLibraryAdapter {
  int discoverCalls = 0;
  final List<String> browseCalls = [];

  @override
  Future<List<LocalMediaEntry>> discover() async {
    discoverCalls++;
    return const [
      LocalMediaEntry(
        id: 'opaque-server',
        name: 'Living room server',
        kind: LocalMediaEntryKind.folder,
        accessUri: 'dlna://server/opaque/root',
        childrenUri: 'dlna://server/opaque/root',
      ),
    ];
  }

  @override
  Future<List<LocalMediaEntry>> browse(String containerUri) async {
    browseCalls.add(containerUri);
    return const [
      LocalMediaEntry(
        id: 'opaque-movie',
        name: 'Remote movie',
        kind: LocalMediaEntryKind.video,
        accessUri: 'http://192.168.1.2/movie.mp4',
      ),
    ];
  }
}

class _RecoveringDlnaLibraryAdapter implements DlnaUpnpLibraryAdapter {
  int discoverCalls = 0;

  @override
  Future<List<LocalMediaEntry>> discover() async {
    discoverCalls++;
    if (discoverCalls == 1) {
      throw const LocalMediaAccessException('discovery_failed');
    }
    return const [
      LocalMediaEntry(
        id: 'recovered-server',
        name: 'Recovered server',
        kind: LocalMediaEntryKind.folder,
        accessUri: 'dlna://server/recovered/root',
        childrenUri: 'dlna://server/recovered/root',
      ),
    ];
  }

  @override
  Future<List<LocalMediaEntry>> browse(String containerUri) async => const [];
}

class _DeniedLocalMediaLibraryAdapter implements LocalMediaLibraryAdapter {
  const _DeniedLocalMediaLibraryAdapter();

  @override
  Future<List<LocalMediaEntry>> browse(String rootUri) async => const [];

  @override
  Future<LocalMediaLibraryCapabilities> capabilities() async =>
      const LocalMediaLibraryCapabilities(
        removableStorage: true,
        dlnaUpnp: false,
      );

  @override
  Future<String?> requestRemovableStorageRoot() {
    throw const LocalMediaAccessException('permission_denied');
  }
}

/// Stands in for a real network fetch when a newly-added M3U source is
/// reloaded (see configured_m3u_failure_test.dart's `_FakeSourceParser` for
/// the same pattern). Every method that would otherwise touch the network or
/// [prefs] is overridden, so [prefs] only exists to satisfy
/// [M3UParserService]'s constructor.
class _ImmediateM3uSourceParser extends M3UParserService {
  _ImmediateM3uSourceParser({
    required super.prefs,
    required String sourceId,
    required this.channels,
  }) : super(dio: Dio(), sourceId: sourceId);

  final List<IPTVChannel> channels;
  String? _url;

  @override
  String? getPlaylistUrl() => _url;

  @override
  Future<void> setPlaylistUrl(String url) async {
    _url = url;
  }

  @override
  Future<PlaylistFetchOutcome> fetchPlaylistOutcome({
    bool forceRefresh = false,
  }) async => PlaylistFetchOutcome.loaded(channels);
}

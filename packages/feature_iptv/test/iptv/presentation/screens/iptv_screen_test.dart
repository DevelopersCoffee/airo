import "dart:async";
import "dart:io";

import "package:dio/dio.dart";
import "package:feature_iptv/application/channel_metadata_enrichment.dart";
import "package:feature_iptv/feature_iptv.dart";
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test double for [M3UParserService] that lets tests drive
/// `fetchPlaylistWithProgress` via a fixture [ImportProgress] stream instead
/// of hitting real HTTP. Every call opens a fresh [StreamController] (Save
/// and Retry both re-invoke the import) so tests can push emissions onto
/// whichever controller `streamControllers.last` refers to after each call.
class _FixtureM3UParserService extends M3UParserService {
  _FixtureM3UParserService({required super.dio, required super.prefs})
    : super(
        // `setPlaylistUrl`/`clearCache` touch the real cache directory via
        // path_provider, which has no platform-channel mock under
        // `flutter_test` and would otherwise hang forever awaiting a reply
        // that never arrives. Point it at the test's temp dir instead.
        cacheDirectoryProvider: () async => Directory.systemTemp,
      );

  final List<StreamController<ImportProgress>> streamControllers = [];
  int fetchWithProgressCallCount = 0;

  @override
  Stream<ImportProgress> fetchPlaylistWithProgress({
    bool forceRefresh = false,
  }) {
    fetchWithProgressCallCount++;
    final controller = StreamController<ImportProgress>();
    streamControllers.add(controller);
    return controller.stream;
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
            iptvChannelsProvider.overrideWith((ref) async => channels),
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
            ),
          ),
        );
      },
    );
  }

  Widget createEmptyWidget() {
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
          ],
          child: const MaterialApp(home: IPTVScreen()),
        );
      },
    );
  }

  Future<void> openIptvDrawer(WidgetTester tester) async {
    final scaffoldState = tester
        .stateList<ScaffoldState>(find.byType(Scaffold))
        .firstWhere((state) => state.widget.drawer != null);
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();
  }

  Future<void> selectDrawerTile(
    WidgetTester tester,
    ValueKey<String> key,
  ) async {
    tester.widget<ListTile>(find.byKey(key)).onTap?.call();
    await tester.pumpAndSettle();
  }

  Future<void> activateAppBarAction(WidgetTester tester, String tooltip) async {
    final action = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == tooltip,
      ),
    );
    action.onPressed?.call();
    await tester.pumpAndSettle();
  }

  testWidgets('renders Airo TV app bar and responsive live list', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Search channels'), findsOneWidget);
      expect(find.byTooltip('Playlist source'), findsOneWidget);
      expect(find.byTooltip('Guide URL'), findsOneWidget);
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

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('City News Live'), findsWidgets);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('hides Cast action on macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Airo TV'), findsOneWidget);
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
    expect(find.text('Airo TV'), findsNothing);
    expect(find.byType(VideoPlayerWidget), findsOneWidget);

    AiroNativePictureInPicture.debugNotifyStateChanged(false);
    await tester.pump();

    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets(
    'browse preview exposes a full player entry point',
    (tester) async {
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
        const ValueKey('iptv-preview-fullscreen-button'),
      );
      expect(fullscreenButton, findsOneWidget);

      await tester.tap(fullscreenButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(fullscreenButton, findsNothing);
      expect(
        find.byKey(const ValueKey('iptv-player-fullscreen-button')),
        findsOneWidget,
      );
    },
    // Tracked as Pixel 9 fullscreen overlay/back hit-test follow-up.
    skip: true,
  );

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

    expect(
      find.byKey(const ValueKey('iptv-preview-fullscreen-button')),
      findsOneWidget,
    );
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

  testWidgets(
    'system Back exits fullscreen playback before popping the app',
    (tester) async {
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
        find.byKey(const ValueKey('iptv-preview-fullscreen-button')),
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
      expect(find.text('Airo TV'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('iptv-preview-fullscreen-button')),
        findsOneWidget,
      );
    },
    // Tracked as Pixel 9 fullscreen overlay/back hit-test follow-up.
    skip: true,
  );

  testWidgets(
    'hamburger menu opens the drawer and Guide pushes the guide screen',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await openIptvDrawer(tester);

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);

      await selectDrawerTile(tester, const ValueKey('iptv-drawer-guide'));

      // The pushed guide screen owns its own search field, distinct from the
      // Stream screen's playlist search sheet.
      expect(find.text('Search the guide'), findsOneWidget);
    },
  );

  testWidgets(
    'hamburger menu Favorites entry pushes the mobile favorites screen',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await openIptvDrawer(tester);

      expect(find.text('Favorites'), findsOneWidget);

      await selectDrawerTile(tester, const ValueKey('iptv-drawer-favorites'));

      expect(find.widgetWithText(AppBar, 'Favorites'), findsOneWidget);
    },
  );

  testWidgets('hamburger menu Settings entry invokes the app callback', (
    tester,
  ) async {
    var openedSettings = false;
    await tester.pumpWidget(
      createWidget(onSettings: () => openedSettings = true),
    );
    await tester.pumpAndSettle();

    await openIptvDrawer(tester);

    expect(find.text('Settings'), findsOneWidget);

    await selectDrawerTile(tester, const ValueKey('iptv-drawer-settings'));

    expect(openedSettings, isTrue);
  });

  testWidgets('opens search sheet from app bar action', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await activateAppBarAction(tester, 'Search channels');

    expect(find.text('Search channels'), findsOneWidget);
    expect(
      find.text('Find live channels by name, group, or request.'),
      findsOneWidget,
    );
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets(
    'playlist source sheet action row renders without overflow at phone '
    'width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await activateAppBarAction(tester, 'Playlist source');

      expect(find.text('Add Playlist Source'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('opens XMLTV source sheet from the Guide URL app bar action', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await activateAppBarAction(tester, 'Guide URL');

    expect(find.text('XMLTV Guide Source'), findsOneWidget);
    expect(find.text('No XMLTV source configured yet.'), findsOneWidget);
  });

  testWidgets(
    'Add Playlist sheet shows a progress indicator and stage label while '
    'the import stream emits',
    (tester) async {
      late _FixtureM3UParserService parser;
      await tester.pumpWidget(
        createWidget(
          extraOverrides: [
            m3uParserProvider.overrideWith((ref) {
              parser = _FixtureM3UParserService(
                dio: Dio(),
                prefs: ref.watch(sharedPreferencesProvider),
              );
              return parser;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await activateAppBarAction(tester, 'Playlist source');

      await tester.enterText(
        find.byType(TextField),
        'https://example.com/playlist.m3u',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      // Not pumpAndSettle: the indeterminate LinearProgressIndicator
      // schedules frames continuously while importing, so settling never
      // completes until the stream reaches a terminal stage.
      await tester.pump();
      await tester.pump();

      expect(parser.fetchWithProgressCallCount, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Starting playlist import'), findsOneWidget);

      parser.streamControllers.last.add(
        const ImportProgress(
          stage: ImportStage.download,
          message: 'Downloading playlist',
        ),
      );
      await tester.pump();

      expect(find.text('Downloading playlist'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets(
    'Add Playlist sheet shows an error and Retry on a failed import, and '
    'Retry re-invokes the import',
    (tester) async {
      late _FixtureM3UParserService parser;
      await tester.pumpWidget(
        createWidget(
          extraOverrides: [
            m3uParserProvider.overrideWith((ref) {
              parser = _FixtureM3UParserService(
                dio: Dio(),
                prefs: ref.watch(sharedPreferencesProvider),
              );
              return parser;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await activateAppBarAction(tester, 'Playlist source');
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/playlist.m3u',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      // Not pumpAndSettle: see note in the progress-indicator test above.
      await tester.pump();
      await tester.pump();

      expect(parser.fetchWithProgressCallCount, 1);

      parser.streamControllers.last.add(
        ImportProgress(stage: ImportStage.failed, error: StateError('boom')),
      );
      await tester.pump();
      // The failed panel has no animating widgets, so it's safe to settle.
      await tester.pumpAndSettle();

      expect(find.textContaining('Import failed'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
      // The sheet stays open on failure so the user can retry or edit the URL.
      expect(find.text('Add Playlist Source'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
      await tester.pump();
      await tester.pump();

      expect(parser.fetchWithProgressCallCount, 2);
      expect(find.text('Starting playlist import'), findsOneWidget);
    },
  );

  testWidgets(
    'Add Playlist sheet closes and invalidates railsProvider when the '
    'import reaches ImportStage.ready',
    (tester) async {
      late _FixtureM3UParserService parser;
      var railsBuildCount = 0;
      await tester.pumpWidget(
        createWidget(
          extraOverrides: [
            m3uParserProvider.overrideWith((ref) {
              parser = _FixtureM3UParserService(
                dio: Dio(),
                prefs: ref.watch(sharedPreferencesProvider),
              );
              return parser;
            }),
            railsProvider.overrideWith((ref) async {
              railsBuildCount++;
              return [];
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(railsBuildCount, 1);

      await activateAppBarAction(tester, 'Playlist source');
      await tester.enterText(
        find.byType(TextField),
        'https://example.com/playlist.m3u',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      // Not pumpAndSettle: see note in the progress-indicator test above.
      await tester.pump();
      await tester.pump();

      expect(find.text('Add Playlist Source'), findsOneWidget);

      parser.streamControllers.last.add(
        const ImportProgress(
          stage: ImportStage.ready,
          fraction: 1,
          message: 'Imported 3 channels',
        ),
      );
      // Sheet pops in response to `ready`; the indeterminate bar is gone
      // once it's off the tree, so settling is safe again.
      await tester.pumpAndSettle();

      expect(find.text('Add Playlist Source'), findsNothing);
      expect(railsBuildCount, 2);
    },
  );

  testWidgets('fresh install shows bring-your-own playlist state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(createEmptyWidget());
    await tester.pumpAndSettle();

    expect(find.text('Airo TV'), findsOneWidget);
    expect(find.byTooltip('Playlist source'), findsOneWidget);
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
    semantics.dispose();
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

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('City News Live'), findsWidgets);
    expect(find.text('News'), findsWidgets);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.byIcon(Icons.live_tv), findsWidgets);
    expect(find.text('Play on TV'), findsNothing);
    expect(
      find.text('Send this channel to a Chromecast-enabled TV.'),
      findsNothing,
    );
  });

  testWidgets('hides Movies & Shows action when onOpenVod is not provided', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Movies & Shows'), findsNothing);
  });

  testWidgets('opens VOD via the Movies & Shows app bar action', (
    tester,
  ) async {
    var openVodCalled = false;
    await tester.pumpWidget(
      createWidget(onOpenVod: () => openVodCalled = true),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Movies & Shows'), findsOneWidget);

    await activateAppBarAction(tester, 'Movies & Shows');

    expect(openVodCalled, isTrue);
  });

  testWidgets(
    'hides Play file on TV drawer entry when onPickLocalMediaForTv is not '
    'provided',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await openIptvDrawer(tester);

      expect(find.text('Play file on TV (debug)'), findsNothing);
    },
  );

  testWidgets(
    'Play file on TV drawer entry opens the handoff sheet for the picked '
    'file',
    (tester) async {
      const item = PhoneLocalMediaItem(
        filePath: '/tmp/movie.mp4',
        title: 'Movie Night',
        container: 'mp4',
      );
      await tester.pumpWidget(
        createWidget(onPickLocalMediaForTv: () async => item),
      );
      await tester.pumpAndSettle();

      await openIptvDrawer(tester);

      expect(find.text('Play file on TV (debug)'), findsOneWidget);

      await selectDrawerTile(tester, const ValueKey('iptv-drawer-play-on-tv'));

      expect(find.text('Movie Night'), findsOneWidget);
      expect(find.text('Play on TV'), findsOneWidget);
    },
  );

  testWidgets(
    'Play file on TV entry does nothing when the picker is cancelled',
    (tester) async {
      await tester.pumpWidget(
        createWidget(onPickLocalMediaForTv: () async => null),
      );
      await tester.pumpAndSettle();

      await openIptvDrawer(tester);
      await selectDrawerTile(tester, const ValueKey('iptv-drawer-play-on-tv'));

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

      await activateAppBarAction(tester, 'Search channels');

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

    await activateAppBarAction(tester, 'Search channels');

    await tester.enterText(find.byType(TextField).last, 'City News');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(playedChannels, hasLength(1));
    expect(playedChannels.single.id, 'news-1');
  });
}

/// Streaming service double that records [playChannel] calls without touching
/// the real playback engine.
class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService({required this.played})
    : super(engine: FakeAiroPlaybackEngine());

  final List<IPTVChannel> played;

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    played.add(channel);
  }
}

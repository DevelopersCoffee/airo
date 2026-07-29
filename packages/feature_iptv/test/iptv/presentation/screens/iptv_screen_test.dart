import "package:feature_iptv/application/channel_metadata_enrichment.dart";
import "package:feature_iptv/feature_iptv.dart";
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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

      expect(find.text('Playlist sources'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('playlist-source-add-button')),
        findsOneWidget,
      );
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

  testWidgets('playlist manager adds a named source from the app bar', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await activateAppBarAction(tester, 'Playlist source');
    await tester.tap(find.byKey(const ValueKey('playlist-source-add-button')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('playlist-source-label-field')),
      'India',
    );
    await tester.enterText(
      find.byKey(const ValueKey('playlist-source-url-field')),
      'https://iptv-org.github.io/iptv/countries/in.m3u',
    );
    final saveButton = find.byKey(
      const ValueKey('playlist-source-save-button'),
    );
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('India'), findsOneWidget);
    expect(find.text('1 playlist source'), findsOneWidget);
  });

  testWidgets('adding a playlist preserves existing favorites', (tester) async {
    await tester.pumpWidget(
      createWidget(
        initialPreferences: const {
          'iptv_favorite_channel_ids': ['news-1'],
        },
      ),
    );
    await tester.pumpAndSettle();

    await activateAppBarAction(tester, 'Playlist source');
    await tester.tap(find.byKey(const ValueKey('playlist-source-add-button')));
    await tester.pump();
    await tester.tap(find.text('By country'));
    await tester.pump();
    final saveButton = find.byKey(
      const ValueKey('playlist-source-save-button'),
    );
    await tester.ensureVisible(saveButton);
    await tester.pump();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final scope = ProviderScope.containerOf(
      tester.element(find.byType(IPTVScreen)),
    );
    expect(
      await scope.read(favoriteChannelsStorageProvider).getFavoriteChannelIds(),
      {'news-1'},
    );
  });

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

      expect(find.text('Play file on TV'), findsNothing);
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

      await openIptvDrawer(tester);

      expect(find.text('Play file on TV'), findsOneWidget);

      await selectDrawerTile(tester, const ValueKey('iptv-drawer-play-on-tv'));

      expect(find.text('Movie Night'), findsOneWidget);
      expect(
        find.textContaining('Choose a Chromecast-enabled TV'),
        findsOneWidget,
      );
      expect(find.text('Play on TV'), findsNothing);
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

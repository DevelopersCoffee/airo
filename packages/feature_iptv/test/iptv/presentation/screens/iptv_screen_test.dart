import "package:feature_iptv/feature_iptv.dart";
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    Future<PhoneLocalMediaItem?> Function()? onPickLocalMediaForTv,
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
          ],
          child: MaterialApp(
            home: IPTVScreen(
              onOpenVod: onOpenVod,
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

  testWidgets('renders Stream app bar, category filters, and live list', (
    tester,
  ) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Stream'), findsOneWidget);
    expect(find.byTooltip('Search channels'), findsOneWidget);
    expect(find.byTooltip('Cast'), findsOneWidget);
    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('News (1)'), findsOneWidget);
    expect(find.text('Sports (1)'), findsOneWidget);
    expect(find.text('Entertainment (0)'), findsOneWidget);
    expect(find.text('Music (1)'), findsOneWidget);
    expect(find.text('Featured Player'), findsOneWidget);
    expect(find.text('Select a channel to start watching'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.text('Playlist Channels'), findsOneWidget);
    expect(find.text('City News Live'), findsOneWidget);
    expect(find.text('LIVE'), findsWidgets);
  });

  testWidgets(
    'hamburger menu opens the drawer and Guide pushes the guide screen',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);

      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();

      // The pushed guide screen owns its own search field, distinct from the
      // Stream screen's playlist search sheet.
      expect(find.text('Search the guide'), findsOneWidget);
    },
  );

  testWidgets('opens search sheet from app bar action', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Search channels'));
    await tester.pumpAndSettle();

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

      await tester.tap(find.byTooltip('Playlist source'));
      await tester.pumpAndSettle();

      expect(find.text('Playlist source'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fresh install shows bring-your-own playlist state', (
    tester,
  ) async {
    await tester.pumpWidget(createEmptyWidget());
    await tester.pumpAndSettle();

    expect(find.text('Stream'), findsOneWidget);
    expect(find.byTooltip('Playlist source'), findsOneWidget);
    expect(find.text('Add your playlist'), findsOneWidget);
    expect(
      find.textContaining(
        'does not provide channels, playlists, or program guide data',
      ),
      findsOneWidget,
    );
    expect(find.text('Add playlist URL'), findsOneWidget);
    expect(find.text('Live Channels'), findsNothing);
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

    expect(find.text('Playlist Channels'), findsOneWidget);
    expect(find.text('City News Live'), findsWidgets);
    expect(find.text('News'), findsWidgets);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.byIcon(Icons.equalizer), findsOneWidget);
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

    await tester.tap(find.byTooltip('Movies & Shows'));
    await tester.pumpAndSettle();

    expect(openVodCalled, isTrue);
  });

  testWidgets(
    'hides Play file on TV drawer entry when onPickLocalMediaForTv is not '
    'provided',
    (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

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

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      expect(find.text('Play file on TV (debug)'), findsOneWidget);

      await tester.tap(find.text('Play file on TV (debug)'));
      await tester.pumpAndSettle();

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

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play file on TV (debug)'));
      await tester.pumpAndSettle();

      expect(find.text('Play on TV'), findsNothing);
    },
  );
}

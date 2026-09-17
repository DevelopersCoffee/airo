import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/widgets/tv_mini_guide_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _news = IPTVChannel(
  id: 'news-1',
  name: 'City News Live',
  streamUrl: 'https://example.com/news.m3u8',
  group: 'News',
  category: ChannelCategory.news,
);

const _sports = IPTVChannel(
  id: 'sports-1',
  name: 'Stadium Sports',
  streamUrl: 'https://example.com/sports.m3u8',
  group: 'Sports',
  category: ChannelCategory.sports,
);

const _movies = IPTVChannel(
  id: 'movies-1',
  name: 'Cinema Prime',
  streamUrl: 'https://example.com/movies.m3u8',
  group: 'Movies',
  category: ChannelCategory.movies,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> flushAsync(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpOverlay(
    WidgetTester tester, {
    required TvMiniGuidePreviewFactory previewFactory,
    ValueChanged<IPTVChannel>? onSelected,
    List<IPTVChannel> channels = const [_news, _sports, _movies],
    String currentChannelId = 'news-1',
  }) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TvMiniGuideOverlay(
                  channels: channels,
                  currentChannelId: currentChannelId,
                  onSelected: onSelected ?? (_) {},
                  previewFactory: previewFactory,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> pumpPlayer(
    WidgetTester tester, {
    required VideoPlayerStreamingService main,
    required TvMiniGuidePreviewFactory previewFactory,
    List<IPTVChannel> recents = const [_sports],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        iptvStreamingServiceProvider.overrideWithValue(main),
        streamProbeTransportProvider.overrideWithValue(
          _AlwaysAvailableProbeTransport(),
        ),
        iptvChannelsProvider.overrideWith(
          (ref) async => const [_news, _sports, _movies],
        ),
        recentlyWatchedChannelsProvider.overrideWith((ref) async => recents),
        tvMiniGuidePreviewFactoryProvider.overrideWithValue(previewFactory),
      ],
    );
    addTearDown(container.dispose);
    await container.read(iptvChannelsProvider.future);

    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
      ),
    );
    await tester.pump();
    await main.playChannel(_news);
    await tester.pump();
  }

  testWidgets(
    'settles 500 ms then starts at most one muted preview on the focused card',
    (tester) async {
      final previews = <_RecordingPreviewService>[];
      await pumpOverlay(
        tester,
        previewFactory: () {
          final preview = _RecordingPreviewService();
          previews.add(preview);
          return preview;
        },
      );

      expect(find.text('Mini guide'), findsOneWidget);
      expect(find.text('City News Live'), findsWidgets);
      expect(previews, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pump(const Duration(milliseconds: 499));
      expect(previews, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await flushAsync(tester);

      expect(previews, hasLength(1));
      expect(previews.single.playCount, 1);
      expect(previews.single.lastChannel?.id, 'news-1');
      expect(previews.single.currentState.isMuted, isTrue);
      expect(previews.single.currentState.volume, 0);
      expect(find.text('LIVE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('mini-guide-preview-news-1')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    },
  );

  testWidgets(
    'moving focus stops the previous preview before starting the next',
    (tester) async {
      final previews = <_RecordingPreviewService>[];
      await pumpOverlay(
        tester,
        previewFactory: () {
          final preview = _RecordingPreviewService();
          previews.add(preview);
          return preview;
        },
      );

      await tester.pump(const Duration(milliseconds: 500));
      await flushAsync(tester);
      expect(previews, hasLength(1));
      expect(previews.single.lastChannel?.id, 'news-1');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await flushAsync(tester);

      expect(previews, hasLength(1));
      expect(previews.single.stopCount, 1);
      expect(previews.single.disposed, isTrue);

      await tester.pump(const Duration(milliseconds: 500));
      await flushAsync(tester);

      expect(previews, hasLength(2));
      expect(previews.where((preview) => preview.stopCount == 0), hasLength(1));
      expect(previews.last.lastChannel?.id, 'sports-1');
      expect(previews.first.stopCount, 1);
    },
  );

  testWidgets('preview failure keeps the logo and error on that card', (
    tester,
  ) async {
    await pumpOverlay(tester, previewFactory: _FailingPreviewService.new);

    await tester.pump(const Duration(milliseconds: 500));
    await flushAsync(tester);

    expect(find.text('Mini guide'), findsOneWidget);
    expect(find.text('Preview unavailable'), findsOneWidget);
    expect(find.text('City News Live'), findsWidgets);
  });

  testWidgets('preview failure does not stop the main Watch player', (
    tester,
  ) async {
    final main = _RecordingMainService();
    await pumpPlayer(
      tester,
      main: main,
      previewFactory: _FailingPreviewService.new,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await flushAsync(tester);

    expect(find.text('Mini guide'), findsOneWidget);
    expect(main.stopCount, 0);
    expect(main.currentState.currentChannel?.id, 'news-1');
    expect(main.currentState.playbackState, PlaybackState.playing);

    await main.stop();
  });

  testWidgets('Back releases the preview and leaves main playing', (
    tester,
  ) async {
    final main = _RecordingMainService();
    final previews = <_RecordingPreviewService>[];
    await pumpPlayer(
      tester,
      main: main,
      previewFactory: () {
        final preview = _RecordingPreviewService();
        previews.add(preview);
        return preview;
      },
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await flushAsync(tester);

    expect(previews, hasLength(1));
    expect(find.text('Mini guide'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await flushAsync(tester);

    expect(find.text('Mini guide'), findsNothing);
    expect(previews.single.stopCount, 1);
    expect(previews.single.disposed, isTrue);
    expect(main.stopCount, 0);
    expect(main.currentState.currentChannel?.id, 'news-1');
    expect(main.currentState.playbackState, PlaybackState.playing);

    await main.stop();
  });

  testWidgets('OK stops preview, retunes main, and closes Mini Guide', (
    tester,
  ) async {
    final main = _RecordingMainService();
    final previews = <_RecordingPreviewService>[];
    await pumpPlayer(
      tester,
      main: main,
      previewFactory: () {
        final preview = _RecordingPreviewService();
        previews.add(preview);
        return preview;
      },
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await flushAsync(tester);

    expect(previews, hasLength(1));
    expect(previews.single.lastChannel?.id, 'sports-1');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await flushAsync(tester);

    expect(find.text('Mini guide'), findsNothing);
    expect(previews.single.stopCount, greaterThanOrEqualTo(1));
    expect(previews.single.disposed, isTrue);
    expect(main.currentState.currentChannel?.id, 'sports-1');

    await main.stop();
  });

  testWidgets('DOWN Recent Channels stays logos-only with no preview decoder', (
    tester,
  ) async {
    final main = _RecordingMainService();
    var previewFactoryCalls = 0;
    await pumpPlayer(
      tester,
      main: main,
      previewFactory: () {
        previewFactoryCalls++;
        return _RecordingPreviewService();
      },
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await flushAsync(tester);

    expect(find.text('Recently watched'), findsOneWidget);
    expect(find.text('Stadium Sports'), findsOneWidget);
    expect(previewFactoryCalls, 0);
    expect(main.stopCount, 0);

    await main.stop();
  });
}

class _RecordingPreviewService extends VideoPlayerStreamingService {
  _RecordingPreviewService()
    : super(engine: FakeAiroPlaybackEngine(), mixWithOthers: true);

  int playCount = 0;
  int stopCount = 0;
  bool disposed = false;
  IPTVChannel? lastChannel;

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    playCount++;
    lastChannel = channel;
    await super.playChannel(channel);
    await setVolume(0);
    if (!currentState.isMuted) {
      await toggleMute();
    }
  }

  @override
  Future<void> stop() async {
    stopCount++;
    await super.stop();
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await super.dispose();
  }
}

class _FailingEngine extends FakeAiroPlaybackEngine {
  @override
  Future<AiroPlaybackState> open(AiroMediaOpenRequest request) {
    throw StateError('preview decoder failed');
  }
}

class _FailingPreviewService extends VideoPlayerStreamingService {
  _FailingPreviewService()
    : super(engine: _FailingEngine(), mixWithOthers: true);
}

class _RecordingMainService extends VideoPlayerStreamingService {
  _RecordingMainService() : super(engine: FakeAiroPlaybackEngine());

  int stopCount = 0;

  @override
  Future<void> stop() async {
    stopCount++;
    await super.stop();
  }
}

class _AlwaysAvailableProbeTransport implements StreamProbeTransport {
  @override
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  }) async {
    return const StreamProbeHttpResponse(statusCode: 206);
  }
}

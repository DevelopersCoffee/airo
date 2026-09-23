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
    VoidCallback? onMoveToControls,
    void Function({bool fromBack})? onDismiss,
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
                  onMoveToControls: onMoveToControls ?? () {},
                  onDismiss: onDismiss ?? ({bool fromBack = false}) {},
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
    bool useTvTransportBar = false,
    bool enableTouchGestures = true,
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
        child: MaterialApp(
          home: Scaffold(
            body: VideoPlayerWidget(
              useTvTransportBar: useTvTransportBar,
              enableTouchGestures: enableTouchGestures,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await main.playChannel(_news);
    await tester.pump();
  }

  /// Controls start visible, so Back returns to the video zone where Down
  /// opens the Mini Guide.
  Future<void> openMiniGuideFromVideo(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
  }

  testWidgets('Up asks the parent to show controls and Down asks it to close', (
    tester,
  ) async {
    var moved = 0;
    var dismissed = 0;
    await pumpOverlay(
      tester,
      previewFactory: _RecordingPreviewService.new,
      onMoveToControls: () => moved++,
      onDismiss: ({bool fromBack = false}) => dismissed++,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(moved, 1);
    expect(dismissed, 1);
  });

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
      expect(previews.single.volumeBeforePlay, 0);
      expect(previews.single.mutedBeforePlay, isTrue);
      expect(previews.single.engine.volumesAtPlay, [0.0]);
      expect(previews.single.audioContext.requested, isEmpty);
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
      expect(previews.single.teardownOrder, ['stop', 'dispose']);

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

    await openMiniGuideFromVideo(tester);
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

    await openMiniGuideFromVideo(tester);
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

    await openMiniGuideFromVideo(tester);
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

  testWidgets('Mini Guide stays a bottom strip under the player height', (
    tester,
  ) async {
    final main = _RecordingMainService();
    await pumpPlayer(
      tester,
      main: main,
      previewFactory: _RecordingPreviewService.new,
      useTvTransportBar: true,
      enableTouchGestures: false,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    await openMiniGuideFromVideo(tester);
    await tester.pump();

    expect(find.text('Mini guide'), findsOneWidget);
    final guide = tester.getRect(find.byType(TvMiniGuideOverlay));
    final player = tester.getRect(find.byType(VideoPlayerWidget));
    expect(guide.height, lessThan(player.height * 0.5));
    expect(guide.height, greaterThan(96));
    expect(guide.bottom, closeTo(player.bottom, 1));
    expect(guide.top, greaterThan(player.top));

    await main.stop();
  });

  testWidgets('Down opens the Mini Guide from recent channels', (tester) async {
    final main = _RecordingMainService();
    await pumpPlayer(
      tester,
      main: main,
      previewFactory: _RecordingPreviewService.new,
    );

    await openMiniGuideFromVideo(tester);
    await tester.pump();

    expect(find.text('Mini guide'), findsOneWidget);
    expect(find.text('Recently watched'), findsNothing);
    expect(find.text('Stadium Sports'), findsOneWidget);
    expect(main.stopCount, 0);

    await tester.pump(const Duration(milliseconds: 500));
    await flushAsync(tester);
    await main.stop();
  });
}

class _RecordingEngine extends FakeAiroPlaybackEngine {
  final volumesAtPlay = <double>[];

  @override
  Future<AiroPlaybackState> play() async {
    volumesAtPlay.add(currentState.volume);
    return super.play();
  }
}

class _RecordingAudioContext extends AudioContextManager {
  final requested = <AudioFocusType>[];

  @override
  void requestFocus(AudioFocusType type) {
    requested.add(type);
  }
}

class _RecordingPreviewService extends VideoPlayerStreamingService {
  factory _RecordingPreviewService() {
    final engine = _RecordingEngine();
    final audioContext = _RecordingAudioContext();
    return _RecordingPreviewService._(engine, audioContext);
  }

  _RecordingPreviewService._(this.engine, this.audioContext)
    : super(engine: engine, audioContext: audioContext, mixWithOthers: true);

  final _RecordingEngine engine;
  final _RecordingAudioContext audioContext;
  int playCount = 0;
  int stopCount = 0;
  bool disposed = false;
  IPTVChannel? lastChannel;
  double? volumeBeforePlay;
  bool? mutedBeforePlay;
  final teardownOrder = <String>[];

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    playCount++;
    lastChannel = channel;
    volumeBeforePlay = currentState.volume;
    mutedBeforePlay = currentState.isMuted;
    await super.playChannel(channel);
  }

  @override
  Future<void> stop() async {
    stopCount++;
    // Yield so a parallel dispose() would finish first — sequential
    // teardown must still record stop before dispose.
    await Future<void>.value();
    teardownOrder.add('stop');
    await super.stop();
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    teardownOrder.add('dispose');
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

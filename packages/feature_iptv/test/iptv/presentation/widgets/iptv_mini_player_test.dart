import 'dart:async';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Streaming service double that lets tests observe `stop()` calls and
/// drive the streaming state stream directly, without touching the real
/// playback engine or its platform channels.
class _FakeMiniPlayerStreamingService extends VideoPlayerStreamingService {
  _FakeMiniPlayerStreamingService({required this.controller})
    : super(engine: FakeAiroPlaybackEngine());

  final StreamController<StreamingState> controller;
  bool stopped = false;

  @override
  Future<void> stop() async {
    stopped = true;
    controller.add(StreamingState());
  }
}

void main() {
  const liveChannel = IPTVChannel(
    id: 'chan-1',
    name: 'City News Live',
    streamUrl: 'https://example.com/news.m3u8',
    group: 'News',
  );

  late StreamController<StreamingState> controller;
  late _FakeMiniPlayerStreamingService fakeService;

  setUp(() {
    controller = StreamController<StreamingState>.broadcast();
    fakeService = _FakeMiniPlayerStreamingService(controller: controller);
  });

  tearDown(() async {
    await fakeService.dispose();
    await controller.close();
  });

  Widget pumpMiniPlayer() {
    return ProviderScope(
      overrides: [
        iptvStreamingServiceProvider.overrideWithValue(fakeService),
        streamingStateProvider.overrideWith((ref) => controller.stream),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: IPTVMiniPlayer(),
          ),
        ),
      ),
    );
  }

  group('IPTVMiniPlayer', () {
    testWidgets('shows the channel name and category when playing', (
      tester,
    ) async {
      await tester.pumpWidget(pumpMiniPlayer());
      controller.add(StreamingState(currentChannel: liveChannel));
      await tester.pump();

      expect(find.text('City News Live'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
    });

    testWidgets('hides entirely when no channel is playing', (tester) async {
      await tester.pumpWidget(pumpMiniPlayer());
      controller.add(StreamingState());
      await tester.pump();

      expect(find.byKey(const ValueKey('iptv-mini-player')), findsNothing);
    });

    testWidgets('shows the LIVE pill when the channel is live', (tester) async {
      await tester.pumpWidget(pumpMiniPlayer());
      controller.add(
        StreamingState(currentChannel: liveChannel, isLiveStream: true),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('iptv-mini-player-live-pill')),
        findsOneWidget,
      );
      expect(find.text('LIVE'), findsOneWidget);
    });

    testWidgets('hides the LIVE pill when the channel is not live', (
      tester,
    ) async {
      await tester.pumpWidget(pumpMiniPlayer());
      controller.add(
        StreamingState(currentChannel: liveChannel, isLiveStream: false),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('iptv-mini-player-live-pill')),
        findsNothing,
      );
      expect(find.text('LIVE'), findsNothing);
    });

    testWidgets('Watch button navigates back to the stream tab', (
      tester,
    ) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvStreamingServiceProvider.overrideWithValue(fakeService),
            streamingStateProvider.overrideWith((ref) => controller.stream),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  capturedRef = ref;
                  // Force the mini player visible even on the stream tab so
                  // the test can isolate the Watch button's behavior.
                  return const IPTVMiniPlayer(forceVisible: true);
                },
              ),
            ),
          ),
        ),
      );
      controller.add(
        StreamingState(currentChannel: liveChannel, isLiveStream: true),
      );
      await tester.pump();

      // Start off on the Home tab.
      capturedRef.read(iptvNavigationTabProvider.notifier).state =
          IptvNavigationTab.home.index;
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('iptv-mini-player-watch')));
      await tester.pump();

      expect(
        capturedRef.read(iptvNavigationTabProvider),
        IptvNavigationTab.stream.index,
      );
    });

    testWidgets('dismiss button stops playback and clears now-playing', (
      tester,
    ) async {
      await tester.pumpWidget(pumpMiniPlayer());
      controller.add(
        StreamingState(currentChannel: liveChannel, isLiveStream: true),
      );
      await tester.pump();

      expect(find.text('City News Live'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('iptv-mini-player-dismiss')));
      await tester.pump();

      expect(fakeService.stopped, isTrue);
      expect(find.text('City News Live'), findsNothing);
      expect(find.byKey(const ValueKey('iptv-mini-player')), findsNothing);
    });
  });
}

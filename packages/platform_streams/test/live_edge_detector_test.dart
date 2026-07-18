import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';
import 'package:platform_streams/platform_streams.dart';

void main() {
  group('LiveEdgeDetector.attachToEngine', () {
    late FakeAiroPlaybackEngine engine;
    late LiveEdgeDetector detector;

    AiroMediaOpenRequest request() {
      return AiroMediaOpenRequest(
        requestId: 'live-edge-1',
        sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-1'),
        mediaKind: AiroPlaybackMediaKind.hls,
      );
    }

    setUp(() {
      engine = FakeAiroPlaybackEngine();
      detector = LiveEdgeDetector(
        config: const LiveEdgeConfig(updateInterval: Duration(milliseconds: 50)),
      );
    });

    tearDown(() {
      detector.dispose();
    });

    test(
      'engine state with null/zero duration is classified as live',
      () async {
        await engine.open(request());
        // FakeAiroPlaybackEngine never sets a duration on open (stays null),
        // and _updateLiveEdgeState treats a null duration as Duration.zero —
        // which _detectLiveStream's heuristic classifies as live. This is
        // the only duration shape FakeAiroPlaybackEngine can produce without
        // extending it, so this test covers the live branch; the VOD branch
        // (finite, non-trivial duration) is exercised end-to-end by Task 7's
        // VideoPlayerStreamingService characterization tests instead, since
        // proving it here would need platform_media's
        // VideoPlayerAiroPlaybackEngine + FakeVideoPlayerPlatform, which
        // platform_streams cannot depend on without a package-layering cycle
        // (platform_media already depends on platform_streams).
        LiveEdgeState? received;
        detector.onStateUpdate = (s) => received = s;
        detector.attachToEngine(engine);

        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(received, isNotNull);
        expect(received!.isLiveStream, isTrue);
      },
    );

    test('detach stops receiving further updates', () async {
      await engine.open(request());
      var updateCount = 0;
      detector.onStateUpdate = (_) => updateCount++;
      detector.attachToEngine(engine);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final countAtDetach = updateCount;
      detector.detach();

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(updateCount, countAtDetach);
    });

    test('notifyUserSeek suppresses drift detection immediately after', () async {
      await engine.open(request());
      var driftDetected = false;
      detector.onDriftDetected = () => driftDetected = true;
      detector.attachToEngine(engine);
      detector.notifyUserSeek();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(driftDetected, isFalse);
    });
  });
}

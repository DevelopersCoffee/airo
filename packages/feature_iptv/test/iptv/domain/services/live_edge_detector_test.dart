import 'package:flutter_test/flutter_test.dart';
import "package:feature_iptv/feature_iptv.dart";

void main() {
  group('LiveEdgeConfig', () {
    test('defaultConfig should have sensible defaults', () {
      const config = LiveEdgeConfig.defaultConfig;

      expect(config.liveEdgeThreshold, equals(const Duration(seconds: 3)));
      expect(config.autoResyncThreshold, equals(const Duration(seconds: 30)));
      expect(config.updateInterval, equals(const Duration(seconds: 1)));
    });

    test('should be customizable', () {
      const config = LiveEdgeConfig(
        liveEdgeThreshold: Duration(seconds: 5),
        autoResyncThreshold: Duration(seconds: 60),
        updateInterval: Duration(milliseconds: 500),
      );

      expect(config.liveEdgeThreshold.inSeconds, equals(5));
      expect(config.autoResyncThreshold.inSeconds, equals(60));
      expect(config.updateInterval.inMilliseconds, equals(500));
    });
  });

  group('LiveStreamState', () {
    test('should have all expected states', () {
      expect(
        LiveStreamState.values,
        containsAll([
          LiveStreamState.live,
          LiveStreamState.behindLive,
          LiveStreamState.paused,
          LiveStreamState.dvrPlayback,
          LiveStreamState.unknown,
        ]),
      );
    });
  });

  group('LiveEdgeState', () {
    test('vod factory should create non-live state', () {
      final vodState = LiveEdgeState.vod();

      expect(vodState.isLiveStream, isFalse);
      expect(vodState.liveEdge, equals(Duration.zero));
      expect(vodState.liveDelay, equals(Duration.zero));
      expect(vodState.hasDvrSupport, isFalse);
    });

    test('should store all properties', () {
      const state = LiveEdgeState(
        isLiveStream: true,
        liveEdge: Duration(minutes: 5),
        liveDelay: Duration(seconds: 10),
        liveStreamState: LiveStreamState.behindLive,
        hasDvrSupport: true,
        dvrWindowStart: Duration(minutes: 2),
        dvrWindowDuration: Duration(minutes: 3),
      );

      expect(state.isLiveStream, isTrue);
      expect(state.liveEdge.inMinutes, equals(5));
      expect(state.liveDelay.inSeconds, equals(10));
      expect(state.liveStreamState, equals(LiveStreamState.behindLive));
      expect(state.hasDvrSupport, isTrue);
      expect(state.dvrWindowStart?.inMinutes, equals(2));
      expect(state.dvrWindowDuration?.inMinutes, equals(3));
    });
  });

  group('LiveEdgeDetector', () {
    late LiveEdgeDetector detector;

    setUp(() {
      detector = LiveEdgeDetector();
    });

    tearDown(() {
      detector.dispose();
    });

    test('should create with default config', () {
      expect(detector, isNotNull);
    });

    test('should create with custom config', () {
      final customDetector = LiveEdgeDetector(
        config: const LiveEdgeConfig(liveEdgeThreshold: Duration(seconds: 5)),
      );

      expect(customDetector, isNotNull);
      customDetector.dispose();
    });

    test('should allow setting callbacks', () {
      detector.onStateUpdate = (state) {
        // Callback set successfully
      };
      detector.onDriftDetected = () {
        // Callback set successfully
      };

      expect(detector.onStateUpdate, isNotNull);
      expect(detector.onDriftDetected, isNotNull);
    });

    test('dispose should clear callbacks', () {
      detector.onStateUpdate = (state) {};
      detector.onDriftDetected = () {};

      detector.dispose();

      expect(detector.onStateUpdate, isNull);
      expect(detector.onDriftDetected, isNull);
    });

    test('notifyUserSeek should not throw', () {
      expect(() => detector.notifyUserSeek(), returnsNormally);
    });
  });

  group('StreamingState Live DVR Properties', () {
    test('default state should be non-live', () {
      const state = StreamingState();

      expect(state.isLiveStream, isFalse);
      expect(state.liveEdge, isNull);
      expect(state.liveDelay, equals(Duration.zero));
      expect(state.hasDvrSupport, isFalse);
    });

    test('isAtLiveEdge should return true when delay <= 3 seconds', () {
      final atEdgeState = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 2),
      );

      expect(atEdgeState.isAtLiveEdge, isTrue);
    });

    test('isAtLiveEdge should return false when delay > 3 seconds', () {
      final behindState = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 10),
      );

      expect(behindState.isAtLiveEdge, isFalse);
    });

    test('isBehindLive should return true when delay > 3 seconds', () {
      final behindState = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 10),
      );

      expect(behindState.isBehindLive, isTrue);
    });

    test('isBehindLive should return false when at live edge', () {
      final atEdgeState = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 2),
      );

      expect(atEdgeState.isBehindLive, isFalse);
    });

    test('shouldShowGoLive should return true when behind live', () {
      final behindState = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 15),
        playbackState: PlaybackState.playing,
      );

      expect(behindState.shouldShowGoLive, isTrue);
    });

    test('shouldShowGoLive should return true when paused', () {
      final pausedState = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 2),
        playbackState: PlaybackState.paused,
      );

      expect(pausedState.shouldShowGoLive, isTrue);
    });

    test('shouldShowGoLive should return false when at live and playing', () {
      final liveState = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 1),
        playbackState: PlaybackState.playing,
      );

      expect(liveState.shouldShowGoLive, isFalse);
    });

    test('shouldAutoResync should return true when delay > 30 seconds', () {
      final driftedState = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 45),
      );

      expect(driftedState.shouldAutoResync, isTrue);
    });

    test('shouldAutoResync should return false when delay <= 30 seconds', () {
      final normalState = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 20),
      );

      expect(normalState.shouldAutoResync, isFalse);
    });

    test('formattedDelay should return seconds format for < 60 seconds', () {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(seconds: 45),
      );

      expect(state.formattedDelay, equals('45s behind'));
    });

    test('formattedDelay should return minutes format for >= 60 seconds', () {
      final state = const StreamingState().copyWith(
        isLiveStream: true,
        liveDelay: const Duration(minutes: 2, seconds: 30),
      );

      expect(state.formattedDelay, equals('2m 30s behind'));
    });

    test('canSeekBack should return true with DVR support', () {
      final dvrState = const StreamingState().copyWith(
        isLiveStream: true,
        hasDvrSupport: true,
        dvrWindowDuration: const Duration(minutes: 30),
      );

      expect(dvrState.canSeekBack, isTrue);
    });

    test('canSeekBack should return false without DVR support', () {
      final noDvrState = const StreamingState().copyWith(
        isLiveStream: true,
        hasDvrSupport: false,
      );

      expect(noDvrState.canSeekBack, isFalse);
    });
  });
}

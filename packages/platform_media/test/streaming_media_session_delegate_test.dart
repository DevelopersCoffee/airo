import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player_platform.dart';

/// Records every delegate callback so tests can assert exactly what the
/// streaming service reported to the (fake) OS media session.
class _RecordingMediaSessionDelegate implements StreamingMediaSessionDelegate {
  final List<String> calls = <String>[];
  String? lastChannelName;
  String? lastStreamUrl;

  @override
  Future<void> onChannelStarted({
    required String channelName,
    required String streamUrl,
  }) async {
    calls.add('channelStarted');
    lastChannelName = channelName;
    lastStreamUrl = streamUrl;
  }

  @override
  Future<void> onPlaybackPaused() async {
    calls.add('paused');
  }

  @override
  Future<void> onPlaybackResumed() async {
    calls.add('resumed');
  }

  @override
  Future<void> onPlaybackStopped() async {
    calls.add('stopped');
  }
}

class _ThrowingMediaSessionDelegate implements StreamingMediaSessionDelegate {
  @override
  Future<void> onChannelStarted({
    required String channelName,
    required String streamUrl,
  }) async {
    throw StateError('host media session exploded');
  }

  @override
  Future<void> onPlaybackPaused() async {
    throw StateError('host media session exploded');
  }

  @override
  Future<void> onPlaybackResumed() async {
    throw StateError('host media session exploded');
  }

  @override
  Future<void> onPlaybackStopped() async {
    throw StateError('host media session exploded');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fakePlatform;
  late VideoPlayerAiroPlaybackEngine engine;
  late _RecordingMediaSessionDelegate delegate;
  late VideoPlayerStreamingService service;

  const channel = IPTVChannel(
    id: 'chan-1',
    name: 'Test Channel',
    streamUrl: 'https://example.com/live.m3u8',
  );

  setUp(() {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    engine = VideoPlayerAiroPlaybackEngine();
    delegate = _RecordingMediaSessionDelegate();
    service = VideoPlayerStreamingService(
      engine: engine,
      mediaSessionDelegate: delegate,
    );
  });

  tearDown(() async {
    await service.dispose();
  });

  group('VideoPlayerStreamingService media session delegate', () {
    test(
      'playChannel success reports onChannelStarted with name and resolved URL',
      () async {
        await service.playChannel(channel);
        await pumpEventQueue();

        expect(delegate.calls, contains('channelStarted'));
        expect(delegate.lastChannelName, 'Test Channel');
        expect(delegate.lastStreamUrl, 'https://example.com/live.m3u8');
      },
    );

    test('playChannel failure reports nothing to the delegate', () async {
      fakePlatform.scriptedInitError = PlatformException(
        code: 'VideoError',
        message: 'decoder rejected format',
      );

      await service.playChannel(channel);
      await pumpEventQueue();

      expect(service.currentState.playbackState, PlaybackState.error);
      expect(delegate.calls, isEmpty);
    });

    test('pause, resume, and stop each report their transition', () async {
      await service.playChannel(channel);

      await service.pause();
      await service.resume();
      await service.stop();
      await pumpEventQueue();

      expect(
        delegate.calls,
        containsAllInOrder(<String>[
          'channelStarted',
          'paused',
          'resumed',
          'stopped',
        ]),
      );
    });

    test('a throwing delegate never breaks playback', () async {
      final throwingService = VideoPlayerStreamingService(
        engine: engine,
        mediaSessionDelegate: _ThrowingMediaSessionDelegate(),
      );
      addTearDown(throwingService.dispose);

      await throwingService.playChannel(channel);
      await throwingService.pause();
      await throwingService.resume();
      await throwingService.stop();
      await pumpEventQueue();

      // Every transition completed despite the host delegate throwing on
      // each one — reporting is best-effort by design.
      expect(throwingService.currentState.playbackState, PlaybackState.idle);
    });

    test('a null delegate leaves playback behavior unchanged', () async {
      final plainService = VideoPlayerStreamingService(engine: engine);
      addTearDown(plainService.dispose);

      await plainService.playChannel(channel);
      await plainService.pause();
      await plainService.resume();
      await plainService.stop();

      expect(plainService.currentState.playbackState, PlaybackState.idle);
    });

    test('the delegate is settable after construction', () async {
      final lateService = VideoPlayerStreamingService(engine: engine);
      addTearDown(lateService.dispose);

      // Host-side media handlers initialize asynchronously at app startup,
      // after the service may already exist — hence the setter.
      lateService.mediaSessionDelegate = delegate;

      await lateService.playChannel(channel);
      await pumpEventQueue();

      expect(delegate.calls, contains('channelStarted'));
      expect(delegate.lastChannelName, 'Test Channel');
    });
  });
}

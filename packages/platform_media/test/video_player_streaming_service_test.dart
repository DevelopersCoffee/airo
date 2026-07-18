import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fakePlatform;
  late VideoPlayerStreamingService service;

  IPTVChannel channel({String streamUrl = 'https://example.com/live.m3u8'}) {
    return IPTVChannel(
      id: 'chan-1',
      name: 'Test Channel',
      streamUrl: streamUrl,
    );
  }

  setUp(() {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    service = VideoPlayerStreamingService(
      engine: VideoPlayerAiroPlaybackEngine(),
    );
  });

  tearDown(() async {
    await service.dispose();
  });

  group('VideoPlayerStreamingService playChannel', () {
    test('opens via the injected engine and reaches playing', () async {
      await service.playChannel(channel());
      expect(service.currentState.playbackState, PlaybackState.playing);
      expect(service.currentState.currentChannel?.id, 'chan-1');
    });

    test('decoder failure surfaces as a typed error and retry count increments', () async {
      fakePlatform.scriptedInitError = PlatformException(
        code: 'VideoError',
        message: 'decoder rejected format',
      );
      await service.playChannel(channel());
      expect(service.currentState.playbackState, PlaybackState.error);
      expect(service.currentState.retryCount, 1);
    });

    test('buildVideoView returns non-null after a successful open', () async {
      await service.playChannel(channel());
      expect(service.buildVideoView(), isNotNull);
    });

    test('buildVideoView returns null before any channel is played', () {
      expect(service.buildVideoView(), isNull);
    });
  });

  group('VideoPlayerStreamingService selectTrack', () {
    test('unknown track id is a no-op that does not throw', () async {
      await service.playChannel(channel());
      await service.selectTrack(
        kind: AiroPlaybackTrackKind.subtitle,
        trackId: 'nonexistent',
      );
      expect(
        service.currentState.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
        isNull,
      );
    });
  });

  group('VideoPlayerStreamingService attachExternalSubtitle', () {
    test('attached subtitle appears in tracks after the next playChannel', () async {
      service.attachExternalSubtitle(
        AiroPlaybackExternalSubtitle(
          handle: AiroPlaybackSourceHandle.redacted('sub-en'),
          languageCode: 'en',
          label: 'English',
        ),
      );
      await service.playChannel(channel());
      expect(service.currentState.tracks, hasLength(1));
      expect(service.currentState.tracks.single.isExternal, isTrue);
    });

    test('subtitle does not appear before the next playChannel', () async {
      await service.playChannel(channel());
      expect(service.currentState.tracks, isEmpty);

      service.attachExternalSubtitle(
        AiroPlaybackExternalSubtitle(
          handle: AiroPlaybackSourceHandle.redacted('sub-en'),
          languageCode: 'en',
        ),
      );
      // Not applied yet — still empty until the next playChannel.
      expect(service.currentState.tracks, isEmpty);
    });
  });

  group('VideoPlayerStreamingService DVR/live-edge/buffer-health regression', () {
    test(
      'a stream with a large finite duration is classified as VOD (isLiveStream false)',
      () async {
        final vodService = VideoPlayerStreamingService(
          engine: VideoPlayerAiroPlaybackEngine(),
          liveEdgeConfig: const LiveEdgeConfig(
            updateInterval: Duration(milliseconds: 50),
          ),
        );
        addTearDown(vodService.dispose);

        fakePlatform = FakeVideoPlayerPlatform(
          fakeDuration: const Duration(minutes: 90),
        );
        VideoPlayerPlatform.instance = fakePlatform;

        await vodService.playChannel(channel());
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(vodService.currentState.isLiveStream, isFalse);
      },
    );

    test(
      'a stream with zero duration is classified as live (isLiveStream true)',
      () async {
        final liveService = VideoPlayerStreamingService(
          engine: VideoPlayerAiroPlaybackEngine(),
          liveEdgeConfig: const LiveEdgeConfig(
            updateInterval: Duration(milliseconds: 50),
          ),
        );
        addTearDown(liveService.dispose);

        fakePlatform = FakeVideoPlayerPlatform(fakeDuration: Duration.zero);
        VideoPlayerPlatform.instance = fakePlatform;

        await liveService.playChannel(channel());
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(liveService.currentState.isLiveStream, isTrue);
      },
    );

    test(
      'buffer-health monitor recalculates bufferHealth from the default 100',
      () async {
        // BufferStatus() defaults bufferHealth to 100 (the pristine,
        // pre-timer value). FakeVideoPlayerPlatform never scripts buffered
        // DurationRanges, so bufferedAhead is deterministically zero once
        // the 1s Timer.periodic in _startBufferMonitoring ticks — driving
        // bufferHealth to 0 (0 / targetBufferDuration * 100). Seeing 0
        // instead of the untouched default of 100 is what proves the timer
        // actually ran, not just that BufferStatus has a value.
        await service.playChannel(channel());
        expect(service.currentState.bufferStatus.bufferHealth, 100);

        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(service.currentState.bufferStatus.bufferHealth, 0);
      },
      timeout: const Timeout(Duration(seconds: 5)),
    );
  });
}

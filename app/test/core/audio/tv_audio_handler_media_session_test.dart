import 'package:airo_app/core/audio/tv_audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// #980: TvAudioHandler's two-direction contract with
/// VideoPlayerStreamingService — the delegate reporting path updates
/// media-session state only, the audio_service control path fires
/// user-intent callbacks, and transition guards keep the two from
/// recursing into each other.
void main() {
  group('TvAudioHandler media session contract (#980)', () {
    test(
      'onChannelStarted reports playing state and channel metadata',
      () async {
        final handler = TvAudioHandler();
        var userCallbacks = 0;
        handler.onUserPlayRequested = () => userCallbacks++;
        handler.onUserPauseRequested = () => userCallbacks++;
        handler.onUserStopRequested = () => userCallbacks++;

        await handler.onChannelStarted(
          channelName: 'Test Channel',
          streamUrl: 'https://example.com/live.m3u8',
        );

        expect(handler.isPlaying, isTrue);
        expect(handler.currentChannelName, 'Test Channel');
        expect(handler.currentStreamUrl, 'https://example.com/live.m3u8');
        // Reporting path must not look like a user action.
        expect(userCallbacks, 0);
      },
    );

    test(
      'delegate reporting path (paused/resumed/stopped) fires no user callbacks',
      () async {
        final handler = TvAudioHandler();
        var userCallbacks = 0;
        handler.onUserPlayRequested = () => userCallbacks++;
        handler.onUserPauseRequested = () => userCallbacks++;
        handler.onUserStopRequested = () => userCallbacks++;

        await handler.onChannelStarted(
          channelName: 'Test Channel',
          streamUrl: 'https://example.com/live.m3u8',
        );
        await handler.onPlaybackPaused();
        expect(handler.isPlaying, isFalse);

        await handler.onPlaybackResumed();
        expect(handler.isPlaying, isTrue);

        await handler.onPlaybackStopped();
        expect(handler.isPlaying, isFalse);
        expect(handler.currentChannelName, isNull);
        expect(handler.currentStreamUrl, isNull);

        expect(userCallbacks, 0);
      },
    );

    test(
      'control path fires user-intent callbacks on real transitions',
      () async {
        final handler = TvAudioHandler();
        var pauseRequests = 0;
        var playRequests = 0;
        var stopRequests = 0;
        handler.onUserPauseRequested = () => pauseRequests++;
        handler.onUserPlayRequested = () => playRequests++;
        handler.onUserStopRequested = () => stopRequests++;

        await handler.playChannel(
          'Test Channel',
          'https://example.com/live.m3u8',
        );

        await handler.pause();
        expect(pauseRequests, 1);

        await handler.play();
        expect(playRequests, 1);

        await handler.stop();
        expect(stopRequests, 1);
      },
    );

    test('pause while already paused is a no-op (recursion guard)', () async {
      final handler = TvAudioHandler();
      var pauseRequests = 0;
      handler.onUserPauseRequested = () => pauseRequests++;

      await handler.playChannel(
        'Test Channel',
        'https://example.com/live.m3u8',
      );
      await handler.pause();
      expect(pauseRequests, 1);

      // The loop this guards against: delegate.onPlaybackPaused ->
      // handler state, then notification pause -> service.pause() ->
      // delegate again. A second pause must not fire another callback.
      await handler.pause();
      expect(pauseRequests, 1);
      expect(handler.isPlaying, isFalse);
    });

    test('play while already playing is a no-op (recursion guard)', () async {
      final handler = TvAudioHandler();
      var playRequests = 0;
      handler.onUserPlayRequested = () => playRequests++;

      await handler.playChannel(
        'Test Channel',
        'https://example.com/live.m3u8',
      );

      await handler.play();
      expect(playRequests, 0);
      expect(handler.isPlaying, isTrue);
    });

    test('stop while idle is a no-op (recursion guard)', () async {
      final handler = TvAudioHandler();
      var stopRequests = 0;
      handler.onUserStopRequested = () => stopRequests++;

      await handler.stop();
      expect(stopRequests, 0);

      await handler.playChannel(
        'Test Channel',
        'https://example.com/live.m3u8',
      );
      await handler.stop();
      expect(stopRequests, 1);

      // Already stopped: a repeat stop (e.g. service.stop() racing a
      // notification stop) must not fire again.
      await handler.stop();
      expect(stopRequests, 1);
    });
  });
}

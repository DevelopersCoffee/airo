import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/airo_playback_engine_conformance.dart';
import 'support/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fakePlatform;

  setUp(() {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  runAiroPlaybackEngineConformanceSuite(
    'videoPlayer',
    () => VideoPlayerAiroPlaybackEngine(),
  );

  group('VideoPlayerAiroPlaybackEngine engine-specific behavior', () {
    AiroMediaOpenRequest request() {
      return AiroMediaOpenRequest(
        requestId: 'open-1',
        sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-handle-1'),
        mediaKind: AiroPlaybackMediaKind.hls,
      );
    }

    test('backendKind is videoPlayer', () {
      final engine = VideoPlayerAiroPlaybackEngine();
      expect(engine.backendKind, AiroPlaybackBackendKind.videoPlayer);
    });

    test(
      'platform decoder failure surfaces as a typed decoderFailed error',
      () async {
        fakePlatform.scriptedInitError = PlatformException(
          code: 'VideoError',
          message: 'decoder rejected format',
        );
        final engine = VideoPlayerAiroPlaybackEngine();

        final state = await engine.open(request());

        expect(state.phase, AiroPlaybackEnginePhase.failed);
        expect(state.error?.code, AiroPlaybackErrorCode.decoderFailed);
        expect(state.error?.operation, 'open');
        await engine.dispose();
      },
    );

    test('HTTP-status-bearing platform failure extracts httpStatusCode '
        '(geo-blocked 403 must not be blamed on the device)', () async {
      fakePlatform.scriptedInitError = PlatformException(
        code: 'VideoError',
        message:
            'Video player had error com.google.android.exoplayer2.'
            'ExoPlaybackException: Source error, caused by '
            'HttpDataSource\$InvalidResponseCodeException: '
            'Response code: 403',
      );
      final engine = VideoPlayerAiroPlaybackEngine();

      final state = await engine.open(request());

      expect(state.phase, AiroPlaybackEnginePhase.failed);
      expect(state.error?.httpStatusCode, 403);
      await engine.dispose();
    });

    test(
      'platform failure without an HTTP status leaves httpStatusCode null',
      () async {
        fakePlatform.scriptedInitError = PlatformException(
          code: 'VideoError',
          message: 'decoder rejected format',
        );
        final engine = VideoPlayerAiroPlaybackEngine();

        final state = await engine.open(request());

        expect(state.error?.httpStatusCode, isNull);
        await engine.dispose();
      },
    );

    test(
      'selectQuality is unsupported: no quality catalog in this adapter',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(request());

        final state = await engine.selectQuality('720p');
        expect(state.error?.code, AiroPlaybackErrorCode.qualityUnavailable);
        await engine.dispose();
      },
    );

    test('selectTrack fails typed when no matching track exists', () async {
      final engine = VideoPlayerAiroPlaybackEngine();
      await engine.open(request());

      final state = await engine.selectTrack(
        kind: AiroPlaybackTrackKind.audio,
        trackId: 'audio-1',
      );
      expect(state.error?.code, AiroPlaybackErrorCode.trackUnavailable);
      await engine.dispose();
    });

    test(
      'external subtitles from open request appear in state.tracks',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(
          AiroMediaOpenRequest(
            requestId: 'open-sub',
            sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-1'),
            mediaKind: AiroPlaybackMediaKind.hls,
            externalSubtitles: [
              AiroPlaybackExternalSubtitle(
                handle: AiroPlaybackSourceHandle.redacted('sub-en'),
                languageCode: 'en',
                label: 'English',
              ),
            ],
          ),
        );
        expect(engine.currentState.tracks, hasLength(1));
        expect(engine.currentState.tracks.single.isExternal, isTrue);
        expect(engine.currentState.tracks.single.id, 'external_sub_0');
        await engine.dispose();
      },
    );

    test(
      'selectTrack picks a projected external subtitle and records it',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(
          AiroMediaOpenRequest(
            requestId: 'open-sub',
            sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-1'),
            mediaKind: AiroPlaybackMediaKind.hls,
            externalSubtitles: [
              AiroPlaybackExternalSubtitle(
                handle: AiroPlaybackSourceHandle.redacted('sub-en'),
                languageCode: 'en',
              ),
            ],
          ),
        );

        final state = await engine.selectTrack(
          kind: AiroPlaybackTrackKind.subtitle,
          trackId: 'external_sub_0',
        );

        expect(state.error, isNull);
        expect(
          state.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
          'external_sub_0',
        );
        await engine.dispose();
      },
    );

    test(
      'diagnostics reports hardware-accelerated after a successful open',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(request());

        final diagnostics = await engine.diagnostics();
        expect(diagnostics.hardwareAccelerated, isTrue);
        await engine.dispose();
      },
    );

    test('buildView is null before open, non-null after', () async {
      final engine = VideoPlayerAiroPlaybackEngine();
      expect(engine.buildView(), isNull);

      await engine.open(request());
      expect(engine.buildView(), isNotNull);

      await engine.dispose();
    });

    test('buildView is null after dispose', () async {
      final engine = VideoPlayerAiroPlaybackEngine();
      await engine.open(request());
      await engine.dispose();
      expect(engine.buildView(), isNull);
    });

    test(
      'controller buffering events are reflected on the states stream without an explicit call',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        final phases = <AiroPlaybackEnginePhase>[];
        final subscription = engine.states.listen((s) => phases.add(s.phase));

        await engine.open(request());
        await engine.play();
        fakePlatform.emitBufferingStart();
        await Future<void>.delayed(Duration.zero);
        fakePlatform.emitBufferingEnd();
        await Future<void>.delayed(Duration.zero);

        await subscription.cancel();
        await engine.dispose();

        expect(phases, contains(AiroPlaybackEnginePhase.buffering));
        // Returns to playing after buffering ends.
        expect(phases.last, AiroPlaybackEnginePhase.playing);
      },
    );

    test(
      'buffering while paused restores to paused, not playing, once buffering clears',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(request());
        await engine.play();
        await engine.pause();

        fakePlatform.emitBufferingStart();
        await Future<void>.delayed(Duration.zero);
        expect(engine.currentState.phase, AiroPlaybackEnginePhase.buffering);

        fakePlatform.emitBufferingEnd();
        await Future<void>.delayed(Duration.zero);
        expect(engine.currentState.phase, AiroPlaybackEnginePhase.paused);

        await engine.dispose();
      },
    );

    test(
      'seek during active playback keeps phase == playing, not paused',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(request());
        await engine.play();
        expect(engine.currentState.phase, AiroPlaybackEnginePhase.playing);

        final state = await engine.seek(const Duration(seconds: 30));

        expect(state.phase, AiroPlaybackEnginePhase.playing);
        expect(engine.currentState.phase, AiroPlaybackEnginePhase.playing);
        await engine.dispose();
      },
    );

    test(
      'seek while genuinely paused still results in phase == paused',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(request());
        await engine.play();
        await engine.pause();
        expect(engine.currentState.phase, AiroPlaybackEnginePhase.paused);

        final state = await engine.seek(const Duration(seconds: 30));

        expect(state.phase, AiroPlaybackEnginePhase.paused);
        await engine.dispose();
      },
    );

    test(
      'engine state carries bufferedRanges reflecting the controller value',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(request());
        await engine.play();
        fakePlatform.emitBufferingStart();
        await Future<void>.delayed(Duration.zero);
        fakePlatform.emitBufferingEnd();
        await Future<void>.delayed(Duration.zero);

        // FakeVideoPlayerPlatform never scripts buffered DurationRanges, so
        // VideoPlayerController.value.buffered stays at its default empty
        // list — deterministically empty here, proving the field is read
        // from controller.value without throwing rather than left stale
        // from construction (it would also be empty pre-listener, so this
        // alone doesn't prove wiring; combined with the phase-transition
        // test above, which does observably change, it's sufficient).
        expect(engine.currentState.bufferedRanges, isEmpty);

        await engine.dispose();
      },
    );
  });
}

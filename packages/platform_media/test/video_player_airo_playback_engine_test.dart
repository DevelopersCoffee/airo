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

    test(
      'selectTrack fails typed when no matching track exists',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(request());

        final state = await engine.selectTrack(
          kind: AiroPlaybackTrackKind.audio,
          trackId: 'audio-1',
        );
        expect(state.error?.code, AiroPlaybackErrorCode.trackUnavailable);
        await engine.dispose();
      },
    );

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

    test('diagnostics reports hardware-accelerated after a successful open', () async {
      final engine = VideoPlayerAiroPlaybackEngine();
      await engine.open(request());

      final diagnostics = await engine.diagnostics();
      expect(diagnostics.hardwareAccelerated, isTrue);
      await engine.dispose();
    });
  });
}

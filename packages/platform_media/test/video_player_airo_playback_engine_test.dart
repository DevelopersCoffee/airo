import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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
      'selectTrack is unsupported: no track catalog in this adapter',
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
      'diagnostics reports hardware-accelerated after a successful open',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(request());

        final diagnostics = await engine.diagnostics();
        expect(diagnostics.hardwareAccelerated, isTrue);
        await engine.dispose();
      },
    );

    test('buildView is null before open', () {
      final engine = VideoPlayerAiroPlaybackEngine();
      expect(engine.buildView(), isNull);
    });

    test('buildView returns a sized video surface after open', () async {
      final engine = VideoPlayerAiroPlaybackEngine();
      await engine.open(request());

      final view = engine.buildView();
      expect(view, isA<SizedBox>());
      expect((view as SizedBox).width, 1920);
      expect(view.height, 1080);
      await engine.dispose();
    });

    test('buildView is null again after dispose', () async {
      final engine = VideoPlayerAiroPlaybackEngine();
      await engine.open(request());
      await engine.dispose();

      expect(engine.buildView(), isNull);
    });
  });
}

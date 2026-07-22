import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

/// Shared contract-conformance suite: any [AiroPlaybackEngine] implementation
/// must pass these lifecycle assertions identically. Parameterize this over
/// every concrete engine (videoPlayer, mpv, ...) instead of writing a new
/// suite per engine.
void runAiroPlaybackEngineConformanceSuite(
  String label,
  AiroPlaybackEngine Function() createEngine,
) {
  group('AiroPlaybackEngine contract conformance ($label)', () {
    AiroMediaOpenRequest request() {
      return AiroMediaOpenRequest(
        requestId: 'conformance-open-1',
        sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-handle-1'),
        mediaKind: AiroPlaybackMediaKind.hls,
      );
    }

    test('open succeeds and reaches the open phase', () async {
      final engine = createEngine();
      final state = await engine.open(request());

      expect(state.phase, AiroPlaybackEnginePhase.open);
      expect(state.error, isNull);
      expect(state.backendKind, engine.backendKind);
      await engine.dispose();
    });

    test('play/pause/seek/stop each resolve to the expected phase', () async {
      final engine = createEngine();
      await engine.open(request());

      final playState = await engine.play();
      expect(playState.phase, AiroPlaybackEnginePhase.playing);

      final pauseState = await engine.pause();
      expect(pauseState.phase, AiroPlaybackEnginePhase.paused);

      final seekState = await engine.seek(const Duration(seconds: 5));
      expect(seekState.phase, AiroPlaybackEnginePhase.paused);
      expect(seekState.position, const Duration(seconds: 5));

      final stopState = await engine.stop();
      expect(stopState.phase, AiroPlaybackEnginePhase.stopped);
      expect(stopState.position, Duration.zero);
      await engine.dispose();
    });

    test('setVolume clamps into [0, 1]', () async {
      final engine = createEngine();
      await engine.open(request());

      final state = await engine.setVolume(1.7);
      expect(state.volume, 1);
      await engine.dispose();
    });

    test('setPlaybackSpeed reflects requested speed', () async {
      final engine = createEngine();
      await engine.open(request());

      final state = await engine.setPlaybackSpeed(1.5);
      expect(state.playbackSpeed, 1.5);
      await engine.dispose();
    });

    test('diagnostics never throws and reports this backend', () async {
      final engine = createEngine();
      await engine.open(request());

      final diagnostics = await engine.diagnostics();
      expect(diagnostics.backendId, engine.backendKind.stableId);
      await engine.dispose();
    });

    test(
      'picture-in-picture never throws: either succeeds or fails typed',
      () async {
        final engine = createEngine();
        await engine.open(request());

        final enterState = await engine.enterPictureInPicture();
        if (enterState.error != null) {
          expect(enterState.error!.operation, 'enterPictureInPicture');
        }

        final exitState = await engine.exitPictureInPicture();
        if (exitState.error != null) {
          expect(exitState.error!.operation, 'exitPictureInPicture');
        }
        await engine.dispose();
      },
    );

    test('dispose completes without throwing', () async {
      final engine = createEngine();
      await engine.open(request());
      await expectLater(engine.dispose(), completes);
    });

    test('buildView never throws, before or after open', () async {
      final engine = createEngine();
      expect(() => engine.buildView(), returnsNormally);

      await engine.open(request());
      expect(() => engine.buildView(), returnsNormally);
      await engine.dispose();
    });
  });
}

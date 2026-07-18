import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import 'support/airo_playback_engine_conformance.dart';
import 'support/fake_mpv_player_facade.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Contract-conformance: identical lifecycle assertions the videoPlayer
  // engine passes. The mpv engine must be a drop-in from the caller's view.
  runAiroPlaybackEngineConformanceSuite(
    'mpv',
    () => MpvAiroPlaybackEngine(playerFactory: FakeMpvPlayerFacade.new),
  );

  group('MpvAiroPlaybackEngine engine-specific behavior', () {
    AiroMediaOpenRequest request() {
      return AiroMediaOpenRequest(
        requestId: 'open-1',
        sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-handle-1'),
        mediaKind: AiroPlaybackMediaKind.hls,
      );
    }

    test('backendKind is mpv', () {
      final engine = MpvAiroPlaybackEngine(
        playerFactory: FakeMpvPlayerFacade.new,
      );
      expect(engine.backendKind, AiroPlaybackBackendKind.mpv);
    });

    test('open forwards the source handle URL to the facade', () async {
      FakeMpvPlayerFacade? capturedFake;
      final engine = MpvAiroPlaybackEngine(
        playerFactory: () {
          final fake = FakeMpvPlayerFacade();
          capturedFake = fake;
          return fake;
        },
      );
      await engine.open(request());
      expect(capturedFake!.lastOpenedUrl, 'opaque-handle-1');
      await engine.dispose();
    });

    test('facade open throw surfaces as typed decoderFailed', () async {
      final engine = MpvAiroPlaybackEngine(
        playerFactory: () =>
            FakeMpvPlayerFacade(scriptedOpenError: StateError('bad codec')),
      );
      final state = await engine.open(request());
      expect(state.phase, AiroPlaybackEnginePhase.failed);
      expect(state.error?.code, AiroPlaybackErrorCode.decoderFailed);
      expect(state.error?.operation, 'open');
      await engine.dispose();
    });

    test('diagnostics reflects the facade hardware-accel flag', () async {
      final engine = MpvAiroPlaybackEngine(
        playerFactory: () => FakeMpvPlayerFacade(hardwareAccelerated: false),
      );
      await engine.open(request());
      final diagnostics = await engine.diagnostics();
      expect(diagnostics.hardwareAccelerated, isFalse);
      await engine.dispose();
    });

    test('PiP unsupported: mpv has no OS PiP', () async {
      final engine = MpvAiroPlaybackEngine(
        playerFactory: FakeMpvPlayerFacade.new,
      );
      await engine.open(request());

      final enterState = await engine.enterPictureInPicture();
      expect(
        enterState.error?.code,
        AiroPlaybackErrorCode.unsupportedOperation,
      );
      expect(enterState.error?.operation, 'enterPictureInPicture');

      final exitState = await engine.exitPictureInPicture();
      expect(exitState.error?.code, AiroPlaybackErrorCode.unsupportedOperation);
      await engine.dispose();
    });

    test('setVolume clamps into [0, 1] and scales to facade range', () async {
      FakeMpvPlayerFacade? capturedFake;
      final engine = MpvAiroPlaybackEngine(
        playerFactory: () {
          final fake = FakeMpvPlayerFacade();
          capturedFake = fake;
          return fake;
        },
      );
      await engine.open(request());

      final state = await engine.setVolume(1.7);
      expect(state.volume, 1);
      // media_kit uses 0..100 scale — engine must scale from 0..1.
      expect(capturedFake!.volume, 100.0);
      await engine.dispose();
    });

    test(
      'external subtitles from open request appear in state.tracks',
      () async {
        final engine = MpvAiroPlaybackEngine(
          playerFactory: FakeMpvPlayerFacade.new,
        );
        await engine.open(
          AiroMediaOpenRequest(
            requestId: 'open-sub',
            sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-1'),
            mediaKind: AiroPlaybackMediaKind.hls,
            externalSubtitles: [
              AiroPlaybackExternalSubtitle(
                handle: AiroPlaybackSourceHandle.redacted('sub-fr'),
                languageCode: 'fr',
                label: 'Français',
              ),
              AiroPlaybackExternalSubtitle(
                handle: AiroPlaybackSourceHandle.redacted('sub-de'),
                languageCode: 'de',
              ),
            ],
          ),
        );
        expect(engine.currentState.tracks, hasLength(2));
        expect(engine.currentState.tracks[0].label, 'Français');
        expect(engine.currentState.tracks[1].languageCode, 'de');
        expect(engine.currentState.tracks.every((t) => t.isExternal), isTrue);
        await engine.dispose();
      },
    );

    test('selectTrack succeeds for a projected external subtitle', () async {
      final engine = MpvAiroPlaybackEngine(
        playerFactory: FakeMpvPlayerFacade.new,
      );
      await engine.open(
        AiroMediaOpenRequest(
          requestId: 'open-sub',
          sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-1'),
          mediaKind: AiroPlaybackMediaKind.hls,
          externalSubtitles: [
            AiroPlaybackExternalSubtitle(
              handle: AiroPlaybackSourceHandle.redacted('sub-fr'),
              languageCode: 'fr',
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
    });

    test('selectTrack fails typed for an unknown track id', () async {
      final engine = MpvAiroPlaybackEngine(
        playerFactory: FakeMpvPlayerFacade.new,
      );
      await engine.open(request());

      final state = await engine.selectTrack(
        kind: AiroPlaybackTrackKind.audio,
        trackId: 'nope',
      );
      expect(state.error?.code, AiroPlaybackErrorCode.trackUnavailable);
      await engine.dispose();
    });
    test('dispose releases the facade', () async {
      FakeMpvPlayerFacade? capturedFake;
      final engine = MpvAiroPlaybackEngine(
        playerFactory: () {
          final fake = FakeMpvPlayerFacade();
          capturedFake = fake;
          return fake;
        },
      );
      await engine.open(request());
      await engine.dispose();
      expect(capturedFake!.disposed, isTrue);
    });
  });
}

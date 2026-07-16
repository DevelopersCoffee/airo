import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

/// Test double that scripts open() outcomes call-by-call, so coordinator
/// tests can drive codec/decoder/source failures deterministically without
/// a real decode backend.
class _ScriptedPlaybackEngine implements AiroPlaybackEngine {
  _ScriptedPlaybackEngine({
    required this.backendKind,
    required List<AiroPlaybackErrorCode?> openScript,
  }) : _openScript = List.of(openScript),
       _state = AiroPlaybackState.idle(backendKind: backendKind);

  @override
  final AiroPlaybackBackendKind backendKind;

  final List<AiroPlaybackErrorCode?> _openScript;
  int openCallCount = 0;
  int disposeCallCount = 0;
  AiroPlaybackState _state;

  final StreamController<AiroPlaybackState> _controller =
      StreamController<AiroPlaybackState>.broadcast();

  @override
  Stream<AiroPlaybackState> get states => _controller.stream;

  @override
  AiroPlaybackState get currentState => _state;

  @override
  Future<AiroPlaybackState> open(AiroMediaOpenRequest request) async {
    openCallCount++;
    final errorCode = openCallCount <= _openScript.length
        ? _openScript[openCallCount - 1]
        : _openScript.last;
    _state = AiroPlaybackState(
      backendKind: backendKind,
      phase: errorCode == null
          ? AiroPlaybackEnginePhase.open
          : AiroPlaybackEnginePhase.failed,
      request: request,
      error: errorCode == null ? null : AiroPlaybackError(code: errorCode),
    );
    _controller.add(_state);
    return _state;
  }

  @override
  Future<AiroPlaybackState> play() async => _state;

  @override
  Future<AiroPlaybackState> pause() async => _state;

  @override
  Future<AiroPlaybackState> stop() async => _state;

  @override
  Future<AiroPlaybackState> seek(Duration position) async => _state;

  @override
  Future<AiroPlaybackState> setVolume(double volume) async => _state;

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async => _state;

  @override
  Future<AiroPlaybackState> selectQuality(String qualityId) async => _state;

  @override
  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async => _state;

  @override
  Future<AiroPlaybackDiagnostics> diagnostics() async {
    return AiroPlaybackDiagnostics(backendId: backendKind.stableId);
  }

  @override
  Future<AiroPlaybackState> enterPictureInPicture() async => _state;

  @override
  Future<AiroPlaybackState> exitPictureInPicture() async => _state;

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    await _controller.close();
  }

  /// Test-only: simulate a mid-playback runtime error arriving on this
  /// engine's own `states` stream (distinct from an `open()` failure).
  void emitRuntimeError(AiroPlaybackErrorCode code) {
    _state = _state.copyWith(
      phase: AiroPlaybackEnginePhase.failed,
      error: AiroPlaybackError(code: code),
    );
    _controller.add(_state);
  }
}

void main() {
  group('AiroEngineFallbackCoordinator', () {
    AiroMediaOpenRequest request() {
      return AiroMediaOpenRequest(
        requestId: 'open-1',
        sourceHandle: AiroPlaybackSourceHandle.redacted('source-handle-1'),
        mediaKind: AiroPlaybackMediaKind.hls,
      );
    }

    test('primary succeeds: no fallback attempted', () async {
      final primary = _ScriptedPlaybackEngine(
        backendKind: AiroPlaybackBackendKind.videoPlayer,
        openScript: const [null],
      );
      final fallback = _ScriptedPlaybackEngine(
        backendKind: AiroPlaybackBackendKind.mpv,
        openScript: const [null],
      );
      final coordinator = AiroEngineFallbackCoordinator(
        primaryEngine: primary,
        fallbackEngine: fallback,
      );

      final decision = await coordinator.open(request());

      expect(decision.code, AiroEngineFallbackDecisionCode.openedOnPrimary);
      expect(primary.openCallCount, 1);
      expect(fallback.openCallCount, 0);
      expect(coordinator.isLocked, isTrue);
      expect(coordinator.activeEngine.backendKind, primary.backendKind);
    });

    test('primary codecUnsupported: mpv tried once, succeeds', () async {
      final primary = _ScriptedPlaybackEngine(
        backendKind: AiroPlaybackBackendKind.videoPlayer,
        openScript: const [AiroPlaybackErrorCode.codecUnsupported],
      );
      final fallback = _ScriptedPlaybackEngine(
        backendKind: AiroPlaybackBackendKind.mpv,
        openScript: const [null],
      );
      final coordinator = AiroEngineFallbackCoordinator(
        primaryEngine: primary,
        fallbackEngine: fallback,
      );

      final decision = await coordinator.open(request());

      expect(decision.code, AiroEngineFallbackDecisionCode.switchedToFallback);
      expect(primary.openCallCount, 1);
      expect(fallback.openCallCount, 1);
      expect(coordinator.isLocked, isTrue);
      expect(coordinator.activeEngine.backendKind, fallback.backendKind);
      expect(coordinator.triedEngines, {
        AiroPlaybackBackendKind.videoPlayer,
        AiroPlaybackBackendKind.mpv,
      });
      expect(
        primary.disposeCallCount,
        1,
        reason:
            'abandoned primary must be disposed before the fallback swap, '
            'never left alive alongside the new engine',
      );
    });

    test(
      'primary and fallback both fail: FAILED, exactly 2 open() calls, no 3rd attempt',
      () async {
        final primary = _ScriptedPlaybackEngine(
          backendKind: AiroPlaybackBackendKind.videoPlayer,
          openScript: const [AiroPlaybackErrorCode.decoderFailed],
        );
        final fallback = _ScriptedPlaybackEngine(
          backendKind: AiroPlaybackBackendKind.mpv,
          openScript: const [AiroPlaybackErrorCode.decoderFailed],
        );
        final coordinator = AiroEngineFallbackCoordinator(
          primaryEngine: primary,
          fallbackEngine: fallback,
        );

        final decision = await coordinator.open(request());

        expect(decision.code, AiroEngineFallbackDecisionCode.exhausted);
        expect(primary.openCallCount, 1);
        expect(fallback.openCallCount, 1);
        expect(coordinator.isLocked, isFalse);
        expect(
          primary.disposeCallCount,
          1,
          reason: 'primary must be disposed before the fallback is attempted, '
              'regardless of whether the fallback itself succeeds',
        );

        // Calling open() again must not attempt a 3rd engine (anti-loop).
        final secondDecision = await coordinator.open(request());
        expect(secondDecision.code, AiroEngineFallbackDecisionCode.exhausted);
        expect(primary.openCallCount, 1);
        expect(fallback.openCallCount, 1);
      },
    );

    test(
      'fallback gated on weak device: straight to FAILED, no fallback attempt',
      () async {
        final primary = _ScriptedPlaybackEngine(
          backendKind: AiroPlaybackBackendKind.videoPlayer,
          openScript: const [AiroPlaybackErrorCode.codecUnsupported],
        );
        final coordinator = AiroEngineFallbackCoordinator(
          primaryEngine: primary,
          fallbackEngine: null,
        );

        final decision = await coordinator.open(request());

        expect(decision.code, AiroEngineFallbackDecisionCode.exhausted);
        expect(primary.openCallCount, 1);
        expect(coordinator.isLocked, isFalse);
      },
    );

    test(
      'source error: delegated to source failover, engine-fallback budget untouched',
      () async {
        final primary = _ScriptedPlaybackEngine(
          backendKind: AiroPlaybackBackendKind.videoPlayer,
          openScript: const [AiroPlaybackErrorCode.sourceUnavailable],
        );
        final fallback = _ScriptedPlaybackEngine(
          backendKind: AiroPlaybackBackendKind.mpv,
          openScript: const [null],
        );
        final coordinator = AiroEngineFallbackCoordinator(
          primaryEngine: primary,
          fallbackEngine: fallback,
        );

        final decision = await coordinator.open(request());

        expect(
          decision.code,
          AiroEngineFallbackDecisionCode.delegatedToSourceFailover,
        );
        expect(primary.openCallCount, 1);
        expect(fallback.openCallCount, 0);
        expect(coordinator.isLocked, isFalse);
        expect(coordinator.triedEngines, {AiroPlaybackBackendKind.videoPlayer});
      },
    );

    test(
      'networkUnavailable is also delegated to source failover, not engine axis',
      () async {
        final primary = _ScriptedPlaybackEngine(
          backendKind: AiroPlaybackBackendKind.videoPlayer,
          openScript: const [AiroPlaybackErrorCode.networkUnavailable],
        );
        final coordinator = AiroEngineFallbackCoordinator(
          primaryEngine: primary,
          fallbackEngine: null,
        );

        final decision = await coordinator.open(request());

        expect(
          decision.code,
          AiroEngineFallbackDecisionCode.delegatedToSourceFailover,
        );
      },
    );

    test('mid-playback error after lock: no engine swap, ever', () async {
      final primary = _ScriptedPlaybackEngine(
        backendKind: AiroPlaybackBackendKind.videoPlayer,
        openScript: const [null],
      );
      final fallback = _ScriptedPlaybackEngine(
        backendKind: AiroPlaybackBackendKind.mpv,
        openScript: const [null],
      );
      final coordinator = AiroEngineFallbackCoordinator(
        primaryEngine: primary,
        fallbackEngine: fallback,
      );

      await coordinator.open(request());
      expect(coordinator.isLocked, isTrue);

      final runtimeDecision = coordinator.recordRuntimeError(
        AiroPlaybackErrorCode.codecUnsupported,
      );

      expect(runtimeDecision.code, AiroEngineFallbackDecisionCode.ignoredLocked);
      expect(fallback.openCallCount, 0);
      expect(coordinator.activeEngine.backendKind, primary.backendKind);
    });

    test(
      'a real runtime codec error on the locked engine\'s states stream is '
      'observed automatically and never swaps',
      () async {
        final primary = _ScriptedPlaybackEngine(
          backendKind: AiroPlaybackBackendKind.videoPlayer,
          openScript: const [null],
        );
        final fallback = _ScriptedPlaybackEngine(
          backendKind: AiroPlaybackBackendKind.mpv,
          openScript: const [null],
        );
        final coordinator = AiroEngineFallbackCoordinator(
          primaryEngine: primary,
          fallbackEngine: fallback,
        );

        await coordinator.open(request());
        expect(coordinator.isLocked, isTrue);

        final observed = <AiroEngineFallbackDecision>[];
        final subscription = coordinator.runtimeDecisions.listen(
          observed.add,
        );

        // Simulate a real mid-playback decode failure arriving on the
        // engine's own states stream, not a direct recordRuntimeError call.
        primary.emitRuntimeError(AiroPlaybackErrorCode.decoderFailed);
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(observed, hasLength(1));
        expect(observed.single.code, AiroEngineFallbackDecisionCode.ignoredLocked);
        expect(fallback.openCallCount, 0);
        expect(coordinator.activeEngine.backendKind, primary.backendKind);
      },
    );

    test('dispose() tears down the currently active engine', () async {
      final primary = _ScriptedPlaybackEngine(
        backendKind: AiroPlaybackBackendKind.videoPlayer,
        openScript: const [null],
      );
      final coordinator = AiroEngineFallbackCoordinator(primaryEngine: primary);

      await coordinator.open(request());
      await coordinator.dispose();

      expect(primary.disposeCallCount, 1);
    });
  });
}

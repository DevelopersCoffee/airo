import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:platform_player/platform_player.dart';

import 'mpv/media_kit_mpv_player_facade.dart';
import 'mpv/mpv_player_facade.dart';

/// Concrete [AiroPlaybackEngine] backed by mpv (via media_kit).
///
/// Runs as the primary engine on Windows/Linux, and as the codec/decoder
/// fallback on Android-mobile / iOS / macOS. Never runs on Android TV (native
/// libs excluded from that flavor for size) or Web (media_kit's web target is
/// weak). PiP is not supported — mpv has no OS-level PiP.
///
/// The [MpvPlayerFacade] seam keeps tests off the native mpv path so
/// `flutter test` on the host is deterministic; production callers get the
/// default [MediaKitMpvPlayerFacade].
class MpvAiroPlaybackEngine implements AiroPlaybackEngine {
  MpvAiroPlaybackEngine({MpvPlayerFacade Function()? playerFactory})
    : _playerFactory = playerFactory ?? MediaKitMpvPlayerFacade.new;

  final MpvPlayerFacade Function() _playerFactory;

  MpvPlayerFacade? _player;
  AiroPlaybackState _state = AiroPlaybackState.idle(
    backendKind: AiroPlaybackBackendKind.mpv,
  );
  final StreamController<AiroPlaybackState> _stateController =
      StreamController<AiroPlaybackState>.broadcast();

  @override
  AiroPlaybackBackendKind get backendKind => AiroPlaybackBackendKind.mpv;

  @override
  Stream<AiroPlaybackState> get states => _stateController.stream;

  @override
  AiroPlaybackState get currentState => _state;

  @override
  Future<AiroPlaybackState> open(AiroMediaOpenRequest request) async {
    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.opening,
        request: request,
        position: request.startPosition,
      ),
    );

    await _disposePlayer();
    final player = _playerFactory();
    _player = player;

    late MpvOpenResult result;
    try {
      result = await player.open(request.sourceHandle.value);
    } on Object {
      return _fail(AiroPlaybackErrorCode.decoderFailed, 'open', request);
    }

    if (request.startPosition > Duration.zero) {
      await player.seek(request.startPosition);
    }
    await player.setVolume(_toFacadeVolume(_state.volume));
    await player.setRate(_state.playbackSpeed);

    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.open,
        request: request,
        position: request.startPosition,
        duration: result.duration,
        diagnostics: AiroPlaybackDiagnostics(
          backendId: backendKind.stableId,
          hardwareAccelerated: result.hardwareAccelerated,
        ),
      ),
    );
    return _state;
  }

  @override
  Future<AiroPlaybackState> play() async {
    await _player?.play();
    return _transition(AiroPlaybackEnginePhase.playing);
  }

  @override
  Future<AiroPlaybackState> pause() async {
    await _player?.pause();
    return _transition(AiroPlaybackEnginePhase.paused);
  }

  @override
  Future<AiroPlaybackState> stop() async {
    await _player?.stop();
    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.stopped,
        position: Duration.zero,
      ),
    );
    return _state;
  }

  @override
  Future<AiroPlaybackState> seek(Duration position) async {
    await _player?.seek(position);
    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.paused,
        position: position,
      ),
    );
    return _state;
  }

  @override
  Future<AiroPlaybackState> setVolume(double volume) async {
    final clamped = volume.clamp(0, 1).toDouble();
    await _player?.setVolume(_toFacadeVolume(clamped));
    _emit(_state.copyWith(volume: clamped));
    return _state;
  }

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async {
    await _player?.setRate(speed);
    _emit(_state.copyWith(playbackSpeed: speed));
    return _state;
  }

  @override
  Future<AiroPlaybackState> selectQuality(String qualityId) async {
    return _fail(
      AiroPlaybackErrorCode.qualityUnavailable,
      'selectQuality',
      _state.request,
    );
  }

  @override
  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async {
    return _fail(
      AiroPlaybackErrorCode.trackUnavailable,
      'selectTrack',
      _state.request,
    );
  }

  @override
  Future<AiroPlaybackDiagnostics> diagnostics() async {
    return _state.diagnostics ??
        AiroPlaybackDiagnostics(backendId: backendKind.stableId);
  }

  @override
  Future<AiroPlaybackState> enterPictureInPicture() async {
    return _fail(
      AiroPlaybackErrorCode.unsupportedOperation,
      'enterPictureInPicture',
      _state.request,
    );
  }

  @override
  Future<AiroPlaybackState> exitPictureInPicture() async {
    return _fail(
      AiroPlaybackErrorCode.unsupportedOperation,
      'exitPictureInPicture',
      _state.request,
    );
  }

  // media_kit's headless Player has no widget surface of its own — a video
  // view needs media_kit_video's VideoController/Video, which isn't a
  // dependency yet (adding it needs its own open-source-council review, same
  // as the exact-pinned media_kit/media_kit_libs_video versions above).
  // Tracked as CV-030 follow-up rather than added here.
  @override
  Widget? buildView() => null;

  @override
  Future<void> dispose() async {
    await _disposePlayer();
    await _stateController.close();
  }

  Future<void> _disposePlayer() async {
    final player = _player;
    _player = null;
    await player?.dispose();
  }

  AiroPlaybackState _transition(AiroPlaybackEnginePhase phase) {
    _emit(_state.copyWith(phase: phase));
    return _state;
  }

  AiroPlaybackState _fail(
    AiroPlaybackErrorCode code,
    String operation,
    AiroMediaOpenRequest? request,
  ) {
    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.failed,
        request: request,
        error: AiroPlaybackError(code: code, operation: operation),
      ),
    );
    return _state;
  }

  void _emit(AiroPlaybackState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  // media_kit's Player uses a 0..100 volume scale; the AiroPlaybackEngine
  // contract normalizes to 0..1.
  double _toFacadeVolume(double normalized) => normalized * 100.0;
}

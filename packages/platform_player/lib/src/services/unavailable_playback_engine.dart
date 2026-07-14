import 'dart:async';

import '../models/playback_engine_models.dart';
import 'airo_playback_engine.dart';

class UnavailableAiroPlaybackEngine implements AiroPlaybackEngine {
  UnavailableAiroPlaybackEngine({
    AiroPlaybackErrorCode code = AiroPlaybackErrorCode.backendUnavailable,
  }) : _errorCode = code,
       _state = AiroPlaybackState(
         backendKind: AiroPlaybackBackendKind.unavailable,
         phase: AiroPlaybackEnginePhase.unavailable,
         error: AiroPlaybackError(code: code),
       );

  final AiroPlaybackErrorCode _errorCode;
  final StreamController<AiroPlaybackState> _controller =
      StreamController<AiroPlaybackState>.broadcast();
  AiroPlaybackState _state;

  @override
  AiroPlaybackBackendKind get backendKind =>
      AiroPlaybackBackendKind.unavailable;

  @override
  Stream<AiroPlaybackState> get states => _controller.stream;

  @override
  AiroPlaybackState get currentState => _state;

  @override
  Future<AiroPlaybackState> open(AiroMediaOpenRequest request) async {
    return _unsupported('open', request: request);
  }

  @override
  Future<AiroPlaybackState> play() async => _unsupported('play');

  @override
  Future<AiroPlaybackState> pause() async => _unsupported('pause');

  @override
  Future<AiroPlaybackState> stop() async => _unsupported('stop');

  @override
  Future<AiroPlaybackState> seek(Duration position) async =>
      _unsupported('seek');

  @override
  Future<AiroPlaybackState> setVolume(double volume) async {
    return _unsupported('setVolume');
  }

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async {
    return _unsupported('setPlaybackSpeed');
  }

  @override
  Future<AiroPlaybackState> selectQuality(String qualityId) async {
    return _unsupported('selectQuality');
  }

  @override
  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async {
    return _unsupported('selectTrack');
  }

  @override
  Future<AiroPlaybackDiagnostics> diagnostics() async {
    return AiroPlaybackDiagnostics(
      backendId: AiroPlaybackBackendKind.unavailable.stableId,
      detailCodes: const ['backend_unavailable'],
    );
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  AiroPlaybackState _unsupported(
    String operation, {
    AiroMediaOpenRequest? request,
  }) {
    _state = AiroPlaybackState(
      backendKind: AiroPlaybackBackendKind.unavailable,
      phase: AiroPlaybackEnginePhase.unavailable,
      request: request ?? _state.request,
      error: AiroPlaybackError(code: _errorCode, operation: operation),
    );
    _controller.add(_state);
    return _state;
  }
}

import 'dart:async';

import '../models/playback_engine_models.dart';
import 'airo_playback_engine.dart';

class FakeAiroPlaybackEngine implements AiroPlaybackEngine {
  FakeAiroPlaybackEngine({
    List<AiroPlaybackQualityOption> qualityOptions = const [
      AiroPlaybackQualityOption(id: 'auto', label: 'Auto'),
      AiroPlaybackQualityOption(
        id: '720p',
        label: '720p',
        width: 1280,
        height: 720,
      ),
    ],
    List<AiroPlaybackTrackOption> tracks = const [
      AiroPlaybackTrackOption(
        id: 'audio-main',
        kind: AiroPlaybackTrackKind.audio,
        label: 'Main',
      ),
    ],
    AiroPlaybackDiagnostics? diagnostics,
  }) : _qualityOptions = List.unmodifiable(qualityOptions),
       _tracks = List.unmodifiable(tracks),
       _diagnostics =
           diagnostics ??
           AiroPlaybackDiagnostics(
             backendId: AiroPlaybackBackendKind.fake.stableId,
             detailCodes: const ['fake_engine'],
           ),
       _state = AiroPlaybackState.idle(
         backendKind: AiroPlaybackBackendKind.fake,
       );

  final StreamController<AiroPlaybackState> _controller =
      StreamController<AiroPlaybackState>.broadcast();
  final List<AiroPlaybackQualityOption> _qualityOptions;
  final List<AiroPlaybackTrackOption> _tracks;
  final AiroPlaybackDiagnostics _diagnostics;
  AiroPlaybackState _state;

  @override
  AiroPlaybackBackendKind get backendKind => AiroPlaybackBackendKind.fake;

  @override
  Stream<AiroPlaybackState> get states => _controller.stream;

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
    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.open,
        request: request,
        position: request.startPosition,
        qualityOptions: _qualityOptions,
        selectedQualityId:
            request.preferredQualityId ?? _qualityOptions.firstOrNull?.id,
        tracks: _tracks,
        selectedTrackIds: _initialTrackSelection(_tracks),
        diagnostics: _diagnostics,
      ),
    );
    return _state;
  }

  @override
  Future<AiroPlaybackState> play() async {
    return _transition(AiroPlaybackEnginePhase.playing);
  }

  @override
  Future<AiroPlaybackState> pause() async {
    return _transition(AiroPlaybackEnginePhase.paused);
  }

  @override
  Future<AiroPlaybackState> stop() async {
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
    _emit(_state.copyWith(phase: AiroPlaybackEnginePhase.seeking));
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
    _emit(_state.copyWith(volume: clamped));
    return _state;
  }

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async {
    _emit(_state.copyWith(playbackSpeed: speed));
    return _state;
  }

  @override
  Future<AiroPlaybackState> selectQuality(String qualityId) async {
    if (!_qualityOptions.any((option) => option.id == qualityId)) {
      return _fail(
        AiroPlaybackError(
          code: AiroPlaybackErrorCode.qualityUnavailable,
          operation: 'selectQuality',
        ),
      );
    }
    _emit(_state.copyWith(selectedQualityId: qualityId));
    return _state;
  }

  @override
  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async {
    if (!_tracks.any((track) => track.kind == kind && track.id == trackId)) {
      return _fail(
        AiroPlaybackError(
          code: AiroPlaybackErrorCode.trackUnavailable,
          operation: 'selectTrack',
        ),
      );
    }
    _emit(
      _state.copyWith(
        selectedTrackIds: {..._state.selectedTrackIds, kind: trackId},
      ),
    );
    return _state;
  }

  @override
  Future<AiroPlaybackDiagnostics> diagnostics() async => _diagnostics;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  Future<AiroPlaybackState> _transition(AiroPlaybackEnginePhase phase) async {
    _emit(_state.copyWith(phase: phase));
    return _state;
  }

  AiroPlaybackState _fail(AiroPlaybackError error) {
    _emit(_state.copyWith(phase: AiroPlaybackEnginePhase.failed, error: error));
    return _state;
  }

  void _emit(AiroPlaybackState state) {
    _state = state;
    _controller.add(state);
  }

  static Map<AiroPlaybackTrackKind, String> _initialTrackSelection(
    List<AiroPlaybackTrackOption> tracks,
  ) {
    final selected = <AiroPlaybackTrackKind, String>{};
    for (final track in tracks) {
      selected.putIfAbsent(track.kind, () => track.id);
    }
    return selected;
  }
}

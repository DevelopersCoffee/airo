import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_player/platform_player.dart';
import 'package:video_player/video_player.dart';

/// Concrete [AiroPlaybackEngine] wrapping the `video_player` package
/// (ExoPlayer / AVPlayer / `<video>` depending on platform). This is the
/// `videoPlayer` default engine the design's resolver picks for
/// Web/Android/Android TV/iOS/macOS.
///
/// Note: `AiroPlaybackSourceHandle.value` is expected to already be a
/// directly-openable URI by the time it reaches this engine. Resolving an
/// opaque handle token into a real URL (e.g. via a proxy/token layer) is out
/// of scope here — this engine only consumes the handle's value as-is.
class VideoPlayerAiroPlaybackEngine implements AiroPlaybackEngine {
  VideoPlayerController? _controller;
  AiroPlaybackState _state = AiroPlaybackState.idle(
    backendKind: AiroPlaybackBackendKind.videoPlayer,
  );
  final StreamController<AiroPlaybackState> _stateController =
      StreamController<AiroPlaybackState>.broadcast();

  @override
  AiroPlaybackBackendKind get backendKind => AiroPlaybackBackendKind.videoPlayer;

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

    await _disposeController();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(request.sourceHandle.value),
    );
    _controller = controller;

    try {
      await controller.initialize();
    } on TimeoutException {
      return _fail(
        AiroPlaybackErrorCode.networkUnavailable,
        'open',
        request,
      );
    } on PlatformException {
      return _fail(AiroPlaybackErrorCode.decoderFailed, 'open', request);
    } on Object {
      return _fail(AiroPlaybackErrorCode.backendUnavailable, 'open', request);
    }

    if (request.startPosition > Duration.zero) {
      await controller.seekTo(request.startPosition);
    }
    await controller.setVolume(_state.volume);
    await controller.setPlaybackSpeed(_state.playbackSpeed);
    controller.addListener(_onControllerValueChanged);

    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.open,
        request: request,
        position: request.startPosition,
        duration: controller.value.duration,
        diagnostics: AiroPlaybackDiagnostics(
          backendId: backendKind.stableId,
          hardwareAccelerated: true,
        ),
      ),
    );
    return _state;
  }

  /// Continuously mirrors `VideoPlayerController.value` into
  /// [AiroPlaybackState], fired on every native player update (position
  /// ticks, buffering transitions, errors) — not just on explicit method
  /// calls. This is what lets [AiroPlaybackEngine] consumers (progress bars,
  /// buffer-health monitors, live-edge detectors) observe playback without
  /// holding a reference to the raw controller.
  void _onControllerValueChanged() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;

    if (value.hasError) {
      _fail(AiroPlaybackErrorCode.decoderFailed, 'playback', _state.request);
      return;
    }

    final nextPhase = value.isBuffering
        ? AiroPlaybackEnginePhase.buffering
        : (_state.phase == AiroPlaybackEnginePhase.buffering
              ? AiroPlaybackEnginePhase.playing
              : _state.phase);

    _emit(
      _state.copyWith(
        phase: nextPhase,
        position: value.position,
        duration: value.duration,
        bufferedRanges: value.buffered
            .map(
              (r) => AiroPlaybackBufferedRange(start: r.start, end: r.end),
            )
            .toList(),
      ),
    );
  }

  @override
  Future<AiroPlaybackState> play() async {
    await _controller?.play();
    return _transition(AiroPlaybackEnginePhase.playing);
  }

  @override
  Future<AiroPlaybackState> pause() async {
    await _controller?.pause();
    return _transition(AiroPlaybackEnginePhase.paused);
  }

  @override
  Future<AiroPlaybackState> stop() async {
    await _controller?.pause();
    await _controller?.seekTo(Duration.zero);
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
    await _controller?.seekTo(position);
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
    await _controller?.setVolume(clamped);
    _emit(_state.copyWith(volume: clamped));
    return _state;
  }

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
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

  @override
  Widget? buildView() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    return SizedBox(
      width: controller.value.size.width,
      height: controller.value.size.height,
      child: VideoPlayer(controller),
    );
  }

  @override
  Future<void> dispose() async {
    await _disposeController();
    await _stateController.close();
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerValueChanged);
    await controller?.dispose();
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
}

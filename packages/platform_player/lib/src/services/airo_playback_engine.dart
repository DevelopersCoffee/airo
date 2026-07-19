import 'package:flutter/widgets.dart';

import '../models/playback_engine_models.dart';

abstract class AiroPlaybackEngine {
  AiroPlaybackBackendKind get backendKind;

  Stream<AiroPlaybackState> get states;

  AiroPlaybackState get currentState;

  Future<AiroPlaybackState> open(AiroMediaOpenRequest request);

  Future<AiroPlaybackState> play();

  Future<AiroPlaybackState> pause();

  Future<AiroPlaybackState> stop();

  Future<AiroPlaybackState> seek(Duration position);

  Future<AiroPlaybackState> setVolume(double volume);

  Future<AiroPlaybackState> setPlaybackSpeed(double speed);

  Future<AiroPlaybackState> selectQuality(String qualityId);

  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  });

  Future<AiroPlaybackDiagnostics> diagnostics();

  Future<AiroPlaybackState> enterPictureInPicture();

  Future<AiroPlaybackState> exitPictureInPicture();

  /// Returns the backend's native video-rendering widget, unscaled, or
  /// `null` when no frame surface is available yet (not opened, or a
  /// backend that has no visual surface of its own, e.g. [unavailable] or
  /// [fake]). Callers apply their own fit/aspect-ratio wrapper around the
  /// result rather than this method handling it.
  Widget? buildView();

  Future<void> dispose();
}

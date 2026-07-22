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

  Future<AiroPlaybackState> clearTrackSelection(AiroPlaybackTrackKind kind);

  Future<AiroPlaybackDiagnostics> diagnostics();

  Future<AiroPlaybackState> enterPictureInPicture();

  Future<AiroPlaybackState> exitPictureInPicture();

  /// Returns a widget rendering this engine's video surface, sized to the
  /// video's intrinsic dimensions (ready to be wrapped in a FittedBox by the
  /// caller for aspect-ratio fitting). Returns null when there is nothing
  /// local to render: not yet opened, no local video surface for this
  /// backend (e.g. cast), or the backend doesn't support rendering yet.
  Widget? buildView();

  Future<void> dispose();
}

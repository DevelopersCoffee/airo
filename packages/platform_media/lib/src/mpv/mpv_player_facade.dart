import 'dart:async';

/// Thin seam over the concrete mpv player library (media_kit today). Everything
/// the [MpvAiroPlaybackEngine] needs at runtime, and nothing more, so tests can
/// substitute a fake without pulling in native mpv/libmpv.
///
/// Keep this surface intentionally small: engine responsibilities (state
/// machine, error taxonomy translation, source-handle handling) live in the
/// engine adapter, not here.
abstract class MpvPlayerFacade {
  /// Load a source URL, sending [httpHeaders] with the request. Returns the
  /// observed post-open metadata (duration, hardware-accel flag). Throw an
  /// [Object] to signal a decoder/codec failure — the engine adapter maps
  /// that to a typed [AiroPlaybackErrorCode.decoderFailed].
  ///
  /// [httpHeaders] carries the playlist's own `http-user-agent`/referrer
  /// attributes. Providers that require them answer 403 without them.
  Future<MpvOpenResult> open(
    String url, {
    Map<String, String> httpHeaders = const {},
  });

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> seek(Duration duration);

  /// Volume in the underlying player's native range (media_kit uses 0..100).
  Future<void> setVolume(double value);

  Future<void> setRate(double value);

  /// Returns only bounded, non-sensitive playback properties.
  Future<MpvDiagnosticSnapshot> diagnostics();

  Future<void> dispose();
}

class MpvOpenResult {
  MpvOpenResult({required this.duration, required this.hardwareAccelerated});

  final Duration duration;
  final bool hardwareAccelerated;
}

class MpvDiagnosticSnapshot {
  const MpvDiagnosticSnapshot({
    this.videoCodec,
    this.videoWidth,
    this.videoHeight,
    this.framesPerSecond,
    this.droppedFrames,
    this.audioCodec,
    this.audioBitrateKbps,
    this.audioChannels,
    this.cacheDuration,
  });

  final String? videoCodec;
  final int? videoWidth;
  final int? videoHeight;
  final double? framesPerSecond;
  final int? droppedFrames;
  final String? audioCodec;
  final int? audioBitrateKbps;
  final int? audioChannels;
  final Duration? cacheDuration;
}

import '../models/spatial_audio_models.dart';

/// Post-decode PCM processor seam for Spatial Mode (#2080 / #2082).
///
/// v1 spike ships an identity implementation only; real binaural DSP replaces
/// [process] on the native side without changing this Dart contract.
abstract class AiroSpatialPcmProcessor {
  AiroPcmAudioBuffer process(AiroPcmAudioBuffer input);

  int get framesProcessed;
}

/// Copies PCM samples unchanged — proves the tap path without DSP latency.
class AiroIdentitySpatialPcmProcessor implements AiroSpatialPcmProcessor {
  int _framesProcessed = 0;

  @override
  int get framesProcessed => _framesProcessed;

  @override
  AiroPcmAudioBuffer process(AiroPcmAudioBuffer input) {
    _framesProcessed += input.frameCount;
    return AiroPcmAudioBuffer(
      sampleRateHz: input.sampleRateHz,
      channelCount: input.channelCount,
      encoding: input.encoding,
      samples: input.samples,
      presentationTimeUs: input.presentationTimeUs,
    );
  }

  void resetDiagnostics() {
    _framesProcessed = 0;
  }
}

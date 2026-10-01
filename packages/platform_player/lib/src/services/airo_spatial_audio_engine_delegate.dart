import '../models/playback_engine_models.dart';
import '../models/spatial_audio_models.dart';
import 'airo_spatial_audio_platform.dart';
import 'airo_spatial_audio_tap_resolver.dart';
import 'spatial_audio_pcm_processor.dart';

/// Shared Original/Spatial mode state for [AiroPlaybackEngine] implementations.
class AiroSpatialAudioEngineDelegate {
  AiroSpatialAudioEngineDelegate({
    required this.backendKind,
    AiroSpatialPcmProcessor? processor,
    Future<AiroSpatialAudioTapStatus> Function()? nativeTapProbe,
  }) : _processor = processor ?? AiroIdentitySpatialPcmProcessor(),
       _nativeTapProbe = nativeTapProbe;

  final AiroPlaybackBackendKind backendKind;
  final AiroSpatialPcmProcessor _processor;
  final Future<AiroSpatialAudioTapStatus> Function()? _nativeTapProbe;

  AiroSpatialAudioMode mode = AiroSpatialAudioMode.original;

  AiroSpatialAudioTapStatus expectedTapStatus() {
    return AiroSpatialAudioTapResolver.expectedForBackend(backendKind);
  }

  Future<AiroSpatialAudioTapStatus> queryTapStatus() async {
    if (_nativeTapProbe != null) {
      return _nativeTapProbe!();
    }
    final expected = expectedTapStatus();
    if (expected.tapKind == AiroSpatialAudioTapKind.pcmAfterDecode &&
        backendKind == AiroPlaybackBackendKind.fake) {
      return AiroSpatialAudioTapStatus(
        backendKind: backendKind,
        tapKind: AiroSpatialAudioTapKind.pcmAfterDecode,
        detailCodes: expected.detailCodes,
        processorInstalled: true,
        framesProcessed: _processor.framesProcessed,
      );
    }
    return expected;
  }

  Future<AiroSpatialAudioMode> setMode(AiroSpatialAudioMode newMode) async {
    mode = newMode;
    if (backendKind == AiroPlaybackBackendKind.media3) {
      await AiroSpatialAudioPlatform.setSpatialAudioMode(newMode);
    }
    return mode;
  }

  /// Exercises the in-process identity processor (fake/tests and Dart-only
  /// simulations). Real IPTV playback uses the native Media3 chain on TV.
  AiroPcmAudioBuffer processPcm(AiroPcmAudioBuffer input) {
    if (mode == AiroSpatialAudioMode.original) {
      return input;
    }
    return _processor.process(input);
  }
}

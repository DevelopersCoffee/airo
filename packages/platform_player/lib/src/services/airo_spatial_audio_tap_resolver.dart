import '../models/playback_engine_models.dart';
import '../models/spatial_audio_models.dart';

/// Maps [AiroPlaybackBackendKind] to expected PCM tap posture for design
/// notes and engine defaults (not a runtime probe of the native stack).
class AiroSpatialAudioTapResolver {
  const AiroSpatialAudioTapResolver._();

  static AiroSpatialAudioTapStatus expectedForBackend(
    AiroPlaybackBackendKind backendKind,
  ) {
    switch (backendKind) {
      case AiroPlaybackBackendKind.media3:
        return AiroSpatialAudioTapStatus(
          backendKind: backendKind,
          tapKind: AiroSpatialAudioTapKind.pcmAfterDecode,
          detailCodes: const [
            'media3_default_audio_sink',
            'identity_processor_chain',
          ],
          processorInstalled: true,
        );
      case AiroPlaybackBackendKind.videoPlayer:
        return AiroSpatialAudioTapStatus(
          backendKind: backendKind,
          tapKind: AiroSpatialAudioTapKind.opaqueBackend,
          detailCodes: const [
            'flutter_video_player_plugin',
            'query_native_for_tv_fork',
            'tv_pubspec_video_player_android_fork',
          ],
        );
      case AiroPlaybackBackendKind.mpv:
      case AiroPlaybackBackendKind.libVlc:
        return AiroSpatialAudioTapStatus(
          backendKind: backendKind,
          tapKind: AiroSpatialAudioTapKind.opaqueBackend,
          detailCodes: const ['native_player_no_pcm_hook_in_dart_layer'],
        );
      case AiroPlaybackBackendKind.cast:
        return AiroSpatialAudioTapStatus(
          backendKind: backendKind,
          tapKind: AiroSpatialAudioTapKind.unavailable,
          detailCodes: const ['remote_receiver_audio'],
        );
      case AiroPlaybackBackendKind.fake:
        return AiroSpatialAudioTapStatus(
          backendKind: backendKind,
          tapKind: AiroSpatialAudioTapKind.pcmAfterDecode,
          detailCodes: const ['in_process_identity_processor'],
          processorInstalled: true,
        );
      case AiroPlaybackBackendKind.unavailable:
        return AiroSpatialAudioTapStatus(
          backendKind: backendKind,
          tapKind: AiroSpatialAudioTapKind.unavailable,
          detailCodes: const ['backend_unavailable'],
        );
    }
  }
}

import 'package:equatable/equatable.dart';

import 'playback_engine_models.dart';

enum AiroPlaybackPlatform {
  androidMobile('android_mobile'),
  androidTv('android_tv'),
  ios('ios'),
  macos('macos'),
  windows('windows'),
  linux('linux'),
  web('web'),
  unknown('unknown');

  const AiroPlaybackPlatform(this.stableId);

  final String stableId;
}

class AiroPlaybackDeviceProfile extends Equatable {
  const AiroPlaybackDeviceProfile({required this.platform});

  final AiroPlaybackPlatform platform;

  @override
  List<Object?> get props => [platform];
}

class AiroPlaybackEngineResolver {
  const AiroPlaybackEngineResolver();

  AiroPlaybackBackendKind resolve(AiroPlaybackDeviceProfile profile) {
    return switch (profile.platform) {
      AiroPlaybackPlatform.web => AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.androidMobile => AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.androidTv => AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.ios => AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.macos => AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.windows => AiroPlaybackBackendKind.mpv,
      AiroPlaybackPlatform.linux => AiroPlaybackBackendKind.mpv,
      AiroPlaybackPlatform.unknown => AiroPlaybackBackendKind.unavailable,
    };
  }
}

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

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

/// Determines the running [AiroPlaybackPlatform] from Flutter's own
/// platform signals. Android TV can't be distinguished from Android mobile
/// via [defaultTargetPlatform] alone — the caller must supply [isAndroidTv]
/// from its own TV-detection (e.g. a build-flavor flag or native form-factor
/// check); this function only maps what Flutter already knows.
AiroPlaybackPlatform currentAiroPlaybackPlatform({bool isAndroidTv = false}) {
  if (kIsWeb) return AiroPlaybackPlatform.web;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android =>
      isAndroidTv
          ? AiroPlaybackPlatform.androidTv
          : AiroPlaybackPlatform.androidMobile,
    TargetPlatform.iOS => AiroPlaybackPlatform.ios,
    TargetPlatform.macOS => AiroPlaybackPlatform.macos,
    TargetPlatform.windows => AiroPlaybackPlatform.windows,
    TargetPlatform.linux => AiroPlaybackPlatform.linux,
    TargetPlatform.fuchsia => AiroPlaybackPlatform.unknown,
  };
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

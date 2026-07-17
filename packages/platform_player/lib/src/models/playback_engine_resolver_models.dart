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

/// Small value type the [AiroPlaybackEngineResolver.resolveFallback] gate
/// consults. Kept in `platform_player` (not `platform_media`) to avoid a
/// circular dependency — callers construct it from their own device profile
/// source (typically `AiroMediaDeviceCapabilityProfile` in `platform_media`).
class AiroPlaybackFallbackDeviceHints extends Equatable {
  const AiroPlaybackFallbackDeviceHints({
    this.totalRamMb,
    this.hasHardwareH264Decoder,
  });

  /// Total physical RAM in MB. `null` means "unknown" — the gate assumes the
  /// device is capable in that case (do not punish devices whose capability
  /// probe hasn't run yet). If below [kMpvFallbackMinRamMb], the mpv fallback
  /// is disabled: software decode there would OOM or crawl, so a doomed second
  /// `open()` attempt is skipped in favor of a clean typed error.
  final int? totalRamMb;

  /// Whether the OS media stack advertises a hardware H.264 decoder. A device
  /// missing hardware H.264 is a strong signal it cannot sustain mpv's
  /// software decode either — gate the fallback off in that case.
  final bool? hasHardwareH264Decoder;

  @override
  List<Object?> get props => [totalRamMb, hasHardwareH264Decoder];
}

/// Fallback gate threshold. 2GB RAM is roughly the floor at which mpv's
/// software H.264/HEVC decode has a chance to keep up; below that, the
/// primary→fallback swap wastes battery and buffers on a doomed attempt.
/// Callers may override by passing a lower/higher value from their profile.
const int kMpvFallbackMinRamMb = 2048;

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

  /// Picks the engine used by the fallback coordinator when the primary emits
  /// a codec/decoder failure. Returns `null` when no meaningful fallback
  /// exists on this platform *or* the device profile is too weak to make a
  /// second attempt worthwhile — that null is the signal
  /// [AiroEngineFallbackCoordinator] uses to degrade cleanly to
  /// "primary only; codec failure → typed error."
  ///
  /// Ordering matters: platform bundling wins over device hints. mpv is not
  /// shipped on Android TV or Web at all, so even a high-RAM Android TV
  /// returns null.
  AiroPlaybackBackendKind? resolveFallback(
    AiroPlaybackDeviceProfile profile, {
    AiroPlaybackFallbackDeviceHints hints =
        const AiroPlaybackFallbackDeviceHints(),
  }) {
    // mpv is not bundled on TV (storage-starved) or Web (weak backend).
    // Windows/Linux already run mpv as primary, so it can't also fall back.
    switch (profile.platform) {
      case AiroPlaybackPlatform.androidTv:
      case AiroPlaybackPlatform.web:
      case AiroPlaybackPlatform.windows:
      case AiroPlaybackPlatform.linux:
      case AiroPlaybackPlatform.unknown:
        return null;
      case AiroPlaybackPlatform.androidMobile:
      case AiroPlaybackPlatform.ios:
      case AiroPlaybackPlatform.macos:
        break;
    }

    // Device-capability gate — the ONLY place device awareness lives.
    final ram = hints.totalRamMb;
    if (ram != null && ram < kMpvFallbackMinRamMb) {
      return null;
    }
    if (hints.hasHardwareH264Decoder == false) {
      return null;
    }
    return AiroPlaybackBackendKind.mpv;
  }
}

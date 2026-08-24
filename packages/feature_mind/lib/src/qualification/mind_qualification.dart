import 'package:flutter/foundation.dart';

import '../capture/domain/live_transcription_support.dart';

/// Explicit product qualification states for Airo Mind capabilities.
///
/// These are ordered from least to most qualified. A capability is only
/// [production] when its declared ceiling AND the runtime's actual reported
/// capability both allow it — a feature flag alone can never reach production
/// (see [MindQualificationResolver]). This mirrors the qualification policy in
/// `docs/features/airo-mind/production-qualification.md`.
enum MindQualificationState {
  /// The capability is not available on the platform (e.g. no native FFI on
  /// web, or the platform build is not wired).
  unsupported,

  /// Implemented but not qualified: no measured gates, may change or break.
  experimental,

  /// Qualified for opt-in preview use with a disclaimer; not the default and
  /// not backed by the full production gate suite.
  preview,

  /// Backed by passing release gates, benchmarks, and platform validation.
  production;

  /// Monotonic rank used for ordering/capping. Higher is more qualified.
  int get rank => index;

  bool isAtLeast(MindQualificationState other) => rank >= other.rank;

  /// Returns the lower (less qualified) of the two states. Used to cap a
  /// declared ceiling down to what the runtime can actually deliver.
  MindQualificationState atMost(MindQualificationState ceiling) =>
      rank <= ceiling.rank ? this : ceiling;

  String get label => switch (this) {
    MindQualificationState.unsupported => 'Unsupported',
    MindQualificationState.experimental => 'Experimental',
    MindQualificationState.preview => 'Preview',
    MindQualificationState.production => 'Production',
  };
}

/// The capability rows of the Airo Mind qualification matrix (spec §23).
enum MindCapability {
  recording,
  offlineStt,
  liveStt,
  stabilization,
  vocabulary,
  liveSpeakerActivity,
  finalDiarization,
  liveConversationIr,
  liveInsights,
  postRecordingIr,
  search,
  memory;

  String get label => switch (this) {
    MindCapability.recording => 'Recording',
    MindCapability.offlineStt => 'Offline STT',
    MindCapability.liveStt => 'Live STT',
    MindCapability.stabilization => 'Stabilization',
    MindCapability.vocabulary => 'Vocabulary',
    MindCapability.liveSpeakerActivity => 'Live speaker activity',
    MindCapability.finalDiarization => 'Final diarization',
    MindCapability.liveConversationIr => 'Live Conversation IR',
    MindCapability.liveInsights => 'Live insights',
    MindCapability.postRecordingIr => 'Post-recording IR',
    MindCapability.search => 'Search',
    MindCapability.memory => 'Memory',
  };

  /// Capabilities that depend on the live processing pipeline being active on
  /// the host. When the host cannot run the live pipeline these are capped to
  /// [MindQualificationState.unsupported] regardless of their declared ceiling.
  bool get requiresLivePipeline => switch (this) {
    MindCapability.liveStt ||
    MindCapability.stabilization ||
    MindCapability.liveSpeakerActivity ||
    MindCapability.liveConversationIr ||
    MindCapability.liveInsights => true,
    _ => false,
  };
}

/// Platforms the qualification matrix is defined over. Desktop collapses
/// macOS/Linux/Windows because Airo Mind treats them as one qualification
/// target (the native engines are built for all three).
enum MindPlatform {
  desktop,
  android,
  ios,
  web;

  String get label => switch (this) {
    MindPlatform.desktop => 'Desktop',
    MindPlatform.android => 'Android',
    MindPlatform.ios => 'iOS',
    MindPlatform.web => 'Web',
  };
}

/// Resolves the current host to a [MindPlatform]. [platform] and [isWeb] are
/// injectable so the matrix can be evaluated for any target in tests.
MindPlatform resolveMindPlatform({TargetPlatform? platform, bool? isWeb}) {
  if (isWeb ?? kIsWeb) return MindPlatform.web;
  final host = platform ?? defaultTargetPlatform;
  return switch (host) {
    TargetPlatform.android => MindPlatform.android,
    TargetPlatform.iOS => MindPlatform.ios,
    TargetPlatform.macOS ||
    TargetPlatform.linux ||
    TargetPlatform.windows => MindPlatform.desktop,
    TargetPlatform.fuchsia => MindPlatform.web,
  };
}

/// The declared qualification ceilings per capability and platform.
///
/// A "ceiling" is the *most* qualified state a capability may report on a
/// platform. The resolved state is always capped down to what the runtime can
/// actually deliver ([MindQualificationResolver]). The default ceilings encode
/// the honest current state established by the Phase 1 audit: no capability is
/// declared [MindQualificationState.production] yet, so the resolved matrix can
/// never claim production until the ceilings are raised from test evidence.
@immutable
class MindQualificationMatrix {
  const MindQualificationMatrix(this._ceilings);

  final Map<MindPlatform, Map<MindCapability, MindQualificationState>>
  _ceilings;

  /// The declared ceiling for [capability] on [platform]. Defaults to
  /// [MindQualificationState.unsupported] when a cell is not listed.
  MindQualificationState declaredCeiling(
    MindCapability capability,
    MindPlatform platform,
  ) => _ceilings[platform]?[capability] ?? MindQualificationState.unsupported;

  /// The honest current-state matrix (spec §23). Desktop is the first
  /// qualification target and tops out at [MindQualificationState.preview];
  /// Android live intelligence is not on the native fan-out path yet; iOS Mind
  /// is not wired natively; web has no offline engines.
  factory MindQualificationMatrix.current() {
    const s = MindQualificationState.unsupported;
    const e = MindQualificationState.experimental;
    const p = MindQualificationState.preview;
    return const MindQualificationMatrix({
      MindPlatform.desktop: {
        MindCapability.recording: p,
        MindCapability.offlineStt: p,
        MindCapability.liveStt: p,
        MindCapability.stabilization: p,
        MindCapability.vocabulary: p,
        MindCapability.liveSpeakerActivity: p,
        MindCapability.finalDiarization: p,
        MindCapability.liveConversationIr: e,
        MindCapability.liveInsights: e,
        MindCapability.postRecordingIr: p,
        MindCapability.search: p,
        MindCapability.memory: p,
      },
      MindPlatform.android: {
        MindCapability.recording: p,
        MindCapability.offlineStt: p,
        MindCapability.liveStt: s,
        MindCapability.stabilization: s,
        MindCapability.vocabulary: p,
        MindCapability.liveSpeakerActivity: s,
        MindCapability.finalDiarization: p,
        MindCapability.liveConversationIr: s,
        MindCapability.liveInsights: s,
        MindCapability.postRecordingIr: p,
        MindCapability.search: p,
        MindCapability.memory: p,
      },
      // iOS native Mind engines are not wired (feature_mind omits the iOS
      // platform); everything is unsupported until that build path exists.
      MindPlatform.ios: {},
      // Web has no dart:ffi; the offline engines are stubbed out.
      MindPlatform.web: {},
    });
  }
}

/// Actual runtime capability signals reported by the host, used to cap declared
/// ceilings down to what can really run. This is the "actual capability
/// configuration" the product derives states from (spec §24) — never a raw
/// feature flag.
@immutable
class MindRuntimeCapabilitySignals {
  const MindRuntimeCapabilitySignals({
    required this.nativeBridgeAvailable,
    required this.recordingSupported,
    required this.liveHostSupported,
  });

  /// The FFI bridge to the native engines loaded (whisper/llama cdylibs).
  /// When false, every offline capability collapses to unsupported.
  final bool nativeBridgeAvailable;

  /// A file recorder is available on this host.
  final bool recordingSupported;

  /// The live processing pipeline can run on this host (currently desktop
  /// only, via [liveTranscriptionPreviewSupported]).
  final bool liveHostSupported;

  /// Derives signals from the host platform using the existing support gates.
  /// [nativeBridgeAvailable] must be provided by the caller because it depends
  /// on whether the engine libraries actually loaded at runtime.
  factory MindRuntimeCapabilitySignals.forHost({
    required bool nativeBridgeAvailable,
    TargetPlatform? platform,
    bool? isWeb,
  }) {
    final web = isWeb ?? kIsWeb;
    return MindRuntimeCapabilitySignals(
      nativeBridgeAvailable: nativeBridgeAvailable && !web,
      recordingSupported: !web,
      liveHostSupported:
          !web && liveTranscriptionPreviewSupported(platform: platform),
    );
  }
}

/// The resolved qualification of a single capability on a platform.
@immutable
class MindCapabilityQualification {
  const MindCapabilityQualification({
    required this.capability,
    required this.platform,
    required this.declaredCeiling,
    required this.state,
  });

  final MindCapability capability;
  final MindPlatform platform;
  final MindQualificationState declaredCeiling;

  /// The effective state = min(declaredCeiling, runtime capability ceiling).
  final MindQualificationState state;

  bool get isProduction => state == MindQualificationState.production;

  /// Whether the capability should be surfaced to the user at all.
  bool get isAvailable => state != MindQualificationState.unsupported;
}

/// Resolves declared ceilings against actual runtime signals so the UI only
/// exposes what the runtime truly supports (spec §19, §24).
class MindQualificationResolver {
  MindQualificationResolver({MindQualificationMatrix? matrix})
    : _matrix = matrix ?? MindQualificationMatrix.current();

  final MindQualificationMatrix _matrix;

  /// The most-qualified state the runtime signals permit for [capability],
  /// before applying the declared ceiling.
  MindQualificationState _runtimeCeiling(
    MindCapability capability,
    MindPlatform platform,
    MindRuntimeCapabilitySignals signals,
  ) {
    // No native engines -> nothing offline works.
    if (platform == MindPlatform.web || !signals.nativeBridgeAvailable) {
      return MindQualificationState.unsupported;
    }
    if (capability == MindCapability.recording && !signals.recordingSupported) {
      return MindQualificationState.unsupported;
    }
    if (capability.requiresLivePipeline && !signals.liveHostSupported) {
      return MindQualificationState.unsupported;
    }
    // The runtime can run it; the declared ceiling decides how far.
    return MindQualificationState.production;
  }

  MindCapabilityQualification resolve(
    MindCapability capability,
    MindPlatform platform,
    MindRuntimeCapabilitySignals signals,
  ) {
    final declared = _matrix.declaredCeiling(capability, platform);
    final runtime = _runtimeCeiling(capability, platform, signals);
    return MindCapabilityQualification(
      capability: capability,
      platform: platform,
      declaredCeiling: declared,
      state: declared.atMost(runtime),
    );
  }

  /// Resolves every capability for [platform] against [signals].
  Map<MindCapability, MindCapabilityQualification> resolveMatrix(
    MindPlatform platform,
    MindRuntimeCapabilitySignals signals,
  ) => {
    for (final capability in MindCapability.values)
      capability: resolve(capability, platform, signals),
  };
}

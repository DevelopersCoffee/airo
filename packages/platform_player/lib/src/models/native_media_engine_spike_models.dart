import 'package:equatable/equatable.dart';

import 'playback_engine_models.dart';

const String kAiroNativeMediaEngineSpikeSchemaVersion = '1.0.0';

enum AiroPlaybackSurfaceMode {
  texture('texture'),
  platformView('platform_view'),
  externalReceiver('external_receiver'),
  headless('headless');

  const AiroPlaybackSurfaceMode(this.stableId);

  final String stableId;
}

enum AiroNativeMediaEngineFeature {
  hardwareDecode('hardware_decode'),
  softwareDecodeFallback('software_decode_fallback'),
  decoderDiagnostics('decoder_diagnostics'),
  bufferDiagnostics('buffer_diagnostics'),
  subtitleTracks('subtitle_tracks'),
  audioTracks('audio_tracks'),
  adaptiveStreaming('adaptive_streaming'),
  lowLatencyLive('low_latency_live'),
  protectedPlayback('protected_playback');

  const AiroNativeMediaEngineFeature(this.stableId);

  final String stableId;
}

enum AiroNativeMediaEngineMaturity {
  stable('stable'),
  candidate('candidate'),
  experimental('experimental'),
  blocked('blocked');

  const AiroNativeMediaEngineMaturity(this.stableId);

  final String stableId;
}

enum AiroNativeMediaEngineBlockerCode {
  accepted('accepted'),
  backendBlocked('backend_blocked'),
  experimentalBackendNotAllowed('experimental_backend_not_allowed'),
  unsupportedMediaKind('unsupported_media_kind'),
  missingSurfaceMode('missing_surface_mode'),
  missingRequiredFeature('missing_required_feature'),
  missingDiagnostics('missing_diagnostics'),
  missingHardwareDecode('missing_hardware_decode'),
  missingDecoderFallback('missing_decoder_fallback');

  const AiroNativeMediaEngineBlockerCode(this.stableId);

  final String stableId;
}

class AiroNativeMediaEngineCandidate extends Equatable {
  AiroNativeMediaEngineCandidate({
    required this.candidateId,
    required this.backendKind,
    required this.maturity,
    required Set<AiroPlaybackMediaKind> supportedMediaKinds,
    required Set<AiroPlaybackSurfaceMode> surfaceModes,
    required Set<AiroNativeMediaEngineFeature> features,
    this.schemaVersion = kAiroNativeMediaEngineSpikeSchemaVersion,
  }) : supportedMediaKinds = Set.unmodifiable(supportedMediaKinds),
       surfaceModes = Set.unmodifiable(surfaceModes),
       features = Set.unmodifiable(features);

  final String schemaVersion;
  final String candidateId;
  final AiroPlaybackBackendKind backendKind;
  final AiroNativeMediaEngineMaturity maturity;
  final Set<AiroPlaybackMediaKind> supportedMediaKinds;
  final Set<AiroPlaybackSurfaceMode> surfaceModes;
  final Set<AiroNativeMediaEngineFeature> features;

  bool supportsAllMediaKinds(Set<AiroPlaybackMediaKind> mediaKinds) =>
      supportedMediaKinds.containsAll(mediaKinds);

  bool supportsAllSurfaceModes(Set<AiroPlaybackSurfaceMode> modes) =>
      surfaceModes.containsAll(modes);

  bool supportsAllFeatures(
    Set<AiroNativeMediaEngineFeature> requiredFeatures,
  ) => features.containsAll(requiredFeatures);

  @override
  String toString() {
    return 'AiroNativeMediaEngineCandidate('
        'candidateId: $candidateId, '
        'backendKind: ${backendKind.stableId}, '
        'maturity: ${maturity.stableId}, '
        'supportedMediaKinds: ${supportedMediaKinds.map((kind) => kind.stableId).toList()}, '
        'surfaceModes: ${surfaceModes.map((mode) => mode.stableId).toList()}, '
        'features: ${features.map((feature) => feature.stableId).toList()}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    candidateId,
    backendKind,
    maturity,
    supportedMediaKinds,
    surfaceModes,
    features,
  ];
}

class AiroNativeMediaEngineSpikeRequest extends Equatable {
  AiroNativeMediaEngineSpikeRequest({
    required this.requestId,
    required Set<AiroPlaybackMediaKind> requiredMediaKinds,
    required Set<AiroPlaybackSurfaceMode> requiredSurfaceModes,
    required Set<AiroNativeMediaEngineFeature> requiredFeatures,
    this.allowExperimentalBackends = false,
    this.requiresHardwareDecode = true,
    this.requiresDecoderFallback = true,
    this.requiresDiagnostics = true,
    this.schemaVersion = kAiroNativeMediaEngineSpikeSchemaVersion,
  }) : requiredMediaKinds = Set.unmodifiable(requiredMediaKinds),
       requiredSurfaceModes = Set.unmodifiable(requiredSurfaceModes),
       requiredFeatures = Set.unmodifiable(requiredFeatures);

  final String schemaVersion;
  final String requestId;
  final Set<AiroPlaybackMediaKind> requiredMediaKinds;
  final Set<AiroPlaybackSurfaceMode> requiredSurfaceModes;
  final Set<AiroNativeMediaEngineFeature> requiredFeatures;
  final bool allowExperimentalBackends;
  final bool requiresHardwareDecode;
  final bool requiresDecoderFallback;
  final bool requiresDiagnostics;

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    requiredMediaKinds,
    requiredSurfaceModes,
    requiredFeatures,
    allowExperimentalBackends,
    requiresHardwareDecode,
    requiresDecoderFallback,
    requiresDiagnostics,
  ];
}

class AiroNativeMediaEngineEvaluation extends Equatable {
  AiroNativeMediaEngineEvaluation({
    required this.requestId,
    required this.candidateId,
    required List<AiroNativeMediaEngineBlockerCode> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final String requestId;
  final String candidateId;
  final List<AiroNativeMediaEngineBlockerCode> blockers;

  bool get accepted =>
      blockers.length == 1 &&
      blockers.single == AiroNativeMediaEngineBlockerCode.accepted;

  @override
  List<Object?> get props => [requestId, candidateId, blockers];
}

class AiroNativeMediaEngineSpikePolicy {
  const AiroNativeMediaEngineSpikePolicy();

  AiroNativeMediaEngineEvaluation evaluate({
    required AiroNativeMediaEngineCandidate candidate,
    required AiroNativeMediaEngineSpikeRequest request,
  }) {
    final blockers = <AiroNativeMediaEngineBlockerCode>[];
    if (candidate.maturity == AiroNativeMediaEngineMaturity.blocked) {
      blockers.add(AiroNativeMediaEngineBlockerCode.backendBlocked);
    }
    if (candidate.maturity == AiroNativeMediaEngineMaturity.experimental &&
        !request.allowExperimentalBackends) {
      blockers.add(
        AiroNativeMediaEngineBlockerCode.experimentalBackendNotAllowed,
      );
    }
    if (!candidate.supportsAllMediaKinds(request.requiredMediaKinds)) {
      blockers.add(AiroNativeMediaEngineBlockerCode.unsupportedMediaKind);
    }
    if (!candidate.supportsAllSurfaceModes(request.requiredSurfaceModes)) {
      blockers.add(AiroNativeMediaEngineBlockerCode.missingSurfaceMode);
    }
    if (!candidate.supportsAllFeatures(request.requiredFeatures)) {
      blockers.add(AiroNativeMediaEngineBlockerCode.missingRequiredFeature);
    }
    if (request.requiresDiagnostics &&
        (!candidate.features.contains(
              AiroNativeMediaEngineFeature.decoderDiagnostics,
            ) ||
            !candidate.features.contains(
              AiroNativeMediaEngineFeature.bufferDiagnostics,
            ))) {
      blockers.add(AiroNativeMediaEngineBlockerCode.missingDiagnostics);
    }
    if (request.requiresHardwareDecode &&
        !candidate.features.contains(
          AiroNativeMediaEngineFeature.hardwareDecode,
        )) {
      blockers.add(AiroNativeMediaEngineBlockerCode.missingHardwareDecode);
    }
    if (request.requiresDecoderFallback &&
        !candidate.features.contains(
          AiroNativeMediaEngineFeature.softwareDecodeFallback,
        )) {
      blockers.add(AiroNativeMediaEngineBlockerCode.missingDecoderFallback);
    }

    return AiroNativeMediaEngineEvaluation(
      requestId: request.requestId,
      candidateId: candidate.candidateId,
      blockers: blockers.isEmpty
          ? const [AiroNativeMediaEngineBlockerCode.accepted]
          : blockers,
    );
  }
}

abstract interface class AiroNativeMediaEngineCandidateRegistry {
  List<AiroNativeMediaEngineCandidate> candidates();
}

class AiroNoOpNativeMediaEngineCandidateRegistry
    implements AiroNativeMediaEngineCandidateRegistry {
  const AiroNoOpNativeMediaEngineCandidateRegistry();

  @override
  List<AiroNativeMediaEngineCandidate> candidates() => const [];
}

class AiroFakeNativeMediaEngineCandidateRegistry
    implements AiroNativeMediaEngineCandidateRegistry {
  AiroFakeNativeMediaEngineCandidateRegistry({
    required List<AiroNativeMediaEngineCandidate> candidates,
  }) : _candidates = List.unmodifiable(candidates);

  final List<AiroNativeMediaEngineCandidate> _candidates;

  @override
  List<AiroNativeMediaEngineCandidate> candidates() => _candidates;
}

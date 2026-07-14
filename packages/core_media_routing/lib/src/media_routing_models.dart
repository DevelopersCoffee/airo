import 'dart:async';

import 'package:equatable/equatable.dart';

const String kAiroMediaRoutingSchemaVersion = '1.0.0';

enum AiroMediaRouteIntent {
  play('play'),
  resume('resume'),
  handoff('handoff'),
  preview('preview');

  const AiroMediaRouteIntent(this.stableId);

  final String stableId;
}

enum AiroMediaRouteKind {
  receiverDirect('receiver_direct'),
  lanDirect('lan_direct'),
  serverDirect('server_direct'),
  desktopRelay('desktop_relay'),
  phoneProxy('phone_proxy'),
  cloudCommandOnly('cloud_command_only');

  const AiroMediaRouteKind(this.stableId);

  final String stableId;

  bool get isPhoneProxy => this == phoneProxy;

  bool get canCarryMedia => this != cloudCommandOnly;
}

enum AiroMediaSourceKind {
  internet('internet'),
  iptv('iptv'),
  lanServer('lan_server'),
  nas('nas'),
  desktop('desktop'),
  phoneLocal('phone_local'),
  cloudStateOnly('cloud_state_only');

  const AiroMediaSourceKind(this.stableId);

  final String stableId;
}

enum AiroMediaRouteBlockerCode {
  unavailable('unavailable'),
  untrusted('untrusted'),
  directPlaybackUnsupported('direct_playback_unsupported'),
  codecUnsupported('codec_unsupported'),
  unsafeSourceHandle('unsafe_source_handle'),
  expired('expired'),
  phoneProxyRequiresConfirmation('phone_proxy_requires_confirmation'),
  cloudCannotCarryMedia('cloud_cannot_carry_media'),
  noEligibleRoute('no_eligible_route');

  const AiroMediaRouteBlockerCode(this.stableId);

  final String stableId;
}

enum AiroMediaRouteSourceHandleRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroMediaRouteSourceHandleRejectionCode(this.stableId);

  final String stableId;
}

class AiroMediaRouteSourceHandle extends Equatable {
  const AiroMediaRouteSourceHandle._(this.value);

  factory AiroMediaRouteSourceHandle.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroMediaRouteSourceHandle._(value.trim());
  }

  final String value;

  static AiroMediaRouteSourceHandleRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroMediaRouteSourceHandleRejectionCode.empty;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroMediaRouteSourceHandleRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroMediaRouteSourceHandleRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroMediaRouteSourceHandleRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroMediaRouteSourceHandleRejectionCode.credentialLikeValue;
    }

    return null;
  }

  @override
  String toString() => 'AiroMediaRouteSourceHandle(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroMediaRouteCandidate extends Equatable {
  AiroMediaRouteCandidate({
    required this.candidateId,
    required this.kind,
    required this.sourceKind,
    required this.sourceHandle,
    required this.playbackNodeId,
    required this.sourceNodeId,
    Set<String> supportedCodecs = const {},
    this.isAvailable = true,
    this.isTrusted = true,
    this.supportsDirectPlayback = true,
    this.expiresAt,
    this.schemaVersion = kAiroMediaRoutingSchemaVersion,
  }) : supportedCodecs = Set.unmodifiable(supportedCodecs);

  final String schemaVersion;
  final String candidateId;
  final AiroMediaRouteKind kind;
  final AiroMediaSourceKind sourceKind;
  final AiroMediaRouteSourceHandle sourceHandle;
  final String playbackNodeId;
  final String sourceNodeId;
  final Set<String> supportedCodecs;
  final bool isAvailable;
  final bool isTrusted;
  final bool supportsDirectPlayback;
  final DateTime? expiresAt;

  bool isExpired(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  bool supportsAllCodecs(Set<String> requiredCodecs) =>
      requiredCodecs.isEmpty || supportedCodecs.containsAll(requiredCodecs);

  @override
  String toString() {
    return 'AiroMediaRouteCandidate('
        'candidateId: $candidateId, '
        'kind: ${kind.stableId}, '
        'sourceKind: ${sourceKind.stableId}, '
        'playbackNodeId: $playbackNodeId, '
        'sourceNodeId: $sourceNodeId, '
        'sourceHandle: redacted'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    candidateId,
    kind,
    sourceKind,
    sourceHandle,
    playbackNodeId,
    sourceNodeId,
    supportedCodecs,
    isAvailable,
    isTrusted,
    supportsDirectPlayback,
    expiresAt,
  ];
}

class AiroMediaRouteRequest extends Equatable {
  AiroMediaRouteRequest({
    required this.requestId,
    required this.intent,
    required this.requestedAt,
    required Iterable<AiroMediaRouteCandidate> candidates,
    Set<String> requiredCodecs = const {},
    this.userConfirmedPhoneProxy = false,
    this.schemaVersion = kAiroMediaRoutingSchemaVersion,
  }) : candidates = List.unmodifiable(candidates),
       requiredCodecs = Set.unmodifiable(requiredCodecs);

  final String schemaVersion;
  final String requestId;
  final AiroMediaRouteIntent intent;
  final DateTime requestedAt;
  final List<AiroMediaRouteCandidate> candidates;
  final Set<String> requiredCodecs;
  final bool userConfirmedPhoneProxy;

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    intent,
    requestedAt,
    candidates,
    requiredCodecs,
    userConfirmedPhoneProxy,
  ];
}

class AiroMediaRouteEvaluation extends Equatable {
  AiroMediaRouteEvaluation({
    required this.candidate,
    required List<AiroMediaRouteBlockerCode> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final AiroMediaRouteCandidate candidate;
  final List<AiroMediaRouteBlockerCode> blockers;

  bool get eligible => blockers.isEmpty;

  @override
  List<Object?> get props => [candidate, blockers];
}

class AiroMediaRouteDecision extends Equatable {
  AiroMediaRouteDecision({
    required this.requestId,
    required Iterable<AiroMediaRouteEvaluation> evaluations,
    required this.selected,
    this.schemaVersion = kAiroMediaRoutingSchemaVersion,
  }) : evaluations = List.unmodifiable(evaluations);

  final String schemaVersion;
  final String requestId;
  final List<AiroMediaRouteEvaluation> evaluations;
  final AiroMediaRouteEvaluation? selected;

  bool get hasRoute => selected != null;

  AiroMediaRouteKind? get selectedKind => selected?.candidate.kind;

  List<AiroMediaRouteEvaluation> get rejected =>
      evaluations.where((evaluation) => !evaluation.eligible).toList();

  @override
  String toString() {
    return 'AiroMediaRouteDecision('
        'requestId: $requestId, '
        'selectedCandidateId: ${selected?.candidate.candidateId}, '
        'selectedKind: ${selected?.candidate.kind.stableId}, '
        'rejections: ${rejected.map((evaluation) => {'candidateId': evaluation.candidate.candidateId, 'blockers': evaluation.blockers.map((code) => code.stableId)}).toList()}'
        ')';
  }

  @override
  List<Object?> get props => [schemaVersion, requestId, evaluations, selected];
}

abstract interface class AiroMediaRoutingEngine {
  FutureOr<AiroMediaRouteDecision> selectRoute(AiroMediaRouteRequest request);
}

class AiroDeterministicMediaRoutingEngine implements AiroMediaRoutingEngine {
  const AiroDeterministicMediaRoutingEngine();

  @override
  AiroMediaRouteDecision selectRoute(AiroMediaRouteRequest request) {
    final baselineEvaluations = [
      for (final candidate in request.candidates)
        AiroMediaRouteEvaluation(
          candidate: candidate,
          blockers: _baselineBlockers(request, candidate),
        ),
    ];
    final hasNonPhoneEligible = baselineEvaluations.any(
      (evaluation) =>
          evaluation.eligible && !evaluation.candidate.kind.isPhoneProxy,
    );

    final evaluations = [
      for (final evaluation in baselineEvaluations)
        if (evaluation.candidate.kind.isPhoneProxy)
          AiroMediaRouteEvaluation(
            candidate: evaluation.candidate,
            blockers: [
              ...evaluation.blockers,
              if (hasNonPhoneEligible || !request.userConfirmedPhoneProxy)
                AiroMediaRouteBlockerCode.phoneProxyRequiresConfirmation,
            ],
          )
        else
          evaluation,
    ];

    final eligible =
        evaluations.where((evaluation) => evaluation.eligible).toList()
          ..sort(_compareEvaluations);

    return AiroMediaRouteDecision(
      requestId: request.requestId,
      evaluations: evaluations,
      selected: eligible.isEmpty ? null : eligible.first,
    );
  }

  List<AiroMediaRouteBlockerCode> _baselineBlockers(
    AiroMediaRouteRequest request,
    AiroMediaRouteCandidate candidate,
  ) {
    final blockers = <AiroMediaRouteBlockerCode>[];
    if (!candidate.kind.canCarryMedia) {
      blockers.add(AiroMediaRouteBlockerCode.cloudCannotCarryMedia);
    }
    if (!candidate.isAvailable) {
      blockers.add(AiroMediaRouteBlockerCode.unavailable);
    }
    if (!candidate.isTrusted) {
      blockers.add(AiroMediaRouteBlockerCode.untrusted);
    }
    if (!candidate.supportsDirectPlayback &&
        !candidate.kind.isPhoneProxy &&
        candidate.kind.canCarryMedia) {
      blockers.add(AiroMediaRouteBlockerCode.directPlaybackUnsupported);
    }
    if (!candidate.supportsAllCodecs(request.requiredCodecs)) {
      blockers.add(AiroMediaRouteBlockerCode.codecUnsupported);
    }
    if (candidate.isExpired(request.requestedAt)) {
      blockers.add(AiroMediaRouteBlockerCode.expired);
    }
    return blockers;
  }

  int _compareEvaluations(
    AiroMediaRouteEvaluation left,
    AiroMediaRouteEvaluation right,
  ) {
    final priority = _routePriority(
      right.candidate.kind,
    ).compareTo(_routePriority(left.candidate.kind));
    if (priority != 0) return priority;
    return left.candidate.candidateId.compareTo(right.candidate.candidateId);
  }

  int _routePriority(AiroMediaRouteKind kind) {
    return switch (kind) {
      AiroMediaRouteKind.receiverDirect => 100,
      AiroMediaRouteKind.lanDirect => 90,
      AiroMediaRouteKind.serverDirect => 80,
      AiroMediaRouteKind.desktopRelay => 70,
      AiroMediaRouteKind.phoneProxy => 10,
      AiroMediaRouteKind.cloudCommandOnly => -100,
    };
  }
}

import 'package:equatable/equatable.dart';

const String kAiroAiDelegationSchemaVersion = '1.0.0';

enum AiroAiSearchCapability {
  naturalLanguageSearch('natural_language_search'),
  voiceSearch('voice_search'),
  semanticRanking('semantic_ranking'),
  recommendations('recommendations');

  const AiroAiSearchCapability(this.stableId);

  final String stableId;
}

enum AiroAiProcessingLocation {
  onDevice('on_device'),
  companionDevice('companion_device'),
  homeNode('home_node'),
  cloudRelay('cloud_relay'),
  unavailable('unavailable');

  const AiroAiProcessingLocation(this.stableId);

  final String stableId;
}

enum AiroAiPrivacyMode {
  localOnly('local_only'),
  trustedLocalNetwork('trusted_local_network'),
  cloudAllowed('cloud_allowed');

  const AiroAiPrivacyMode(this.stableId);

  final String stableId;
}

enum AiroAiConfidenceBucket {
  none('none'),
  low('low'),
  medium('medium'),
  high('high');

  const AiroAiConfidenceBucket(this.stableId);

  final String stableId;
}

enum AiroAiSearchInputRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroAiSearchInputRejectionCode(this.stableId);

  final String stableId;
}

enum AiroAiDelegationBlockerCode {
  noCandidates('no_candidates'),
  missingCapability('missing_capability'),
  untrustedCandidate('untrusted_candidate'),
  unavailableCandidate('unavailable_candidate'),
  privacyModeMismatch('privacy_mode_mismatch'),
  latencyBudgetExceeded('latency_budget_exceeded');

  const AiroAiDelegationBlockerCode(this.stableId);

  final String stableId;
}

enum AiroAiSearchStatus {
  accepted('accepted'),
  unavailable('unavailable'),
  rejected('rejected');

  const AiroAiSearchStatus(this.stableId);

  final String stableId;
}

class AiroAiSearchInput extends Equatable {
  const AiroAiSearchInput._(this.value);

  factory AiroAiSearchInput.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroAiSearchInput._(value.trim());
  }

  final String value;

  static AiroAiSearchInputRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroAiSearchInputRejectionCode.empty;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroAiSearchInputRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroAiSearchInputRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroAiSearchInputRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroAiSearchInputRejectionCode.credentialLikeValue;
    }

    return null;
  }

  @override
  String toString() => 'AiroAiSearchInput(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroAiDelegationRequest extends Equatable {
  AiroAiDelegationRequest({
    required this.requestId,
    required this.input,
    required Set<AiroAiSearchCapability> requiredCapabilities,
    required this.privacyMode,
    this.maxLatency = const Duration(seconds: 2),
    this.schemaVersion = kAiroAiDelegationSchemaVersion,
  }) : requiredCapabilities = Set.unmodifiable(requiredCapabilities);

  final String schemaVersion;
  final String requestId;
  final AiroAiSearchInput input;
  final Set<AiroAiSearchCapability> requiredCapabilities;
  final AiroAiPrivacyMode privacyMode;
  final Duration maxLatency;

  @override
  String toString() {
    return 'AiroAiDelegationRequest('
        'requestId: $requestId, '
        'input: redacted, '
        'requiredCapabilities: ${requiredCapabilities.map((capability) => capability.stableId).join(',')}, '
        'privacyMode: ${privacyMode.stableId}, '
        'maxLatency: $maxLatency'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    input,
    requiredCapabilities,
    privacyMode,
    maxLatency,
  ];
}

class AiroAiDelegationCandidate extends Equatable {
  AiroAiDelegationCandidate({
    required this.candidateId,
    required this.displayName,
    required this.processingLocation,
    required Set<AiroAiSearchCapability> capabilities,
    required this.isTrusted,
    required this.isAvailable,
    required this.estimatedLatency,
    this.schemaVersion = kAiroAiDelegationSchemaVersion,
  }) : capabilities = Set.unmodifiable(capabilities);

  final String schemaVersion;
  final String candidateId;
  final String displayName;
  final AiroAiProcessingLocation processingLocation;
  final Set<AiroAiSearchCapability> capabilities;
  final bool isTrusted;
  final bool isAvailable;
  final Duration estimatedLatency;

  bool supportsAll(Set<AiroAiSearchCapability> requiredCapabilities) =>
      capabilities.containsAll(requiredCapabilities);

  @override
  List<Object?> get props => [
    schemaVersion,
    candidateId,
    displayName,
    processingLocation,
    capabilities,
    isTrusted,
    isAvailable,
    estimatedLatency,
  ];
}

class AiroAiDelegationBlocker extends Equatable {
  const AiroAiDelegationBlocker({required this.code, this.candidateId});

  final AiroAiDelegationBlockerCode code;
  final String? candidateId;

  @override
  List<Object?> get props => [code, candidateId];
}

class AiroAiDelegationDecision extends Equatable {
  AiroAiDelegationDecision({
    required this.requestId,
    required this.selectedCandidate,
    required List<AiroAiDelegationBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final String requestId;
  final AiroAiDelegationCandidate? selectedCandidate;
  final List<AiroAiDelegationBlocker> blockers;

  bool get accepted => selectedCandidate != null && blockers.isEmpty;

  AiroAiProcessingLocation get processingLocation =>
      selectedCandidate?.processingLocation ??
      AiroAiProcessingLocation.unavailable;

  @override
  List<Object?> get props => [requestId, selectedCandidate, blockers];
}

class AiroAiDelegationSelector {
  const AiroAiDelegationSelector({
    this.preferredLocations = const [
      AiroAiProcessingLocation.onDevice,
      AiroAiProcessingLocation.companionDevice,
      AiroAiProcessingLocation.homeNode,
      AiroAiProcessingLocation.cloudRelay,
    ],
  });

  final List<AiroAiProcessingLocation> preferredLocations;

  AiroAiDelegationDecision select({
    required AiroAiDelegationRequest request,
    required Iterable<AiroAiDelegationCandidate> candidates,
  }) {
    final candidateList = candidates.toList();
    if (candidateList.isEmpty) {
      return AiroAiDelegationDecision(
        requestId: request.requestId,
        selectedCandidate: null,
        blockers: const [
          AiroAiDelegationBlocker(
            code: AiroAiDelegationBlockerCode.noCandidates,
          ),
        ],
      );
    }

    final accepted = <AiroAiDelegationCandidate>[];
    final blockers = <AiroAiDelegationBlocker>[];

    for (final candidate in candidateList) {
      final blocker = _blockerFor(request: request, candidate: candidate);
      if (blocker == null) {
        accepted.add(candidate);
      } else {
        blockers.add(blocker);
      }
    }

    if (accepted.isEmpty) {
      return AiroAiDelegationDecision(
        requestId: request.requestId,
        selectedCandidate: null,
        blockers: blockers,
      );
    }

    accepted.sort((left, right) {
      final locationComparison = _locationRank(
        left.processingLocation,
      ).compareTo(_locationRank(right.processingLocation));
      if (locationComparison != 0) return locationComparison;
      return left.estimatedLatency.compareTo(right.estimatedLatency);
    });

    return AiroAiDelegationDecision(
      requestId: request.requestId,
      selectedCandidate: accepted.first,
      blockers: const [],
    );
  }

  AiroAiDelegationBlocker? _blockerFor({
    required AiroAiDelegationRequest request,
    required AiroAiDelegationCandidate candidate,
  }) {
    if (!candidate.supportsAll(request.requiredCapabilities)) {
      return AiroAiDelegationBlocker(
        code: AiroAiDelegationBlockerCode.missingCapability,
        candidateId: candidate.candidateId,
      );
    }
    if (!candidate.isTrusted) {
      return AiroAiDelegationBlocker(
        code: AiroAiDelegationBlockerCode.untrustedCandidate,
        candidateId: candidate.candidateId,
      );
    }
    if (!candidate.isAvailable) {
      return AiroAiDelegationBlocker(
        code: AiroAiDelegationBlockerCode.unavailableCandidate,
        candidateId: candidate.candidateId,
      );
    }
    if (!_privacyAllows(request.privacyMode, candidate.processingLocation)) {
      return AiroAiDelegationBlocker(
        code: AiroAiDelegationBlockerCode.privacyModeMismatch,
        candidateId: candidate.candidateId,
      );
    }
    if (candidate.estimatedLatency > request.maxLatency) {
      return AiroAiDelegationBlocker(
        code: AiroAiDelegationBlockerCode.latencyBudgetExceeded,
        candidateId: candidate.candidateId,
      );
    }
    return null;
  }

  bool _privacyAllows(
    AiroAiPrivacyMode privacyMode,
    AiroAiProcessingLocation location,
  ) {
    return switch (privacyMode) {
      AiroAiPrivacyMode.localOnly =>
        location == AiroAiProcessingLocation.onDevice,
      AiroAiPrivacyMode.trustedLocalNetwork =>
        location == AiroAiProcessingLocation.onDevice ||
            location == AiroAiProcessingLocation.companionDevice ||
            location == AiroAiProcessingLocation.homeNode,
      AiroAiPrivacyMode.cloudAllowed =>
        location != AiroAiProcessingLocation.unavailable,
    };
  }

  int _locationRank(AiroAiProcessingLocation location) {
    final index = preferredLocations.indexOf(location);
    return index == -1 ? preferredLocations.length : index;
  }
}

class AiroAiSearchResult extends Equatable {
  AiroAiSearchResult({
    required this.requestId,
    required this.status,
    required this.processingLocation,
    required this.confidence,
    List<String> resultRefs = const [],
    this.schemaVersion = kAiroAiDelegationSchemaVersion,
  }) : resultRefs = List.unmodifiable(resultRefs);

  final String schemaVersion;
  final String requestId;
  final AiroAiSearchStatus status;
  final AiroAiProcessingLocation processingLocation;
  final AiroAiConfidenceBucket confidence;
  final List<String> resultRefs;

  @override
  String toString() {
    return 'AiroAiSearchResult('
        'requestId: $requestId, '
        'status: ${status.stableId}, '
        'processingLocation: ${processingLocation.stableId}, '
        'confidence: ${confidence.stableId}, '
        'resultRefs: ${resultRefs.length}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    requestId,
    status,
    processingLocation,
    confidence,
    resultRefs,
  ];
}

abstract class AiroAiSearchDelegationProvider {
  Future<AiroAiSearchResult> search(AiroAiDelegationRequest request);
}

class AiroNoOpAiSearchDelegationProvider
    implements AiroAiSearchDelegationProvider {
  const AiroNoOpAiSearchDelegationProvider();

  @override
  Future<AiroAiSearchResult> search(AiroAiDelegationRequest request) async {
    return AiroAiSearchResult(
      requestId: request.requestId,
      status: AiroAiSearchStatus.unavailable,
      processingLocation: AiroAiProcessingLocation.unavailable,
      confidence: AiroAiConfidenceBucket.none,
    );
  }
}

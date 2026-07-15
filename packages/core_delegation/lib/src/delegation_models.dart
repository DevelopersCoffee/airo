import 'package:equatable/equatable.dart';

const String kAiroDelegationSchemaVersion = '1.0.0';
const int kAiroDelegationResultVersion = 1;

enum AiroDelegationTaskKind {
  search('search'),
  playlistParsing('playlist_parsing'),
  epgProcessing('epg_processing'),
  metadataMatching('metadata_matching'),
  aiIntentParsing('ai_intent_parsing'),
  subtitleLookup('subtitle_lookup'),
  streamHealthRanking('stream_health_ranking'),
  artworkResizing('artwork_resizing'),
  sourceResolution('source_resolution'),
  credentialAssistedPlayback('credential_assisted_playback'),
  transcoding('transcoding');

  const AiroDelegationTaskKind(this.stableId);

  final String stableId;
}

enum AiroDelegationTaskStatus {
  pending('pending'),
  accepted('accepted'),
  running('running'),
  succeeded('succeeded'),
  failed('failed'),
  cancelled('cancelled'),
  timedOut('timed_out'),
  unavailable('unavailable'),
  duplicateSuppressed('duplicate_suppressed'),
  fallbackSelected('fallback_selected');

  const AiroDelegationTaskStatus(this.stableId);

  final String stableId;
}

enum AiroDelegationValidationCode {
  accepted('accepted'),
  taskIdMissing('task_id_missing'),
  timeoutInvalid('timeout_invalid'),
  encryptedPayloadMissing('encrypted_payload_missing'),
  resultVersionUnsupported('result_version_unsupported'),
  expired('expired'),
  cancelled('cancelled');

  const AiroDelegationValidationCode(this.stableId);

  final String stableId;
}

enum AiroDelegationSelectionBlockerCode {
  noCandidates('no_candidates'),
  missingCapability('missing_capability'),
  untrustedCandidate('untrusted_candidate'),
  unavailableCandidate('unavailable_candidate'),
  latencyBudgetExceeded('latency_budget_exceeded'),
  validationFailed('validation_failed'),
  duplicateSuppressed('duplicate_suppressed'),
  fallbackRequired('fallback_required');

  const AiroDelegationSelectionBlockerCode(this.stableId);

  final String stableId;
}

enum AiroDelegationFallbackKind {
  localCompact('local_compact'),
  noOpUnavailable('no_op_unavailable'),
  userActionRequired('user_action_required'),
  retryLater('retry_later');

  const AiroDelegationFallbackKind(this.stableId);

  final String stableId;
}

class AiroDelegationTaskRequest extends Equatable {
  const AiroDelegationTaskRequest({
    required this.taskId,
    required this.deduplicationKey,
    required this.kind,
    required this.createdAt,
    required this.timeout,
    this.requiresEncryptedPayload = false,
    this.hasEncryptedPayload = false,
    this.requiredResultVersion = kAiroDelegationResultVersion,
    this.schemaVersion = kAiroDelegationSchemaVersion,
  });

  final String schemaVersion;
  final String taskId;
  final String deduplicationKey;
  final AiroDelegationTaskKind kind;
  final DateTime createdAt;
  final Duration timeout;
  final bool requiresEncryptedPayload;
  final bool hasEncryptedPayload;
  final int requiredResultVersion;

  DateTime get deadline => createdAt.add(timeout);

  bool isExpired(DateTime now) => !deadline.isAfter(now);

  List<AiroDelegationValidationCode> validate({
    required DateTime now,
    Set<String> cancelledTaskIds = const {},
  }) {
    final codes = <AiroDelegationValidationCode>[];
    if (taskId.trim().isEmpty || deduplicationKey.trim().isEmpty) {
      codes.add(AiroDelegationValidationCode.taskIdMissing);
    }
    if (timeout <= Duration.zero) {
      codes.add(AiroDelegationValidationCode.timeoutInvalid);
    }
    if (requiresEncryptedPayload && !hasEncryptedPayload) {
      codes.add(AiroDelegationValidationCode.encryptedPayloadMissing);
    }
    if (requiredResultVersion <= 0) {
      codes.add(AiroDelegationValidationCode.resultVersionUnsupported);
    }
    if (isExpired(now)) {
      codes.add(AiroDelegationValidationCode.expired);
    }
    if (cancelledTaskIds.contains(taskId)) {
      codes.add(AiroDelegationValidationCode.cancelled);
    }

    return codes.isEmpty
        ? const [AiroDelegationValidationCode.accepted]
        : codes;
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'taskId': taskId,
      'deduplicationKey': deduplicationKey,
      'kind': kind.stableId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'deadline': deadline.toUtc().toIso8601String(),
      'timeoutMs': timeout.inMilliseconds,
      'requiresEncryptedPayload': requiresEncryptedPayload,
      'hasEncryptedPayload': hasEncryptedPayload,
      'requiredResultVersion': requiredResultVersion,
    };
  }

  @override
  String toString() {
    return 'AiroDelegationTaskRequest('
        'taskId: $taskId, '
        'deduplicationKey: $deduplicationKey, '
        'kind: ${kind.stableId}, '
        'payload: redacted, '
        'timeoutMs: ${timeout.inMilliseconds}, '
        'requiredResultVersion: $requiredResultVersion'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    taskId,
    deduplicationKey,
    kind,
    createdAt,
    timeout,
    requiresEncryptedPayload,
    hasEncryptedPayload,
    requiredResultVersion,
  ];
}

class AiroDelegationCandidate extends Equatable {
  AiroDelegationCandidate({
    required this.nodeId,
    required this.displayName,
    required Set<AiroDelegationTaskKind> supportedTaskKinds,
    required this.isTrusted,
    required this.isAvailable,
    required this.estimatedLatency,
    this.maxResultVersion = kAiroDelegationResultVersion,
    this.schemaVersion = kAiroDelegationSchemaVersion,
  }) : supportedTaskKinds = Set.unmodifiable(supportedTaskKinds);

  final String schemaVersion;
  final String nodeId;
  final String displayName;
  final Set<AiroDelegationTaskKind> supportedTaskKinds;
  final bool isTrusted;
  final bool isAvailable;
  final Duration estimatedLatency;
  final int maxResultVersion;

  bool supports(AiroDelegationTaskRequest request) {
    return supportedTaskKinds.contains(request.kind) &&
        maxResultVersion >= request.requiredResultVersion;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    nodeId,
    displayName,
    supportedTaskKinds,
    isTrusted,
    isAvailable,
    estimatedLatency,
    maxResultVersion,
  ];
}

class AiroDelegationTaskRecord extends Equatable {
  const AiroDelegationTaskRecord({
    required this.taskId,
    required this.deduplicationKey,
    required this.status,
    required this.updatedAt,
    this.resultVersion = kAiroDelegationResultVersion,
    this.resultRef,
  });

  final String taskId;
  final String deduplicationKey;
  final AiroDelegationTaskStatus status;
  final DateTime updatedAt;
  final int resultVersion;
  final String? resultRef;

  bool get terminal =>
      status == AiroDelegationTaskStatus.succeeded ||
      status == AiroDelegationTaskStatus.failed ||
      status == AiroDelegationTaskStatus.cancelled ||
      status == AiroDelegationTaskStatus.timedOut ||
      status == AiroDelegationTaskStatus.unavailable;

  Map<String, Object?> toPublicMap() {
    return {
      'taskId': taskId,
      'deduplicationKey': deduplicationKey,
      'status': status.stableId,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'resultVersion': resultVersion,
      'hasResultRef': resultRef != null,
      'terminal': terminal,
    };
  }

  @override
  List<Object?> get props => [
    taskId,
    deduplicationKey,
    status,
    updatedAt,
    resultVersion,
    resultRef,
  ];
}

class AiroDelegationFallbackDecision extends Equatable {
  const AiroDelegationFallbackDecision({
    required this.kind,
    required this.userVisibleUnavailable,
  });

  final AiroDelegationFallbackKind kind;
  final bool userVisibleUnavailable;

  Map<String, Object?> toPublicMap() {
    return {
      'kind': kind.stableId,
      'userVisibleUnavailable': userVisibleUnavailable,
    };
  }

  @override
  List<Object?> get props => [kind, userVisibleUnavailable];
}

class AiroDelegationSelectionBlocker extends Equatable {
  const AiroDelegationSelectionBlocker({
    required this.code,
    this.candidateId,
    this.validationCode,
  });

  final AiroDelegationSelectionBlockerCode code;
  final String? candidateId;
  final AiroDelegationValidationCode? validationCode;

  @override
  List<Object?> get props => [code, candidateId, validationCode];
}

class AiroDelegationDispatchDecision extends Equatable {
  AiroDelegationDispatchDecision({
    required this.request,
    required this.selectedCandidate,
    required List<AiroDelegationSelectionBlocker> blockers,
    this.existingRecord,
    this.fallbackDecision,
  }) : blockers = List.unmodifiable(blockers);

  final AiroDelegationTaskRequest request;
  final AiroDelegationCandidate? selectedCandidate;
  final List<AiroDelegationSelectionBlocker> blockers;
  final AiroDelegationTaskRecord? existingRecord;
  final AiroDelegationFallbackDecision? fallbackDecision;

  bool get accepted => selectedCandidate != null && blockers.isEmpty;

  bool get duplicateSuppressed => existingRecord != null;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'duplicateSuppressed': duplicateSuppressed,
      'request': request.toPublicMap(),
      'selectedCandidateId': selectedCandidate?.nodeId,
      'blockers': blockers
          .map(
            (blocker) => {
              'code': blocker.code.stableId,
              'candidateId': blocker.candidateId,
              'validationCode': blocker.validationCode?.stableId,
            },
          )
          .toList(growable: false),
      'existingRecord': existingRecord?.toPublicMap(),
      'fallbackDecision': fallbackDecision?.toPublicMap(),
    };
  }

  @override
  List<Object?> get props => [
    request,
    selectedCandidate,
    blockers,
    existingRecord,
    fallbackDecision,
  ];
}

class AiroDelegationResultEnvelope extends Equatable {
  const AiroDelegationResultEnvelope({
    required this.taskId,
    required this.status,
    required this.resultVersion,
    required this.completedAt,
    this.resultRef,
    this.fallbackKind,
    this.schemaVersion = kAiroDelegationSchemaVersion,
  });

  final String schemaVersion;
  final String taskId;
  final AiroDelegationTaskStatus status;
  final int resultVersion;
  final DateTime completedAt;
  final String? resultRef;
  final AiroDelegationFallbackKind? fallbackKind;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'taskId': taskId,
      'status': status.stableId,
      'resultVersion': resultVersion,
      'completedAt': completedAt.toUtc().toIso8601String(),
      'hasResultRef': resultRef != null,
      'fallbackKind': fallbackKind?.stableId,
    };
  }

  @override
  String toString() {
    return 'AiroDelegationResultEnvelope('
        'taskId: $taskId, '
        'status: ${status.stableId}, '
        'resultVersion: $resultVersion, '
        'result: redacted'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    taskId,
    status,
    resultVersion,
    completedAt,
    resultRef,
    fallbackKind,
  ];
}

class AiroDelegationPolicy {
  const AiroDelegationPolicy({
    this.defaultFallback = const AiroDelegationFallbackDecision(
      kind: AiroDelegationFallbackKind.userActionRequired,
      userVisibleUnavailable: true,
    ),
  });

  final AiroDelegationFallbackDecision defaultFallback;

  AiroDelegationDispatchDecision select({
    required AiroDelegationTaskRequest request,
    required Iterable<AiroDelegationCandidate> candidates,
    required DateTime now,
    Iterable<AiroDelegationTaskRecord> existingRecords = const [],
    Set<String> cancelledTaskIds = const {},
  }) {
    final validationCodes = request.validate(
      now: now,
      cancelledTaskIds: cancelledTaskIds,
    );
    if (!_validationAccepted(validationCodes)) {
      return AiroDelegationDispatchDecision(
        request: request,
        selectedCandidate: null,
        blockers: validationCodes
            .map(
              (code) => AiroDelegationSelectionBlocker(
                code: AiroDelegationSelectionBlockerCode.validationFailed,
                validationCode: code,
              ),
            )
            .toList(growable: false),
        fallbackDecision: defaultFallback,
      );
    }

    final existingRecord = _existingRecordFor(request, existingRecords);
    if (existingRecord != null) {
      return AiroDelegationDispatchDecision(
        request: request,
        selectedCandidate: null,
        blockers: const [
          AiroDelegationSelectionBlocker(
            code: AiroDelegationSelectionBlockerCode.duplicateSuppressed,
          ),
        ],
        existingRecord: existingRecord,
      );
    }

    final candidateList = candidates.toList(growable: false);
    if (candidateList.isEmpty) {
      return _fallbackDecision(
        request: request,
        blockers: const [
          AiroDelegationSelectionBlocker(
            code: AiroDelegationSelectionBlockerCode.noCandidates,
          ),
        ],
      );
    }

    final accepted = <AiroDelegationCandidate>[];
    final blockers = <AiroDelegationSelectionBlocker>[];

    for (final candidate in candidateList) {
      final blocker = _blockerFor(request: request, candidate: candidate);
      if (blocker == null) {
        accepted.add(candidate);
      } else {
        blockers.add(blocker);
      }
    }

    if (accepted.isEmpty) {
      return _fallbackDecision(
        request: request,
        blockers: [
          ...blockers,
          const AiroDelegationSelectionBlocker(
            code: AiroDelegationSelectionBlockerCode.fallbackRequired,
          ),
        ],
      );
    }

    accepted.sort(
      (left, right) => left.estimatedLatency.compareTo(right.estimatedLatency),
    );

    return AiroDelegationDispatchDecision(
      request: request,
      selectedCandidate: accepted.first,
      blockers: const [],
    );
  }

  AiroDelegationTaskRecord? _existingRecordFor(
    AiroDelegationTaskRequest request,
    Iterable<AiroDelegationTaskRecord> existingRecords,
  ) {
    for (final record in existingRecords) {
      if (record.deduplicationKey == request.deduplicationKey) {
        return record;
      }
    }
    return null;
  }

  AiroDelegationDispatchDecision _fallbackDecision({
    required AiroDelegationTaskRequest request,
    required List<AiroDelegationSelectionBlocker> blockers,
  }) {
    return AiroDelegationDispatchDecision(
      request: request,
      selectedCandidate: null,
      blockers: blockers,
      fallbackDecision: defaultFallback,
    );
  }

  AiroDelegationSelectionBlocker? _blockerFor({
    required AiroDelegationTaskRequest request,
    required AiroDelegationCandidate candidate,
  }) {
    if (!candidate.supports(request)) {
      return AiroDelegationSelectionBlocker(
        code: AiroDelegationSelectionBlockerCode.missingCapability,
        candidateId: candidate.nodeId,
      );
    }
    if (!candidate.isTrusted) {
      return AiroDelegationSelectionBlocker(
        code: AiroDelegationSelectionBlockerCode.untrustedCandidate,
        candidateId: candidate.nodeId,
      );
    }
    if (!candidate.isAvailable) {
      return AiroDelegationSelectionBlocker(
        code: AiroDelegationSelectionBlockerCode.unavailableCandidate,
        candidateId: candidate.nodeId,
      );
    }
    if (candidate.estimatedLatency > request.timeout) {
      return AiroDelegationSelectionBlocker(
        code: AiroDelegationSelectionBlockerCode.latencyBudgetExceeded,
        candidateId: candidate.nodeId,
      );
    }
    return null;
  }

  bool _validationAccepted(List<AiroDelegationValidationCode> codes) {
    return codes.length == 1 &&
        codes.single == AiroDelegationValidationCode.accepted;
  }
}

abstract class AiroDelegationDispatcher {
  Future<AiroDelegationResultEnvelope> dispatch(
    AiroDelegationTaskRequest request,
  );
}

class AiroNoOpDelegationDispatcher implements AiroDelegationDispatcher {
  const AiroNoOpDelegationDispatcher();

  @override
  Future<AiroDelegationResultEnvelope> dispatch(
    AiroDelegationTaskRequest request,
  ) async {
    return AiroDelegationResultEnvelope(
      taskId: request.taskId,
      status: AiroDelegationTaskStatus.unavailable,
      resultVersion: request.requiredResultVersion,
      completedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      fallbackKind: AiroDelegationFallbackKind.noOpUnavailable,
    );
  }
}

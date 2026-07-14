import 'package:equatable/equatable.dart';

const String kAiroLargePlaylistWorkerSchemaVersion = '1.0.0';

enum AiroLargePlaylistWorkerStage {
  sourceOpen('source_open'),
  parse('parse'),
  normalize('normalize'),
  dedupe('dedupe'),
  batchWrite('batch_write'),
  buildIndex('index'),
  finalize('finalize');

  const AiroLargePlaylistWorkerStage(this.stableId);

  final String stableId;
}

enum AiroLargePlaylistWorkerStatus {
  queued('queued'),
  running('running'),
  partialAvailable('partial_available'),
  cancelRequested('cancel_requested'),
  cancelled('cancelled'),
  completed('completed'),
  failed('failed');

  const AiroLargePlaylistWorkerStatus(this.stableId);

  final String stableId;
}

enum AiroLargePlaylistWorkerDiagnosticCode {
  sourceUnavailable('source_unavailable'),
  parseFailed('parse_failed'),
  batchWriteFailed('batch_write_failed'),
  cancellationRequested('cancellation_requested'),
  partialAvailabilityPublished('partial_availability_published'),
  privacyUnsafeSourceRef('privacy_unsafe_source_ref');

  const AiroLargePlaylistWorkerDiagnosticCode(this.stableId);

  final String stableId;
}

enum AiroLargePlaylistWorkerPlanBlockerCode {
  accepted('accepted'),
  emptyJobId('empty_job_id'),
  invalidExpectedItemCount('invalid_expected_item_count'),
  invalidBatchSize('invalid_batch_size'),
  invalidConcurrency('invalid_concurrency'),
  missingRequiredStage('missing_required_stage'),
  privacyUnsafeSourceRef('privacy_unsafe_source_ref');

  const AiroLargePlaylistWorkerPlanBlockerCode(this.stableId);

  final String stableId;
}

enum AiroLargePlaylistSourceRefRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroLargePlaylistSourceRefRejectionCode(this.stableId);

  final String stableId;
}

class AiroLargePlaylistSourceRef extends Equatable {
  const AiroLargePlaylistSourceRef._(this.value);

  factory AiroLargePlaylistSourceRef.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroLargePlaylistSourceRef._(value.trim());
  }

  final String value;

  static AiroLargePlaylistSourceRefRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroLargePlaylistSourceRefRejectionCode.empty;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroLargePlaylistSourceRefRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroLargePlaylistSourceRefRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroLargePlaylistSourceRefRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroLargePlaylistSourceRefRejectionCode.credentialLikeValue;
    }
    return null;
  }

  @override
  String toString() => 'AiroLargePlaylistSourceRef(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroLargePlaylistImportPlan extends Equatable {
  AiroLargePlaylistImportPlan({
    required this.jobId,
    required this.sourceRef,
    required this.expectedItemCount,
    required this.batchSize,
    required this.maxConcurrency,
    required Iterable<AiroLargePlaylistWorkerStage> stages,
    this.allowPartialAvailability = true,
    this.schemaVersion = kAiroLargePlaylistWorkerSchemaVersion,
  }) : stages = List.unmodifiable(stages);

  final String schemaVersion;
  final String jobId;
  final AiroLargePlaylistSourceRef sourceRef;
  final int expectedItemCount;
  final int batchSize;
  final int maxConcurrency;
  final List<AiroLargePlaylistWorkerStage> stages;
  final bool allowPartialAvailability;

  int get expectedBatchCount => (expectedItemCount / batchSize).ceil();

  @override
  List<Object?> get props => [
    schemaVersion,
    jobId,
    sourceRef,
    expectedItemCount,
    batchSize,
    maxConcurrency,
    stages,
    allowPartialAvailability,
  ];
}

class AiroLargePlaylistImportDiagnostic extends Equatable {
  const AiroLargePlaylistImportDiagnostic({
    required this.code,
    required this.stage,
    this.safeDetail,
    this.schemaVersion = kAiroLargePlaylistWorkerSchemaVersion,
  });

  final String schemaVersion;
  final AiroLargePlaylistWorkerDiagnosticCode code;
  final AiroLargePlaylistWorkerStage stage;
  final String? safeDetail;

  @override
  List<Object?> get props => [schemaVersion, code, stage, safeDetail];
}

class AiroLargePlaylistProgress extends Equatable {
  AiroLargePlaylistProgress({
    required this.jobId,
    required this.stage,
    required this.status,
    required this.expectedItemCount,
    required this.parsedCount,
    required this.normalizedCount,
    required this.dedupedCount,
    required this.writtenCount,
    required this.failedCount,
    required this.batchIndex,
    Iterable<AiroLargePlaylistImportDiagnostic> diagnostics = const [],
    this.schemaVersion = kAiroLargePlaylistWorkerSchemaVersion,
  }) : diagnostics = List.unmodifiable(diagnostics);

  final String schemaVersion;
  final String jobId;
  final AiroLargePlaylistWorkerStage stage;
  final AiroLargePlaylistWorkerStatus status;
  final int expectedItemCount;
  final int parsedCount;
  final int normalizedCount;
  final int dedupedCount;
  final int writtenCount;
  final int failedCount;
  final int batchIndex;
  final List<AiroLargePlaylistImportDiagnostic> diagnostics;

  double get completionRatio {
    if (expectedItemCount <= 0) {
      return 0;
    }
    final completed = writtenCount > 0 ? writtenCount : parsedCount;
    return (completed / expectedItemCount).clamp(0, 1).toDouble();
  }

  bool get hasPartialAvailability =>
      status == AiroLargePlaylistWorkerStatus.partialAvailable ||
      writtenCount > 0;

  bool get isTerminal =>
      status == AiroLargePlaylistWorkerStatus.completed ||
      status == AiroLargePlaylistWorkerStatus.cancelled ||
      status == AiroLargePlaylistWorkerStatus.failed;

  @override
  String toString() {
    return 'AiroLargePlaylistProgress('
        'jobId: $jobId, '
        'stage: ${stage.stableId}, '
        'status: ${status.stableId}, '
        'expectedItemCount: $expectedItemCount, '
        'writtenCount: $writtenCount, '
        'failedCount: $failedCount'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    jobId,
    stage,
    status,
    expectedItemCount,
    parsedCount,
    normalizedCount,
    dedupedCount,
    writtenCount,
    failedCount,
    batchIndex,
    diagnostics,
  ];
}

class AiroPlaylistBatchWriteRequest extends Equatable {
  const AiroPlaylistBatchWriteRequest({
    required this.jobId,
    required this.batchIndex,
    required this.recordCount,
    this.schemaVersion = kAiroLargePlaylistWorkerSchemaVersion,
  });

  final String schemaVersion;
  final String jobId;
  final int batchIndex;
  final int recordCount;

  @override
  List<Object?> get props => [schemaVersion, jobId, batchIndex, recordCount];
}

class AiroPlaylistBatchWriteResult extends Equatable {
  const AiroPlaylistBatchWriteResult({
    required this.jobId,
    required this.batchIndex,
    required this.acceptedCount,
    required this.rejectedCount,
    this.schemaVersion = kAiroLargePlaylistWorkerSchemaVersion,
  });

  final String schemaVersion;
  final String jobId;
  final int batchIndex;
  final int acceptedCount;
  final int rejectedCount;

  bool get isSuccessful => rejectedCount == 0;

  @override
  List<Object?> get props => [
    schemaVersion,
    jobId,
    batchIndex,
    acceptedCount,
    rejectedCount,
  ];
}

class AiroLargePlaylistWorkerPlanEvaluation extends Equatable {
  AiroLargePlaylistWorkerPlanEvaluation({
    required this.jobId,
    required Iterable<AiroLargePlaylistWorkerPlanBlockerCode> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final String jobId;
  final List<AiroLargePlaylistWorkerPlanBlockerCode> blockers;

  bool get accepted =>
      blockers.length == 1 &&
      blockers.single == AiroLargePlaylistWorkerPlanBlockerCode.accepted;

  @override
  List<Object?> get props => [jobId, blockers];
}

class AiroLargePlaylistWorkerPolicy {
  const AiroLargePlaylistWorkerPolicy();

  static const Set<AiroLargePlaylistWorkerStage> requiredStages = {
    AiroLargePlaylistWorkerStage.sourceOpen,
    AiroLargePlaylistWorkerStage.parse,
    AiroLargePlaylistWorkerStage.normalize,
    AiroLargePlaylistWorkerStage.dedupe,
    AiroLargePlaylistWorkerStage.batchWrite,
    AiroLargePlaylistWorkerStage.buildIndex,
    AiroLargePlaylistWorkerStage.finalize,
  };

  AiroLargePlaylistWorkerPlanEvaluation validate(
    AiroLargePlaylistImportPlan plan,
  ) {
    final blockers = <AiroLargePlaylistWorkerPlanBlockerCode>[];
    if (plan.jobId.trim().isEmpty) {
      blockers.add(AiroLargePlaylistWorkerPlanBlockerCode.emptyJobId);
    }
    if (plan.expectedItemCount <= 0) {
      blockers.add(
        AiroLargePlaylistWorkerPlanBlockerCode.invalidExpectedItemCount,
      );
    }
    if (plan.batchSize <= 0 || plan.batchSize > plan.expectedItemCount) {
      blockers.add(AiroLargePlaylistWorkerPlanBlockerCode.invalidBatchSize);
    }
    if (plan.maxConcurrency <= 0) {
      blockers.add(AiroLargePlaylistWorkerPlanBlockerCode.invalidConcurrency);
    }
    if (!plan.stages.toSet().containsAll(requiredStages)) {
      blockers.add(AiroLargePlaylistWorkerPlanBlockerCode.missingRequiredStage);
    }
    if (AiroLargePlaylistSourceRef.validate(plan.sourceRef.value) != null) {
      blockers.add(
        AiroLargePlaylistWorkerPlanBlockerCode.privacyUnsafeSourceRef,
      );
    }

    return AiroLargePlaylistWorkerPlanEvaluation(
      jobId: plan.jobId,
      blockers: blockers.isEmpty
          ? const [AiroLargePlaylistWorkerPlanBlockerCode.accepted]
          : blockers,
    );
  }
}

abstract interface class AiroPlaylistBatchWriter {
  Future<AiroPlaylistBatchWriteResult> writeBatch(
    AiroPlaylistBatchWriteRequest request,
  );
}

class AiroNoOpPlaylistBatchWriter implements AiroPlaylistBatchWriter {
  const AiroNoOpPlaylistBatchWriter();

  @override
  Future<AiroPlaylistBatchWriteResult> writeBatch(
    AiroPlaylistBatchWriteRequest request,
  ) async {
    return AiroPlaylistBatchWriteResult(
      jobId: request.jobId,
      batchIndex: request.batchIndex,
      acceptedCount: 0,
      rejectedCount: request.recordCount,
    );
  }
}

class AiroFakePlaylistBatchWriter implements AiroPlaylistBatchWriter {
  const AiroFakePlaylistBatchWriter({this.rejectAll = false});

  final bool rejectAll;

  @override
  Future<AiroPlaylistBatchWriteResult> writeBatch(
    AiroPlaylistBatchWriteRequest request,
  ) async {
    return AiroPlaylistBatchWriteResult(
      jobId: request.jobId,
      batchIndex: request.batchIndex,
      acceptedCount: rejectAll ? 0 : request.recordCount,
      rejectedCount: rejectAll ? request.recordCount : 0,
    );
  }
}

abstract interface class AiroLargePlaylistWorker {
  Stream<AiroLargePlaylistProgress> run(AiroLargePlaylistImportPlan plan);
  Future<void> cancel(String jobId);
}

class AiroNoOpLargePlaylistWorker implements AiroLargePlaylistWorker {
  const AiroNoOpLargePlaylistWorker();

  @override
  Stream<AiroLargePlaylistProgress> run(
    AiroLargePlaylistImportPlan plan,
  ) async* {
    yield AiroLargePlaylistProgress(
      jobId: plan.jobId,
      stage: AiroLargePlaylistWorkerStage.sourceOpen,
      status: AiroLargePlaylistWorkerStatus.failed,
      expectedItemCount: plan.expectedItemCount,
      parsedCount: 0,
      normalizedCount: 0,
      dedupedCount: 0,
      writtenCount: 0,
      failedCount: 0,
      batchIndex: 0,
      diagnostics: const [
        AiroLargePlaylistImportDiagnostic(
          code: AiroLargePlaylistWorkerDiagnosticCode.sourceUnavailable,
          stage: AiroLargePlaylistWorkerStage.sourceOpen,
        ),
      ],
    );
  }

  @override
  Future<void> cancel(String jobId) async {}
}

class AiroFakeLargePlaylistWorker implements AiroLargePlaylistWorker {
  AiroFakeLargePlaylistWorker({
    required Iterable<AiroLargePlaylistProgress> progress,
  }) : _progress = List.unmodifiable(progress);

  final List<AiroLargePlaylistProgress> _progress;
  final Set<String> _cancelledJobIds = {};

  @override
  Stream<AiroLargePlaylistProgress> run(
    AiroLargePlaylistImportPlan plan,
  ) async* {
    for (final event in _progress.where((event) => event.jobId == plan.jobId)) {
      if (_cancelledJobIds.contains(plan.jobId)) {
        yield AiroLargePlaylistProgress(
          jobId: plan.jobId,
          stage: event.stage,
          status: AiroLargePlaylistWorkerStatus.cancelled,
          expectedItemCount: plan.expectedItemCount,
          parsedCount: event.parsedCount,
          normalizedCount: event.normalizedCount,
          dedupedCount: event.dedupedCount,
          writtenCount: event.writtenCount,
          failedCount: event.failedCount,
          batchIndex: event.batchIndex,
          diagnostics: const [
            AiroLargePlaylistImportDiagnostic(
              code: AiroLargePlaylistWorkerDiagnosticCode.cancellationRequested,
              stage: AiroLargePlaylistWorkerStage.batchWrite,
            ),
          ],
        );
        return;
      }
      yield event;
    }
  }

  @override
  Future<void> cancel(String jobId) async {
    _cancelledJobIds.add(jobId);
  }
}

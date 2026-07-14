import 'package:equatable/equatable.dart';

const String kAiroMediaDatabaseBenchmarkSchemaVersion = '1.0.0';

enum AiroMediaBenchmarkDatasetKind {
  liveIptv('live_iptv'),
  vodCatalog('vod_catalog'),
  compactEpg('compact_epg'),
  mixedCatalog('mixed_catalog');

  const AiroMediaBenchmarkDatasetKind(this.stableId);

  final String stableId;
}

enum AiroMediaBenchmarkOperation {
  importBatch('import_batch'),
  searchText('search_text'),
  lookupById('lookup_by_id'),
  updateStreamHealth('update_stream_health'),
  writeProgress('write_progress'),
  deleteExpired('delete_expired'),
  snapshotCompactWindow('snapshot_compact_window');

  const AiroMediaBenchmarkOperation(this.stableId);

  final String stableId;
}

enum AiroMediaBenchmarkMetric {
  elapsedMillis('elapsed_millis'),
  peakMemoryMb('peak_memory_mb'),
  storageMb('storage_mb'),
  rowsPerSecond('rows_per_second');

  const AiroMediaBenchmarkMetric(this.stableId);

  final String stableId;
}

enum AiroMediaBenchmarkBlockerCode {
  accepted('accepted'),
  missingMetric('missing_metric'),
  incompleteWorkload('incomplete_workload'),
  failedWorkload('failed_workload'),
  overTimeBudget('over_time_budget'),
  overMemoryBudget('over_memory_budget'),
  overStorageBudget('over_storage_budget'),
  belowThroughputFloor('below_throughput_floor'),
  privacyUnsafeStableId('privacy_unsafe_stable_id');

  const AiroMediaBenchmarkBlockerCode(this.stableId);

  final String stableId;
}

class AiroMediaBenchmarkStableIdPolicy {
  const AiroMediaBenchmarkStableIdPolicy();

  bool isSafe(String value) => rejectionFor(value) == null;

  AiroMediaBenchmarkStableIdRejection? rejectionFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroMediaBenchmarkStableIdRejection.empty;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroMediaBenchmarkStableIdRejection.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroMediaBenchmarkStableIdRejection.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroMediaBenchmarkStableIdRejection.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroMediaBenchmarkStableIdRejection.credentialLikeValue;
    }
    return null;
  }
}

enum AiroMediaBenchmarkStableIdRejection {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value');

  const AiroMediaBenchmarkStableIdRejection(this.stableId);

  final String stableId;
}

class AiroMediaBenchmarkDatasetProfile extends Equatable {
  const AiroMediaBenchmarkDatasetProfile({
    required this.profileId,
    required this.kind,
    required this.liveChannelCount,
    required this.vodItemCount,
    required this.epgProgramCount,
    required this.playlistSourceCount,
    required this.metadataFieldCount,
    this.schemaVersion = kAiroMediaDatabaseBenchmarkSchemaVersion,
  });

  final String schemaVersion;
  final String profileId;
  final AiroMediaBenchmarkDatasetKind kind;
  final int liveChannelCount;
  final int vodItemCount;
  final int epgProgramCount;
  final int playlistSourceCount;
  final int metadataFieldCount;

  int get totalMediaItems => liveChannelCount + vodItemCount;

  int get totalIndexedRecords =>
      liveChannelCount + vodItemCount + epgProgramCount;

  @override
  String toString() {
    return 'AiroMediaBenchmarkDatasetProfile('
        'profileId: $profileId, '
        'kind: ${kind.stableId}, '
        'liveChannelCount: $liveChannelCount, '
        'vodItemCount: $vodItemCount, '
        'epgProgramCount: $epgProgramCount, '
        'playlistSourceCount: $playlistSourceCount, '
        'metadataFieldCount: $metadataFieldCount'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    kind,
    liveChannelCount,
    vodItemCount,
    epgProgramCount,
    playlistSourceCount,
    metadataFieldCount,
  ];
}

class AiroMediaBenchmarkWorkloadStep extends Equatable {
  const AiroMediaBenchmarkWorkloadStep({
    required this.stepId,
    required this.operation,
    required this.recordCount,
    this.queryCount = 0,
    this.concurrency = 1,
    this.schemaVersion = kAiroMediaDatabaseBenchmarkSchemaVersion,
  });

  final String schemaVersion;
  final String stepId;
  final AiroMediaBenchmarkOperation operation;
  final int recordCount;
  final int queryCount;
  final int concurrency;

  @override
  List<Object?> get props => [
    schemaVersion,
    stepId,
    operation,
    recordCount,
    queryCount,
    concurrency,
  ];
}

class AiroMediaBenchmarkBudget extends Equatable {
  const AiroMediaBenchmarkBudget({
    required this.maxElapsedMillis,
    required this.maxPeakMemoryMb,
    required this.maxStorageMb,
    required this.minRowsPerSecond,
    this.schemaVersion = kAiroMediaDatabaseBenchmarkSchemaVersion,
  });

  final String schemaVersion;
  final int maxElapsedMillis;
  final int maxPeakMemoryMb;
  final int maxStorageMb;
  final double minRowsPerSecond;

  @override
  List<Object?> get props => [
    schemaVersion,
    maxElapsedMillis,
    maxPeakMemoryMb,
    maxStorageMb,
    minRowsPerSecond,
  ];
}

class AiroMediaDatabaseBenchmarkPlan extends Equatable {
  AiroMediaDatabaseBenchmarkPlan({
    required this.planId,
    required this.dataset,
    required Iterable<AiroMediaBenchmarkWorkloadStep> steps,
    required Set<AiroMediaBenchmarkMetric> requiredMetrics,
    required this.budget,
    this.schemaVersion = kAiroMediaDatabaseBenchmarkSchemaVersion,
  }) : steps = List.unmodifiable(steps),
       requiredMetrics = Set.unmodifiable(requiredMetrics);

  final String schemaVersion;
  final String planId;
  final AiroMediaBenchmarkDatasetProfile dataset;
  final List<AiroMediaBenchmarkWorkloadStep> steps;
  final Set<AiroMediaBenchmarkMetric> requiredMetrics;
  final AiroMediaBenchmarkBudget budget;

  Set<String> get requiredStepIds =>
      Set.unmodifiable(steps.map((step) => step.stepId));

  @override
  List<Object?> get props => [
    schemaVersion,
    planId,
    dataset,
    steps,
    requiredMetrics,
    budget,
  ];
}

class AiroMediaBenchmarkMetricSample extends Equatable {
  const AiroMediaBenchmarkMetricSample({
    required this.stepId,
    required this.operation,
    required this.completedRecordCount,
    this.elapsedMillis,
    this.peakMemoryMb,
    this.storageMb,
    this.rowsPerSecond,
    this.schemaVersion = kAiroMediaDatabaseBenchmarkSchemaVersion,
  });

  final String schemaVersion;
  final String stepId;
  final AiroMediaBenchmarkOperation operation;
  final int completedRecordCount;
  final int? elapsedMillis;
  final int? peakMemoryMb;
  final int? storageMb;
  final double? rowsPerSecond;

  bool hasMetric(AiroMediaBenchmarkMetric metric) {
    return switch (metric) {
      AiroMediaBenchmarkMetric.elapsedMillis => elapsedMillis != null,
      AiroMediaBenchmarkMetric.peakMemoryMb => peakMemoryMb != null,
      AiroMediaBenchmarkMetric.storageMb => storageMb != null,
      AiroMediaBenchmarkMetric.rowsPerSecond => rowsPerSecond != null,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    stepId,
    operation,
    completedRecordCount,
    elapsedMillis,
    peakMemoryMb,
    storageMb,
    rowsPerSecond,
  ];
}

class AiroMediaDatabaseBenchmarkRun extends Equatable {
  AiroMediaDatabaseBenchmarkRun({
    required this.planId,
    required this.runnerId,
    required Iterable<AiroMediaBenchmarkMetricSample> samples,
    Set<String> failedStepIds = const {},
    this.schemaVersion = kAiroMediaDatabaseBenchmarkSchemaVersion,
  }) : samples = List.unmodifiable(samples),
       failedStepIds = Set.unmodifiable(failedStepIds);

  final String schemaVersion;
  final String planId;
  final String runnerId;
  final List<AiroMediaBenchmarkMetricSample> samples;
  final Set<String> failedStepIds;

  Set<String> get completedStepIds =>
      Set.unmodifiable(samples.map((sample) => sample.stepId));

  int get totalElapsedMillis => samples.fold<int>(
    0,
    (total, sample) => total + (sample.elapsedMillis ?? 0),
  );

  int get peakMemoryMb => samples.fold<int>(
    0,
    (peak, sample) => sample.peakMemoryMb != null && sample.peakMemoryMb! > peak
        ? sample.peakMemoryMb!
        : peak,
  );

  int get maxStorageMb => samples.fold<int>(
    0,
    (peak, sample) => sample.storageMb != null && sample.storageMb! > peak
        ? sample.storageMb!
        : peak,
  );

  double get minRowsPerSecond {
    final values = samples
        .map((sample) => sample.rowsPerSecond)
        .whereType<double>()
        .toList();
    if (values.isEmpty) {
      return 0;
    }
    values.sort();
    return values.first;
  }

  @override
  String toString() {
    return 'AiroMediaDatabaseBenchmarkRun('
        'planId: $planId, '
        'runnerId: $runnerId, '
        'sampleCount: ${samples.length}, '
        'failedStepCount: ${failedStepIds.length}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    planId,
    runnerId,
    samples,
    failedStepIds,
  ];
}

class AiroMediaDatabaseBenchmarkEvaluation extends Equatable {
  AiroMediaDatabaseBenchmarkEvaluation({
    required this.planId,
    required this.runnerId,
    required Iterable<AiroMediaBenchmarkBlockerCode> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final String planId;
  final String runnerId;
  final List<AiroMediaBenchmarkBlockerCode> blockers;

  bool get accepted =>
      blockers.length == 1 &&
      blockers.single == AiroMediaBenchmarkBlockerCode.accepted;

  @override
  List<Object?> get props => [planId, runnerId, blockers];
}

class AiroMediaDatabaseBenchmarkPolicy {
  const AiroMediaDatabaseBenchmarkPolicy({
    this.stableIdPolicy = const AiroMediaBenchmarkStableIdPolicy(),
  });

  final AiroMediaBenchmarkStableIdPolicy stableIdPolicy;

  AiroMediaDatabaseBenchmarkEvaluation evaluate({
    required AiroMediaDatabaseBenchmarkPlan plan,
    required AiroMediaDatabaseBenchmarkRun run,
  }) {
    final blockers = <AiroMediaBenchmarkBlockerCode>[];
    if (_hasUnsafeStableId(plan, run)) {
      blockers.add(AiroMediaBenchmarkBlockerCode.privacyUnsafeStableId);
    }
    if (run.failedStepIds.isNotEmpty) {
      blockers.add(AiroMediaBenchmarkBlockerCode.failedWorkload);
    }
    if (!run.completedStepIds.containsAll(plan.requiredStepIds)) {
      blockers.add(AiroMediaBenchmarkBlockerCode.incompleteWorkload);
    }
    if (_hasMissingMetric(plan: plan, run: run)) {
      blockers.add(AiroMediaBenchmarkBlockerCode.missingMetric);
    }
    if (run.totalElapsedMillis > plan.budget.maxElapsedMillis) {
      blockers.add(AiroMediaBenchmarkBlockerCode.overTimeBudget);
    }
    if (run.peakMemoryMb > plan.budget.maxPeakMemoryMb) {
      blockers.add(AiroMediaBenchmarkBlockerCode.overMemoryBudget);
    }
    if (run.maxStorageMb > plan.budget.maxStorageMb) {
      blockers.add(AiroMediaBenchmarkBlockerCode.overStorageBudget);
    }
    if (run.minRowsPerSecond < plan.budget.minRowsPerSecond) {
      blockers.add(AiroMediaBenchmarkBlockerCode.belowThroughputFloor);
    }

    return AiroMediaDatabaseBenchmarkEvaluation(
      planId: plan.planId,
      runnerId: run.runnerId,
      blockers: blockers.isEmpty
          ? const [AiroMediaBenchmarkBlockerCode.accepted]
          : blockers,
    );
  }

  bool _hasMissingMetric({
    required AiroMediaDatabaseBenchmarkPlan plan,
    required AiroMediaDatabaseBenchmarkRun run,
  }) {
    for (final sample in run.samples) {
      for (final metric in plan.requiredMetrics) {
        if (!sample.hasMetric(metric)) {
          return true;
        }
      }
    }
    return run.samples.isEmpty && plan.requiredMetrics.isNotEmpty;
  }

  bool _hasUnsafeStableId(
    AiroMediaDatabaseBenchmarkPlan plan,
    AiroMediaDatabaseBenchmarkRun run,
  ) {
    final values = <String>[
      plan.planId,
      plan.dataset.profileId,
      run.planId,
      run.runnerId,
      ...plan.steps.map((step) => step.stepId),
      ...run.samples.map((sample) => sample.stepId),
      ...run.failedStepIds,
    ];
    return values.any((value) => !stableIdPolicy.isSafe(value));
  }
}

abstract interface class AiroMediaDatabaseBenchmarkRunner {
  Future<AiroMediaDatabaseBenchmarkRun> run(
    AiroMediaDatabaseBenchmarkPlan plan,
  );
}

class AiroNoOpMediaDatabaseBenchmarkRunner
    implements AiroMediaDatabaseBenchmarkRunner {
  const AiroNoOpMediaDatabaseBenchmarkRunner({this.runnerId = 'noop'});

  final String runnerId;

  @override
  Future<AiroMediaDatabaseBenchmarkRun> run(
    AiroMediaDatabaseBenchmarkPlan plan,
  ) async {
    return AiroMediaDatabaseBenchmarkRun(
      planId: plan.planId,
      runnerId: runnerId,
      samples: const [],
    );
  }
}

class AiroFakeMediaDatabaseBenchmarkRunner
    implements AiroMediaDatabaseBenchmarkRunner {
  AiroFakeMediaDatabaseBenchmarkRunner({
    required Iterable<AiroMediaBenchmarkMetricSample> samples,
    Set<String> failedStepIds = const {},
    this.runnerId = 'fake',
  }) : samples = List.unmodifiable(samples),
       failedStepIds = Set.unmodifiable(failedStepIds);

  final String runnerId;
  final List<AiroMediaBenchmarkMetricSample> samples;
  final Set<String> failedStepIds;

  @override
  Future<AiroMediaDatabaseBenchmarkRun> run(
    AiroMediaDatabaseBenchmarkPlan plan,
  ) async {
    return AiroMediaDatabaseBenchmarkRun(
      planId: plan.planId,
      runnerId: runnerId,
      samples: samples,
      failedStepIds: failedStepIds,
    );
  }
}

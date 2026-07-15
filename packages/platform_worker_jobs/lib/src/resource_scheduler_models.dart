import 'package:equatable/equatable.dart';

const String kAiroWorkerSchedulerSchemaVersion = '1.0.0';
const int kAiroWorkerSchedulerProtocolVersion = 1;
const int kAiroWorkerSchedulerDefaultMaxConcurrentJobs = 2;
const int kAiroWorkerSchedulerDefaultMaxMemoryMb = 128;
const int kAiroWorkerSchedulerDefaultMaxStorageMb = 256;
const int kAiroWorkerSchedulerDefaultMaxCpuPercent = 50;

enum AiroWorkerJobKind {
  playbackRecovery('playback_recovery'),
  pairingSecurity('pairing_security'),
  protocolHeartbeat('protocol_heartbeat'),
  playlistImport('playlist_import'),
  epgRefresh('epg_refresh'),
  searchIndexing('search_indexing'),
  streamHealthProbe('stream_health_probe'),
  databaseCompaction('database_compaction'),
  artworkCacheWarmup('artwork_cache_warmup'),
  cacheCleanup('cache_cleanup'),
  deviceSync('device_sync'),
  modelDownload('model_download'),
  recordingPrep('recording_prep');

  const AiroWorkerJobKind(this.stableId);

  final String stableId;
}

enum AiroWorkerJobPriority {
  critical('critical'),
  high('high'),
  normal('normal'),
  low('low'),
  opportunistic('opportunistic');

  const AiroWorkerJobPriority(this.stableId);

  final String stableId;
}

enum AiroWorkerExecutionMode {
  foregroundCritical('foreground_critical'),
  playbackAdjacent('playback_adjacent'),
  background('background'),
  idleOnly('idle_only'),
  maintenance('maintenance');

  const AiroWorkerExecutionMode(this.stableId);

  final String stableId;
}

enum AiroWorkerInterruptibility {
  nonInterruptible('non_interruptible'),
  checkpointed('checkpointed'),
  cancellable('cancellable');

  const AiroWorkerInterruptibility(this.stableId);

  final String stableId;

  bool get canYield => this != nonInterruptible;
}

enum AiroWorkerPressureLevel {
  normal('normal'),
  elevated('elevated'),
  high('high'),
  critical('critical');

  const AiroWorkerPressureLevel(this.stableId);

  final String stableId;

  bool get blocksBackground => this == high || this == critical;

  bool get blocksAllNonCritical => this == critical;
}

enum AiroWorkerPlaybackState {
  idle('idle'),
  starting('starting'),
  playing('playing'),
  buffering('buffering'),
  recovering('recovering'),
  stopped('stopped');

  const AiroWorkerPlaybackState(this.stableId);

  final String stableId;

  bool get isActive =>
      this == starting ||
      this == playing ||
      this == buffering ||
      this == recovering;

  bool get isFragile =>
      this == starting || this == buffering || this == recovering;
}

enum AiroWorkerNetworkState {
  unavailable('unavailable'),
  metered('metered'),
  constrained('constrained'),
  unmetered('unmetered');

  const AiroWorkerNetworkState(this.stableId);

  final String stableId;
}

enum AiroWorkerSchedulerAction {
  schedule('schedule'),
  defer('defer'),
  throttle('throttle'),
  cancel('cancel'),
  reject('reject');

  const AiroWorkerSchedulerAction(this.stableId);

  final String stableId;
}

enum AiroWorkerSchedulerCode {
  accepted('accepted'),
  schemaMismatch('schema_mismatch'),
  protocolTooOld('protocol_too_old'),
  protocolTooNew('protocol_too_new'),
  unsafeStableId('unsafe_stable_id'),
  unsupportedJobKind('unsupported_job_kind'),
  expiredJob('expired_job'),
  playbackContention('playback_contention'),
  focusContention('focus_contention'),
  memoryPressure('memory_pressure'),
  storagePressure('storage_pressure'),
  thermalPressure('thermal_pressure'),
  lowBattery('low_battery'),
  networkUnavailable('network_unavailable'),
  meteredNetworkBlocked('metered_network_blocked'),
  concurrentJobLimit('concurrent_job_limit'),
  budgetExceeded('budget_exceeded'),
  nonInterruptibleConflict('non_interruptible_conflict'),
  adapterUnavailable('adapter_unavailable'),
  cancelled('cancelled');

  const AiroWorkerSchedulerCode(this.stableId);

  final String stableId;
}

enum AiroWorkerStableValueRejectionCode {
  empty('empty'),
  urlValue('url_value'),
  localPathValue('local_path_value'),
  localIpValue('local_ip_value'),
  credentialLikeValue('credential_like_value'),
  invalidStableId('invalid_stable_id');

  const AiroWorkerStableValueRejectionCode(this.stableId);

  final String stableId;
}

class AiroWorkerStableValue extends Equatable {
  const AiroWorkerStableValue._(this.value);

  factory AiroWorkerStableValue.stable(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroWorkerStableValue._(value.trim());
  }

  final String value;

  static AiroWorkerStableValueRejectionCode? validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return AiroWorkerStableValueRejectionCode.empty;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return AiroWorkerStableValueRejectionCode.urlValue;
    }
    if (trimmed.startsWith('file://') ||
        trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(trimmed)) {
      return AiroWorkerStableValueRejectionCode.localPathValue;
    }
    if (RegExp(
      r'\b(?:10|127|172\.(?:1[6-9]|2\d|3[0-1])|192\.168)\.',
    ).hasMatch(trimmed)) {
      return AiroWorkerStableValueRejectionCode.localIpValue;
    }
    if (RegExp(
      r'\b(?:bearer|basic)\s+[A-Za-z0-9._~+/=-]+',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return AiroWorkerStableValueRejectionCode.credentialLikeValue;
    }
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9_.-]*$').hasMatch(trimmed)) {
      return AiroWorkerStableValueRejectionCode.invalidStableId;
    }
    return null;
  }

  @override
  String toString() => 'AiroWorkerStableValue(redacted)';

  @override
  List<Object?> get props => [value];
}

class AiroWorkerResourceBudget extends Equatable {
  const AiroWorkerResourceBudget({
    this.maxMemoryMb = 0,
    this.maxStorageMb = 0,
    this.maxCpuPercent = 0,
    this.maxNetworkKbps = 0,
    this.expectedDuration = Duration.zero,
  }) : assert(maxMemoryMb >= 0),
       assert(maxStorageMb >= 0),
       assert(maxCpuPercent >= 0),
       assert(maxNetworkKbps >= 0);

  final int maxMemoryMb;
  final int maxStorageMb;
  final int maxCpuPercent;
  final int maxNetworkKbps;
  final Duration expectedDuration;

  bool exceeds(AiroWorkerResourceBudget limit) {
    return maxMemoryMb > limit.maxMemoryMb ||
        maxStorageMb > limit.maxStorageMb ||
        maxCpuPercent > limit.maxCpuPercent ||
        maxNetworkKbps > limit.maxNetworkKbps;
  }

  @override
  List<Object?> get props => [
    maxMemoryMb,
    maxStorageMb,
    maxCpuPercent,
    maxNetworkKbps,
    expectedDuration,
  ];
}

class AiroWorkerJobDescriptor extends Equatable {
  const AiroWorkerJobDescriptor({
    required this.jobId,
    required this.kind,
    required this.priority,
    required this.executionMode,
    required this.interruptibility,
    required this.budget,
    required this.createdAt,
    required this.expiresAt,
    this.requiresUnmeteredNetwork = false,
    this.requiresCharging = false,
    this.allowDuringPlayback = false,
    this.schemaVersion = kAiroWorkerSchedulerSchemaVersion,
    this.protocolVersion = kAiroWorkerSchedulerProtocolVersion,
  });

  final String schemaVersion;
  final int protocolVersion;
  final AiroWorkerStableValue jobId;
  final AiroWorkerJobKind kind;
  final AiroWorkerJobPriority priority;
  final AiroWorkerExecutionMode executionMode;
  final AiroWorkerInterruptibility interruptibility;
  final AiroWorkerResourceBudget budget;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool requiresUnmeteredNetwork;
  final bool requiresCharging;
  final bool allowDuringPlayback;

  bool isExpired(DateTime now) => !now.isBefore(expiresAt);

  bool get isCritical => priority == AiroWorkerJobPriority.critical;

  bool get isHeavy =>
      budget.maxMemoryMb >= 64 ||
      budget.maxCpuPercent >= 40 ||
      executionMode == AiroWorkerExecutionMode.idleOnly ||
      executionMode == AiroWorkerExecutionMode.maintenance;

  @override
  String toString() {
    return 'AiroWorkerJobDescriptor('
        'jobId: ${jobId.value}, '
        'kind: ${kind.stableId}, '
        'priority: ${priority.stableId}, '
        'executionMode: ${executionMode.stableId}, '
        'interruptibility: ${interruptibility.stableId}'
        ')';
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    protocolVersion,
    jobId,
    kind,
    priority,
    executionMode,
    interruptibility,
    budget,
    createdAt,
    expiresAt,
    requiresUnmeteredNetwork,
    requiresCharging,
    allowDuringPlayback,
  ];
}

class AiroWorkerRunningJob extends Equatable {
  const AiroWorkerRunningJob({
    required this.jobId,
    required this.kind,
    required this.priority,
    required this.interruptibility,
    required this.startedAt,
  });

  final AiroWorkerStableValue jobId;
  final AiroWorkerJobKind kind;
  final AiroWorkerJobPriority priority;
  final AiroWorkerInterruptibility interruptibility;
  final DateTime startedAt;

  bool get canYield => interruptibility.canYield;

  @override
  List<Object?> get props => [
    jobId,
    kind,
    priority,
    interruptibility,
    startedAt,
  ];
}

class AiroWorkerResourceSnapshot extends Equatable {
  AiroWorkerResourceSnapshot({
    required this.capturedAt,
    required this.playbackState,
    required this.memoryPressure,
    required this.storagePressure,
    required this.thermalPressure,
    required this.networkState,
    required Iterable<AiroWorkerRunningJob> runningJobs,
    this.focusNavigationActive = false,
    this.batteryPercent = 100,
    this.isCharging = true,
  }) : assert(batteryPercent >= 0 && batteryPercent <= 100),
       runningJobs = List.unmodifiable(runningJobs);

  final DateTime capturedAt;
  final AiroWorkerPlaybackState playbackState;
  final bool focusNavigationActive;
  final AiroWorkerPressureLevel memoryPressure;
  final AiroWorkerPressureLevel storagePressure;
  final AiroWorkerPressureLevel thermalPressure;
  final int batteryPercent;
  final bool isCharging;
  final AiroWorkerNetworkState networkState;
  final List<AiroWorkerRunningJob> runningJobs;

  bool get hasActivePlayback => playbackState.isActive;

  bool get hasCriticalPressure =>
      memoryPressure.blocksAllNonCritical ||
      storagePressure.blocksAllNonCritical ||
      thermalPressure.blocksAllNonCritical;

  @override
  List<Object?> get props => [
    capturedAt,
    playbackState,
    focusNavigationActive,
    memoryPressure,
    storagePressure,
    thermalPressure,
    batteryPercent,
    isCharging,
    networkState,
    runningJobs,
  ];
}

class AiroWorkerSchedulerPolicy extends Equatable {
  AiroWorkerSchedulerPolicy({
    Set<AiroWorkerJobKind> supportedJobKinds = const {
      AiroWorkerJobKind.playbackRecovery,
      AiroWorkerJobKind.pairingSecurity,
      AiroWorkerJobKind.protocolHeartbeat,
      AiroWorkerJobKind.playlistImport,
      AiroWorkerJobKind.epgRefresh,
      AiroWorkerJobKind.searchIndexing,
      AiroWorkerJobKind.streamHealthProbe,
      AiroWorkerJobKind.databaseCompaction,
      AiroWorkerJobKind.artworkCacheWarmup,
      AiroWorkerJobKind.cacheCleanup,
      AiroWorkerJobKind.deviceSync,
      AiroWorkerJobKind.modelDownload,
      AiroWorkerJobKind.recordingPrep,
    },
    this.acceptedSchemaVersion = kAiroWorkerSchedulerSchemaVersion,
    this.minProtocolVersion = kAiroWorkerSchedulerProtocolVersion,
    this.maxProtocolVersion = kAiroWorkerSchedulerProtocolVersion,
    this.maxConcurrentJobs = kAiroWorkerSchedulerDefaultMaxConcurrentJobs,
    this.minBatteryPercent = 20,
    this.maxBudget = const AiroWorkerResourceBudget(
      maxMemoryMb: kAiroWorkerSchedulerDefaultMaxMemoryMb,
      maxStorageMb: kAiroWorkerSchedulerDefaultMaxStorageMb,
      maxCpuPercent: kAiroWorkerSchedulerDefaultMaxCpuPercent,
      maxNetworkKbps: 4096,
      expectedDuration: Duration(minutes: 15),
    ),
  }) : supportedJobKinds = Set.unmodifiable(supportedJobKinds);

  final String acceptedSchemaVersion;
  final int minProtocolVersion;
  final int maxProtocolVersion;
  final int maxConcurrentJobs;
  final int minBatteryPercent;
  final AiroWorkerResourceBudget maxBudget;
  final Set<AiroWorkerJobKind> supportedJobKinds;

  AiroWorkerSchedulerDecision evaluate({
    required AiroWorkerJobDescriptor job,
    required AiroWorkerResourceSnapshot snapshot,
    required DateTime now,
  }) {
    final codes = <AiroWorkerSchedulerCode>[];

    if (job.schemaVersion != acceptedSchemaVersion) {
      codes.add(AiroWorkerSchedulerCode.schemaMismatch);
    }
    if (job.protocolVersion < minProtocolVersion) {
      codes.add(AiroWorkerSchedulerCode.protocolTooOld);
    }
    if (job.protocolVersion > maxProtocolVersion) {
      codes.add(AiroWorkerSchedulerCode.protocolTooNew);
    }
    if (!supportedJobKinds.contains(job.kind)) {
      codes.add(AiroWorkerSchedulerCode.unsupportedJobKind);
    }
    if (job.isExpired(now)) {
      codes.add(AiroWorkerSchedulerCode.expiredJob);
    }
    if (AiroWorkerStableValue.validate(job.jobId.value) != null) {
      codes.add(AiroWorkerSchedulerCode.unsafeStableId);
    }
    if (job.budget.exceeds(maxBudget)) {
      codes.add(AiroWorkerSchedulerCode.budgetExceeded);
    }
    _addPressureCodes(job, snapshot, codes);
    _addNetworkCodes(job, snapshot, codes);
    _addConcurrencyCodes(job, snapshot, codes);

    return AiroWorkerSchedulerDecision(
      jobId: job.jobId,
      action: _actionFor(codes, job),
      codes: codes.isEmpty ? const [AiroWorkerSchedulerCode.accepted] : codes,
    );
  }

  void _addPressureCodes(
    AiroWorkerJobDescriptor job,
    AiroWorkerResourceSnapshot snapshot,
    List<AiroWorkerSchedulerCode> codes,
  ) {
    if (snapshot.hasActivePlayback &&
        job.isHeavy &&
        !job.allowDuringPlayback &&
        !job.isCritical) {
      codes.add(AiroWorkerSchedulerCode.playbackContention);
    }
    if (snapshot.focusNavigationActive &&
        job.isHeavy &&
        job.priority.index > AiroWorkerJobPriority.high.index) {
      codes.add(AiroWorkerSchedulerCode.focusContention);
    }
    if (snapshot.memoryPressure.blocksBackground && !job.isCritical) {
      codes.add(AiroWorkerSchedulerCode.memoryPressure);
    }
    if (snapshot.storagePressure.blocksBackground &&
        job.kind != AiroWorkerJobKind.cacheCleanup &&
        !job.isCritical) {
      codes.add(AiroWorkerSchedulerCode.storagePressure);
    }
    if (snapshot.thermalPressure.blocksBackground && !job.isCritical) {
      codes.add(AiroWorkerSchedulerCode.thermalPressure);
    }
    if (!snapshot.isCharging &&
        snapshot.batteryPercent < minBatteryPercent &&
        !job.isCritical) {
      codes.add(AiroWorkerSchedulerCode.lowBattery);
    }
  }

  void _addNetworkCodes(
    AiroWorkerJobDescriptor job,
    AiroWorkerResourceSnapshot snapshot,
    List<AiroWorkerSchedulerCode> codes,
  ) {
    if (job.budget.maxNetworkKbps <= 0) return;
    if (snapshot.networkState == AiroWorkerNetworkState.unavailable) {
      codes.add(AiroWorkerSchedulerCode.networkUnavailable);
    }
    if (job.requiresUnmeteredNetwork &&
        snapshot.networkState == AiroWorkerNetworkState.metered) {
      codes.add(AiroWorkerSchedulerCode.meteredNetworkBlocked);
    }
  }

  void _addConcurrencyCodes(
    AiroWorkerJobDescriptor job,
    AiroWorkerResourceSnapshot snapshot,
    List<AiroWorkerSchedulerCode> codes,
  ) {
    if (snapshot.runningJobs.length >= maxConcurrentJobs) {
      final canPreempt =
          job.isCritical &&
          snapshot.runningJobs.any((runningJob) => runningJob.canYield);
      if (canPreempt) {
        codes.add(AiroWorkerSchedulerCode.cancelled);
      } else {
        codes.add(AiroWorkerSchedulerCode.concurrentJobLimit);
      }
    }
    if (job.interruptibility == AiroWorkerInterruptibility.nonInterruptible &&
        snapshot.runningJobs.any(
          (runningJob) =>
              runningJob.interruptibility ==
              AiroWorkerInterruptibility.nonInterruptible,
        )) {
      codes.add(AiroWorkerSchedulerCode.nonInterruptibleConflict);
    }
  }

  AiroWorkerSchedulerAction _actionFor(
    List<AiroWorkerSchedulerCode> codes,
    AiroWorkerJobDescriptor job,
  ) {
    if (codes.isEmpty) return AiroWorkerSchedulerAction.schedule;
    if (codes.any(_isRejectCode)) return AiroWorkerSchedulerAction.reject;
    if (codes.contains(AiroWorkerSchedulerCode.cancelled) && job.isCritical) {
      return AiroWorkerSchedulerAction.cancel;
    }
    if (codes.any(_isThrottleCode)) return AiroWorkerSchedulerAction.throttle;
    return AiroWorkerSchedulerAction.defer;
  }

  bool _isRejectCode(AiroWorkerSchedulerCode code) {
    return code == AiroWorkerSchedulerCode.schemaMismatch ||
        code == AiroWorkerSchedulerCode.protocolTooOld ||
        code == AiroWorkerSchedulerCode.protocolTooNew ||
        code == AiroWorkerSchedulerCode.unsafeStableId ||
        code == AiroWorkerSchedulerCode.unsupportedJobKind ||
        code == AiroWorkerSchedulerCode.expiredJob ||
        code == AiroWorkerSchedulerCode.budgetExceeded ||
        code == AiroWorkerSchedulerCode.networkUnavailable ||
        code == AiroWorkerSchedulerCode.nonInterruptibleConflict;
  }

  bool _isThrottleCode(AiroWorkerSchedulerCode code) {
    return code == AiroWorkerSchedulerCode.memoryPressure ||
        code == AiroWorkerSchedulerCode.storagePressure ||
        code == AiroWorkerSchedulerCode.thermalPressure;
  }

  @override
  List<Object?> get props => [
    acceptedSchemaVersion,
    minProtocolVersion,
    maxProtocolVersion,
    maxConcurrentJobs,
    minBatteryPercent,
    maxBudget,
    supportedJobKinds,
  ];
}

class AiroWorkerSchedulerDecision extends Equatable {
  AiroWorkerSchedulerDecision({
    required this.jobId,
    required this.action,
    required Iterable<AiroWorkerSchedulerCode> codes,
  }) : codes = List.unmodifiable(codes);

  final AiroWorkerStableValue jobId;
  final AiroWorkerSchedulerAction action;
  final List<AiroWorkerSchedulerCode> codes;

  bool get accepted =>
      action == AiroWorkerSchedulerAction.schedule &&
      codes.length == 1 &&
      codes.single == AiroWorkerSchedulerCode.accepted;

  Map<String, Object?> toDiagnosticMap() {
    return {
      'jobId': jobId.value,
      'action': action.stableId,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [jobId, action, codes];
}

abstract interface class AiroWorkerJobScheduler {
  Future<AiroWorkerSchedulerDecision> schedule({
    required AiroWorkerJobDescriptor job,
    required AiroWorkerResourceSnapshot snapshot,
    required DateTime now,
  });

  Future<AiroWorkerSchedulerDecision> cancel(AiroWorkerStableValue jobId);
}

class AiroNoOpWorkerJobScheduler implements AiroWorkerJobScheduler {
  const AiroNoOpWorkerJobScheduler();

  @override
  Future<AiroWorkerSchedulerDecision> schedule({
    required AiroWorkerJobDescriptor job,
    required AiroWorkerResourceSnapshot snapshot,
    required DateTime now,
  }) async {
    return AiroWorkerSchedulerDecision(
      jobId: job.jobId,
      action: AiroWorkerSchedulerAction.reject,
      codes: const [AiroWorkerSchedulerCode.adapterUnavailable],
    );
  }

  @override
  Future<AiroWorkerSchedulerDecision> cancel(
    AiroWorkerStableValue jobId,
  ) async {
    return AiroWorkerSchedulerDecision(
      jobId: jobId,
      action: AiroWorkerSchedulerAction.reject,
      codes: const [AiroWorkerSchedulerCode.adapterUnavailable],
    );
  }
}

class AiroFakeWorkerJobScheduler implements AiroWorkerJobScheduler {
  AiroFakeWorkerJobScheduler({required this.policy});

  final AiroWorkerSchedulerPolicy policy;
  final List<AiroWorkerJobDescriptor> scheduledJobs = [];
  final Set<AiroWorkerStableValue> cancelledJobIds = {};

  @override
  Future<AiroWorkerSchedulerDecision> schedule({
    required AiroWorkerJobDescriptor job,
    required AiroWorkerResourceSnapshot snapshot,
    required DateTime now,
  }) async {
    final decision = policy.evaluate(job: job, snapshot: snapshot, now: now);
    if (decision.accepted ||
        decision.action == AiroWorkerSchedulerAction.cancel) {
      scheduledJobs.add(job);
    }
    return decision;
  }

  @override
  Future<AiroWorkerSchedulerDecision> cancel(
    AiroWorkerStableValue jobId,
  ) async {
    cancelledJobIds.add(jobId);
    return AiroWorkerSchedulerDecision(
      jobId: jobId,
      action: AiroWorkerSchedulerAction.cancel,
      codes: const [AiroWorkerSchedulerCode.cancelled],
    );
  }
}

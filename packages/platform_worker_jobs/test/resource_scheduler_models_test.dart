import 'package:flutter_test/flutter_test.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';

void main() {
  group('Airo worker resource scheduler contract', () {
    final now = DateTime.utc(2026, 7, 14, 12);
    final policy = AiroWorkerSchedulerPolicy();

    test('schedules lightweight protocol job during active playback', () {
      final decision = policy.evaluate(
        job: _job(
          now: now,
          kind: AiroWorkerJobKind.protocolHeartbeat,
          priority: AiroWorkerJobPriority.high,
          executionMode: AiroWorkerExecutionMode.playbackAdjacent,
          budget: const AiroWorkerResourceBudget(
            maxMemoryMb: 4,
            maxCpuPercent: 2,
          ),
          allowDuringPlayback: true,
        ),
        snapshot: _snapshot(
          now: now,
          playbackState: AiroWorkerPlaybackState.playing,
        ),
        now: now,
      );

      expect(decision.accepted, isTrue);
      expect(decision.toDiagnosticMap(), {
        'jobId': 'job-1',
        'action': AiroWorkerSchedulerAction.schedule.stableId,
        'codes': [AiroWorkerSchedulerCode.accepted.stableId],
      });
    });

    test('defers heavy import while playback and focus are active', () {
      final decision = policy.evaluate(
        job: _job(
          now: now,
          kind: AiroWorkerJobKind.playlistImport,
          executionMode: AiroWorkerExecutionMode.background,
          budget: const AiroWorkerResourceBudget(
            maxMemoryMb: 96,
            maxCpuPercent: 45,
            maxNetworkKbps: 512,
          ),
        ),
        snapshot: _snapshot(
          now: now,
          playbackState: AiroWorkerPlaybackState.buffering,
          focusNavigationActive: true,
        ),
        now: now,
      );

      expect(decision.action, AiroWorkerSchedulerAction.defer);
      expect(
        decision.codes,
        contains(AiroWorkerSchedulerCode.playbackContention),
      );
      expect(decision.codes, contains(AiroWorkerSchedulerCode.focusContention));
    });

    test('throttles non-critical jobs under resource pressure', () {
      final decision = policy.evaluate(
        job: _job(
          now: now,
          kind: AiroWorkerJobKind.epgRefresh,
          budget: const AiroWorkerResourceBudget(
            maxMemoryMb: 32,
            maxCpuPercent: 20,
          ),
        ),
        snapshot: _snapshot(
          now: now,
          memoryPressure: AiroWorkerPressureLevel.high,
          storagePressure: AiroWorkerPressureLevel.high,
          thermalPressure: AiroWorkerPressureLevel.high,
        ),
        now: now,
      );

      expect(decision.action, AiroWorkerSchedulerAction.throttle);
      expect(decision.codes, contains(AiroWorkerSchedulerCode.memoryPressure));
      expect(decision.codes, contains(AiroWorkerSchedulerCode.storagePressure));
      expect(decision.codes, contains(AiroWorkerSchedulerCode.thermalPressure));
    });

    test('rejects expired over-budget unsupported jobs', () {
      final restrictedPolicy = AiroWorkerSchedulerPolicy(
        supportedJobKinds: const {AiroWorkerJobKind.protocolHeartbeat},
        maxBudget: const AiroWorkerResourceBudget(
          maxMemoryMb: 8,
          maxStorageMb: 8,
          maxCpuPercent: 5,
          maxNetworkKbps: 10,
        ),
      );

      final decision = restrictedPolicy.evaluate(
        job: _job(
          now: now,
          kind: AiroWorkerJobKind.modelDownload,
          expiresAt: now.subtract(const Duration(seconds: 1)),
          budget: const AiroWorkerResourceBudget(
            maxMemoryMb: 64,
            maxStorageMb: 512,
            maxCpuPercent: 30,
            maxNetworkKbps: 4096,
          ),
        ),
        snapshot: _snapshot(now: now),
        now: now,
      );

      expect(decision.action, AiroWorkerSchedulerAction.reject);
      expect(
        decision.codes,
        contains(AiroWorkerSchedulerCode.unsupportedJobKind),
      );
      expect(decision.codes, contains(AiroWorkerSchedulerCode.expiredJob));
      expect(decision.codes, contains(AiroWorkerSchedulerCode.budgetExceeded));
    });

    test('defer and reject network and battery constrained work', () {
      final meteredDecision = policy.evaluate(
        job: _job(
          now: now,
          kind: AiroWorkerJobKind.deviceSync,
          requiresUnmeteredNetwork: true,
          budget: const AiroWorkerResourceBudget(maxNetworkKbps: 256),
        ),
        snapshot: _snapshot(
          now: now,
          networkState: AiroWorkerNetworkState.metered,
          batteryPercent: 10,
          isCharging: false,
        ),
        now: now,
      );
      final offlineDecision = policy.evaluate(
        job: _job(
          now: now,
          kind: AiroWorkerJobKind.deviceSync,
          budget: const AiroWorkerResourceBudget(maxNetworkKbps: 256),
        ),
        snapshot: _snapshot(
          now: now,
          networkState: AiroWorkerNetworkState.unavailable,
        ),
        now: now,
      );

      expect(meteredDecision.action, AiroWorkerSchedulerAction.defer);
      expect(
        meteredDecision.codes,
        contains(AiroWorkerSchedulerCode.meteredNetworkBlocked),
      );
      expect(
        meteredDecision.codes,
        contains(AiroWorkerSchedulerCode.lowBattery),
      );
      expect(offlineDecision.action, AiroWorkerSchedulerAction.reject);
      expect(
        offlineDecision.codes,
        contains(AiroWorkerSchedulerCode.networkUnavailable),
      );
    });

    test('critical job can preempt lower priority interruptible work', () {
      final running = AiroWorkerRunningJob(
        jobId: AiroWorkerStableValue.stable('running-import'),
        kind: AiroWorkerJobKind.playlistImport,
        priority: AiroWorkerJobPriority.normal,
        interruptibility: AiroWorkerInterruptibility.checkpointed,
        startedAt: now.subtract(const Duration(minutes: 1)),
      );

      final decision = AiroWorkerSchedulerPolicy(maxConcurrentJobs: 1).evaluate(
        job: _job(
          now: now,
          kind: AiroWorkerJobKind.playbackRecovery,
          priority: AiroWorkerJobPriority.critical,
          executionMode: AiroWorkerExecutionMode.foregroundCritical,
          budget: const AiroWorkerResourceBudget(
            maxMemoryMb: 8,
            maxCpuPercent: 5,
          ),
        ),
        snapshot: _snapshot(now: now, runningJobs: [running]),
        now: now,
      );

      expect(decision.action, AiroWorkerSchedulerAction.cancel);
      expect(decision.codes, contains(AiroWorkerSchedulerCode.cancelled));
    });

    test('rejects non-interruptible conflicts', () {
      final running = AiroWorkerRunningJob(
        jobId: AiroWorkerStableValue.stable('running-db-compaction'),
        kind: AiroWorkerJobKind.databaseCompaction,
        priority: AiroWorkerJobPriority.normal,
        interruptibility: AiroWorkerInterruptibility.nonInterruptible,
        startedAt: now.subtract(const Duration(minutes: 1)),
      );

      final decision = policy.evaluate(
        job: _job(
          now: now,
          kind: AiroWorkerJobKind.recordingPrep,
          interruptibility: AiroWorkerInterruptibility.nonInterruptible,
        ),
        snapshot: _snapshot(now: now, runningJobs: [running]),
        now: now,
      );

      expect(decision.action, AiroWorkerSchedulerAction.reject);
      expect(
        decision.codes,
        contains(AiroWorkerSchedulerCode.nonInterruptibleConflict),
      );
    });

    test('stable value rejects raw locations and credential material', () {
      expect(
        () => AiroWorkerStableValue.stable('https://example.com/job'),
        throwsArgumentError,
      );
      expect(
        () => AiroWorkerStableValue.stable('/Users/me/job'),
        throwsArgumentError,
      );
      expect(
        () => AiroWorkerStableValue.stable('192.168.1.15'),
        throwsArgumentError,
      );
      expect(
        () => AiroWorkerStableValue.stable('Bearer abc123'),
        throwsArgumentError,
      );
    });

    test('no-op scheduler rejects schedule and cancel', () async {
      const scheduler = AiroNoOpWorkerJobScheduler();

      final scheduleDecision = await scheduler.schedule(
        job: _job(now: now),
        snapshot: _snapshot(now: now),
        now: now,
      );
      final cancelDecision = await scheduler.cancel(
        AiroWorkerStableValue.stable('job-1'),
      );

      expect(scheduleDecision.action, AiroWorkerSchedulerAction.reject);
      expect(
        scheduleDecision.codes,
        contains(AiroWorkerSchedulerCode.adapterUnavailable),
      );
      expect(cancelDecision.action, AiroWorkerSchedulerAction.reject);
    });

    test('fake scheduler records scheduled and cancelled jobs', () async {
      final scheduler = AiroFakeWorkerJobScheduler(policy: policy);
      final job = _job(now: now);

      final scheduleDecision = await scheduler.schedule(
        job: job,
        snapshot: _snapshot(now: now),
        now: now,
      );
      final cancelDecision = await scheduler.cancel(job.jobId);

      expect(scheduleDecision.accepted, isTrue);
      expect(scheduler.scheduledJobs, [job]);
      expect(cancelDecision.action, AiroWorkerSchedulerAction.cancel);
      expect(scheduler.cancelledJobIds, contains(job.jobId));
    });
  });
}

AiroWorkerJobDescriptor _job({
  required DateTime now,
  AiroWorkerJobKind kind = AiroWorkerJobKind.cacheCleanup,
  AiroWorkerJobPriority priority = AiroWorkerJobPriority.normal,
  AiroWorkerExecutionMode executionMode = AiroWorkerExecutionMode.background,
  AiroWorkerInterruptibility interruptibility =
      AiroWorkerInterruptibility.checkpointed,
  AiroWorkerResourceBudget budget = const AiroWorkerResourceBudget(
    maxMemoryMb: 16,
    maxStorageMb: 16,
    maxCpuPercent: 10,
  ),
  DateTime? expiresAt,
  bool requiresUnmeteredNetwork = false,
  bool requiresCharging = false,
  bool allowDuringPlayback = false,
}) {
  return AiroWorkerJobDescriptor(
    jobId: AiroWorkerStableValue.stable('job-1'),
    kind: kind,
    priority: priority,
    executionMode: executionMode,
    interruptibility: interruptibility,
    budget: budget,
    createdAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(minutes: 5)),
    requiresUnmeteredNetwork: requiresUnmeteredNetwork,
    requiresCharging: requiresCharging,
    allowDuringPlayback: allowDuringPlayback,
  );
}

AiroWorkerResourceSnapshot _snapshot({
  required DateTime now,
  AiroWorkerPlaybackState playbackState = AiroWorkerPlaybackState.idle,
  bool focusNavigationActive = false,
  AiroWorkerPressureLevel memoryPressure = AiroWorkerPressureLevel.normal,
  AiroWorkerPressureLevel storagePressure = AiroWorkerPressureLevel.normal,
  AiroWorkerPressureLevel thermalPressure = AiroWorkerPressureLevel.normal,
  int batteryPercent = 100,
  bool isCharging = true,
  AiroWorkerNetworkState networkState = AiroWorkerNetworkState.unmetered,
  Iterable<AiroWorkerRunningJob> runningJobs = const [],
}) {
  return AiroWorkerResourceSnapshot(
    capturedAt: now,
    playbackState: playbackState,
    focusNavigationActive: focusNavigationActive,
    memoryPressure: memoryPressure,
    storagePressure: storagePressure,
    thermalPressure: thermalPressure,
    batteryPercent: batteryPercent,
    isCharging: isCharging,
    networkState: networkState,
    runningJobs: runningJobs,
  );
}

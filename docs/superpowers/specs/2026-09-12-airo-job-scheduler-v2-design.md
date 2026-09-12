# `airo_job_scheduler` v2.0 Architecture & Design Specification

> **Date**: 2026-09-12  
> **Status**: Approved Specification  
> **Package Target**: `DevelopersCoffee/airo_job_scheduler` (v2.0.0)  
> **Monorepo Shim**: `packages/platform_worker_jobs`  

---

## 1. Executive Summary

`airo_job_scheduler` v2.0 evolves the library from a foreground Dart isolate task pool into an enterprise-ready, cross-platform federated job scheduler. It unifies foreground cooperative isolate scheduling, persistent ACID queueing (SQLite/IndexedDB), background handoff to native OS schedulers (Android Jetpack `WorkManager`, iOS `BGTaskScheduler`), and zero-GC main thread frame yielding for games.

---

## 2. Architectural Layering & Federated Model

```text
 ┌────────────────────────────────────────────────────────────────────────┐
 │                      airo_job_scheduler (App API)                      │
 └──────────────────────────────────┬─────────────────────────────────────┘
                                    │
 ┌──────────────────────────────────▼─────────────────────────────────────┐
 │               airo_job_scheduler_platform_interface                    │
 └─────────┬────────────────────────┬────────────────────────┬────────────┘
           │                        │                        │
 ┌─────────▼──────────┐   ┌─────────▼──────────┐   ┌─────────▼──────────┐
 │ ..._android        │   │ ..._ios            │   │ ..._web            │
 │ WorkManager        │   │ BGTaskScheduler    │   │ WebWorker/Timer    │
 └────────────────────┘   └────────────────────┘   └────────────────────┘
```

The system is structured as 5 federated Dart pub packages:

1. **`airo_job_scheduler_platform_interface`**: Shared models (`JobTask`, `JobConstraints`, `RetryPolicy`), abstract platform interface contracts, and method channel definitions.
2. **`airo_job_scheduler`**: Main user-facing entrypoint providing the `SchedulerEngine`, SQLite persistent queue manager, isolate pool manager, and telemetry event stream.
3. **`airo_job_scheduler_android`**: Native Kotlin plugin wrapping Android Jetpack `WorkManager` (`CoroutineWorker`) for native background execution.
4. **`airo_job_scheduler_ios`**: Native Swift plugin wrapping iOS `BGTaskScheduler` (`BGAppRefreshTask`, `BGProcessingTask`).
5. **`airo_job_scheduler_web`**: Pure Web Worker and `Timer`-based queue fallback.

---

## 3. Public API Specification

```dart
/// System constraints for executing background & worker jobs.
class JobConstraints {
  final NetworkStateConstraint network;
  final PowerStateConstraint power;
  final DeviceIdleConstraint idle;
  final int minStorageSpaceBytes;
  final Duration? maxExecutionTime;

  const JobConstraints({
    this.network = NetworkStateConstraint.none,
    this.power = PowerStateConstraint.none,
    this.idle = DeviceIdleConstraint.none,
    this.minStorageSpaceBytes = 0,
    this.maxExecutionTime,
  });
}

/// Exponential backoff policy with randomized full jitter.
class RetryPolicy {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final bool useJitter;

  const RetryPolicy({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 30),
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
  });

  Duration calculateDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;
    double delayMs = initialDelay.inMilliseconds * 
        (math.pow(backoffMultiplier, attempt - 1));
    if (delayMs > maxDelay.inMilliseconds) {
      delayMs = maxDelay.inMilliseconds.toDouble();
    }
    if (useJitter) {
      final random = math.Random();
      delayMs = delayMs * (0.5 + random.nextDouble() * 0.5);
    }
    return Duration(milliseconds: delayMs.round());
  }
}
```

---

## 4. Persistent ACID Storage Schema & Lifecycle State Machine

### SQLite Database Table Definitions

```sql
CREATE TABLE IF NOT EXISTS scheduled_jobs (
    job_id TEXT PRIMARY KEY NOT NULL,
    tag TEXT NOT NULL,
    priority INTEGER NOT NULL DEFAULT 50,
    status TEXT NOT NULL DEFAULT 'queued',
    constraints_json TEXT NOT NULL,
    retry_policy_json TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    encrypted INTEGER NOT NULL DEFAULT 0,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    scheduled_at INTEGER NOT NULL,
    next_run_at INTEGER NOT NULL,
    last_run_at INTEGER,
    completed_at INTEGER,
    error_message TEXT,
    stack_trace TEXT,
    created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_jobs_status_next_run 
ON scheduled_jobs(status, next_run_at, priority DESC);

CREATE INDEX IF NOT EXISTS idx_jobs_tag 
ON scheduled_jobs(tag);

CREATE TABLE IF NOT EXISTS job_execution_logs (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id TEXT NOT NULL,
    event_type TEXT NOT NULL,
    progress REAL DEFAULT 0.0,
    details TEXT,
    timestamp INTEGER NOT NULL,
    FOREIGN KEY(job_id) REFERENCES scheduled_jobs(job_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS job_dependencies (
    parent_job_id TEXT NOT NULL,
    child_job_id TEXT NOT NULL,
    required_status TEXT NOT NULL DEFAULT 'completed',
    PRIMARY KEY (parent_job_id, child_job_id),
    FOREIGN KEY(parent_job_id) REFERENCES scheduled_jobs(job_id) ON DELETE CASCADE,
    FOREIGN KEY(child_job_id) REFERENCES scheduled_jobs(job_id) ON DELETE CASCADE
);
```

### State Machine Lifecycle

```text
 [Enqueued] ────► [Queued] ────► [Scheduled] ────► [InFlight] ────► [Completed]
                                      ▲                 │
                                      │                 ├──► [Throttled]
                                      │                 │         │
                                      │                 │         ▼
                                      └─────────────────┴──── [Failed] ────► [DeadLetter]
```

---

## 5. Verification & Compliance Standards

1. **Static Analysis**: Zero analyzer warnings or errors with `flutter_lints` across all 5 package components.
2. **Test Coverage**: >90% unit test coverage for `RetryPolicy`, `JobConstraints`, SQLite migrations, queue deduplication, and isolate pool lifecycle.
3. **pub.dev Points**: 140/140 points target for standalone publication.

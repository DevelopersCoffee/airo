# Platform Jobs

`platform_jobs` is the asynchronous execution engine for AIRO.

This package owns the execution semantics for all background and long-running operations in the system, including downloads, Whisper transcription, embedding generation, OCR, and workflows.

**It does not contain business logic.** Feature packages submit work. `platform_jobs` schedules and monitors it.

## Principles
1. **Typed Jobs:** Every job implements `Job<T>` where `T` is a strongly-typed payload.
2. **Worker Model:** Workers are registered for specific Job types. Jobs hold the data, workers hold the execution logic.
3. **Cancellation:** Cancellation is cooperative via `JobCancellationToken`.
4. **Retry Policies:** Transients failures are managed internally via `RetryPolicy` (e.g. exponential backoff).
5. **Observability:** State transitions emit typed telemetry (`JobQueuedEvent`, `JobStartedEvent`, `JobSucceededEvent`) through `platform_events`.

## Public API
- `JobScheduler`: Enqueues work, registers workers, and manages active tasks.
- `JobWorker`: Executes a specific typed job.
- `JobMonitor`: Exposes real-time queue depth and execution stats.
- `JobCancellationToken`: Allows tasks to exit cleanly without corrupting state.

## Rules
- Feature packages are forbidden from managing their own thread pools or long-running async closures.
- Jobs must be idempotent to allow safe retry behavior.

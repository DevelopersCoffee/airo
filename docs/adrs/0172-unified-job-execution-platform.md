# ADR 0172: Unified Job Execution Platform

## Status
Accepted

## Context
AIRO relies heavily on asynchronous, heavy workloads: large model downloads, on-device Whisper transcriptions, embedding generation, RAG indexing, and MCP (Model Context Protocol) executions.
If every feature package creates its own background isolate, manages its own retry logic, and attempts to report progress individually, we will have a chaotic, unmonitorable system. Hard crashes, out-of-memory errors, and race conditions are inevitable.

## Decision
We introduce `platform_jobs` to serve as the singular execution engine for AIRO.

1. **Job vs Worker Separation:** A `Job` is merely an immutable, strongly-typed configuration (payload, priority, queue, retry policy). The actual execution logic lives in a `JobWorker` which is registered during bootstrap.
2. **Queue Architecture:** Jobs are organized into logical queues (`downloads`, `runtime`, `meetings`, `memory`) to allow for distinct concurrency limits and prioritization later.
3. **Retry Strategy:** The scheduler itself owns retry semantics. A job definition declares its `RetryPolicy` (e.g., `linearBackoff`), and the scheduler manages the delay and execution looping.
4. **Cooperative Cancellation:** To prevent corrupting disk states, forced termination is forbidden. Every worker receives a `JobCancellationToken` and is expected to check `token.isCancelled` during heavy loops.
5. **Scheduler Ownership:** Feature packages submit jobs to the `JobScheduler`. They do not await the job directly; instead, they observe success/failure via `platform_events` or the `JobMonitor`.

## Consequences
**Positive:**
- Complete observability: we can build a diagnostic screen showing exactly what the app is doing at any microsecond.
- Safe retries and cancellation for huge downloads.
- Future-proof: we can seamlessly swap the in-memory execution loop for Isolate-based or Android WorkManager execution without rewriting feature packages.

**Negative:**
- Adds slight boilerplate compared to just calling `compute(myFunction)`. Feature teams must write a dedicated `Job` and `Worker` class.

# Issue #499 Feature Packet — Progressive Download System

**Primary owner agent:** Platform Architect
**Review agents:** Framework Agent, Chief Architect, Chief Security Officer,
Chief Performance Officer, Chief QA Officer, Chief Documentation Officer,
Chief Open Source Officer
**Layer:** Mixed — reusable Flutter plugin contract plus Android/iOS adapters
**Sprint:** Milestone 1 — Phase 1 Core Platform
**Parent roadmap:** #499, consumed by #496

## Critical Agent Gate

**Problem:** Large artifacts currently expose progress and cancellation, but
pause, resume, retry, durable background work, integrity enforcement, and
resume-without-restarting behavior are not implemented as one reusable
contract.
**User / actor:** Airo, Airo Coin, and Airo Mind users downloading large local
artifacts on unreliable or metered connections.
**Framework or application layer:** Framework/platform. Product modules consume
the contract and must not implement their own downloader.
**Owning agent:** Platform Architect.
**Reviewing agents:** Framework Agent, Chief Architect, Chief Security Officer,
Chief Performance Officer, Chief QA Officer, Chief Documentation Officer,
Chief Open Source Officer.
**Impacted modules/files:** new `packages/platform_downloads` Flutter plugin;
`packages/core_ai` model adapter; Android/iOS app-local downloader removal;
focused package/native tests and contract documentation.
**Base branch/worktree:** confirmed from fetched `origin/main` at
`fe6fe33be99896780ed6a9fa4f3063bd14955b7b` in
`airo-worktrees/milestone-1-core-platform-20260727`.
**Open questions:** None blocking. If a remote server does not support byte
ranges or invalidates its validator, the adapter may restart only after
emitting a machine-readable `resume_not_supported` reason.
**Decision:** Ready.

## Cross-Agent Contract

**Provider agent:** Platform Architect provides
`platform_downloads/background-download-contract/v1`.
**Consumer agent:** Framework Agent (`core_ai`) first; Airo Coin and Airo Mind
may import the same package without depending on AI or app code.
**Interface/API:** typed request, queue snapshot, progress event, and controller
operations: enqueue, pause, resume, retry, cancel, inspect, and dispose.
**Input shape:** stable artifact ID, HTTPS source URI, sandboxed destination,
optional expected byte count, optional SHA-256, and non-sensitive display
metadata.
**Output shape:** ordered queue entries with
queued/downloading/paused/verifying/completed/failed/cancelled status,
downloaded and total bytes, speed, retry count, and structured failure reason.
**State changes:** a resumable partial artifact is retained on pause and
retryable failure; a verified artifact is atomically promoted to its final
destination; cancel removes resumable state and partial data.
**Errors:** invalid request, insufficient storage, transport failure,
resume-not-supported, integrity mismatch, platform unavailable, and cancelled
are stable reason codes. Human-readable detail is additive and not parsed.
**Permissions:** network plus OS-required background/foreground-download
capabilities. The contract does not request contacts, location, microphone, or
model access.
**Privacy/redaction:** no analytics, raw authorization headers, file contents,
or full local paths in progress events/logs. Only HTTPS sources are accepted.
**Persistence:** native adapters retain OS job/resume state so work survives UI
navigation and app suspension. Queue state is recoverable after Flutter engine
reattachment.
**Versioning/migration:** additive v1 contract. The existing
`com.airo.model_download` consumer migrates to the package channel and is then
removed; no parallel implementations remain.
**Tests required:** pure-Dart contract/queue tests; method-channel adapter tests;
Android tests for range append, partial retention, retry, cancellation, and
hash mismatch; iOS tests for resume-data lifecycle and hash mismatch; a
host-runnable `core_ai` adapter test.

## Deterministic Use Cases

### UC-499-001: Queue multiple artifacts

**Actor:** Product module.
**Preconditions:** No active download; three valid HTTPS requests.
**Trigger:** Enqueue A, B, and C.
**Happy path:** A downloads while B and C remain ordered; each successor starts
once the previous terminal event is emitted.
**Alternate paths:** Cancelling B leaves A active and C next.
**Failure paths:** A retryable failure pauses progression until retry/cancel.
**Data created/updated/deleted:** queue records and partial/final artifacts.
**Privacy expectations:** snapshots expose artifact IDs, not local paths.

### UC-499-002: Pause and resume without losing bytes

**Actor:** User.
**Preconditions:** A has downloaded a non-zero prefix and the server supports
resume.
**Trigger:** Pause, then resume.
**Happy path:** The partial prefix remains and the resumed request continues
from the recorded offset.
**Alternate paths:** OS background transfer resumes through its native token.
**Failure paths:** If the server changed or rejects resume, emit
`resume_not_supported` before a deliberate restart.
**Data created/updated/deleted:** partial bytes and native resume metadata.
**Privacy expectations:** resume metadata stays in the app sandbox.

### UC-499-003: Retry a transient failure

**Actor:** User or policy controller.
**Preconditions:** A failed after receiving bytes.
**Trigger:** Retry A.
**Happy path:** Retry preserves the partial bytes and increments retry count.
**Alternate paths:** A zero-byte failure starts normally.
**Failure paths:** Permanent HTTP/security errors remain failed until explicit
action.
**Data created/updated/deleted:** retry metadata; partial data retained.
**Privacy expectations:** error details redact URLs and credentials.

### UC-499-004: Verify integrity before promotion

**Actor:** Framework consumer.
**Preconditions:** Request includes expected SHA-256.
**Trigger:** Transport reaches the expected end.
**Happy path:** Status becomes verifying, the digest matches, and the partial
file is atomically promoted.
**Alternate paths:** Without an expected hash, expected byte count is enforced.
**Failure paths:** A mismatch never produces a completed final artifact and
emits `integrity_mismatch`.
**Data created/updated/deleted:** verified final artifact or rejected partial.
**Privacy expectations:** only the expected/actual digest classification is
reported; contents are never logged.

### UC-499-005: Cancel and clean up

**Actor:** User.
**Preconditions:** Request is queued, active, paused, or failed with resumable
state.
**Trigger:** Cancel.
**Happy path:** OS work, resume metadata, queue record, and partial bytes are
removed; a cancelled event is emitted.
**Alternate paths:** Cancelling a missing/terminal ID is idempotent.
**Failure paths:** Cleanup failure emits a structured platform error.
**Data created/updated/deleted:** all in-progress state is deleted.
**Privacy expectations:** no data leaves the sandbox.

## Automation Flow

### AUTO-499-001: Reusable progressive-download contract

**Given:** A fake platform adapter, deterministic clock, three requests, a
resumable byte source, and known SHA-256 fixtures.
**When:** Tests enqueue, pause, resume, fail, retry, complete, and cancel.
**Then:** Queue order, byte preservation, terminal states, integrity gating,
idempotency, and cleanup exactly match the v1 contract.
**Fixtures:** Small byte arrays and fixed digests; no network.
**Mocks/stubs:** Fake native adapter and sandbox filesystem.
**Assertions:** Event sequence, offsets, retry counts, final/partial existence,
and stable failure codes.
**Cleanup:** Temporary directories and controllers are disposed.

### AUTO-499-002: Native adapter behavior

**Given:** Android and iOS native test fixtures with a controllable byte source.
**When:** Native tests exercise background start, pause/resume tokens or byte
ranges, retry, cancel, and digest verification.
**Then:** Each adapter satisfies the same v1 state transitions and never
silently discards a valid partial download.
**Fixtures:** Local deterministic responses; no public artifact download.
**Mocks/stubs:** WorkManager/URLSession test seams.
**Assertions:** Native persisted state, requested offset, emitted payload,
atomic promotion, and cleanup.
**Cleanup:** Native test storage is removed.

## Implementation Boundaries

- Framework files: `packages/platform_downloads/**`,
  `packages/core_ai/lib/src/download/**`
- Application files: provider/UI consumption only under
  `app/lib/features/settings/**`
- Native files: move implementation from `app/android` and `app/ios` into the
  plugin package; app hosts only register/import the plugin
- Tests: package contract/adapter tests plus focused native tests
- Docs: package README, module manifest, migration note
- Verification environment: host Flutter/Dart and native unit/build checks;
  physical-device evidence is required only for OS suspension behavior that
  native tests cannot simulate

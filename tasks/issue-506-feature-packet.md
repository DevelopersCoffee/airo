## Feature Packet

**Primary owner agent:** Meeting Intelligence Agent
**Framework provider owner:** Chief Architect (`platform_worker_jobs`)
**Review agents:** Chief Architect, Chief Performance Officer, Chief Security
Officer, Chief QA Officer, Product Manager, Chief Documentation Officer
**Layer:** Mixed
**Milestone:** Phase 2 — Reliability
**Canonical spec:**
`docs/superpowers/specs/2026-07-28-milestone-2-background-ai-processing.md`

### Critical Agent Gate

**Problem:** Meeting completion currently invokes
`MeetingIntelligencePipeline.process(...)` and repository persistence directly.
The current path does not provide independently observable background stages
for summary generation, indexing, embeddings, speaker clustering, or Memory
updates.
**User / actor:** People completing meetings, release maintainers, and QA
automation.
**Framework or application layer:** Mixed. Worker execution/resource policy is
framework code; meeting stages and product orchestration are application/domain
code.
**Owning agent:** Meeting Intelligence Agent.
**Reviewing agents:** Chief Architect, Chief Performance Officer, Chief
Security Officer, Chief QA Officer, Product Manager, Chief Documentation
Officer.
**Impacted modules/files:** `packages/platform_worker_jobs`,
new `packages/feature_meeting_intelligence`, `app/lib/features/meeting`,
profile pubspecs, and `.github/airo-build-profiles.json`.
**Base branch/worktree:** Yes. Fetched `origin/main` and `origin/v1_bkp`; created
`codex/milestone-2-reliability-20260728` at `origin/main`
`c2768d01388f1110151cf89431343de08fd53620`; bootstrap merge-base matched.
**Data:** Reads final transcript chunks and meeting/audio metadata; creates
redacted summaries, search-index inputs, embeddings, speaker-cluster outputs,
and consent-eligible Memory updates. No raw content may enter diagnostics.
**Offline/model/permission/failure behavior:** Work remains local by default.
Missing model, Memory runtime, permission, or provider returns a typed
`unavailable`/failed stage; it must not be reported as completed. One failed
stage must not erase successful independent stages.
**Finished API/UX:** Meeting completion returns after background work is
accepted. Callers observe typed progress and may cancel eligible stages.
Release profiles include/exclude the entire feature package without source
edits.
**Dependency findings:** A reusable embedding provider has no clearly scoped
implementation issue (#277 owns runtime foundation and #288 owns RAG
consumption). Speaker implementation belongs to #267/#504; #512 is validation.
Meeting Memory behavior belongs to #268 and durable writes depend on the Airo
Mind runtime chain #1193 -> #1194 -> #1195. #506 owns isolate-backed execution;
#518 owns OS lifecycle validation.
**Open decision:** Approve this mapping and decide whether the missing embedding
provider is a framework issue linked to #506 or a #506 sub-issue.

**Decision:** Blocked pending maintainer review of the scope and dependency
mapping.
The additive package/contract slice is ready to begin once this gate is marked
Ready. #506 cannot close until all five stages have verified real providers.

### Cross-Agent Contract

**Provider agent:** Chief Architect / `platform_worker_jobs`.
**Consumer agent:** Meeting Intelligence Agent /
`feature_meeting_intelligence`.
**Interface/API:** Stable background-AI worker kinds, immutable meeting
job/stage/outcome models, cancellation handle, stage-provider interfaces, and a
background coordinator.
**Input shape:** Sendable local meeting ID, redacted/final transcript snapshot,
audio metadata required by a stage, stable model/provider identifiers, and
cancellation state.
**Output shape:** Immutable per-stage progress and terminal outcomes:
`completed`, `failed`, `cancelled`, or `unavailable`.
**State changes:** Successful application adapters persist redacted
summary/index/embedding/cluster/Memory results. Framework execution does not
own meeting persistence.
**Errors:** Provider unavailable, unsupported device/model, cancellation,
worker failure, persistence failure, invalid input, resource-policy deferral.
**Permissions:** Local model/storage/Memory permissions are requested by
application adapters, never implicitly by the worker framework.
**Privacy/redaction:** Redact before persistence, Memory writes, or public
diagnostics. Never log transcript text, prompts, paths, credentials, or vectors.
**Persistence:** Existing meeting persistence remains an adapter during this
slice. No schema expansion is allowed without a separate migration contract.
**Versioning/migration:** Stable IDs are append-only. The release package is
included only by profile manifest/pubspec. Existing synchronous pure helpers
remain temporarily for deterministic tests.
**Tests required:** Stable-ID tests, stage independence, happy/failure/
cancellation/unavailable tests, caller non-blocking integration test,
build-profile inclusion/exclusion tests, privacy assertions, and existing
meeting regression tests.

### Deterministic Use Cases

#### UC-506-001: Complete a meeting without UI-isolate post-processing

**Actor:** Meeting user.
**Preconditions:** Active meeting with final transcript chunks; full release
profile includes the meeting-intelligence module.
**Trigger:** User completes the meeting.
**Happy path:** Controller snapshots final chunks, accepts background work,
clears active UI state, and returns; summary and indexing complete through the
worker boundary.
**Alternate paths:** A configured stage may be deferred by resource policy.
**Failure paths:** Rejected job leaves a typed failure and does not claim
processing success.
**Data created/updated/deleted:** Redacted final transcript, summary, index
input, and stage status.
**Privacy expectations:** Partial chunks and raw sensitive values are not
persisted or logged.

#### UC-506-002: Independent stage failure

**Actor:** Background coordinator.
**Preconditions:** Summary/index providers exist; embedding provider fails.
**Trigger:** Coordinator runs the accepted job.
**Happy path:** Summary/index outcomes remain completed; embedding is failed;
later eligible stages follow declared dependencies.
**Alternate paths:** Missing provider is `unavailable`, not failed.
**Failure paths:** Persistence failure is observable and retryable; successful
stage results are not silently erased.
**Data created/updated/deleted:** Only successful stage outputs are committed.
**Privacy expectations:** Failure diagnostics contain stable IDs/codes only.

#### UC-506-003: Release-profile exclusion

**Actor:** Release maintainer.
**Preconditions:** TV or Coins profile selected.
**Trigger:** Build-profile validation/build runs.
**Happy path:** `feature_meeting_intelligence` is absent from the profile
pubspec/module list and cannot register in that shell.
**Alternate paths:** Full/mobile profile includes the package.
**Failure paths:** Validator rejects a profile/module/ship-policy mismatch.
**Data created/updated/deleted:** Build report only.
**Privacy expectations:** No user data is involved.

#### UC-506-004: Cancel accepted work

**Actor:** User or resource policy.
**Preconditions:** An interruptible stage is queued/running.
**Trigger:** Cancellation is requested.
**Happy path:** Eligible work terminates at a deterministic checkpoint and
reports `cancelled`; no later dependent stage starts.
**Alternate paths:** A non-interruptible commit finishes atomically.
**Failure paths:** Cancellation failure is reported with a stable code.
**Data created/updated/deleted:** Partial uncommitted outputs are discarded.
**Privacy expectations:** Cancellation trace contains no content.

### Automation Flow

#### AUTO-506-001: Host-only worker and feature contracts

**Environment:** Host-only; no Android Emulator.
**Given:** Inline deterministic executor, fake stage providers, fixed clock,
and redacted transcript fixtures.
**When:** Jobs complete, fail, become unavailable, and are cancelled.
**Then:** Exact stage transitions, independence, privacy, and cleanup assertions
pass.
**Fixtures:** Local synthetic meeting data only.
**Mocks/stubs:** Fakes preferred; mocks only at model/Memory boundaries.
**Assertions:** Stable codes, no sensitive diagnostics, no skipped/disabled
tests.
**Cleanup:** Dispose coordinator and clear in-memory results.

#### AUTO-506-002: Host-only app integration

**Environment:** Host-only Flutter test.
**Given:** Meeting controller, fake repository, controlled background runner,
and final/partial chunks.
**When:** `completeMeeting` is invoked.
**Then:** The call returns after acceptance, heavy providers have not executed
synchronously on the caller path, final redacted data is eventually persisted,
and partial data is discarded.
**Cleanup:** Cancel pending jobs and dispose fixtures.

#### AUTO-506-003: Host-only release composition

**Environment:** Host-only Python/shell validation.
**Given:** Build profile manifest, module manifests, and variant pubspecs.
**When:** Profile validators run.
**Then:** Full includes the meeting module; TV/Coins exclude it; a synthetic
ship-policy mismatch is rejected.
**Cleanup:** Validator tests use temporary fixtures only.

### Implementation Boundaries

- **Framework files:** `packages/platform_worker_jobs` stable job kinds and
  generic execution/resource contracts only.
- **Application/domain files:** new `feature_meeting_intelligence` package and
  app persistence/model/Memory adapters.
- **Release files:** build-profile manifest and approved profile pubspecs.
- **Tests:** focused package/app/profile tests; no broad remote CI by default.
- **Docs:** canonical design, module README, validation evidence, rollback.
- **Verification environment:** Host-only for the first slices. Exact
  physical-device evidence remains required wherever an issue explicitly asks
  for OS lifecycle, audio route, battery, or performance validation.

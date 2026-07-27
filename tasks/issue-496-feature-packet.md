# Issue #496 Feature Packet — Intelligent Model Manager

**Primary owner agent:** Framework Agent
**Review agents:** Flutter Architect, Product Manager, Chief Architect, Chief
Performance Officer, Chief Security Officer, Chief QA Officer, Chief UX
Officer, Chief Documentation Officer
**Layer:** Mixed — reusable AI model-management contract plus Airo UI
**Sprint:** Milestone 1 — Phase 1 Core Platform
**Parent roadmap:** #496; depends on the reusable download contract in #499

## Critical Agent Gate

**Problem:** Airo has separate catalog, download, storage, selection, and
preload pieces, but the public manager contract and screen do not truthfully
cover queue control, update lifecycle, storage, explicit warmup, or frequent
preloads.
**User / actor:** Airo user choosing and maintaining local models; Airo Mind is
a future consumer of the same framework API.
**Framework or application layer:** Mixed. `core_ai` owns model state and
operations; the Airo application renders and orchestrates the user journey.
**Owning agent:** Framework Agent.
**Reviewing agents:** Flutter Architect, Product Manager, Chief Architect,
Chief Performance Officer, Chief Security Officer, Chief QA Officer, Chief UX
Officer, Chief Documentation Officer.
**Impacted modules/files:** `packages/core_ai` manager/status/receipt APIs;
`packages/platform_downloads` consumer adapter; settings providers and manager
screen; focused unit/widget tests and docs.
**Base branch/worktree:** confirmed from fetched `origin/main` at
`fe6fe33be99896780ed6a9fa4f3063bd14955b7b` in
`airo-worktrees/milestone-1-core-platform-20260727`.
**Open questions:** None blocking. “Recommended” is derived from the existing
device-compatibility/catalog policy, not a remote ranking service. Frequent
preload remains local, explicit, memory-budgeted, and disableable.
**Decision:** Ready after #499 contract is defined; its feature packet now
defines that dependency.

## Cross-Agent Contract

**Provider agent:** Framework Agent provides
`core_ai/intelligent-model-manager/v1` and consumes
`platform_downloads/background-download-contract/v1`.
**Consumer agent:** Flutter Architect implements the Airo screen; Airo Mind can
consume the manager without importing Airo application code.
**Interface/API:** observe immutable manager snapshot; activate, enqueue,
pause, resume, retry, cancel, delete, warm, enable/disable frequent preload,
and refresh.
**Input shape:** model ID plus explicit user action. Catalog and platform
adapters are constructor-injected.
**Output shape:** installed/active/recommended/queued/update-available/storage/
warm/preload state per model plus aggregate storage and queue summary.
**State changes:** model artifact/receipt, selected model, frequent-preload
preference, residency state, and progressive-download state.
**Errors:** stable model-manager failure reasons wrap platform failures without
leaking paths or exception strings into business logic.
**Permissions:** downloads require network/background transfer; activation,
warmup, delete, and preference changes are local.
**Privacy/redaction:** no model prompts, generated content, raw paths, or
credentials are surfaced in manager snapshots. Local aggregate byte counts are
safe for UI.
**Persistence:** install receipts record model/catalog version and verified
digest; frequent-preload IDs are local preferences; runtime residency is
ephemeral.
**Versioning/migration:** additive v1 API replaces the current minimal
`ModelEntry`/manager without adding Coin or Mind dependencies to `core_ai`.
Legacy model files remain discoverable with unknown installed version until
verified or reinstalled.
**Tests required:** manager snapshot tests for every requested category;
receipt/update tests; download-control delegation tests; warm/preload
memory/failure tests; widget tests for the complete manager and accessible
controls.

## Deterministic Use Cases

### UC-496-001: Inspect the complete model state

**Actor:** User.
**Preconditions:** Catalog has compatible and incompatible models; one verified
install and one queued update exist.
**Trigger:** Open Intelligent Model Manager.
**Happy path:** Installed, active, recommended, queue, storage, update,
warm/residency, and frequent-preload state are visible in one coherent screen.
**Alternate paths:** Legacy installs show version unknown rather than inventing
an update.
**Failure paths:** Unavailable storage or compatibility signals render a safe
status instead of failing the screen.
**Data created/updated/deleted:** Read-only snapshot.
**Privacy expectations:** No local paths or prompts are displayed.

### UC-496-002: Install, control, and activate a model

**Actor:** User.
**Preconditions:** Compatible catalog model is not installed.
**Trigger:** Download, optionally pause/resume/retry, then activate.
**Happy path:** The shared queue controls the transfer, verifies it, records
the install version, and enables activation only after completion.
**Alternate paths:** Cancel removes the partial download; another queued model
keeps its relative order.
**Failure paths:** Integrity/storage/platform failures remain actionable and do
not mark the model installed.
**Data created/updated/deleted:** Artifact, install receipt, queue state,
selected-model preference.
**Privacy expectations:** All state remains local except the HTTPS artifact
request.

### UC-496-003: Detect and install an update

**Actor:** User.
**Preconditions:** Installed receipt version differs from the catalog version.
**Trigger:** Refresh/open manager, then choose Update.
**Happy path:** Update available is shown; the replacement downloads and is
atomically promoted after verification; receipt advances.
**Alternate paths:** Dismissal leaves the current verified model usable.
**Failure paths:** Failed replacement preserves the current verified artifact.
**Data created/updated/deleted:** Replacement partial and updated receipt.
**Privacy expectations:** Only version/digest metadata is stored.

### UC-496-004: Warm now and preload frequently used models

**Actor:** User.
**Preconditions:** Model is installed and runtime adapter is available.
**Trigger:** Tap Warm now or enable Frequent preload.
**Happy path:** Explicit warm reports success/resident state; frequent preload
is considered by the existing memory-budgeted preloader on future warmup runs.
**Alternate paths:** User disables frequent preload.
**Failure paths:** Unsupported runtime, active generation, or memory pressure
returns a visible skipped/failed reason and performs no eviction.
**Data created/updated/deleted:** Local preload preference; ephemeral residency.
**Privacy expectations:** No prompt or model content is retained.

### UC-496-005: Delete safely

**Actor:** User.
**Preconditions:** Model is installed; it may be active or preload-enabled.
**Trigger:** Confirm delete.
**Happy path:** Artifact and receipt are removed, selection/preload references
are cleared, and storage totals refresh.
**Alternate paths:** User cancels confirmation with no state change.
**Failure paths:** Partial cleanup reports an actionable failure and does not
claim success.
**Data created/updated/deleted:** Model files, receipt, selection, preload ID.
**Privacy expectations:** Deletion is local and deterministic.

## Automation Flow

### AUTO-496-001: Framework manager state and actions

**Given:** Fake catalog, storage, receipts, compatibility, residency, preload,
and progressive-download adapters with a deterministic clock.
**When:** Tests refresh, install, pause/resume/retry/cancel, activate, update,
warm, toggle preload, and delete.
**Then:** Every requested state is present, actions delegate once, failure
reasons are stable, and destructive state changes occur only after success.
**Fixtures:** Small model metadata and fixed versions/digests.
**Mocks/stubs:** No network, device, or real model.
**Assertions:** Immutable snapshots, event ordering, receipt lifecycle,
selection/preload cleanup, and storage totals.
**Cleanup:** Temporary files and streams are disposed.

### AUTO-496-002: Complete accessible manager screen

**Given:** Provider overrides for installed, active, recommended, queued,
updatable, warming, failed, and storage-summary states.
**When:** Widget tests navigate the screen and activate each control.
**Then:** Required sections and semantic labels render; pause/resume/retry/
cancel/update/delete/warm/preload actions call the correct controller; loading,
empty, unavailable, and error states remain usable.
**Fixtures:** Deterministic provider snapshots.
**Mocks/stubs:** Framework manager controller.
**Assertions:** Visible labels, enabled-state rules, confirmations, action
calls, keyboard/focus semantics, and no raw paths.
**Cleanup:** Provider container and widget tree are disposed.

## Implementation Boundaries

- Framework files: `packages/core_ai/lib/src/intelligent_model_manager/**`,
  model receipt/storage helpers, public exports
- Application files: settings providers and
  `intelligent_model_manager_screen.dart`; no download or model lifecycle logic
  in widgets
- Tests: `packages/core_ai/test/**` and focused app widget/provider tests
- Docs: `core_ai` API/migration docs and Milestone 1 evidence
- Verification environment: host Flutter/Dart; native transfer behavior is
  proved by #499


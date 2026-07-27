# Milestone 1 — Core Platform Task List

## Task 1: Lock governance and reusable contracts

**Acceptance criteria:**
- [x] Fresh worktree matches fetched `origin/main`.
- [x] #496 and #499 have owners, reviewers, layer decisions, contracts,
      deterministic use cases, automation flows, and rollback boundaries.
- [x] Stale `blocked` labels are removed once packets are posted.

**Verification:**
- [x] `git merge-base HEAD origin/main` equals both tips at bootstrap.
- [x] GitHub comments contain the full packets.

**Dependencies:** None

## Task 2: Add `platform_downloads` v1 contract

**Acceptance criteria:**
- [x] Typed request/state/failure/controller APIs are product-neutral.
- [x] FIFO queue semantics and idempotent operations are explicit.
- [x] Package manifest/docs permit Airo, Coin, and Mind consumption without
      reverse dependencies.

**Verification:**
- [x] Focused package format/analyze/tests pass.
- [x] Manifest checker passes.

**Dependencies:** Task 1

## Task 3: Implement Android progressive adapter

**Acceptance criteria:**
- [x] WorkManager transfer survives UI/process background lifecycle.
- [x] Pause/retry retain partial bytes and resume from a valid offset.
- [x] Cancel deletes partial/persisted state.
- [x] Expected size/SHA-256 gates atomic completion.

**Verification:**
- [x] Focused Android unit tests and product-profile compile pass.

**Dependencies:** Task 2

## Task 4: Implement iOS progressive adapter

**Acceptance criteria:**
- [x] Background URLSession task metadata is recoverable.
- [x] Pause/failure resume data is retained and reused when supported.
- [x] Cancel removes resume state.
- [x] Expected size/SHA-256 gates atomic completion.

**Verification:**
- [x] Focused iOS tests/compile pass.

**Dependencies:** Task 2

## Task 5: Adapt `core_ai` downloads

**Acceptance criteria:**
- [x] `ModelDownloadService` delegates to `platform_downloads`.
- [x] Existing public model progress compatibility is migrated deliberately.
- [x] Duplicate app download providers are consolidated.

**Verification:**
- [x] Existing and new focused download tests pass.

**Dependencies:** Tasks 2–4

## Task 6: Complete model manager framework

**Acceptance criteria:**
- [x] Snapshot covers installed, active, recommended, queue, storage, update,
      delete eligibility, residency/warm, and frequent preload.
- [x] Install receipts enable truthful update detection.
- [x] Warm/preload stays memory-budgeted and reports skipped/failure reasons.

**Verification:**
- [x] Focused `core_ai` manager, receipt, preload, and failure tests pass.

**Dependencies:** Task 5

## Task 7: Complete Airo manager UI

**Acceptance criteria:**
- [x] One coherent screen exposes every #496 capability.
- [x] Pause/resume/retry/cancel/update/delete/warm/preload controls are wired.
- [x] Loading, empty, unavailable, error, accessibility, and confirmation
      states are deterministic.

**Verification:**
- [x] Focused provider/widget tests pass.

**Dependencies:** Task 6

## Checkpoint: Implementation complete

- [x] Format and focused analyzer checks pass.
- [x] Package, app, and native focused tests/builds pass.
- [x] Module manifest, docs completeness, and `git diff --check` pass.

## Task 8: Audit and close Milestone 1

**Acceptance criteria:**
- [ ] Every bullet in #496, #499, and #507 has authoritative current evidence.
- [ ] Validation/rollback notes are recorded on #496 and #499.
- [ ] Both open issues are closed as completed.
- [ ] GitHub Milestone 1 reports zero open issues and is closed.

**Verification:**
- [ ] Re-fetch milestone and issue state through the GitHub API.

**Dependencies:** Tasks 1–7

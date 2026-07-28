# Milestone 2 — Reliability Task List

## Task 1: Lock #506 governance and scope

**Acceptance criteria:**
- [x] Clean worktree matches fetched `origin/main` at bootstrap.
- [x] Current milestone and issue state is inventoried.
- [x] Design spec and dependency-ordered plan exist.
- [x] #506 has the complete Feature Packet and explicit maintainer approval.

**Verification:**
- [x] `git rev-parse HEAD`, `origin/main`, and merge-base matched at bootstrap.
- [x] GitHub #506 comment contains owner, reviewers, contract, deterministic
      use cases, automation flows, privacy, rollback, and decision.

**Dependencies:** None

**Files:** spec and task documents only.

## Task 2: Freeze framework worker kinds

**Acceptance criteria:**
- [x] Stable kinds exist for meeting summary, search indexing, embeddings,
      speaker clustering, and Memory update.
- [x] Stable IDs are frozen by tests.
- [x] Existing scheduler/executor behavior remains compatible.

**Verification:**
- [x] `(cd packages/platform_worker_jobs && flutter test)`
- [x] `(cd packages/platform_worker_jobs && flutter analyze)`

**Dependencies:** Task 1

**Files likely touched:** worker models/tests/docs (3 files).

## Task 3: Add the release-selectable feature package

**Acceptance criteria:**
- [x] `feature_meeting_intelligence` owns meeting job/stage/outcome contracts.
- [x] Its manifest forbids `app` and declares an explicit ship policy.
- [x] Full profile includes it; TV and Coins profiles exclude it.

**Verification:**
- [x] Feature package tests/analyze pass.
- [x] `python3 scripts/check-module-manifests.py`
- [x] `python3 scripts/check-build-profiles.py`
- [x] `./scripts/check-variant-pubspecs.sh`

**Dependencies:** Task 2

**Files likely touched:** package API, manifest/pubspec/test, build profile, full
profile pubspec. Split if more than five files are required.

## Task 4: Offload summary generation

**Acceptance criteria:**
- [x] Existing summary behavior is preserved behind a feature-stage provider.
- [x] Production execution uses `AiroWorkerExecutor`.
- [x] Success, failure, cancellation, and unavailable outcomes are tested.

**Verification:**
- [x] Focused feature package tests pass.
- [x] Existing meeting local-slice tests pass.

**Dependencies:** Task 3

**Files likely touched:** summary provider and focused tests (2–3 files).

## Task 5: Offload search-index preparation

**Acceptance criteria:**
- [x] Search-index preparation is a separate observable stage.
- [x] A summary failure does not erase a successful index outcome.
- [x] No raw sensitive values appear in diagnostics.

**Verification:**
- [x] Focused feature package tests pass.
- [x] Existing meeting search tests pass.

**Dependencies:** Task 4

**Files likely touched:** index provider and focused tests (2–3 files).

## Task 6: Make meeting completion non-blocking

**Acceptance criteria:**
- [x] Completion returns after background work is accepted.
- [x] Final chunks are snapshotted before controller state is cleared.
- [x] Persistence failures are observable and do not masquerade as success.

**Verification:**
- [x] App integration test fails on the old synchronous behavior, then passes.
- [x] Focused app analyze/test commands pass.

**Dependencies:** Tasks 4–5

**Files likely touched:** controller, adapter, focused test (3 files).

## Checkpoint: First Vertical Slice

- [x] Summary and indexing run off the UI isolate.
- [x] Full/TV/Coins profile composition is deterministic.
- [x] Existing meeting behavior remains green.
- [x] Maintainer reviews the package/API boundary before missing providers.

## Task 7: Implement real embedding provider

**Acceptance criteria:**
- [x] Existing provider ownership is identified as #355; no duplicate issue is
      created.
- [ ] #355 provides verified real 256/384-dimensional local embeddings.
- [ ] Meeting embeddings use a real local provider with typed failure modes.
- [ ] Vectors/content never appear in public diagnostics.

**Verification:** provider and meeting adapter tests plus memory-budget checks.

**Dependencies:** Checkpoint

## Task 8: Implement real speaker-clustering provider

**Acceptance criteria:**
- [ ] Clustering is distinct from merely carrying native speaker labels.
- [ ] Similar/unknown/overlapping speaker fixtures are deterministic.
- [ ] Cancellation and unsupported-device outcomes are explicit.

**Verification:** focused provider fixtures and meeting adapter tests.

**Dependencies:** Checkpoint

## Task 9: Implement Memory update adapter

**Acceptance criteria:**
- [ ] Uses the approved runtime/Memory contract, not new feature-owned storage.
- [ ] Writes only redacted, consent-eligible content.
- [ ] Deletion/rollback semantics are documented and tested.

**Verification:** Memory adapter contract, privacy, and deletion tests.

**Dependencies:** Checkpoint and approved Memory runtime contract.

## Task 10: Qualify and close #506

**Acceptance criteria:**
- [ ] All five stages have verified real providers.
- [ ] Local validation evidence and rollback notes are posted.
- [ ] Stale `blocked` label is removed only when no dependency remains.
- [ ] #506 is closed with `state_reason=completed`.

**Verification:** re-fetch issue state and all linked evidence.

**Dependencies:** Tasks 7–9

## Task 11: Audit and close remaining milestone validation issues

**Acceptance criteria:**
- [ ] Every named checklist item in #510–#516, #519, and #520 has authoritative
      current evidence.
- [ ] Device-only requirements name the exact device/build/artifact.
- [ ] Each completed issue is closed with `state_reason=completed`.
- [ ] Milestone 2 has zero open issues and is closed.

**Verification:** GitHub milestone/issue API audit plus focused local/device
evidence referenced by each issue.

**Dependencies:** Task 10 and required physical-device availability.

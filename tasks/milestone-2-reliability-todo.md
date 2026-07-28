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
- [x] #355 has a dependency-free exact 256/384-dimensional retrieval
      foundation with deterministic rebuild semantics and 1,200-row host
      benchmark evidence.
- [ ] #355 provides verified real 256/384-dimensional local embeddings.
- [ ] Meeting embeddings use a real local provider with typed failure modes.
- [x] Vectors/content never appear in public diagnostics.
- [x] #506 consumes #355 through a typed app adapter, maps every provider
      failure, and persists successful vectors through the existing schema.
- [x] Missing/unopened models remain honestly `unavailable`; model artifacts
      are not bundled or silently selected.
- [x] Embedding projection and provider diagnostics omit vector/content data.

**Verification:** feature coordinator tests, app adapter/background/repository
tests, focused analysis, and memory-budget checks. Physical offline inference
still belongs to #355 Task 6.

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
- [ ] Every named checklist item in #510–#520 has authoritative current
      evidence.
- [ ] Device-only requirements name the exact device/build/artifact.
- [ ] Each completed issue is closed with `state_reason=completed`.
- [ ] Milestone 2 has zero open issues and is closed.

**Verification:** GitHub milestone/issue API audit plus focused local/device
evidence referenced by each issue.

**Dependencies:** Task 10 and required physical-device availability.

## Qualification audit — 2026-07-28

- [x] Re-fetched milestone state: #517 is the only completed issue; #506,
      #510–#516, and #518–#520 are open and blocked.
- [x] Reopened #518 because its prior closure comment explicitly left the
      Android lifecycle matrix incomplete.
- [x] Attached current focused host evidence to every open validation issue.
- [x] Confirmed no Android target was initially available to Flutter, then
      provisioned the already-installed API 36 ARM64 image as `airo_api36`.
      #519/#520 do not explicitly accept `AIRO_ALLOW_ANDROID_EMULATOR=true`,
      so its results remain exploratory rather than closure evidence.
- [x] Received explicit authorization, installed the full-profile debug APK
      replace-in-place on the physical Pixel 9 without clearing app data, and
      recorded startup, memory, storage, and 200% text/dark-mode observations.
- [x] Restored the Pixel 9 font, rotation, and night-mode settings exactly
      after the reversible UI run and rebooted it for lifecycle evidence.
- [ ] Complete the post-reboot job audit after the Pixel 9 re-advertises over
      wireless ADB; only the Fire TV target is currently visible and remains
      untouched.
- [ ] Run the Android device matrix and attach the exact device, build, and
      artifact evidence required by #510, #514–#516, and #518–#520.
- [ ] Complete the real provider/runtime dependencies required by #506 and
      #511–#513.

Evidence:

- #355 exact vector retrieval:
  <https://github.com/DevelopersCoffee/airo/issues/355#issuecomment-5101246505>
- #510 downloads:
  <https://github.com/DevelopersCoffee/airo/issues/510#issuecomment-5100279001>
- #511 Whisper:
  <https://github.com/DevelopersCoffee/airo/issues/511#issuecomment-5100279789>
- #512 diarization:
  <https://github.com/DevelopersCoffee/airo/issues/512#issuecomment-5100280451>
- #513 LLM:
  <https://github.com/DevelopersCoffee/airo/issues/513#issuecomment-5100281267>
- #514 audio:
  <https://github.com/DevelopersCoffee/airo/issues/514#issuecomment-5100282072>
- #515 notifications:
  <https://github.com/DevelopersCoffee/airo/issues/515#issuecomment-5100282790>
- #516 database:
  <https://github.com/DevelopersCoffee/airo/issues/516#issuecomment-5100283586>
- #518 background processing and corrected state:
  <https://github.com/DevelopersCoffee/airo/issues/518#issuecomment-5100304152>
- #519 UI:
  <https://github.com/DevelopersCoffee/airo/issues/519#issuecomment-5100284951>
  and exploratory Android observation:
  <https://github.com/DevelopersCoffee/airo/issues/519#issuecomment-5100395466>
- #520 performance:
  <https://github.com/DevelopersCoffee/airo/issues/520#issuecomment-5100285792>
  and exploratory Android measurements:
  <https://github.com/DevelopersCoffee/airo/issues/520#issuecomment-5100395459>

Exploratory Android evidence is recorded in
`artifacts/performance/2026-07-28-milestone-2-emulator.md`. It does not replace
the physical-device matrix or an explicit emulator waiver.

# #355 Local Vector Retrieval Foundation Tasks

## Task 1: Freeze the contract with failing tests

**Acceptance criteria:**

- [x] 256- and 384-dimensional results match a scalar reference.
- [x] Equal scores have stable ID ordering.
- [x] Results and caller-provided inputs cannot mutate the index.

**Verification:**

- [x] Focused test fails before production implementation exists.

**Dependencies:** None

**Files:** one test file.

## Task 2: Implement exact immutable retrieval

**Acceptance criteria:**

- [x] Valid records can be searched and appended.
- [x] Atomic rebuild supports update/deletion snapshots.
- [x] Failed append/rebuild leaves the previous snapshot intact.

**Verification:**

- [x] Focused tests pass.
- [x] Focused implementation/test analysis passes.

**Dependencies:** Task 1

**Files:** implementation and public export.

## Task 3: Qualify and record the slice

**Acceptance criteria:**

- [x] Module and worker-policy checks pass.
- [x] No new dependency or private diagnostic surface exists.
- [x] #355 records exact evidence and remaining blockers.

**Verification:**

- [x] `git diff --check`
- [x] GitHub issue re-fetch remains open and blocked.
- [x] Opt-in 1,200-row host benchmark records exact median and p95 evidence.

**Dependencies:** Task 2

**Files:** task/spec evidence only.

## Qualification Evidence

- 2026-07-28 focused suite: 11 tests passed.
- 2026-07-28 focused analyzer: no issues.
- 2026-07-28 deterministic 1,200-row host benchmark:
  - 256 dimensions: median 527 µs, p95 604 µs, max 2,482 µs.
  - 384 dimensions: median 668 µs, p95 713 µs, max 816 µs.
- 2026-07-28 repository gates: 63 manifests valid; worker-policy tests and
  worker-offload policy passed; `git diff --check` passed.
- Package-wide `flutter analyze` and `flutter test` remain blocked by the
  pre-existing `litert_lm_runtime_adapter_test.dart` fake service compile
  failure on the current `origin/main`; the focused retrieval slice is clean.
- GitHub evidence:
  <https://github.com/DevelopersCoffee/airo/issues/355#issuecomment-5101246505>

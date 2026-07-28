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
- [ ] #355 records exact evidence and remaining blockers.

**Verification:**

- [x] `git diff --check`
- [x] GitHub issue re-fetch remains open and blocked.

**Dependencies:** Task 2

**Files:** task/spec evidence only.

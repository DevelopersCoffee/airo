# #355 Local Vector Retrieval Foundation Tasks

## Task 1: Freeze the contract with failing tests

**Acceptance criteria:**

- [ ] 256- and 384-dimensional results match a scalar reference.
- [ ] Equal scores have stable ID ordering.
- [ ] Results and caller-provided inputs cannot mutate the index.

**Verification:**

- [ ] Focused test fails before production implementation exists.

**Dependencies:** None

**Files:** one test file.

## Task 2: Implement exact immutable retrieval

**Acceptance criteria:**

- [ ] Valid records can be searched and appended.
- [ ] Atomic rebuild supports update/deletion snapshots.
- [ ] Failed append/rebuild leaves the previous snapshot intact.

**Verification:**

- [ ] Focused tests pass.
- [ ] `flutter analyze` passes.

**Dependencies:** Task 1

**Files:** implementation and public export.

## Task 3: Qualify and record the slice

**Acceptance criteria:**

- [ ] Module and worker-policy checks pass.
- [ ] No new dependency or private diagnostic surface exists.
- [ ] #355 records exact evidence and remaining blockers.

**Verification:**

- [ ] `git diff --check`
- [ ] GitHub issue re-fetch remains open and blocked.

**Dependencies:** Task 2

**Files:** task/spec evidence only.

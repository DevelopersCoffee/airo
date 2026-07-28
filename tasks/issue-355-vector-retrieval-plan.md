# Implementation Plan: #355 Local Vector Retrieval Foundation

## Overview

Implement the dependency-free retrieval foundation approved for #355. Keep
model inference, persistence, and application wiring out of this slice.

## Architecture Decisions

- `core_ai` owns the reusable vector contract.
- SQLite/Memory callers own durable records and deterministic snapshot order.
- Exact scalar cosine is preferred at the current 1,000-row scale.
- Float32 conversion occurs at validation time so VM and web behavior share
  the same stored values.
- Production large-corpus consumers must offload through an existing worker or
  native boundary.

## Dependency Graph

```text
typed records and validation
            |
            v
immutable exact index
            |
            v
append / atomic rebuild / search
            |
            v
future MediaPipe + Memory adapters
```

## Phase 1: Contract and Tests

1. Add failing tests for dimensions, reference cosine, ordering, and immutable
   results.
2. Add failing tests for append, atomic rebuild, and invalid inputs.

### Checkpoint

- Tests fail because the production contract does not exist.

## Phase 2: Minimal Implementation

3. Implement validated immutable records/results and exact cosine search.
4. Implement append and validate-before-swap rebuild.
5. Export the contract from `core_ai.dart`.

### Checkpoint

- Focused tests pass.
- No dependency, storage, model, or network surface was added.

## Phase 3: Qualification

6. Run package format, focused tests, analyzer, module manifest, worker policy,
   and diff checks.
7. Record evidence on #355 and keep the issue blocked on the real provider and
   device acceptance criteria.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Mutable rows desynchronize IDs | Wrong retrieval | Store validated private float32 rows and stable IDs together. |
| Failed rebuild erases valid state | Search outage | Build replacement completely before swapping. |
| Main-isolate use grows | UI jank | Document synchronous helper boundary and require worker/native production use. |
| Foundation mistaken for completion | False closure | Keep missing provider/device criteria explicit in docs and issue evidence. |

## Open Questions

- MediaPipe model selection and artifact lifecycle remain a later approved
  slice.
- Memory storage remains dependent on #1193–#1195.

# Implementation Plan: Milestone 2 — Reliability

## Overview

Milestone 2 currently has 12 issues: #517 and #518 are closed; #506 and nine
validation issues remain open. Start with #506 because it is the only open
implementation issue and its background execution contract is required by the
LLM, meeting, database, and performance validation work.

The implementation follows the repository's release-profile architecture:
capabilities live in packages, shells compose them through
`core_product_shell`, and `.github/airo-build-profiles.json` plus profile
pubspecs decide what is compiled into each release.

Canonical design:
`docs/superpowers/specs/2026-07-28-milestone-2-background-ai-processing.md`.

## Ownership and Review

- Primary owner for #506 application behavior: Meeting Intelligence Agent.
- Framework provider owner: Chief Architect (`platform_worker_jobs`).
- Required reviewers: Chief Architect, Chief Performance Officer, Chief
  Security Officer, Chief QA Officer, Product Manager, Chief Documentation
  Officer.
- Layer: mixed. Generic execution/resource contracts are framework code;
  meeting stages and orchestration are application/domain code.

## Dependency Graph

```text
build profiles + module ship policy
              │
              ▼
platform_worker_jobs stable AI job kinds
              │
              ▼
feature_meeting_intelligence package contract
      ┌───────┼───────────┬──────────────┐
      ▼       ▼           ▼              ▼
 summary   indexing   embeddings     clustering
      └───────┬───────────┴──────────────┘
              ▼
        Memory update adapter
              │
              ▼
 app meeting controller + persistence adapters
              │
              ▼
 #510–#516, #519, #520 validation evidence
```

## Phase 1: Governance and Baseline

1. Post the full feature packet to #506 and obtain scope approval.
2. Record the milestone inventory and current blockers without closing any
   issue based only on stale comments or labels.
3. Run the existing focused meeting and worker tests to establish a baseline.

### Checkpoint

- Feature packet decision is Ready.
- Worktree tip still descends from current fetched `origin/main`.
- Baseline commands and results are recorded.

## Phase 2: Framework and Package Foundation

4. Add stable background-AI job kinds to `platform_worker_jobs` with tests.
5. Create `feature_meeting_intelligence` with module ownership, ship policy,
   typed stage/job/outcome contracts, and deterministic fake adapters.
6. Add compile-time profile composition: full profile includes the feature;
   TV and Coins omit it.

### Checkpoint

- Worker and feature package format/analyze/tests pass.
- Module manifest, build-profile, and variant-pubspec validators pass.
- No package imports `app`.

## Phase 3: First Working Vertical Slice

7. Move or adapt current summary generation into the feature package and run it
   through `AiroWorkerExecutor`.
8. Move or adapt current search-index preparation as a separate stage.
9. Wire the app meeting controller to accept background work and return before
   those stages complete; persist only redacted final outputs.

### Checkpoint

- Tests prove the caller does not synchronously run summary/index work.
- Summary/index happy, failure, unavailable, and cancellation paths pass.
- Existing meeting persistence/search tests remain green.

## Phase 4: Missing Real Providers

10. Complete or consume #355's framework-owned local embedding provider and
    implement its meeting adapter.
11. Resolve or create the speaker-clustering implementation issue and implement
    its meeting adapter.
12. Resolve the Memory runtime/storage contract and implement the redacted
    meeting Memory update adapter without expanding feature-owned durable
    storage.

### Checkpoint

- All five #506 stages have real providers.
- Each stage is independently cancellable and observable.
- Failure in one stage does not erase completed stage results.
- No sensitive content appears in public diagnostics.

## Phase 5: Milestone Validation

13. Re-audit #510–#516, #519, and #520 against current code and issue criteria.
14. Close host-verifiable slices only after deterministic evidence is attached.
15. For physical-device requirements, run the documented matrix on an approved
    target and attach exact device/build/artifact evidence.
16. Close each bounded issue with `state_reason=completed` only after every
    named criterion is proven.

### Checkpoint

- Milestone 2 reports zero open issues.
- Milestone state is closed.
- No required device or release evidence is replaced by a host-only test.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Vague #506 wording causes false completion | High | Keep five typed stages and require a real provider for closure. |
| Feature package duplicates framework scheduling | High | Keep execution/resource policy in `platform_worker_jobs`; feature owns only meeting semantics. |
| Current meeting SQLite violates the future runtime SSOT | High | Do not expand its schema; make Memory/storage an adapter and track migration separately. |
| Profile says excluded but dependency still compiles | High | Validate both `featureModules` and profile pubspec dependencies. |
| Device-only validation cannot run locally | Medium | Preserve as explicit blocker; attach exact physical-device evidence later. |
| Long-lived migration leaves two implementations | Medium | Keep compatibility adapter temporary and add removal criteria to the todo. |

## Open Questions

- The dependency mapping in the canonical spec requires maintainer review
  before feature implementation.
- #355 owns reusable local embeddings and exact vector retrieval. Do not create
  a duplicate issue; consume its verified contract from the meeting adapter.
- Speaker implementation is already owned by #267/#504.
- Memory product behavior is owned by #268 and remains contractually dependent
  on the Airo Mind runtime chain #1193 -> #1194 -> #1195.
- #518 owns OS lifecycle validation; #506 owns isolate-backed stage execution.

# Daily Project Health Monitor: Core Data Hydration Batch Performance

## Critical Agent Gate

**Problem:** `packages/core_data` has a deterministic repo-health failure where the `batch hydrate inserts 50 items under performance budget` test misses its `100ms` budget on clean runs because nested track graph inserts are executed row-by-row.
**User / actor:** Framework Agent, QA Automation Agent, maintainers relying on core package CI.
**Framework or application layer:** Framework.
**Owning agent:** Framework Agent.
**Reviewing agents:** QA Automation Agent.
**Impacted modules/files:** `packages/core_data/lib/src/storage/life_track_local_data_source.dart`, `packages/core_data/test/storage/life_track_local_data_source_test.dart`
**Base branch/worktree:** confirmed from latest `origin/main`: yes
**Open questions:** None for this maintenance slice; scope is limited to storage write performance and deterministic validation.
**Decision:** Ready

## Deterministic Use Cases

### UC-001: Hydrate a track template with nested items under CI budget
**Actor:** Framework storage layer.
**Preconditions:** In-memory SQLite database is initialized.
**Trigger:** `hydrateTemplate` receives a `LifeTrack` with one milestone and 50 action items.
**Happy path:** The data source persists the full graph and completes within the existing test budget.
**Alternate paths:** Graphs with input requirements still persist all nested rows.
**Failure paths:** If persistence regresses to row-by-row overhead, the package test exceeds the budget and fails.
**Data created/updated/deleted:** Inserts one track graph and nested milestone/action-item/requirement rows.
**Privacy expectations:** Local-only storage; no network activity or external side effects.

## Automation Flow

### AUTO-001: Core data storage performance regression check
**Given:** A clean worktree from latest `origin/main`.
**When:** `cd packages/core_data && flutter test --reporter=compact` runs.
**Then:** The hydration performance test passes and the package test suite stays green.
**Fixtures:** `inMemoryDatabasePath`, synthetic `LifeTrack` fixture.
**Mocks/stubs:** SQLite FFI database factory only.
**Assertions:** Nested graph persistence remains correct and the measured hydration time stays under budget.
**Cleanup:** Close the in-memory data source after each test.

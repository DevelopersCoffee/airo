# Airo Explorable Collection v2 Feature Packet

**Primary owner agent:** Mobile UI Agent
**Review agents:** Framework Agent, Application Agent, QA Automation Agent
**Layer:** Mixed
**Sprint:** v2 platform exploration
**Parent roadmap:** Airo v2 experiential navigation and discovery

## Critical Agent Gate

**Problem:** Airo needs a reusable way to present the same first-party app,
automation, model, memory, and skill dataset through both efficient
productivity views and immersive Airo-owned discovery views, without losing
user state.
**User / actor:** Airo user exploring capabilities, application owner reviewing
surfaces, and agent owner validating where a capability belongs.
**Framework or application layer:** Mixed. The reusable collection exploration
contract belongs in framework-shaped Airo core code; Airo Explore content,
copy, and fixture mapping belong in application feature code.
**Owning agent:** Mobile UI Agent.
**Reviewing agents:** Framework Agent for reusable API boundaries; Application
Agent for Airo Explore workflows; QA Automation Agent for deterministic widget
flows.
**Impacted modules/files:** `app/lib/core/exploration/*`,
`app/lib/features/airo_explore/*`, `app/lib/core/routing/app_router.dart`, and
matching widget tests.
**Base branch/worktree:** Confirmed from latest `origin/main`: yes. Fetched
`origin/main` on 2026-07-12 and verified local `main` matches it at
`cc292ebb14a6d60cf86fb6416b87580a2de3e08e`.
**Open questions:** Production Airo capability inventory and final navigation
placement are future work; this v2 slice uses deterministic local Airo
fixtures and a direct `/airo-explore` route.
**Decision:** Ready.

## Cross-Agent Contract

**Provider agent:** Framework Agent / Mobile UI Agent.
**Consumer agent:** Application Agent / Airo Explore feature owner.
**Interface/API:** `AiroExplorableCollection<T>` accepts immutable
`AiroExplorableCollectionItem<T>` records and renders list plus spatial views over
the same filtered state.
**Input shape:** Item id, title, subtitle, category, group, optional details,
tags, metrics, semantic label, color, and domain payload.
**Output shape:** User-visible selected item detail sheet and optional
`onItemSelected` callback for feature-owned analytics or navigation.
**State changes:** Local UI-only state: view mode, search query, category
filter, sort mode, selected item, and random item selection.
**Errors:** Empty filtered result renders a recoverable empty state. No network
or persistence errors are introduced in this slice.
**Permissions:** None.
**Privacy/redaction:** No personal, payment, location, health, contact, or
private memory data is stored or transmitted. Fixture content is first-party
Airo product metadata only.
**Persistence:** None for v2 component slice.
**Versioning/migration:** Additive API. No database or storage migration.
**Tests required:** Host-only Flutter widget tests for state-preserving view
switching, filtered random discovery, detail selection, and Airo Explore screen
rendering.

## Deterministic Use Cases

### UC-001: Preserve State Across View Modes
**Actor:** Airo user.
**Preconditions:** Airo Explore is open with local Airo fixture items.
**Trigger:** User searches for an app/model/skill/routine and switches from
Index View to Map View.
**Happy path:** The active query/filter remains applied and the same filtered
collection appears in the spatial view.
**Alternate paths:** User clears the query and all items return.
**Failure paths:** If no item matches, the empty state explains that filters can
be changed.
**Data created/updated/deleted:** UI state only.
**Privacy expectations:** No user memory, finance, media, or model preference
data is persisted by this slice.

### UC-002: Discover Random Airo Capability Within Current Filters
**Actor:** Airo user.
**Preconditions:** A category filter is active.
**Trigger:** User taps Surprise.
**Happy path:** A detail sheet opens for an Airo-owned item inside the active
filtered result set.
**Alternate paths:** If one item matches, that item opens.
**Failure paths:** If zero items match, Surprise is disabled.
**Data created/updated/deleted:** UI state only.
**Privacy expectations:** No telemetry in this slice.

### UC-003: Use Conventional Fallback For Spatial View
**Actor:** Keyboard, screen-reader, or mobile user.
**Preconditions:** Map View is active.
**Trigger:** User navigates items using standard focus/tap interactions.
**Happy path:** Every spatial item is a semantic button with label text and
Index View remains available.
**Alternate paths:** User switches back to Index View at any time.
**Failure paths:** Empty spatial results use the same recoverable empty state.
**Data created/updated/deleted:** UI state only.
**Privacy expectations:** None beyond local UI.

## Automation Flow

### AUTO-001: Host Widget State Preservation
**Given:** An `AiroExplorableCollection` with deterministic Airo-style fixtures.
**When:** The test enters a search query and taps the spatial view control.
**Then:** The filtered item remains visible and unrelated items are absent.
**Fixtures:** Inline deterministic fixture list.
**Mocks/stubs:** None.
**Assertions:** Search field value, selected mode, and filtered item labels.
**Cleanup:** Flutter test teardown.

### AUTO-002: Host Widget Random Within Filter
**Given:** An `AiroExplorableCollection` with a category filter and deterministic
random seed.
**When:** The test filters by category and taps Random.
**Then:** The selected item detail belongs to that category.
**Fixtures:** Inline deterministic fixture list.
**Mocks/stubs:** None.
**Assertions:** Detail sheet title and callback payload.
**Cleanup:** Flutter test teardown.

### AUTO-003: Airo Explore Screen Smoke
**Given:** The Airo Explore screen.
**When:** The test renders the screen and switches views.
**Then:** Airo-specific copy, filters, and spatial objects render.
**Fixtures:** Application-owned local Airo fixture items.
**Mocks/stubs:** None.
**Assertions:** Screen title, view toggle, and at least one Airo object.
**Cleanup:** Flutter test teardown.

## Implementation Boundaries

- Framework files: `app/lib/core/exploration/airo_explorable_collection.dart`
- Application files:
  `app/lib/features/airo_explore/presentation/screens/airo_explore_screen.dart`
- Tests:
  `app/test/core/exploration/airo_explorable_collection_test.dart`,
  `app/test/features/airo_explore/presentation/screens/airo_explore_screen_test.dart`
- Docs: this feature packet
- Verification environment: host-only Flutter widget tests from `app`

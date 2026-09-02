# Airo Living Console — Ambient Precision

**Date:** 2026-07-30  
**Status:** Implemented in worktree; ready for review  
**Source brief:** Codex attachment `pasted-text-1.txt`

## Feature Packet

**Primary owner agent:** Flutter Architect  
**Review agents:** Chief UX Officer, Chief Performance Officer, Chief QA
Officer, Chief Documentation Officer, Product Manager, AI/Brain Agent,
Coins / Finance Agent, Media Intelligence Architect, TV Experience Architect  
**Layer:** Mixed — `core_ui` provides the reusable visual contract and product
surfaces consume it  
**Sprint:** Ambient Precision foundation and product migration  
**Parent roadmap:** Airo-wide premium visual system

### Intake

**Problem:** Airo's product surfaces use multiple unrelated visual languages:
the amber/cream Cyber theme, cyan/violet super-app imagery, green/navy TV, and
many feature-local Material values. Motion and effects tokens exist but are not
consumed consistently.

**User / actor:** Airo users on phone, tablet, web/desktop, and TV.

**Expected outcome:** Every Airo screen inherits a calm, premium, accessible
visual foundation. Each domain keeps a controlled accent and content emphasis
without redefining typography, shape, spacing, chrome, or motion.

**Impacted modules:** `core_ui`, `app`, `airo`, `feature_coin`, `feature_iptv`.

**Known constraints:**

- No `flutter_smooth` dependency. Its current package contract is incompatible
  with Airo's Dart and Flutter versions.
- Parsing and serialization boundaries remain off the main isolate.
- No changes to persistence, permissions, model routing, playback, or finance
  calculations.
- Existing theme storage value `cyber` remains valid for migration safety.
- Bedtime and Midas Stream remain distinct modes while sharing the new geometry,
  typography, and interaction grammar where appropriate.
- All four layout families in `RESPONSIVE_STANDARDS.md` remain supported.

### Critical Agent Gate

**Problem:** Visual fragmentation prevents Airo from reading as one premium
super app and encourages new feature-local styling.

**User / actor:** Airo users moving between Money, Mind, Beats, Live, Arena,
Quest, Home, Reader, Auth, Settings, and TV.

**Framework or application layer:** Mixed. Design tokens, ThemeData, motion,
and primitives are framework-owned; route-to-domain mood and screen composition
are application-owned.

**Owning agent:** Flutter Architect.

**Reviewing agents:** Chief UX Officer, Chief Performance Officer, Chief QA
Officer, Chief Documentation Officer, Product Manager, and affected domain
owners.

**Impacted modules/files:** `packages/core_ui/lib/src/theme`,
`packages/core_ui/lib/src/widgets`, `app/lib/core/app`,
`app/lib/core/routing`, product presentation screens, and focused tests.

**Base branch/worktree:** Confirmed from fetched `origin/main` at
`4c7a7273bfa60f38e4a1bf8aaf12371e905733ea` in
`airo-worktrees/ambient-precision-design`.

**Open questions:** None blocking. Domain moods must not alter semantic status
colors. TV focus feedback must remain immediate. The current `/home` duplicate
of Live becomes the Living Console dashboard because the source brief explicitly
requires a modular Now surface; Live remains available at `/iptv`.

**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Flutter Architect (`core_ui`).  
**Consumer agents:** Application, AI/Brain, Coins / Finance, Media
Intelligence, TV Experience.  
**Interface/API:** Theme extensions and widgets for Ambient Precision
foundations, domain mood selection, premium surfaces, headers, and motion.  
**Input shape:** A domain identifier plus optional content and interaction
configuration.  
**Output shape:** ThemeData/ThemeExtension values and reusable widgets; no
business-domain output.  
**State changes:** Theme selection continues to persist through the existing
`AppThemeId` contract. Domain mood is derived from the active route and is not
persisted.  
**Errors:** Missing extensions fall back to safe Material theme values.  
**Permissions:** None.  
**Privacy/redaction:** No user data is introduced, read, logged, or exported.  
**Persistence:** No schema change. Existing `cyber` theme preference remains
valid.  
**Versioning/migration:** `AppThemeId.cyber` remains the stable identifier while
its user-facing name and implementation become Airo Living Console.  
**Tests required:** Token and contrast tests, domain mood tests, shared widget
tests, shell route mood tests, home responsive tests, existing app-shell and
theme-provider regression tests.

### Deterministic Use Cases

#### UC-001: Move between Airo domains

**Actor:** Signed-in Airo user.  
**Preconditions:** Living Console is the selected/default theme.  
**Trigger:** Navigate between Money, Mind, Beats, Live, Arena, and Quest.  
**Happy path:** Geometry, typography, surfaces, chrome, and motion remain
consistent while the active accent changes once per domain.  
**Alternate paths:** Bedtime replaces the mood with its low-light theme; TV
uses ten-foot sizing and focus treatment.  
**Failure paths:** Unknown routes use the neutral Airo mood.  
**Data created/updated/deleted:** None.  
**Privacy expectations:** No navigation content is transmitted or logged.

#### UC-002: Open the Living Console home

**Actor:** Signed-in Airo user.  
**Preconditions:** The app shell is visible.  
**Trigger:** Activate Home.  
**Happy path:** A responsive Now dashboard presents the primary domains and
useful continuation actions in a content-led layout.  
**Alternate paths:** Compact layout stacks sections; wider layouts use a
constrained multi-column composition.  
**Failure paths:** Missing user/media/finance state produces useful static
entry points, not broken or fake data.  
**Data created/updated/deleted:** None.  
**Privacy expectations:** No fabricated balances, playback, or AI activity is
shown.

#### UC-003: Use reduced motion and assistive settings

**Actor:** User with reduced-motion or enlarged-text preferences.  
**Preconditions:** Platform accessibility preference is enabled.  
**Trigger:** Navigate, focus, press, or open a surface.  
**Happy path:** Decorative travel is removed, text remains readable, controls
keep at least 48 dp touch targets, and focus remains visible.  
**Alternate paths:** TV retains immediate focus indication without decorative
follow-through.  
**Failure paths:** Missing accessibility preference defaults to restrained
120/200/300 ms motion.  
**Data created/updated/deleted:** None.  
**Privacy expectations:** Accessibility preferences remain platform-owned.

### Automation Flow

#### AUTO-001: Theme and domain contract

**Environment:** Host-only.  
**Given:** Each Airo domain and theme mode.  
**When:** Theme and domain extensions are resolved.  
**Then:** Required tokens are present, contrast pairs meet WCAG AA, domain
accent selection is deterministic, and `cyber` preference migration remains
valid.  
**Fixtures:** Material test app with each domain.  
**Mocks/stubs:** None.  
**Assertions:** Token values, contrast ratios, shape/motion tiers, fallback
behavior.  
**Cleanup:** Widget tree disposed by the test binding.

#### AUTO-002: Responsive Living Console

**Environment:** Host-only widget tests at 320, 600, 1024, 1440, and 1920 dp.  
**Given:** The Home route in an authenticated shell.  
**When:** The viewport changes across every standard breakpoint.  
**Then:** No overflow occurs, content remains constrained, touch targets remain
usable, and compact/wide compositions expose the same destinations.  
**Fixtures:** Existing router/provider test fixtures.  
**Mocks/stubs:** Authentication and domain state remain local fixtures.  
**Assertions:** Layout structure, navigation actions, semantics, no exceptions.  
**Cleanup:** Test providers and widget tree disposed.

#### AUTO-003: Existing screen regression

**Environment:** Host-only.  
**Given:** Existing focused tests for `core_ui`, app shell, settings/theme,
Money, Mind, Music, Games, Quest, and IPTV presentation.  
**When:** The relevant package test suites run under Living Console.  
**Then:** Existing behavior remains unchanged except the explicitly updated
Home route and visual expectations.  
**Fixtures:** Existing repository fixtures.  
**Mocks/stubs:** Existing repository mocks and stubs.  
**Assertions:** Analyzer clean, tests green, `git diff --check` clean.  
**Cleanup:** None beyond normal test teardown.

### Implementation Boundaries

- **Framework files:** `packages/core_ui/lib/src/theme`,
  `packages/core_ui/lib/src/widgets`, exports, and tests.
- **Application files:** theme setup, route-derived domain scope, shared shell,
  Living Console home, and presentation-only migration away from conflicting
  hard-coded styling.
- **Feature packages:** presentation-only adoption. No provider, storage,
  playback, parsing, or domain-logic changes.
- **Tests:** focused `core_ui`, app shell/theme/home, affected feature widget
  tests, analyzer, formatting, and responsive checks.
- **Docs:** this specification plus any component usage notes required by the
  final API.
- **Verification environment:** Host-only first. Physical Pixel 9, iPad, and
  Fire TV qualification is a separate release verification unless available
  and explicitly requested.

## Visual Contract

### Foundations

- Neutral near-black canvas, layered graphite surfaces, warm off-white text.
- Cyan-to-violet is Airo identity; only one domain accent is active at a time.
- Semantic success, warning, error, and live colors never inherit domain mood.
- Medium-radius geometry with small, medium, large, and pill tiers.
- Blur and glass are reserved for shell chrome and transient overlays.
- Airo display type is limited to branded hero moments. Product body, labels,
  forms, finance data, and reading use the legible system text stack.

### Domain moods

| Domain | Accent | Content emphasis |
| --- | --- | --- |
| Airo / Home | spectral cyan-violet | active work and continuation |
| Money / Coins / Vault | emerald | numbers, trust, confirmation |
| Mind / Chat | violet | conversation, tools, generation state |
| Beats / Music | magenta | artwork and playback |
| Live / IPTV | green | video stage, live and focus state |
| Arena / Games | amber | turn state, challenge, reward |
| Quest / Life Track | coral | progress and completion |
| Reader | warm ivory | long-form readability |
| Auth / Settings | neutral cyan | quiet setup and control |

### Motion grammar

- 120 ms: press, hover, and focus response.
- 200 ms: component state changes.
- 300 ms: routes, sheets, and spatial transitions.
- Spring behavior is reserved for direct manipulation.
- Staggering is limited to six visible items.
- Reduced motion removes travel and looping decoration.
- Loading preserves final geometry and does not mask synchronous main-isolate
  work.

## Acceptance Criteria

- [x] The persisted `cyber` theme resolves to the user-facing Airo Living
  Console theme.
- [x] Shared palette, typography, shape, surface, domain, and motion tokens are
  available from `core_ui`.
- [x] All standard Material primitives used by Airo receive Ambient Precision
  styling from the global theme.
- [x] The application shell derives exactly one domain mood from the active
  route and applies it to shell chrome and content.
- [x] `/home` renders a responsive, data-honest Living Console dashboard;
  `/iptv` remains the Live destination.
- [x] Shared premium surface and page-header primitives are documented and
  adopted by top-level product surfaces.
- [x] Conflicting decorative hard-coded colors/radii are removed from the
  migrated product presentation layer while semantic media/game/status colors
  remain explicit.
- [x] Motion respects platform reduced-motion settings and TV focus feedback
  remains immediate.
- [x] Core UI and affected product tests prove token, responsive, semantics,
  route, and regression behavior.
- [x] No dependency is added and no business-domain contract changes.

## Rollback

Revert the theme, domain scope, shared widgets, and presentation migration as a
single feature change. Existing `AppThemeId.cyber` persistence remains readable,
so rollback requires no data migration.

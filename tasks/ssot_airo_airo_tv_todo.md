# Task List: Airo / Airo TV Single Source of Truth

## Task 1: Lock ownership and migration contract

**Description:** Create the feature packet/ADR for the consolidation and define
the owning agents, package boundaries, compatibility window, and no-break rules
before implementation starts.

**Acceptance criteria:**
- [ ] Owners for shell contracts, IPTV core, mobile adapters, TV adapters, and app shells are explicit.
- [ ] The target package map is approved.
- [ ] The compatibility strategy for old imports, routes, and storage keys is explicit.

**Verification:**
- [ ] `docs/agents/AGENT_POLICY.md` lifecycle artifacts exist for the issue.
- [ ] Reviewers match `docs/agents/COUNCIL.md`.

**Dependencies:** None

**Estimated scope:** Small

## Task 2: Extract shared product-shell contracts

**Description:** Move `FeatureRegistry` and `AppFeatureModule` out of `app/`
into a reusable package with app-profile manifests and startup composition.

**Acceptance criteria:**
- [ ] No shared feature registration contract is owned by `app/`.
- [ ] Super-app and TV entrypoints can consume the same registry package.
- [ ] `IptvFeatureModule` no longer has to live in `app/`.

**Verification:**
- [ ] Super-app entrypoint boots with the new shared registry.
- [ ] TV entrypoint boots with the new shared registry.
- [ ] Focused analyze/tests for touched shell code pass.

**Dependencies:** Task 1

**Estimated scope:** Medium

## Task 3: Create shared IPTV navigation manifest

**Description:** Define the IPTV navigation destinations once and render them
through both mobile drawer and TV rail adapters.

**Acceptance criteria:**
- [ ] Home, Guide, Movies/VOD, Favorites, and Settings come from one manifest.
- [ ] Mobile drawer uses the shared manifest.
- [ ] TV rail uses the shared manifest.

**Verification:**
- [ ] Existing destination labels/icons/semantics remain valid.
- [ ] Widget tests cover both renderers against the same destination source.

**Dependencies:** Task 2

**Estimated scope:** Small

## Task 4: Create shared IPTV settings-section manifest

**Description:** Define IPTV settings sections once and render them through
mobile and TV-specific settings UIs.

**Acceptance criteria:**
- [ ] Theme, playback, PiP, sources, country, and any approved audio settings have one shared contract.
- [ ] Mobile settings hub consumes the shared contract.
- [ ] TV settings screen consumes the shared contract.

**Verification:**
- [ ] Settings parity matrix is documented and tested.
- [ ] Shared providers and storage keys are unchanged.

**Dependencies:** Task 2

**Estimated scope:** Medium

## Task 5: Split `feature_iptv` by responsibility behind a façade

**Description:** Separate shared IPTV logic from mobile and TV presentation
without breaking current public imports.

**Acceptance criteria:**
- [ ] Shared logic lives in IPTV core package(s).
- [ ] Mobile presentation lives in mobile adapter package.
- [ ] TV presentation lives in TV adapter package.
- [ ] Existing `feature_iptv` imports remain supported during migration.

**Verification:**
- [ ] Existing routes still build.
- [ ] Existing provider/storage behavior is unchanged.
- [ ] Focused package analysis and tests pass.

**Dependencies:** Tasks 2-4

**Estimated scope:** Large

## Task 6: Introduce first-class TV app shell

**Description:** Create a standalone TV app shell that consumes shared
contracts instead of relying on a copied pubspec plus alternate target flow.

**Acceptance criteria:**
- [ ] TV shell has its own app root and real manifest.
- [ ] TV shell composes shared IPTV and shell contracts.
- [ ] Existing `main_tv.dart` can be retained temporarily as a compatibility path.

**Verification:**
- [ ] TV app boots and navigates correctly.
- [ ] Existing TV routes, settings, and IPTV flows still work.

**Dependencies:** Task 5

**Estimated scope:** Medium

## Task 7: Retire copied-manifest and app-owned legacy contracts

**Description:** Remove the duplicated `pubspec_tv.yaml` workflow and any
remaining app-owned contracts once the standalone shell path is stable.

**Acceptance criteria:**
- [ ] No product composition contract is duplicated between app shells.
- [ ] `pubspec_tv.yaml` is retired or generated from one source.
- [ ] Legacy app-owned registry/nav/settings definitions are deleted.

**Verification:**
- [ ] Build docs reflect the new shell strategy.
- [ ] Local validation for super-app and TV app passes.

**Dependencies:** Task 6

**Estimated scope:** Medium

## Checkpoint: First SSOT milestone

- [ ] Task 2 complete
- [ ] Task 3 complete
- [ ] Task 4 complete
- [ ] Mobile and TV both read from shared nav/settings contracts

## Checkpoint: Full modular milestone

- [ ] Task 5 complete
- [ ] Task 6 complete
- [ ] Task 7 complete
- [ ] Super-app and TV shell both consume the same shared product contracts

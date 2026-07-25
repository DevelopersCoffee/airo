# ADR-0011: Super-app modular shell SSOT

## Status

Proposed

## Date

2026-07-24

## Context

Airo and Airo TV already share parts of the IPTV implementation, but they do
not share one product-composition contract.

Today:

- `app/lib/main.dart` and `app/lib/main_tv.dart` assemble startup separately
- `FeatureRegistry` and `AppFeatureModule` live inside `app/`
- `feature_iptv` contains both shared IPTV state and platform-specific mobile
  and TV presentation
- IPTV navigation is hardcoded separately in the mobile drawer and TV rail
- IPTV settings are backed by some shared providers, but section composition is
  still split across different mobile and TV screens
- `app/pubspec_tv.yaml` is a copied product manifest rather than a first-class
  modular app shell

This prevents “single source of truth” behavior for Airo and Airo TV. A shared
IPTV change can require editing multiple shell-owned files, and modular Airo TV
work can drift from the super-app.

The repository already has governance and planning rules that require explicit
ownership and cross-agent contracts before implementation:

- `docs/agents/AGENT_POLICY.md`
- `docs/agents/COUNCIL.md`

The required direction is one platform with:

- one super-app shell
- multiple modular app shells
- shared shell/module contracts
- shared IPTV settings/navigation contracts
- shell-specific renderers instead of shell-specific truth

## Decision

Adopt a shared-contract architecture for super-app and modular app composition.

### 1. Create a reusable shell contract layer

Introduce a new package, `core_product_shell`, that owns:

- app profiles
- module registration
- route bundles
- provider override bundles
- startup task bundles
- shell capability descriptors

`FeatureRegistry` and `AppFeatureModule` move out of `app/` into this shared
layer or are replaced there by equivalent abstractions.

### 2. Split IPTV into core truth plus shell adapters

Evolve the current `feature_iptv` package into:

- `feature_iptv_core` for providers, repositories, preferences, descriptors,
  route identities, and shared feature manifests
- `feature_iptv_mobile` for mobile/compact route and widget adapters
- `feature_iptv_tv` for TV route and widget adapters
- `feature_iptv` as a temporary compatibility façade during migration

### 3. Make shared IPTV navigation and settings explicit manifests

Declare the following once in shared IPTV core:

- IPTV navigation destinations
- IPTV settings-section descriptors

Mobile and TV shells render these through different adapter UIs, but they do
not own separate source lists for shared IPTV behavior.

### 4. Move toward first-class app shells

The long-term target is separate app shells, such as:

- `apps/airo_super`
- `apps/airo_tv`

The existing `app/` and `main_tv.dart` entrypoints may remain temporarily while
the shared-contract migration is validated.

### 5. Migrate additively, not with a big-bang rewrite

The migration order is:

1. extract shell/module contracts
2. introduce shared nav/settings manifests
3. split IPTV by responsibility behind a façade
4. adopt first-class app shells
5. retire copied-manifest and app-owned legacy contracts

No first-phase migration may change shared storage keys or break existing
routes without explicit compatibility handling.

## Consequences

### Positive

- Airo and Airo TV gain one source of truth for shared IPTV settings and
  navigation.
- Modular Airo TV work can be adopted by the super-app through shared
  contracts instead of manual shell duplication.
- Ownership boundaries become clearer: shared truth in packages, renderers in
  shells/adapters.
- The TV product can evolve into a first-class modular app instead of a copied
  manifest variant of the super-app.

### Negative

- The refactor introduces new packages and temporary façade layers.
- There will be an intermediate period where both old and new composition paths
  exist simultaneously.
- Teams must maintain compatibility during the migration rather than taking a
  simpler destructive rewrite.

### Risks

- Package split churn can create route/import breakage if done too early.
- Startup behavior can regress if shell-specific work is moved before contracts
  are explicit.
- A compatibility façade can linger longer than intended if the follow-up
  cleanup is not scheduled and enforced.

## Alternatives Considered

### Alternative 1: Keep the current dual-shell arrangement and only patch parity gaps

This would fix visible differences in settings or menus case by case, but it
would leave startup, module registration, and dependency composition duplicated.
It does not create a real single source of truth.

### Alternative 2: Big-bang rewrite directly into separate app shells

This could produce a cleaner end state quickly, but it has higher break risk.
The current codebase still needs compatibility for routes, providers, and
persisted preferences. The additive migration is safer.

### Alternative 3: Keep one `feature_iptv` package forever and split only at the shell level

This would preserve package count, but it would keep shared truth mixed with
platform-specific presentation and bootstrap concerns. That weakens ownership
and slows future modularization.

## Related Decisions

- [ADR-0001](0001-package-structure.md)
- [ADR-0006](0006-mobile-ui-governance-and-shell-ownership.md)
- [ADR-0010](0010-airo-coin-package-first-development.md)

## References

- `docs/agents/AGENT_POLICY.md`
- `docs/agents/COUNCIL.md`
- `docs/features/airo-tv/AIRO_SUPER_APP_SSOT_CONSOLIDATION_FEATURE_PACKET.md`
- `tasks/ssot_airo_airo_tv_gap_analysis.md`
- `tasks/ssot_airo_airo_tv_architecture_blueprint.md`
- `tasks/ssot_airo_airo_tv_todo.md`

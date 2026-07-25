# Gap Analysis: Airo / Airo TV Single Source of Truth

## Scope

This is an analysis-only artifact for the requested consolidation of Airo and
Airo TV into one super-app platform with modular app shells.

Evidence base used for this analysis:

- Clean worktree created from `origin/main` on Friday, July 24, 2026:
  `/Users/udaychauhan/workspace/airo/.codex/worktrees/ssot-analysis-origin-main`
- Policy and ownership:
  - `AGENTS.md`
  - `docs/agents/AGENT_POLICY.md`
  - `docs/agents/COUNCIL.md`
- Product surfaces inspected:
  - `app/lib/main.dart`
  - `app/lib/main_tv.dart`
  - `app/lib/core/app/airo_app.dart`
  - `app/lib/core/app/airo_tv_app.dart`
  - `app/lib/core/routing/app_router.dart`
  - `app/lib/core/app/tv_router.dart`
  - `app/lib/core/app/tv_shell.dart`
  - `app/lib/core/features/feature_registry.dart`
  - `app/lib/features/iptv/iptv_feature_module.dart`
  - `app/lib/features/settings/presentation/screens/settings_hub_screen.dart`
  - `app/lib/features/settings/presentation/screens/playback_settings_screen.dart`
  - `app/lib/features/settings/presentation/screens/audio_settings_screen.dart`
  - `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`
  - `app/lib/features/settings/presentation/tv/tv_playback_section.dart`
  - `app/lib/features/settings/presentation/tv/tv_source_management_section.dart`
  - `packages/feature_iptv/lib/feature_iptv.dart`
  - `packages/feature_iptv/lib/presentation/widgets/iptv_navigation_drawer.dart`
  - `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart`
  - `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart`
  - `app/pubspec.yaml`
  - `app/pubspec_tv.yaml`
  - `packages/feature_iptv/pubspec.yaml`
  - `packages/feature_iptv/module.yaml`

## Critical Agent Clarity Gate

| Question | Decision |
| --- | --- |
| User journey | One platform should own shared IPTV/media logic, settings contracts, navigation contracts, and startup contracts. Super-app and TV-only shells should compose those contracts without reimplementing them. |
| Primary owners | Chief Architect for module boundaries, Media Intelligence Architect for `feature_iptv`, Flutter Architect for app shells and UI composition, Chief QA Officer for no-break migration coverage. |
| Impacted modules | `app/`, `packages/feature_iptv`, `packages/airo`, and likely new shared shell/bootstrap packages plus a future standalone `apps/airo_tv/` or equivalent. |
| Change class | Mixed. Shared contracts are framework-level. Screen composition and product routing are application-level. |
| Cross-agent contract needed | Yes. Shared product contracts must move out of `app/` and out of TV-specific presentation code so both shells consume the same manifest. |
| Main constraint | No breaking changes while modular Airo TV work continues. Existing routes, providers, and preferences must stay stable during migration. |

## Executive Summary

The repository already has one monorepo and one shared IPTV package, but it
does not yet have one source of truth for product composition.

Today the codebase has:

- one shared domain/application package: `packages/feature_iptv`
- one super-app runtime shell: `app/lib/main.dart` + `AppRouter`
- one TV-specific runtime shell: `app/lib/main_tv.dart` + `TvRouter`
- one copied TV dependency manifest: `app/pubspec_tv.yaml`

That means the business logic is partly shared, but the product-definition
layer is duplicated. The current duplication is not only visual. It exists in:

- app startup/bootstrap
- feature registration
- route composition
- navigation destination definition
- settings section composition
- dependency manifests

The correct target is:

1. shared domain/application state stays in shared packages
2. shared product contracts move into reusable package-level manifests
3. mobile and TV shells become adapters over those contracts
4. standalone app shells become thin entrypoints, not owners of business logic

## Current State Map

### 1. Super-app shell

The super-app entrypoint is `app/lib/main.dart`. It initializes Firebase,
preferences, EPG reminders, audio startup, and runs `AiroApp`. Routing is owned
by `app/lib/core/routing/app_router.dart`.

This shell directly owns:

- auth redirects
- branch routing
- super-app navigation
- settings route wiring
- feature-level screen integration

### 2. TV shell

The TV entrypoint is `app/lib/main_tv.dart`. It separately initializes:

- preferences
- TV-only image cache budget
- TV system chrome
- XMLTV repositories
- TV audio service
- feature registry registration
- TV startup tasks

Routing is owned by `app/lib/core/app/tv_router.dart`. TV chrome is owned by
`app/lib/core/app/tv_shell.dart`.

### 3. Shared IPTV package

`packages/feature_iptv` is already the main shared capability package. It owns:

- IPTV providers and persisted preferences
- source management
- EPG data access
- channel filters
- playback preference state
- mobile IPTV screen
- TV IPTV screen
- guide, favorites, VOD
- TV UX widgets

This is the right direction for shared logic, but the package currently mixes:

- shared business/application state
- mobile presentation
- TV presentation
- TV bootstrap exports

### 4. Package `airo`

`packages/airo` is not the super-app contract layer the name suggests. Its
`pubspec.yaml` is minimal and its exports are legacy UI/package exports, not
product composition manifests, shell contracts, or app bootstraps.

This package cannot currently act as the source of truth for app composition.

## Gap Analysis

## Gap 1: Product composition lives in app entrypoints instead of shared contracts

Evidence:

- `app/lib/main.dart`
- `app/lib/main_tv.dart`
- `app/lib/core/routing/app_router.dart`
- `app/lib/core/app/tv_router.dart`

Problem:

- super-app startup and TV startup are separate, imperative, and manually
  assembled
- shared concerns like prefs, IPTV storage, reminders, Firebase gating, cast
  overrides, and startup orchestration are not defined as reusable manifests
- adding a new modular app would likely create a third custom entrypoint

Impact:

- every new app shell re-solves bootstrap
- startup drift is likely
- modularization scales poorly

Required fix:

Create a shared product-shell contract package that defines:

- app profile manifest
- enabled modules
- startup tasks
- provider overrides
- route bundles
- platform-specific shell capabilities

Suggested package: `packages/core_product_shell`

## Gap 2: Feature registration contract is app-owned, not package-owned

Evidence:

- `app/lib/core/features/feature_registry.dart`
- `app/lib/features/iptv/iptv_feature_module.dart`

Problem:

- `AppFeatureModule` and `FeatureRegistry` live inside `app/`
- TV-only shells and future modular shells must import app-layer code to use
  the feature module contract
- `IptvFeatureModule` is also defined in `app/`, even though the feature it
  registers is in `packages/feature_iptv`

Impact:

- package-first modular development is blocked
- future `apps/airo_tv/` or `apps/airo_music/` shells would either duplicate
  the registry or depend on the wrong layer

Required fix:

Move the module/feature registration contract into a reusable package and let
feature packages publish their own manifests.

Suggested split:

- `packages/core_product_shell`: `AppModule`, `AppProfile`, `ModuleRegistry`
- `packages/feature_iptv_mobile`: mobile route bundle
- `packages/feature_iptv_tv`: TV route bundle

## Gap 3: `feature_iptv` mixes shared logic with platform-specific presentation

Evidence:

- `packages/feature_iptv/lib/feature_iptv.dart`
- `packages/feature_iptv/lib/presentation/screens/*`
- `packages/feature_iptv/lib/presentation/tv/*`
- `packages/feature_iptv/lib/presentation/tv_ux/*`
- `packages/feature_iptv/lib/application/airo_tv_bootstrap.dart`

Problem:

- the same package exports mobile screens, TV screens, TV shell widgets, and
  TV bootstrap helpers
- that makes `feature_iptv` both shared domain logic and one specific product
  presentation package

Impact:

- TV changes and mobile changes collide in the same surface
- package boundaries do not reflect ownership boundaries from `COUNCIL.md`
- modular shells cannot adopt only the parts they need cleanly

Required fix:

Split by responsibility, not by repository:

- `packages/feature_iptv_core`
  - providers
  - stores
  - services
  - domain logic
  - source management logic
  - settings descriptors
  - navigation descriptors
- `packages/feature_iptv_mobile`
  - `IPTVScreen`
  - mobile favorites
  - mobile VOD
  - mobile settings renderers/adapters
- `packages/feature_iptv_tv`
  - `IptvTvScreen`
  - TV guide/favorites/VOD
  - TV UX shell pieces
  - TV settings renderers/adapters

Compatibility requirement:

Keep `packages/feature_iptv` temporarily as a façade package that re-exports
the old public API while internally delegating to the new split packages.

## Gap 4: Navigation destinations are duplicated, not declared once

Evidence:

- mobile drawer: `packages/feature_iptv/lib/presentation/widgets/iptv_navigation_drawer.dart`
- mobile use site: `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart`
- TV rail: `app/lib/core/app/tv_shell.dart`

Current state:

- mobile drawer hardcodes Home, Guide, Movies & Shows, Favorites, Settings
- TV rail hardcodes Home, Guide, Movies, Favorites, Settings
- labels are already slightly different
- TV rail lives in `app/`, mobile drawer lives in `feature_iptv`

Problem:

- same product navigation exists in two owners
- adding/removing/reordering destinations requires at least two edits

Required fix:

Declare IPTV navigation destinations once in a shared package-level manifest,
for example:

- destination id
- display label
- semantic label
- icon pair
- route key
- visibility rules by profile

Both mobile drawer and TV rail should render from that manifest.

## Gap 5: Settings content is partly shared in state, but not in composition

Evidence:

- mobile settings: `app/lib/features/settings/presentation/screens/settings_hub_screen.dart`
- mobile playback: `app/lib/features/settings/presentation/screens/playback_settings_screen.dart`
- mobile audio: `app/lib/features/settings/presentation/screens/audio_settings_screen.dart`
- TV settings: `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`
- TV playback: `app/lib/features/settings/presentation/tv/tv_playback_section.dart`
- TV sources: `app/lib/features/settings/presentation/tv/tv_source_management_section.dart`

Current parity observed from source:

| Capability | Mobile | TV | Shared state already exists |
| --- | --- | --- | --- |
| Theme | Yes | Yes | Yes |
| Playback aspect ratio | Yes | Yes | Yes |
| Picture-in-picture | Yes | Yes | Yes |
| Playlist source | Yes | Yes | Yes |
| XMLTV guide source | Yes | Yes | Yes |
| Country picker in settings | Yes | No explicit settings section | Yes |
| Audio settings | Yes | No | No shared settings contract |
| Accessibility | No real implementation | No real implementation | No |

Problem:

- settings state is partly shared already through providers
- settings section composition is not shared
- mobile settings are route/list based, TV settings are rail/detail based
- there is no shared settings section manifest

Impact:

- visible option drift
- future settings will continue to diverge even if they use the same providers

Required fix:

Create a shared settings contract layer that defines sections once and lets
each shell render them differently.

Suggested contract:

- `IptvSettingsSectionId`
- label
- icon
- availability by profile
- renderer hooks for compact/mobile vs TV detail
- ordering

Important note:

The layout should not become identical. The option set should become identical
where intended, while mobile and TV remain different renderers.

## Gap 6: TV build uses a copied pubspec instead of package composition

Evidence:

- `app/pubspec.yaml`
- `app/pubspec_tv.yaml`

Problem:

- TV dependency selection is managed by a second handwritten pubspec
- version drift already exists between the two manifests
- the build strategy is still “copy a different dependency file” instead of
  “build a different app shell from shared packages”

Impact:

- dependency updates are error-prone
- reproducibility is weak
- lean modular apps do not scale past one special case

Required fix:

Move to one of these models:

1. preferred: separate app packages
   - `apps/airo_super/`
   - `apps/airo_tv/`
   each with its own real `pubspec.yaml`
2. fallback: generated manifests from one source file

The current copied `pubspec_tv.yaml` should not remain the long-term solution.

## Gap 7: There is no first-class standalone modular app shell yet

Evidence:

- TV build still lives under `app/`
- current TV shell is an alternate target/entrypoint, not a separate app root

Problem:

- “single super app + multiple modular apps” needs each modular app to have
  an explicit shell boundary
- today Airo TV is a variant inside the host app, not a first-class modular app

Impact:

- app-specific dependencies, assets, package ids, release flows, and
  qualification logic stay tangled

Required fix:

Create a first-class app shell for TV from the shared contracts. This can be
done incrementally without deleting the existing `main_tv.dart` immediately.

## Target Architecture

## Layer model

### Layer 1: Shared foundations

Existing or refined packages:

- `core_*`
- `platform_*`
- `product_capabilities`

Purpose:

- runtime primitives
- storage
- playback/platform access
- entitlements/capabilities

### Layer 2: Shared product contracts

New package:

- `packages/core_product_shell`

Purpose:

- `AppProfile`
- `AppModule`
- `ModuleRegistry`
- startup task contract
- shell route contract
- settings section manifest contract
- navigation destination manifest contract

### Layer 3: Shared feature logic

New or restructured:

- `packages/feature_iptv_core`

Purpose:

- business logic
- providers
- persistence
- IPTV data orchestration
- section manifests
- destination manifests

### Layer 4: Surface adapters

New packages:

- `packages/feature_iptv_mobile`
- `packages/feature_iptv_tv`

Purpose:

- render the same module contracts for different form factors
- own screen widgets and route bundles
- no ownership of core business state

### Layer 5: App shells

Target shells:

- `apps/airo_super/`
- `apps/airo_tv/`

Transitional compatibility:

- keep existing `app/` and `app/lib/main_tv.dart` until the new shells are
  proven and release wiring is migrated

## Recommended Source of Truth Boundaries

### Source of truth for IPTV settings

Put in shared IPTV core package:

- section ids
- order
- visibility rules
- state providers
- section metadata

Renderers:

- mobile renderer in `feature_iptv_mobile`
- TV renderer in `feature_iptv_tv`

### Source of truth for IPTV navigation

Put in shared IPTV core package:

- destination ids
- labels
- semantic labels
- icons
- route ids

Renderers:

- drawer in mobile shell
- rail in TV shell

### Source of truth for enabled modules per app

Put in `core_product_shell`:

- app profile id
- enabled modules
- capability flags
- startup tasks
- route bundles
- shell preferences

Examples:

- `AiroSuperProfile`
- `AiroTvProfile`

### Source of truth for shell bootstrap

Put in `core_product_shell`:

- common startup pipeline
- profile-specific steps
- provider override assembly

This removes bootstrap logic from individual entrypoints over time.

## No-Break Migration Strategy

## Phase 0: Freeze contracts and define ownership

Do before code moves:

- approve target package boundaries
- approve naming
- approve whether `app/` becomes `apps/airo_super/` or stays temporarily
- define exact backwards-compatibility window for old imports

## Phase 1: Extract shared shell contracts first

Do not split screens first.

First extract:

- `FeatureRegistry` / `AppFeatureModule`
- app profile manifest
- startup task contract

Reason:

- without this, every later split still depends on `app/`

## Phase 2: Extract shared settings and nav manifests

Create shared manifests before moving UI:

- `iptv_nav_destinations.dart`
- `iptv_settings_sections.dart`

Then rewire existing mobile and TV UIs to consume them.

Result:

- immediate parity control
- low-risk win
- no large package move required yet

## Phase 3: Split `feature_iptv` into core/mobile/tv packages behind a façade

Keep `packages/feature_iptv` as temporary compatibility export layer:

- old imports continue to resolve
- internals shift to new package boundaries

Do not force a big-bang import rewrite across the repo.

## Phase 4: Create first-class `apps/airo_tv/`

Build `apps/airo_tv/` on top of shared contracts and split IPTV packages.

Keep existing `main_tv.dart` as a compatibility entrypoint until:

- build parity is proven
- release wiring is migrated
- validation passes

## Phase 5: Replace copied pubspec workflow

Prefer app-per-shell manifests over alternate copied pubspecs.

This is where dependency truth becomes stable.

## Phase 6: Deprecate legacy entrypoints and app-owned contracts

Only after validation:

- retire `app/pubspec_tv.yaml`
- retire `app/lib/core/features/feature_registry.dart`
- retire duplicated nav/settings definitions

## What Can Be Unified Immediately Without High Risk

These are the safest first moves:

1. move feature/module registry contract out of `app/`
2. create shared IPTV navigation destination manifest
3. create shared IPTV settings section manifest
4. make TV settings consume the same declared sections as mobile
5. document the target app-profile model

These changes provide immediate SSOT benefit without forcing a large package
restructure first.

## What Should Not Be Unified Blindly

These should stay adapter-specific:

- mobile layout vs TV layout
- shell chrome
- focus/remote behavior
- route transition behavior
- platform-only controls

The single source of truth should be the contract and state, not identical UI.

## Main Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Big-bang package split | High | Use façade exports and phased internal moves |
| Route breakage | High | Keep route ids stable and add adapter tests before moving screens |
| Preference/storage regressions | High | Do not change provider keys or storage keys during the refactor |
| Build instability from app shell move | High | Introduce new app shell alongside old entrypoints first |
| Ownership confusion | Medium | Create package manifests and reviewer rules before extraction |
| Dependency drift during transition | Medium | Stop editing copied TV pubspec except for emergency fixes and prioritize shell separation |

## Open Questions Requiring Product/Architecture Decision

1. Should `app/` become `apps/airo_super/`, or should the repo keep `app/` as
   the long-term super-app root?
2. Do you want `packages/feature_iptv` preserved as the public compatibility
   package name, or should it become the new core package with adapters using
   new names?
3. Should Audio settings be part of the shared IPTV settings contract, or stay
   super-app-only unless TV genuinely needs it?
4. Is “single source of truth” intended only for IPTV/TV surfaces, or for all
   future modules such as Music, Reader, and AI as well?

## Recommended Next Step

The best next implementation slice is not the full split.

The best first slice is:

1. extract `FeatureRegistry` and app-profile contracts into a shared package
2. define shared IPTV navigation destinations
3. define shared IPTV settings section descriptors
4. rewire current mobile and TV shells to consume those descriptors

That creates the first real single source of truth with the lowest migration
risk, and it sets up the later package split cleanly.

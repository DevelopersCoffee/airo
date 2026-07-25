# Architecture Blueprint: Airo Super-App + Modular Airo TV SSOT

## Purpose

This blueprint turns the SSOT gap analysis into an implementation-ready target
architecture. It answers:

1. what becomes the single source of truth
2. what remains shell-specific
3. what packages should exist
4. how to migrate without breaking Airo or Airo TV

This is still analysis-only. It does not claim the refactor is implemented.

## Design Goal

Support one platform with:

- one super-app shell
- multiple modular app shells
- one shared contract for IPTV/media settings and navigation
- one shared contract for module registration and startup
- additive modular development in Airo TV without forcing breaking changes in
  the super-app

## Non-Goals

These are not part of the single source of truth and should not be unified at
the widget level:

- mobile layout and TV layout
- D-pad/focus behavior and touch behavior
- route transitions
- shell chrome
- platform-specific startup branches such as Android TV orientation or remote
  controls

The single source of truth is for contracts and state, not identical UI trees.

## Core Principle

Use one contract, many renderers.

If a product concept must be shared between Airo and Airo TV, it should be
declared exactly once in a package-level manifest or provider contract. Each
shell then adapts that contract to its own UI and platform behavior.

Examples:

- navigation destinations: one contract, drawer on mobile, rail on TV
- settings sections: one contract, list on mobile, split-pane on TV
- startup tasks: one contract, app-profile-specific execution
- enabled modules: one contract, different app-profile selections

## Target Package Graph

```text
packages/
  core_product_shell/        # NEW
  feature_iptv_core/         # NEW
  feature_iptv_mobile/       # NEW
  feature_iptv_tv/           # NEW
  feature_iptv/              # compatibility facade during migration
  airo/                      # optional: keep only if repurposed intentionally

apps/
  airo_super/                # target super-app shell
  airo_tv/                   # target standalone TV shell
```

Transitional state is allowed:

- keep `app/` as the live super-app shell initially
- keep `main_tv.dart` as the live TV entrypoint initially
- move contracts first, then shells, then manifests

## Package Responsibilities

## 1. `core_product_shell`

### Owns

- module registration contracts
- app profile contracts
- startup task contracts
- provider override assembly contracts
- route bundle contracts
- shell capability descriptors

### Does not own

- IPTV business logic
- app-specific screen widgets
- TV-specific focus UI

### Proposed public API

```dart
abstract class AppModule {
  String get id;
  Set<AppProfileId> supportedProfiles;
  List<RouteBase> routesFor(AppProfile profile);
  List<Override> overridesFor(AppProfile profile);
  List<StartupTask> startupTasksFor(AppProfile profile);
}

class AppProfile {
  final AppProfileId id;
  final Set<String> enabledModuleIds;
  final ShellCapabilities capabilities;
}

class ModuleRegistry {
  void register(AppModule module);
  List<RouteBase> resolveRoutes(AppProfile profile);
  List<Override> resolveOverrides(AppProfile profile);
  List<StartupTask> resolveStartupTasks(AppProfile profile);
}
```

### Why this must exist

Right now `FeatureRegistry` and `AppFeatureModule` live in `app/`. That makes
the super-app shell the owner of a contract that modular apps need. This is the
wrong dependency direction.

## 2. `feature_iptv_core`

### Owns

- IPTV providers
- content source persistence
- XMLTV/EPG repositories
- channel filters
- playback preferences
- PiP preference state
- settings section descriptors
- navigation destination descriptors
- route identifiers and semantic ids
- IPTV feature module manifest for the shell registry

### Does not own

- mobile drawer widget
- TV navigation rail widget
- mobile settings screens
- TV settings screen layout
- TV-only shell chrome

### Proposed shared contracts

```dart
enum IptvDestinationId { home, guide, vod, favorites, settings }

class IptvNavigationDestination {
  final IptvDestinationId id;
  final String label;
  final String semanticLabel;
  final IconData icon;
  final IconData selectedIcon;
  final String routeName;
}

enum IptvSettingsSectionId {
  theme,
  playback,
  pictureInPicture,
  sources,
  epgGuide,
  country,
  audio,
  accessibility,
}

class IptvSettingsSectionDescriptor {
  final IptvSettingsSectionId id;
  final String label;
  final IconData icon;
  final Set<AppProfileId> visibleInProfiles;
  final Set<IptvRendererKind> supportedRenderers;
}
```

### Why this must exist

Today the shared state already exists in many places, but the composition of
that state into product options does not. This package is where SSOT becomes
real for settings and navigation.

## 3. `feature_iptv_mobile`

### Owns

- `IPTVScreen`
- mobile favorites and VOD screens
- mobile drawer renderer
- mobile settings renderer
- compact/mobile route bundle adapter

### Does not own

- navigation truth
- settings truth
- playback preference truth

### Consumes

- `feature_iptv_core` descriptors and providers
- `core_product_shell` module contract

## 4. `feature_iptv_tv`

### Owns

- `IptvTvScreen`
- TV guide/favorites/VOD screens
- TV rail renderer
- TV settings renderer
- TV route bundle adapter
- TV UX widgets

### Does not own

- navigation truth
- settings truth
- route identity truth

### Consumes

- `feature_iptv_core` descriptors and providers
- `core_product_shell` module contract

## 5. `feature_iptv` compatibility facade

### Owns

- temporary re-exports
- compatibility imports for existing callers

### Does not own

- new logic
- new UI ownership

### Purpose

This avoids a big-bang import rewrite. Existing callers continue importing
`package:feature_iptv/feature_iptv.dart` while internals are moved into the
new package boundaries.

## 6. `apps/airo_super`

### Owns

- super-app product profile
- auth requirements
- super-app navigation shell
- branch layout
- profile-scoped startup wiring

### Consumes

- `core_product_shell`
- selected modules such as IPTV, Coins, Music, etc.

### Notes

This can be introduced after contracts are extracted. The repo does not need to
rename `app/` immediately.

## 7. `apps/airo_tv`

### Owns

- standalone TV app profile
- TV shell chrome
- TV-specific package id/assets/build settings
- TV app startup adapter

### Consumes

- `core_product_shell`
- `feature_iptv_core`
- `feature_iptv_tv`

### Why this matters

A real modular app should not depend on copying `pubspec_tv.yaml` over the main
app manifest. It should be a first-class shell.

## Single Source of Truth Map

| Concern | Single source of truth | Current owner | Future renderer/adapters |
| --- | --- | --- | --- |
| enabled modules per app | `AppProfile` in `core_product_shell` | entrypoints | super-app shell, TV shell |
| startup tasks | `StartupTask` manifest in `core_product_shell` | `main.dart`, `main_tv.dart` | shell bootstraps |
| feature registration | `AppModule` manifest in `core_product_shell` | `app/core/features` | all shells |
| IPTV nav items | `IptvNavigationDestination` list in `feature_iptv_core` | mobile drawer + TV rail | drawer, rail |
| IPTV settings sections | `IptvSettingsSectionDescriptor` list in `feature_iptv_core` | mobile settings + TV settings | list, split-pane |
| IPTV providers/state | `feature_iptv_core` | `feature_iptv` | all shells |
| route ids for IPTV | `feature_iptv_core` route bundle manifest | mixed app/feature locations | profile-specific routers |
| shell chrome | app shell packages | mixed | shell-specific only |

## Settings Parity Blueprint

## Required parity rule

If a setting is part of shared IPTV behavior, it must be declared once and be
visible in both Airo and Airo TV whenever the target profile allows it.

## Recommended categories

### Shared IPTV settings

- Theme, if theme selection is intentionally shared across product profiles
- Playback aspect ratio
- Picture-in-picture preference
- Playlist source
- XMLTV guide source
- Country filter/default
- Accessibility, when implemented

### Conditional settings

- Audio settings only if TV is supposed to expose them as a real supported
  workflow
- profile-only items such as AI model settings must remain outside IPTV shared
  settings

## Render model

### Mobile

- top-level list
- detail route or sheet per section

### TV

- section rail/list on left
- detail pane on right

Both should be driven by the same section descriptor ordering and visibility.

## Navigation Parity Blueprint

## Required parity rule

The IPTV shell menu should expose the same canonical destination set in both
products unless a destination is profile-gated.

## Canonical destination set

- Home
- Guide
- Movies/VOD
- Favorites
- Settings

Optional future items such as Search, Downloads, or Diagnostics must be added
once in the destination manifest and rendered by both shells according to
profile visibility rules.

## Route Composition Blueprint

## Current problem

Routes are currently spread across:

- `AppRouter`
- `TvRouter`
- feature module classes inside `app/`

## Target

Each feature module should publish route bundles for supported profiles.

Example:

```dart
class IptvModule implements AppModule {
  @override
  List<RouteBase> routesFor(AppProfile profile) {
    switch (profile.id) {
      case AppProfileId.superApp:
        return buildMobileIptvRoutes();
      case AppProfileId.airoTv:
        return buildTvIptvRoutes();
    }
  }
}
```

This keeps route identity centralized while allowing different screen adapters.

## Startup Composition Blueprint

## Current problem

`main.dart` and `main_tv.dart` each imperatively decide:

- prefs
- Firebase
- reminders
- XMLTV repo init
- audio init
- cast overrides
- TV system UI

## Target

Split startup into:

### shared startup tasks

- preferences bootstrap
- shared repositories
- reminder scheduling
- feature initialization

### profile-specific startup tasks

- TV system chrome
- TV audio service
- auth initialization
- mobile-only audio setup

### shell-only imperative code

- `WidgetsFlutterBinding.ensureInitialized()`
- `runApp(...)`

Everything else should move behind startup task contracts.

## Dependency Strategy

## Short term

- keep `app/pubspec.yaml`
- keep `app/pubspec_tv.yaml`
- stop treating copied manifest divergence as acceptable long-term design

## Medium term

Introduce:

- `apps/airo_super/pubspec.yaml`
- `apps/airo_tv/pubspec.yaml`

Each app shell depends only on what it needs.

## Long term

Delete:

- copied TV manifest strategy
- entrypoint-specific feature registration contracts

## Migration Order

## Phase 1: Contract extraction

Create:

- `core_product_shell`
- shared module/app-profile contracts

Move:

- `FeatureRegistry`
- `AppFeatureModule`

Keep behavior unchanged.

## Phase 2: Shared nav/settings manifests

Create in `feature_iptv_core`:

- canonical nav destination list
- canonical settings section list

Rewire current mobile and TV UI to use them.

This is the first visible SSOT milestone.

## Phase 3: Split feature package by responsibility

Move:

- providers/state into `feature_iptv_core`
- mobile screens into `feature_iptv_mobile`
- TV screens into `feature_iptv_tv`

Keep `feature_iptv` as façade.

## Phase 4: Profile-driven routes/startup

Rebuild route and startup assembly through:

- `AppProfile`
- `AppModule`
- `ModuleRegistry`

Keep old entrypoints until parity is proven.

## Phase 5: First-class modular app shells

Create:

- `apps/airo_super`
- `apps/airo_tv`

Switch release/build docs after verification.

## Phase 6: Legacy removal

Delete only after parity and validation:

- `app/lib/core/features/feature_registry.dart`
- duplicated nav definitions
- duplicated settings composition definitions
- copied TV pubspec strategy

## Validation Gates

## Gate 1: Contract parity

Proves:

- mobile and TV both use the same nav manifest
- mobile and TV both use the same settings manifest

Evidence:

- widget tests for drawer/rail
- widget tests for mobile/TV settings renderers

## Gate 2: Behavior parity

Proves:

- storage keys unchanged
- provider behavior unchanged
- route names remain stable or are compat-aliased

Evidence:

- focused provider tests
- regression tests for route access

## Gate 3: Shell parity

Proves:

- super-app and TV shell both boot via shared contracts
- profile-scoped startup tasks execute correctly

Evidence:

- entrypoint smoke tests
- focused analyzer/test runs

## Gate 4: Release parity

Proves:

- TV build no longer depends on manual copied-manifest workflow
- modular shell is releaseable

Evidence:

- app-shell build docs
- focused build validation

## What To Implement First

If implementation starts next, the first slice should be:

1. `core_product_shell`
2. shared IPTV nav manifest
3. shared IPTV settings-section manifest
4. wiring existing mobile and TV UIs to those manifests

Why:

- highest SSOT gain
- lowest break risk
- directly addresses the user-visible drift in settings and hamburger menu
- prepares the later package split cleanly

## Exit Criteria For “SSOT Achieved”

This objective is only truly achieved when all of the following are true:

- Airo and Airo TV use one shared IPTV navigation manifest
- Airo and Airo TV use one shared IPTV settings-section manifest
- module registration and startup composition no longer live only in `app/`
- modular Airo TV development can add/change shared IPTV behavior once and have
  the super-app adopt it through shared contracts
- TV shell exists as a first-class modular app or an equivalent profile-driven
  shell with non-copied product composition

Until then, the analysis is complete but the refactor is not.

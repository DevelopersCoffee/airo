# Phase 1 Implementation Notes: Airo / Airo TV / Airo Coins SSOT

## Status

Implemented (Phase 1 of the migration order in ADR-0011 and
`tasks/ssot_airo_airo_tv_architecture_blueprint.md`). This covers Task 2
("Extract shared product-shell contracts"), Task 3 ("Create shared IPTV
navigation manifest"), and Task 4 ("Create shared IPTV settings-section
manifest") from `tasks/ssot_airo_airo_tv_todo.md`, extended to be
shell-count-agnostic ahead of Airo Coins joining as a third shell.

## What was migrated

### 1. Shared shell/module contract — `packages/core_product_shell` (new)

- `ShellId`: a data value (not a fixed two-case enum) identifying a shell.
  `ShellId.mobile`, `ShellId.tv`, `ShellId.coins` are provided as
  convenience constants; any other `ShellId('...')` is equally valid, so a
  fourth or fifth shell never requires a contract change.
- `AppModule`: the shared module contract (`id`, `supportedShells`,
  `routesFor(ShellId)`, `providerOverridesFor(ShellId)`, `initialize()`,
  `dispose()`).
- `ModuleRegistry`: an instance-scoped registry (`ModuleRegistry(shell: ...)`)
  that resolves routes/overrides/lifecycle per shell. Unlike the old
  `FeatureRegistry`, this is not a single global static — each shell owns its
  own registry instance, so multiple shells (or tests) never contend over
  shared static state.
- 9 unit tests in `packages/core_product_shell/test/module_registry_test.dart`,
  including one that registers a module against `ShellId.coins` and asserts
  the registry resolves it with zero code-path changes to `ModuleRegistry`
  itself — proving the "no 2-branch if/else" requirement.

`app/lib/core/features/feature_registry.dart` (the old app-owned
`AppFeatureModule`/`FeatureRegistry`) is now a thin compatibility shim over
`core_product_shell`:

- `AppFeatureModule` now `implements AppModule` from the shared package.
- `FeatureRegistry`'s static API (`register`, `initializeAll`, `disposeAll`,
  `allRoutes`, `allProviderOverrides`, `registeredFeatures`, `isRegistered`,
  `featureCount`, `featureNames`) is unchanged in name and signature, so
  every existing call site — `app/lib/main_tv.dart`,
  `app/lib/features/iptv/iptv_feature_module.dart`,
  `app/lib/features/music/music_feature_module.dart`,
  `app/lib/core/startup/app_startup_tasks.dart` — needed zero edits.
  Internally, `FeatureRegistry` now delegates to a
  `core_product_shell.ModuleRegistry` scoped to a `ShellId` derived from the
  app's existing `PlatformFeatures.current` (`AppPlatform.androidTv` →
  `ShellId.tv`; `AppPlatform.mobileFull`/`AppPlatform.iPad` → `ShellId.mobile`).

This is additive by design: the reusable contract now lives where a future
`apps/airo_tv/` or Airo Coins shell could depend on it directly without
importing `app/`-layer code, while today's mobile/TV entrypoints keep
working through the unchanged compatibility surface.

### 2. Shared IPTV navigation manifest

New: `packages/feature_iptv/lib/domain/iptv_navigation_manifest.dart`
(exported from `feature_iptv.dart`).

- `IptvDestinationId` (`home`, `guide`, `vod`, `favorites`, `settings`) and
  `IptvNavigationDestination` (label, semantic label, icon, selected icon,
  optional per-shell label overrides via `shellLabelOverrides`).
- `iptvNavigationDestinations`: the one ordered list both shells render.

Wired:

- `packages/feature_iptv/lib/presentation/widgets/iptv_navigation_drawer.dart`
  (mobile drawer) now iterates `iptvNavigationDestinations`, resolving each
  destination's icon/label from the manifest. Visibility (`showMovies`,
  `onSettings != null`) and callback wiring stay in this widget — that's
  shell-specific rendering, not shared truth.
- `app/lib/core/app/tv_shell.dart` (`_TvNavigationRail`/`_TvNavItem`) now
  renders the same `iptvNavigationDestinations` list instead of its own
  local `_TvNavDestination`/`_tvNavDestinations`.

Preserved exactly: the pre-existing label drift between shells (mobile:
"Movies & Shows", TV: "Movies") is captured as a `shellLabelOverrides` entry
on the `vod` destination rather than being silently unified — unifying it
would have been a visible behavior change, which was out of scope. All
existing widget keys, order, and icons are unchanged; 18 pre-existing tests
across `iptv_navigation_drawer_test.dart` and `tv_shell_test.dart` pass
unmodified.

### 3. Shared IPTV settings-section manifest

New: `packages/feature_iptv/lib/domain/iptv_settings_manifest.dart`
(exported from `feature_iptv.dart`).

- `IptvSettingsSectionId` (`theme`, `playback`, `sources`, `playlistSource`,
  `epgGuideSource`, `country`, `audio`, `accessibility`) and
  `IptvSettingsSectionDescriptor` (label, icon, `visibleForShells`, optional
  per-shell label/icon overrides).
- `iptvSettingsSections`: the one list both settings screens read from.

Wired:

- `app/lib/features/settings/presentation/screens/settings_hub_screen.dart`
  (mobile) resolves each of its existing tiles' label/icon from the manifest
  by id (`theme`, `playback`, `playlistSource`, `epgGuideSource`, `country`,
  `audio`).
- `app/lib/features/settings/presentation/tv/tv_settings_screen.dart` (TV)
  now derives its rail (`_sections`) from
  `iptvSettingsSections.where((s) => s.isVisibleFor(ShellId.tv))` instead of
  a local hardcoded tuple list, and its `_selected` state is the shared
  `IptvSettingsSectionId` enum directly (no more parallel
  `_TvSettingsSection` enum).

11 pre-existing tests across `settings_hub_screen_test.dart`,
`tv_settings_screen_test.dart`, and `adaptive_tv_settings_screen_test.dart`
pass unmodified. 9 new focused tests in
`packages/feature_iptv/test/iptv/domain/iptv_navigation_manifest_test.dart`
and `iptv_settings_manifest_test.dart` assert manifest shape, per-shell
label/icon resolution, and behavior for a third shell identifier.

### 4. `main_coins.dart` stub

Added `app/lib/main_coins.dart`: a minimal entrypoint that constructs a
`ModuleRegistry(shell: ShellId.coins)` with zero modules registered and
renders a placeholder screen (`AiroCoinsStubApp`). No routes, no providers,
no legacy `app/lib/features/coins` import. This exists solely to prove the
shell contract accepts a third identifier end-to-end (see
`app/test/main_coins_stub_test.dart`); it is not a real Airo Coins app and
ships no product surface.

## What was deferred to phase 2

Everything past "extract contracts + shared nav/settings manifests" in the
blueprint's migration order stays deferred, per the phase 1 scope agreed in
this task:

- Splitting `packages/feature_iptv` into `feature_iptv_core` /
  `feature_iptv_mobile` / `feature_iptv_tv` behind a compatibility façade
  (blueprint Phase 3 / todo Task 5). The nav/settings manifests were added
  directly to the existing `feature_iptv` package rather than a new core
  package, per the blueprint's own guidance not to force a package split in
  this slice ("Phase 2 ... no large package move required yet").
- First-class `apps/airo_super/` and `apps/airo_tv/` app roots (blueprint
  Phase 4-5 / todo Task 6). `app/lib/main.dart` and `app/lib/main_tv.dart`
  remain the live entrypoints.
- Retiring `app/pubspec_tv.yaml`'s copied-manifest workflow (blueprint Phase
  5 / todo Task 7) — it was only edited here to add the new
  `core_product_shell` path dependency, keeping it in sync with
  `app/pubspec.yaml`.
- Real Airo Coins UI, routes, providers, or storage — explicitly out of
  scope per this task's instructions. Per ADR-0010, any future Airo Coins
  feature work must come from a package-first extraction, never from the
  legacy `app/lib/features/coins` tree; `main_coins.dart` does not import
  it.
- Closing the settings-parity gaps the manifest now records as data
  (`country`/`audio` not yet on TV, `accessibility` not yet on mobile,
  `sources` not yet split identically) — recorded explicitly in
  `iptv_settings_manifest.dart`'s doc comment and covered by tests, but not
  closed, since closing them would be a visible behavior change beyond this
  task's "no visible behavior change" constraint.
- Startup-task and route-bundle composition through `AppModule`/`AppProfile`
  (blueprint's "Startup Composition Blueprint" and "Route Composition
  Blueprint") — `core_product_shell` ships the `AppModule`/`ModuleRegistry`
  contract, but `main.dart`/`main_tv.dart` were not rewritten to assemble
  startup imperatively through it; only `FeatureRegistry` itself was moved
  onto the shared contract.

## Architecture-vs-current-code conflicts and how they were resolved

1. **`implements` vs. inherited defaults.** `core_product_shell.AppModule`
   declares default method bodies (e.g. `isEnabledForShell`) so that most
   consumers can just extend it. `app/lib/core/features/feature_registry.dart`'s
   `AppFeatureModule` needed to keep its own existing method names
   (`isEnabledForPlatform`, `routes`, `providerOverrides`) rather than the
   shared contract's names (`routesFor`, `providerOverridesFor`) to avoid
   changing `IptvFeatureModule`/`MusicFeatureModule`. That meant
   `AppFeatureModule implements AppModule` rather than `extends AppModule` —
   `implements` does not inherit default method bodies, so
   `isEnabledForShell` had to be re-implemented explicitly in
   `AppFeatureModule` even though `AppModule` already provides a default.
   Resolved in favor of zero call-site changes (the task's explicit
   constraint), at the cost of one small duplicated method body.

2. **`ShellId` custom equality vs. `const` collections.** `ShellId` overrides
   `==`/`hashCode` for value equality (so `ShellId('tv') == ShellId('tv')`
   from two different call sites). Dart's const-evaluator does not allow
   types with custom `==` as `const` map/set keys or elements. The blueprint
   examples show manifests as `const` lists holding
   `Set<AppProfileId>`/`Map<AppProfileId, ...>`-shaped fields. Resolved by
   declaring `iptvNavigationDestinations`/`iptvSettingsSections` (and the
   descriptor classes' non-const constructor calls) as ordinary `final`
   top-level values built once at load time, instead of `const` — behaviorally
   identical (one instance, immutable in practice), just not compiler-const.
   Documented inline in both manifest files.

3. **Settings parity is asymmetric today, and the manifest keeps it that
   way.** The blueprint's target state implies one settings-section list
   both shells render identically. The real mobile/TV settings screens
   diverge today (mobile splits Playlist/EPG into two entries and has
   Country/Audio; TV combines them into one "Sources" entry and has no
   Country/Audio, but has an Accessibility stub mobile lacks) — exactly the
   drift documented in `tasks/ssot_airo_airo_tv_gap_analysis.md`'s Gap 5
   table. Rather than force artificial identity (a visible behavior change
   forbidden by this task) or skip the manifest, `visibleForShells` on each
   `IptvSettingsSectionDescriptor` records today's real per-shell visibility
   as data. Closing the gap becomes a future one-line `visibleForShells`
   edit instead of a new architecture decision.

## Validation performed

- `packages/core_product_shell`: `flutter analyze` (0 issues) and
  `flutter test` (9/9 passing).
- `packages/feature_iptv`: `flutter analyze` on touched files (0 issues,
  pre-existing unrelated infos/warnings elsewhere untouched); new manifest
  tests (9/9 passing); `iptv_navigation_drawer_test.dart` (8/8 passing,
  unmodified); full package `flutter test` run — 594 tests, only 3
  pre-existing failures (`player_lock_button_test.dart` x2,
  `iptv_screen_default_to_live_test.dart` x1) confirmed via `git stash` to
  fail identically on the pre-change baseline (unrelated `pumpAndSettle`
  timeouts, not touched by this change).
- `app/`: `flutter analyze` on all touched files (0 issues; the only errors
  seen are pre-existing missing-`firebase_options.dart`, a gitignored
  generated file absent in this worktree, unrelated to this change) —
  `feature_registry.dart`, `tv_shell.dart`, `settings_hub_screen.dart`,
  `tv_settings_screen.dart`, `main_coins.dart`. `flutter test` on
  `settings_hub_screen_test.dart` (9/9), `tv_settings_screen_test.dart`
  (2/2), `adaptive_tv_settings_screen_test.dart` (3/3), `tv_shell_test.dart`
  (1/1), and the new `main_coins_stub_test.dart` (2/2) — all passing,
  unmodified assertions.
- `scripts/check-module-manifests.py`: passes with the new
  `packages/core_product_shell/module.yaml` included (55/55 manifests
  valid).
- Confirmed no storage/`SharedPreferences` keys, route names, or provider
  identities changed by grepping for removed symbols
  (`_TvNavDestination`, `_TvSettingsSection`) across `app/` and
  `packages/feature_iptv` — no remaining references.

## Files changed

- `packages/core_product_shell/` (new package): `pubspec.yaml`,
  `module.yaml`, `lib/core_product_shell.dart`, `lib/src/shell_id.dart`,
  `lib/src/app_module.dart`, `lib/src/module_registry.dart`,
  `test/module_registry_test.dart`
- `app/lib/core/features/feature_registry.dart` (rewritten as compatibility
  shim)
- `app/lib/core/app/tv_shell.dart` (nav rail wired to shared manifest)
- `app/lib/features/settings/presentation/screens/settings_hub_screen.dart`
  (settings tiles wired to shared manifest)
- `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`
  (settings rail wired to shared manifest)
- `app/lib/main_coins.dart` (new stub entrypoint)
- `app/test/main_coins_stub_test.dart` (new)
- `app/pubspec.yaml`, `app/pubspec_tv.yaml` (add `core_product_shell` path
  dependency)
- `packages/feature_iptv/lib/domain/iptv_navigation_manifest.dart` (new)
- `packages/feature_iptv/lib/domain/iptv_settings_manifest.dart` (new)
- `packages/feature_iptv/lib/feature_iptv.dart` (export both manifests)
- `packages/feature_iptv/lib/presentation/widgets/iptv_navigation_drawer.dart`
  (wired to shared nav manifest)
- `packages/feature_iptv/pubspec.yaml`, `packages/feature_iptv/module.yaml`
  (add `core_product_shell` dependency)
- `packages/feature_iptv/test/iptv/domain/iptv_navigation_manifest_test.dart`
  (new)
- `packages/feature_iptv/test/iptv/domain/iptv_settings_manifest_test.dart`
  (new)

## References

- `docs/adr/0011-super-app-modular-shell-ssot.md`
- `docs/adr/0010-airo-coin-package-first-development.md`
- `tasks/ssot_airo_airo_tv_gap_analysis.md`
- `tasks/ssot_airo_airo_tv_architecture_blueprint.md`
- `tasks/ssot_airo_airo_tv_todo.md`
- `docs/features/airo-tv/AIRO_SUPER_APP_SSOT_CONSOLIDATION_FEATURE_PACKET.md`

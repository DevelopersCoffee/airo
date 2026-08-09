# Todo: Cross-App Promotion (Airo Family Showcase)

Plan: [cross-app-promotion-plan.md](cross-app-promotion-plan.md) · Spec: [SPEC.md](../SPEC.md)

- [x] Task: Create `SiblingApp` model + static registry in `core_product_shell`
  - Acceptance: `SiblingApp` class with `id (ShellId)`, `name`, `pitch`,
    `iconAsset`, `deepLinkScheme` (nullable), `androidStoreUrl`,
    `iosStoreUrl`, `isPublishedAndroid`, `isPublishedIos`. Static
    `siblingApps` list with all 4 shipped apps. Helper
    `siblingAppsFor(ShellId current)` excludes self; returns empty list for
    qualification/patrol `ShellId`s.
  - Verify: `flutter test packages/core_product_shell` — new tests cover
    self-exclusion and qualification/patrol suppression.
  - Files: `packages/core_product_shell/lib/src/sibling_apps/sibling_app.dart`,
    `sibling_app_registry.dart`, `core_product_shell.dart` (barrel export),
    `test/sibling_apps/sibling_app_registry_test.dart`

- [x] Task: Copy + wire shared sibling-app icon assets (shipped as one
      shared placeholder mark — no per-flavor icons exist yet, see spec
      resolved decision 2)
  - Acceptance: 4 icon PNGs (one per app) present under
    `packages/core_product_shell/assets/sibling_icons/`, declared in that
    package's `pubspec.yaml` assets section, resolvable from
    `SiblingApp.iconAsset` paths in the registry.
  - Verify: `flutter pub get` succeeds, asset loads in a throwaway widget
    test (`Image.asset` doesn't throw).
  - Files: `packages/core_product_shell/assets/sibling_icons/*.png`,
    `packages/core_product_shell/pubspec.yaml`

- [x] Task: Build `AppInfoTile` widget
  - Acceptance: reads `PackageInfo.fromPlatform()`, renders
    `version (buildNumber)`; tap expands/shows package name. Testable via
    injected `PackageInfo` (don't call the platform channel directly in
    tests).
  - Verify: widget test with mocked `PackageInfo` asserts rendered text.
  - Files: `app/lib/features/settings/presentation/widgets/app_info_tile.dart`,
    `app/test/features/settings/app_info_tile_test.dart`

- [x] Task: Build `SiblingAppCard` widget
  - Acceptance: renders icon + name + pitch; CTA button opens
    `androidStoreUrl`/`iosStoreUrl` (platform-aware) via `url_launcher` when
    published, renders disabled "Coming soon" when not. No deep-link call
    yet (v1 scope per spec).
  - Verify: widget test — tap on published entry triggers launcher call
    with expected URL (mock `url_launcher` platform interface); unpublished
    entry's CTA is disabled and doesn't call launcher.
  - Files: `app/lib/features/settings/presentation/widgets/sibling_app_card.dart`,
    `app/test/features/settings/sibling_app_card_test.dart`

- [x] Task: Wire into `SettingsHubScreen` (phone/coins/mind)
  - Acceptance: `AppInfoTile` + "More Airo Apps" section
    (`SiblingAppCard` per entry from `siblingAppsFor(currentShellId)`)
    appended after existing sections, doesn't reorder/break current tiles.
    Current `ShellId` sourced the same way existing code determines shell
    (check for an existing provider/constant before adding a new one).
  - Verify: `flutter analyze` clean; existing settings widget tests still
    pass; new test confirms section renders with correct entries for a
    given `ShellId`.
  - Files: `app/lib/features/settings/presentation/screens/settings_hub_screen.dart`

- [x] Task: Wire into `TvSettingsScreen`
  - Acceptance: same two additions, adapted to TV rail/detail layout
    (matches existing D-pad focus/navigation conventions in that file —
    check `android-tv-design` skill guidance before laying out focus order).
  - Verify: `flutter analyze` clean; manual Fire TV Stick check — D-pad can
    reach and activate every sibling-app CTA.
  - Files: `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`

- [ ] Task: Manual device verification pass
  - Acceptance: on physical Pixel 9 — phone, Coins, Mind flavors each show
    correct version/build + correct 3-sibling list (self excluded); CTA
    opens store listing (or shows "Coming soon" if unpublished). On Fire TV
    Stick 4K — TV flavor same check via D-pad, plus qualification/patrol
    build confirmed to suppress the sibling section but keep app-info row.
  - Verify: checklist walked on each of the 4 consumer flavors + 1 test
    flavor, per spec Success Criteria. No emulators/simulators — physical
    rig only, per project convention.
  - Files: none (verification only)

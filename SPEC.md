# Spec: Cross-App Promotion (Airo Family Showcase)

## Objective

Every Airo app currently ships in isolation — a user who has Airo TV has no
in-app path to discover Airo, Airo Coins, or Airo Mind, and no visible app
version/build number for support or bug reports. This feature adds two things
to every flavor's Settings hub:

1. **App info row** — version + build number (e.g. `2.4.1 (318)`), tappable
   to reveal full details (package name, build date if available).
2. **"More Airo Apps" section** — a card/list showcasing the other shipped
   Airo apps, each with icon, one-line pitch, and a call-to-action that deep
   links into the sibling app if installed, or opens its store listing if not.

**User:** existing Airo/Airo TV/Airo Coins/Airo Mind users browsing Settings.
**Success:** a user on any one app can see what version they're running and
discover + open/install any sibling app within two taps from Settings, with
zero added friction for the primary settings flows already in the file.

## Scope

All five flavors get both the app-info row and the sibling-app section:
- Airo (phone) — `app/lib/main.dart`, `pubspec.yaml`
- Airo TV — `main_tv.dart`, `pubspec_tv.yaml`
- Airo Coins — `main_coins.dart`, `pubspec_coins.yaml`
- Airo Mind — `main_mind.dart`, `pubspec_mind.yaml`
- Qualification/Patrol (`main_qualification.dart`,
  `pubspec_qualification.yaml`, `pubspec_patrol.yaml`) — internal/CI test
  flavors, in scope per stakeholder decision but sibling-app section is
  behind the same visibility as everything else in the qualification build
  (no special-casing).

Each flavor's own app is excluded from its own sibling list (Airo TV shows
Airo, Airo Coins, Airo Mind — not itself).

## Tech Stack

- Flutter / Dart, Melos workspace (existing).
- `package_info_plus` (already a dependency in `app/pubspec.yaml`,
  `core_ai`, `feature_iptv`) for version/build number.
- `url_launcher` (already a dependency across several packages/flavors) for
  store-listing fallback links.
- Deep-link-if-installed: needs a platform check (e.g. custom URL scheme
  probe via `url_launcher.canLaunchUrl` on each sibling app's registered
  scheme, or Android package-manager query / iOS `LSApplicationQueriesSchemes`)
  — **flagged as an open question below**, since none of the flavors
  currently declare inter-app URL schemes.
- Riverpod for state (matches `SettingsHubScreen`'s existing
  `ConsumerWidget` pattern).

## Project Structure

New/changed files, following the existing settings feature layout:

```
packages/core_product_shell/
  lib/src/sibling_apps/
    sibling_app.dart              → data model: id, name, icon asset,
                                     pitch, storeUrl (iOS/Android),
                                     deepLinkScheme
    sibling_app_registry.dart     → static manifest of all 4 shipped apps
                                     (SSOT, mirrors iptvSettingsSections
                                     pattern already used for TV/mobile
                                     settings parity)

app/lib/features/settings/presentation/
  screens/
    settings_hub_screen.dart      → add app-info row + sibling-apps section
  tv/
    tv_settings_screen.dart       → same, TV layout (rail/detail)
  widgets/
    app_info_tile.dart            → new: version/build display
    sibling_app_card.dart         → new: icon + pitch + CTA button,
                                     shared across phone/TV/coins/mind
```

`sibling_app_registry.dart` lives in `core_product_shell` (already owns
cross-app shell contracts, already forbids `app` as a dependency) so all four
`main_*.dart` entrypoints and both settings screens consume the same list —
avoids the four flavors drifting on which apps/URLs are listed.

## Code Style

Match the existing `SettingsHubScreen` pattern: doc comment above the class
explaining *why* the section exists and what SSOT it draws from, `ListTile`
building blocks, no inline literals — pull labels from the registry.

```dart
/// Registry entry for one Airo family app, rendered in every flavor's
/// "More Airo Apps" section. `id` excludes the current flavor at
/// render time so an app never promotes itself.
class SiblingApp {
  const SiblingApp({
    required this.id,
    required this.name,
    required this.pitch,
    required this.iconAsset,
    required this.deepLinkScheme,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
  });

  final ShellId id;
  final String name;
  final String pitch;
  final String iconAsset;
  final String deepLinkScheme;
  final Uri androidStoreUrl;
  final Uri iosStoreUrl;
}
```

## Testing Strategy

- Unit tests (`core_product_shell` test dir): registry excludes current
  `ShellId` correctly; deep-link-vs-store-fallback URL resolution logic.
- Widget tests (`app/test/features/settings/`): `AppInfoTile` renders
  version/build from a mocked `PackageInfo`; `SiblingAppCard` renders all
  registry entries minus self, CTA tap calls the launcher with the right URL.
- Manual device check: run each flavor per `run-airo-tv` skill / existing
  flavor launch docs, confirm Settings shows correct sibling list and app
  info, confirm tap opens sibling app when installed vs. store link when not
  (test on the physical Pixel 9 + Fire TV Stick rig per project memory, not
  emulators).
- No golden tests required unless Chief UX Officer requests them during
  review (TV rail/detail layout has no existing goldens for this section).

## Boundaries

- **Always do:** keep the sibling-app registry as the single source of truth
  consumed by all flavors (no flavor hardcodes its own copy); follow the
  `runOffMain()` rule if any parsing/JSON exceeds ~50 KB (registry is a
  small static list, unlikely to trigger this); run
  `flutter build web --release` before landing if any touched path affects
  web (Settings screens are cross-platform).
- **Ask first:** adding a new URL-scheme entitlement/`LSApplicationQueriesSchemes`
  declaration per platform (security/App Store review surface — needs
  Chief Security Officer + Chief Release/DevOps sign-off since it changes
  what the app declares to app stores); adding `url_launcher` to any flavor
  that doesn't already depend on it; the exact deep-link probing mechanism
  (Android intent query vs. iOS scheme allowlist) since it's unresolved
  below.
- **Never do:** promote apps not yet shipped/store-listed; make the
  sibling-app section block or precede the flavor's own core settings (it is
  additive, placed after existing sections); collect analytics on which
  sibling app a user tapped without a separate, explicitly-approved
  telemetry spec.

## Success Criteria

- [ ] Every flavor's Settings hub (phone `SettingsHubScreen`, TV
      `TvSettingsScreen`, Coins/Mind equivalents) shows version + build
      number pulled live from `package_info_plus`.
- [ ] Every flavor's Settings hub shows a "More Airo Apps" section listing
      the other 3 shipped apps (not itself), each with icon + one-line pitch.
- [ ] Tapping a sibling app entry deep-links into it if installed, else
      opens the correct store listing for the current platform
      (Android/iOS).
- [ ] `core_product_shell`'s sibling-app registry is the only place the app
      list/URLs are defined; no flavor-local duplication.
- [ ] `flutter analyze` clean, new unit/widget tests pass, `flutter build web
      --release` succeeds.
- [ ] Verified on physical Pixel 9 (phone/Coins/Mind) and Fire TV Stick 4K
      (TV) — both installed-sibling and not-installed-sibling states.

## Resolved Decisions (were Open Questions)

1. **Deep-link mechanism**: v1 ships store-link-only. No custom URL scheme /
   App Link work now — avoids platform manifest/entitlement changes and the
   Ask-First security review this cycle. `SiblingApp.deepLinkScheme` field
   stays in the model (nullable, unused) so phase 2 can wire real
   deep-linking without a registry schema change. CTA button always opens
   the store listing for now.
2. **Icon assets**: no shared small-icon asset dir exists today — only
   `app/assets/airo_icon.png` (phone). Reuse each flavor's existing
   1024×1024 platform app icon (`.../AppIcon.appiconset/app_icon_1024.png`
   equivalent per flavor) copied once into a new shared
   `packages/core_product_shell/assets/sibling_icons/` dir, referenced by
   `SiblingApp.iconAsset`. No new design work.
3. **Store listing status**: not all four apps are confirmed live on both
   stores. `SiblingApp` gets an `isPublished` bool per platform; unpublished
   entries render a disabled "Coming soon" CTA instead of a store link, so
   the registry can be updated flag-only when an app ships.
4. **Qualification/Patrol flavor**: sibling-app section is suppressed for
   these two flavors (test/CI builds, no real users) — app-info row (version
   + build) still shows since that's useful for QA triage. Gate this off
   `ShellId` in the registry consumer, not a separate code path.

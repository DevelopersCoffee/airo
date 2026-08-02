# IPTV Nav Regroup + Settings-Under-Profile — Design

Date: 2026-08-02

## Problem

Guide and Favorites were previously promoted from IPTV into top-level
persistent nav tabs (`app_router.dart` comment at the Guide branch confirms
this was deliberate). This duplicates navigation: the same screens
(`IptvGuideScreen`, `MobileFavoritesScreen`) are reachable both from the
top-level tab bar/overflow sheet and from `IptvNavigationDrawer` inside the
IPTV section itself. Settings is also a top-level tab despite a code comment
saying it "has never had a persistent nav slot and stays reachable via the
profile menu" — the enum/overflow wiring contradicts that intent.

## Goal

1. Guide and Favorites become IPTV-internal only — reachable via the existing
   `IptvNavigationDrawer`, not the top-level tab bar or the phone "More"
   overflow sheet.
2. Settings is removed from the top-level tab bar/overflow. Its sole entry
   point becomes the existing "Settings" `ListTile` on `ProfileScreen`
   (already present at `profile_screen.dart:65-72`, already navigates to
   `RouteNames.settings`).
3. IPTV-specific settings tiles (Theme, Audio, Playback, Playlist Source, EPG
   Guide Source, Country — sourced from `feature_iptv_core`'s
   `iptvSettingsSections` manifest) are visually grouped under one "IPTV"
   section header in `SettingsHubScreen`, instead of appearing as a flat tile
   list alongside non-IPTV settings.

## Non-goals

- No changes to `feature_iptv_core` (`iptv_settings_manifest.dart`,
  `iptv_navigation_manifest.dart`) — manifests already correctly describe the
  IPTV settings/nav destinations.
- No new screens, no new routes, no change to `IptvGuideScreen`,
  `MobileFavoritesScreen`, or `IptvNavigationDrawer` internals.
- No change to `SettingsHubScreen`'s non-IPTV sections (Airo Mind
  portability, Developer Tools, etc.) beyond making room for the new IPTV
  group header.
- TV shell (`tv_shell.dart` nav rail) is out of scope — it already mirrors
  the IPTV drawer's Home/Guide/Movies/Favorites structure and is unaffected
  by phone/tablet top-level tab changes.

## Changes

### 1. `app/lib/core/providers/navigation_provider.dart`
- Remove `AppNavigationTab.guide`, `.favorites`, `.settings` enum entries (or
  keep the enum values but stop referencing them in `widePrimaryTabs` /
  `overflowTabs` — whichever keeps `app_router.dart` branch wiring simplest;
  implementer's call after reading the current switch statements).
- Remove their entries from `widePrimaryTabs` (lines ~195-196) and
  `overflowTabs` (lines ~202-204).

### 2. `app/lib/core/routing/app_router.dart`
- Remove the top-level Guide branch (~349-359), Favorites branch (~364-374),
  and Settings tab branch (~378-394) from the `StatefulShellRoute`.
- Settings route (`/settings` + `airo-portability` sub-route) must still
  exist and be reachable by direct push (from Profile) — move it to a plain
  (non-shell-branch) route registration alongside `/mind/profile` so
  `Navigator.pushNamed(RouteNames.settings)` from `ProfileScreen` keeps
  working.
- Guide/Favorites need no standalone route once removed from the shell —
  they're pushed from within IPTV via `IptvNavigationDrawer`'s existing
  `Navigator.push` calls (`iptv_screen.dart:617-635`), which build the
  widgets directly rather than going through named routes. Confirm no other
  code references `RouteNames.guide` / `RouteNames.favorites` before
  deleting; if something does, keep a route but drop it from the shell
  branches only.

### 3. `app/lib/features/agent_chat/presentation/screens/profile_screen.dart`
- No structural change — the existing Settings `ListTile` (lines 65-72)
  already does the right thing. Verify after the router change that it still
  resolves correctly now that Settings is a plain route, not a shell branch.

### 4. `app/lib/features/settings/presentation/screens/settings_hub_screen.dart`
- Wrap the IPTV-sourced tiles (Theme, Audio, Playback, `CountrySettingsTile`,
  Playlist Source, EPG Guide Source — lines ~32-110) in a single labeled
  section (header text "IPTV", consistent with whatever section-header
  pattern the screen already uses for its other groups, e.g. Airo Mind
  portability). Iterate `iptvSettingsSections` manifest entries under this
  one header instead of rendering them inter-mixed with non-IPTV settings.
- Non-IPTV sections (Airo Mind portability, Developer Tools) keep their
  current headers/order relative to the new IPTV group.

## Testing

- `flutter analyze` clean on `app/`.
- Existing widget/golden tests touching `navigation_provider.dart`,
  `app_router.dart`, `settings_hub_screen.dart`, or bottom nav tab count must
  be updated to reflect 3 fewer top-level tabs (or however many tabs remain)
  — search for tests asserting on `AppNavigationTab` values or tab counts.
- Manual check (documented in PR description, not necessarily device-tested
  given worktree constraints): Profile → Settings → IPTV group visible;
  IPTV section → drawer → Guide/Favorites open; top-level tab bar/overflow
  no longer lists Guide/Favorites/Settings.

## Risk

Low — pure nav/route/UI-grouping change, no manifest or business-logic
change, no cross-package boundary violation (all edits stay inside `app/`
except reading — not modifying — `feature_iptv`/`feature_iptv_core`
manifests already exported for this purpose).

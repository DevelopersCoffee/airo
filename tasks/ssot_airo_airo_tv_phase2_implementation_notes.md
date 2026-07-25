# SSOT Migration — Phase 2 Implementation Notes

Date: 2026-07-25
Follows: `ssot_airo_airo_tv_phase1_implementation_notes.md` (phase 1, PR #1098–#1100)

## What shipped in phase 2

All merged to `main`, each verified green (analyze + tests + module manifests
+ docs gate) before or immediately after merge:

| PR | Change |
|----|--------|
| #1101 | `packages/feature_iptv_core` created — 7 platform-agnostic domain files (nav/settings manifests, local search, VOD grouping/resume, favorite reimport, wakelock debouncer) moved out of `feature_iptv/lib/domain/`, old paths kept as one-line re-export shims. Also moved `TvPlaybackSection` + `TvSourceManagementSection` from `app/lib/features/settings` into `feature_iptv`. |
| #1102 | docs/wiki: recorded the settings module-ownership rule. |
| #1103 | Mobile `PlaybackSettingsScreen` moved from `app/lib/features/settings` into `feature_iptv` (symmetric with the TV move). |
| #1104 | `packages/core_app_shell` created — `app_theme_provider`, `deferred_startup_task`, `platform_features`, `device_form_factor` extracted from `app/lib/core/*` with re-export shims; 5 test files' absolute imports updated. |
| #1105 | Hotfix: `core_app_shell` dependency added to `app/pubspec_tv.yaml` (the separate TV-variant pubspec missed in #1104 — TV build resolves against it, not `pubspec.yaml`). |
| #1106 | Mobile `CountrySettingsTile` (was private `_CountrySettingsTile` in `settings_hub_screen.dart`) moved into `feature_iptv` as a public widget. Completes the settings ownership pass. |

## Settings ownership rule (now enforced by placement)

IPTV-owned, live in `packages/feature_iptv`: Playback (mobile screen + TV
section), Source Management (TV section), Country (mobile tile).

App-level "Airo profile" settings, stay in `app/lib`: Theme (shared with the
whole app's chrome via `appThemeProvider`, now in `core_app_shell`), Audio
(shares `audio_context_provider` with the Music player).

Rule: a setting lives at app level only when it is genuinely cross-app;
otherwise it belongs to the module that owns its state.

## Verified non-issues (no work needed)

- **Video player**: one `VideoPlayerWidget` already serves both mobile and TV
  screens. The `video_player` vs `mpv` engine pair in `platform_media` is an
  intentional capability-gated fallback (low-RAM / no-HW-decode devices), not
  duplication.
- **TV focus/input infra**: `TvFocusable`, `TvFocusManager`, `TvInputHandler`
  already canonical in `core_ui`; `app/lib/core/tv/*` are pre-existing shims.
- **Favorites/cast screens**: shared providers, distinct per-shell layouts —
  already the intended "unify contracts, not widget trees" shape.

## Deliberately deferred (with reasons)

1. **`apps/airo_tv` / `apps/airo_super` first-class app roots** — requires
   extracting ~10 more app-internal modules AND recreating the native Android
   signing setup. Play Store requires the same signing cert for updates;
   getting `applicationId`/keystore wiring wrong in a fresh
   `apps/airo_tv/android` would break the published app's update path. Needs
   a session with device/Play Console verification. See
   `~/.claude` memory note `airo-tv-app-root-scope` and #1104's PR body.
2. **Full `feature_iptv` application/presentation split** — premature until
   the app roots actually split. Both entrypoints already consume the same
   package today; physically partitioning 43 provider + 77 presentation files
   now adds churn with no consumer-visible benefit.
3. **`global_error_handler.dart` extraction** — depends on
   `bug_report_dialog.dart` (+`screenshot_service`, `platform_config`,
   image_picker/url_launcher) which together form a standalone bug-report
   feature, not shared shell infrastructure. Extract that feature as its own
   package first if ever needed.
4. **Airo Coins real UI** — `main_coins.dart` stub only. Blocked on creating
   the clean core-coin package per ADR-0010 (must not fork the three legacy
   divergent coin codebases). Product/design decision needed before build.

## Known pre-existing failures (not from this work)

- `feature_iptv`: `player_lock_button_test.dart` (2 tests, leak-tracker
  order-dependence) and `iptv_screen_default_to_live_test.dart` ("deep link
  does not start the stored-channel resume flow"). Fail identically on
  baseline `main`.
- `app/lib/firebase_options.dart` is gitignored; a committed placeholder
  fallback landed on main 2026-07-25, so full local `app` test runs pass
  again (1017 tests at time of writing).

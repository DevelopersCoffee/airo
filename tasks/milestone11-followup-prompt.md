# Milestone 11 follow-up — paste as-is in a new chat

Repo: DevelopersCoffee/airo. Milestone 11 (epic #674, "v2.0.1 — Public Release
& Store Publishing") is functionally done — 7 issues closed, base branch is
`main` (v2 strategy dropped 2026-08-13), release line is `0.0.7-preview`.
Worktree at `/Users/udaychauhan/workspace/airo-worktrees/milestone-11-public-release`
(branch `milestone/11-public-release-store`) still exists — reuse it or make a
fresh one off latest `origin/main`.

## What's still open (all genuinely blocked, not engineering gaps)

- **#576** Android release signing secrets — needs keystore + signing config
  from the user. Ask, don't fabricate.
- **#756** Firebase Android client registration for `io.airo.app.iptv` /
  `io.airo.app.streaming` — needs Firebase project access from the user.
- **#803** macOS notarization — needs Apple Developer ID cert from the user.
- **#716** iPad Air device qualification campaign — needs a live device
  session with the user, and #576/#756 landed first (needs a signed build).

Don't close epic #674 until these 4 either land or get explicitly deferred.

## Spinoff bugs filed this pass, not fixed — pick these up if asked to keep going

- **#1715** — `pubspec_ios_spm.yaml`: `wakelock_plus` vs
  `flutter_secure_storage_windows` win32 version conflict, blocks
  `variant-dependencies` CI job. Fix is likely just bumping `wakelock_plus`
  past 1.6.0 in `app/pubspec.yaml`.
- **#1716** — 17 pre-existing `feature_mind` test failures on `main` (golden
  layout mismatches in `test/surfaces/*`, and `runtime_console_table_test.dart`
  fully broken). Needs someone with feature_mind context to triage — likely
  two distinct root causes.
- **#1721** — `airo_tv_shell.dart`'s wide-layout explorer panel `Column`
  (line ~280) stacks fixed-height `_ExplorerSection` rows with no scroll
  fallback; overflows "BOTTOM OVERFLOWED" when a mini-player bottom sheet eats
  screen space the shell doesn't account for. Root-caused but not fixed —
  needs testing across every `showStats`/`showHotbar`/`showFilter`/
  `showPlaylist`/`showVideoStage` combo and the TV D-pad focus system before
  touching it.

## Dev environment gotcha (already in memory, but re-state if build fails)

On this machine, Homebrew's `cargo`/`rustc` shadow rustup's toolchain even
under `rustup run stable`, breaking any `flutter build apk` that triggers a
Rust cargokit build (feature_mind, core_native) with a misleading
`error[E0463]: can't find crate for 'core'`. Fix: run
`export PATH="$HOME/.cargo/bin:$PATH"` before building. Also run
`dart run build_runner build` in `packages/feature_mind` before any
`flutter build apk` — its freezed-generated files aren't committed.

## Physical device

A Pixel 9 is available over wireless adb (IP changes per session — re-pair
with `adb pair <ip:port> <code>` if the user gives new pairing info, or
`adb connect` if already paired once, using `adb mdns services` to find the
current live port).

## What to actually do

Ask the user which of the above they want worked: the 4 blocked issues (need
their input to unblock), the 3 spinoff bugs (pure engineering, can start
immediately), or both. Don't assume — the last chat ended on "what's pending"
without a specific next task picked.

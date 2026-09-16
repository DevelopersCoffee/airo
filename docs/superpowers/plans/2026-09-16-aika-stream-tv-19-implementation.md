# Aika Stream TV 0.0.1+19 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship test OBB `0.0.1+19` that fixes Bravia UAT from `0.0.1+18`: Watch owns live audio, Home is QR or silent rails, Play installs on Bravia and Pixel 9.

**Architecture:** Stop using `TvShell` overlays on a mounted `/live` child. Use the routes that already exist in `tv_router.dart` (`/`, `/player`, `/guide`, `/vod`, `/favorites`, `/settings`). Home must stop redirecting to `/live`. Call `VideoPlayerStreamingService.stop()` when leaving `/player`.

**Tech Stack:** Flutter TV flavor, Riverpod, `feature_iptv`, `platform_media` / `platform_player`, `core_ui`.

**Spec:** `docs/superpowers/specs/2026-09-16-aika-stream-tv-19-design.md`  
**Reviewed plan:** `docs/superpowers/plans/2026-09-16-aika-stream-tv-19.md`  
**GitHub:** https://github.com/DevelopersCoffee/airo/issues/2014  
**Base:** `origin/main` only. Not `agent/anya/1991-gguf-plan-repair`.

---

## File map

| File | Responsibility |
| --- | --- |
| `app/lib/core/app/tv_router.dart` | Real Home route. `/` must not redirect to `/live`. Watch is `/player` only. |
| `app/lib/core/app/tv_shell.dart` | Rail collapse/expand. `onDestinationSelected` uses `context.go`, not overlays. No live child under Settings. |
| `app/test/core/app/tv_shell_test.dart` | Rail + Back + silent destinations. |
| `packages/platform_media/lib/src/video_player_streaming_service.dart` | Existing `stop()` (audio focus + engine + media session). Call it; do not fork. |
| `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart` | Bounded transport overlay. Extract Mini Guide. |
| `packages/feature_iptv/lib/presentation/widgets/tv_mini_guide_overlay.dart` | New. One muted preview. |
| `packages/feature_iptv/lib/presentation/tv_ux/` | Home dashboard + QR landing. |
| `packages/feature_iptv/lib/presentation/widgets/tv_playlist_qr_dialog.dart` | Reuse as primary empty Home, restyle. |
| `app/pubspec_tv.yaml` | `0.0.1+19` last. |

---

## Bootstrap (every workstream)

```bash
git fetch origin main
git worktree add ../airo-worktrees/<issue>-aika-stream-tv-19 -b agent/tv/<issue>-aika-stream-tv-19 origin/main
```

Verify: `git merge-base --is-ancestor origin/main HEAD`.

---

### Task 1: Failing test — destinations do not keep a live session

**Files:**
- Modify: `app/test/core/app/tv_shell_test.dart`
- Later: `app/lib/core/app/tv_shell.dart`, `app/lib/core/app/tv_router.dart`

- [ ] **Step 1: Write the failing test**

Add a test that opens Settings via the rail and asserts the IPTV live screen is **not** in the tree (or is `ExcludeFocus`+offstage is not enough: assert `streamingStateProvider` is idle / a stop counter incremented).

Today Settings is `_TvOverlayScreen.settings` painted over `widget.child` (`/live`). The test should fail while that design remains.

```dart
testWidgets('opening Settings from the rail leaves no live playback surface',
    (tester) async {
  // pump TvRouter at /live with a recording FakeVideoPlayerStreamingService
  // tap Settings destination (index 4)
  // expect(stopCount, 1) OR expect(find.byType(VideoPlayerWidget), findsNothing)
});
```

Use the existing fake/stop seams in `feature_iptv` player tests if present. If the service is hard to inject from `app/test`, assert `find.byType(_AdaptiveLiveTvScreen)` / live keys are gone after `context.go(TvRouteNames.settings)`.

- [ ] **Step 2: Run it and confirm it fails**

```bash
cd app && flutter test test/core/app/tv_shell_test.dart
```

Expected: FAIL because overlays keep `/live` mounted.

- [ ] **Step 3: Implement the minimum**

1. In `tv_shell.dart` `_selectDestination`: `context.go` to `TvRouteNames.home|guide|vod|favorites|settings`. Delete `_overlay` / `_TvOverlayScreen` / `_buildOverlay`.
2. In `tv_router.dart`: remove `redirect` of `/` and `/login` to `/live`. `/` builds the new Home (Task 4 can land a stub: QR placeholder). Channel OK goes to `TvRouteNames.player`.
3. When leaving `/player` (Back or `go` away), await `streamingService.stop()` (`platform_media` `VideoPlayerStreamingService.stop` already releases audio focus and media session).
4. Keep `tvTitleSafeFraction`. Keep zen-mode hide rail on fullscreen Watch.

- [ ] **Step 4: Re-run tests**

```bash
cd app && flutter test test/core/app/tv_shell_test.dart
cd packages/feature_iptv && flutter test
```

Expected: PASS. No ghost audio path through overlay.

- [ ] **Step 5: Commit**

```bash
git commit -m "fix(tv): stop live playback when leaving Watch"
```

---

### Task 2: Rail focus regions

**Files:** `app/lib/core/app/tv_shell.dart`, `app/test/core/app/tv_shell_test.dart`

- [ ] Failing tests: LEFT from first content item focuses rail; RIGHT restores last content; Back from Home does not focus rail; rail width ~80 collapsed / ~240 expanded when focused.
- [ ] Keep `_handleContentKeyEvent` leading-edge LEFT, but it must target a real destination route, not overlay index 0 = live.
- [ ] Labels visible only when rail focused (`Aika Stream` + destination names). Collapsed = icons.
- [ ] Run `flutter test test/core/app/tv_shell_test.dart`
- [ ] Commit: `fix(tv): D-pad rail focus regions and collapse`

---

### Task 3: Bounded Watch overlay

**Files:** `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart`, tests next to it.

- [ ] Failing layout test at 1280×720 and 1920×1080: transport actions are a **single** `Row`/`ListView` inside a width-capped panel (~70–80% title-safe), not a `Wrap`.
- [ ] Replace `_buildTvTransportBar` `Wrap` with that panel. Overflow → More sheet.
- [ ] First focus: Pause/Play. Audio/Subtitles `onFocus`+disabled when no tracks. Favourite selected state from storage. Focus ring 4 dp, scale 1.05, height 56–72. Tokens from `AiroSpacing` / `AiroTypography` / `AiroTheme` (no raw `fontSize: 28` in feature_iptv).
- [ ] Auto-hide 5 s; D-pad shows chrome. No on-screen Back.
- [ ] Commit: `fix(iptv): bound TV player overlay to one action row`

---

### Task 4: Home QR + dashboard rails

**Files:** new `packages/feature_iptv/lib/presentation/tv_ux/tv_home_screen.dart` (or app equivalent composed by router), `tv_playlist_qr_dialog.dart`, import sheet, tests.

- [ ] No playlist: QR primary (existing pairing server). URL/USB/Network secondary. IME cannot cover Save/Cancel.
- [ ] Import success: summary card, Start Watching **closes modal and lands Home**, does not auto-tune `/player`.
- [ ] With channels: rails Continue Watching / Live TV (8–12) / Favorites / Recently Added. **Hide empty rails.** Fallback: Live TV from catalog order.
- [ ] Default focus: first card of first visible rail. OK → `/player`. See all Live TV → `/guide`.
- [ ] One-line ellipsis names. No filter chrome on Home.
- [ ] Tests: QR empty; hide empty CW; import close.
- [ ] Commit: `feat(tv): QR Home and silent dashboard rails`

---

### Task 5: Mini Guide live preview

**Files:** Create `packages/feature_iptv/lib/presentation/widgets/tv_mini_guide_overlay.dart`. Shrink `video_player_widget.dart`. Do **not** add another 400 lines to the player widget.

- [ ] Keep UP open / DOWN recents logos-only.
- [ ] One muted preview, 500 ms settle, stop previous on focus move, spinner, LIVE badge, no controls.
- [ ] OK: stop preview, retune main, close. Back: release preview, main continues.
- [ ] Preview fail: logo+error, main stays.
- [ ] Tests: at most one preview controller; dispose on move; fail does not stop main.
- [ ] Commit: `feat(iptv): Mini Guide single muted preview`

---

### Task 6: Dialogs, Browse Network, branding

**Files:** playlist source sheet, network browse empty, TV chrome strings, launcher/splash/QR if still “Airo TV”.

- [ ] Playlist sources: TV panel, no covering keyboard.
- [ ] Browse Network empty: Find media / same network / Scan again / How it works.
- [ ] Grep gate for user-facing TV strings: `Airo TV`, `AIRO TV`, `Midas Stream` in `app/lib` TV + `feature_iptv` presentation (not CHANGELOG).
- [ ] Commit: `fix(tv): TV dialogs, network empty state, Aika Stream chrome`

---

### Task 7: Play dual-form-factor + version 19

**Files:** `app/pubspec_tv.yaml` last. Docs: `docs/release/AIKA_STREAM_PLAY_STORE_GATE.md` Console checklist.

- [ ] Manifest verify only: `leanback`/`touchscreen` `required=false`, both launchers. Do not set leanback required.
- [ ] Human Console: Phone + TV form factors, both screenshot sets, testers, Pixel 9 + Bravia in catalog.
- [ ] Compact Pixel: leave player still calls `stop()` (extend existing lifecycle tests).
- [ ] Bump `version: 0.0.1+19`. Cut OBB via `aika-stream-release.yml` after packet green.
- [ ] Commit: `chore(tv): cut Aika Stream 0.0.1+19`

Do not bump versionName off `0.0.1`.

---

## Checkpoints

After Tasks 1–2: Bravia can leave Watch without audio; D-pad reaches rail.  
After 3–4: overlay and Home match the spec.  
After 5–6: Mini Guide + branding.  
After 7: testers install 19 on Bravia and Pixel 9.

## Out of scope

VOD resume, Pixel 9 TV dashboard, MultiView features, iptv-org presets, historical CHANGELOG rewrite.

## Self-review vs spec

| Spec requirement | Task |
| --- | --- |
| Ghost audio / Watch ownership | 1 |
| D-pad rail | 2 |
| Overlay panel | 3 |
| QR + Home rails | 4 |
| Mini Guide one preview | 5 |
| Dialogs / network / brand | 6 |
| Play TV+phone + 19 | 7 |

<!-- /autoplan restore point: "/Users/udaychauhan/.gstack/projects/DevelopersCoffee-airo/agent-anya-1991-gguf-plan-repair-autoplan-restore-20260916-150759.md" -->
# Aika Stream TV 0.0.1+19 Implementation Plan

> **For agentic workers:** Approved spec: `docs/superpowers/specs/2026-09-16-aika-stream-tv-19-design.md`. Found in `0.0.1+18`. Ships as `0.0.1+19`. Base: `origin/main`.

**Goal:** Dedicated Aika Stream TV interaction layer: Watch owns live audio, Home is a silent dashboard or QR landing, Play listing installs on Bravia and Pixel 9.

**Architecture:** Invert `TvShell` overlay-on-live. Destinations have no player. Watch is a route with a bounded overlay and a single muted Mini Guide preview.

**Tech Stack:** Flutter TV flavor, Riverpod, `feature_iptv`, `platform_player`, `core_ui`. No new playback engine.

## Implementation plan

### Spec: Aika Stream TV 0.0.1+19

**Status:** Draft — pending user review of this file
**Date:** 2026-09-16
**Found in:** `0.0.1+18` (Play internal/test OBB, Bravia)
**Ships in:** `0.0.1+19` (next test OBB; do not bump past 19 until this packet is clean)
**Package:** `com.developerscoffee.tv.midas`
**Entrypoint:** `app/lib/main_tv.dart` / `app/pubspec_tv.yaml`

### Objective

Make Aika Stream a dedicated Android TV product: D-pad focus, viewing-distance scale, persistent navigation, and a Watch surface that owns live playback. Stop treating the ten-foot UI as the mobile/web explorer scaled up.

Testers on the same 19 OBB must be able to install from Play on a **Sony Bravia** and a **Pixel 9**. 18 stays the found-in build. Do not reuse versionCode 18.

### Locked decisions

| Topic | Decision |
| --- | --- |
| Scope | Full Bravia note list in 19 (player overlay, D-pad, branding, ghost audio, Home dashboard, QR onboarding, Mini Guide live preview, filters dialog, network empty state, Play dual form-factor) |
| Binary | One Aika Stream package |
| Bravia | New 10-foot interaction layer |
| Pixel 9 | Same listing; existing compact/touch shell, not the TV dashboard |
| Live audio | Watch owns playback. Home/Guide/Movies/Favorites/Settings are silent |
| Continue Watching | Last-watched live channels via `recentlyWatchedChannelsProvider`. Logos only. OK opens Watch |
| Catalog | Guide, not Home |
| Movies | VOD groups from the user playlist. Real empty state if none |
| Mini Guide | Overlay on Watch only. One muted preview on the focused card |
| First launch | QR-primary onboarding when no playlist |
| After import | Success summary, then silent Home. Modal closes itself |
| SDLC | Parent GitHub issue + child PRs on `origin/main`, then one 19 OBB |

### Non-goals

- A second Aika Stream package or a phone-only listing.
- Rewriting the Pixel 9 compact explorer into the TV dashboard.
- True VOD resume in Continue Watching (watch-progress row is later).
- Playing more than one Mini Guide preview at a time.
- Bundled playlists, iptv-org presets, or any Play policy regression of BYOC.
- Rewriting historical CHANGELOG / evidence that still says “Airo TV”.
- MultiView feature work (leaving Watch still tears down MultiView sessions because Watch owns playback).
- Bumping `versionName` off `0.0.1` in this packet.

### Why 18 behaves this way

`TvShell` (`app/lib/core/app/tv_shell.dart`) mounts `/live` under overlays and documents “VIDEO LAYER always present, never destroyed” / “Playback never stops.” Home is that live route. Guide/Movies/Favorites/Settings paint on top and keep the decoder. That is the Bravia ghost-audio bug, the grid-as-Home, and the focus trap: content and rail are stacked on a player that never releases.

The TV transport bar in `video_player_widget.dart` is a full-bleed `Wrap` (Pause, Restart, Audio, Subtitles, Favourite, Info). On real panels it wraps, overlaps video, and inflates the focus ring.

Mini Guide already opens on D-pad UP. Cards are 96×130 logos. There is no preview decoder.

QR LAN pairing (`TvPlaylistQrDialog` + `TvPlaylistPairingServer`) already exists and is not the primary empty state.

Manifest already has `leanback`/`touchscreen` `required="false"` and both `LAUNCHER` and `LEANBACK_LAUNCHER`. Pixel 9 missing from the 18 test track is a Play Console form-factor / screenshot / tester gap, not a missing activity.

### Approaches considered

1. **Patch `TvShell` overlays** — fastest for chrome-only bugs; cannot stop audio or make Home a dashboard without fighting the retained live child. Rejected.
2. **Dedicated TV interaction layer, sequenced PRs, one 19 OBB** — chosen. Watch is a real route. Destinations do not keep a hidden player.
3. **One long-lived 19 branch** — same product, weak SDLC, painful rebase. Rejected.

### Architecture

```text
TvShell
  ├── Navigation rail (collapsed ~80dp / expanded ~240dp)
  └── Destination (no player)
        Home | Guide | Movies | Favorites | Settings
  └── Watch (full-screen)  ← only player owner
        ├── Bounded transport overlay
        └── Mini Guide overlay (muted preview on focused card)
```

**Focus model**

- Two regions: rail and content. Remember last content focus when entering the rail.
- `LEFT` from the first focusable content item → current rail destination.
- `RIGHT` from rail → previously focused content item.
- `UP`/`DOWN` in the rail move destinations. Expanding the rail (labels) happens when the rail has focus; collapse when content has focus.
- Hardware `Back` does not move focus into the rail. From an overlay (Mini Guide, Filters, dialog): close overlay. From Watch: pop Watch, stop playback, land on the destination that opened it (usually Home). From Home with no overlay: system/app exit behavior unchanged (no exit-confirm gate).
- Rail focus state is obvious at 10 feet (outline + scale + optional left accent).

**Playback ownership**

Watch is a **route**, not a focus node. Overlays on Watch (transport, Mini Guide, More) do not stop the main player.

```text
Watch is the current route → main player may PLAY
Watch popped or replaced by Home/Guide/Movies/Favorites/Settings → STOP and release main + preview
Mini Guide preview unfocused or Mini Guide closed → STOP preview only; main continues
Return to a channel → create a new Watch session
```

Implement at player lifecycle, not only `Back`. Tear down Exo/media-session/`AudioService` so Android does not keep a ghost audio focus. Mini Guide preview is a second, muted, control-free surface that must never outlive the overlay.

**Do not** keep `/live` mounted under destination overlays.

### Destinations

Five top-level items, same order as today’s `iptvNavigationDestinations`, restyled:

| Rail | TV job |
| --- | --- |
| Home | Onboarding or silent dashboard |
| Guide | Catalog, categories, search, Filters dialog, EPG |
| Movies | Playlist VOD. Empty state if none |
| Favorites | Favorite channels/content. Same ids as the Home rail |
| Settings | Playlists, Playback, Network, Appearance, About |

Logo mark + “Aika Stream” when the rail is expanded. Collapsed = icons only.

#### Home — no playlist

Landing, not an empty grid.

- Title: Aika Stream. Line: Your media. Your player.
- Primary: large QR panel using existing LAN pairing. Copy: phone and TV on the same Wi-Fi.
- Secondary: Add playlist URL, USB, Browse Network.
- URL is “Or enter URL manually.” The IME must not cover Save/Cancel.

#### Home — after import

Success card: playlist label, channel count, country/categories when known. Primary **Start Watching** dismisses the modal and lands on the **silent Home dashboard**. It does not auto-tune Watch. Country pick, if used, is inside this close-and-land flow.

#### Home — with channels

Dashboard rails only. No persistent Search / country / category / sort chrome.

| Rail | Source | Decoder |
| --- | --- | --- |
| Continue Watching | `recentlyWatchedChannelsProvider` | None. OK → Watch |
| Live TV | First 8–12 channels in current catalog order. See all → Guide | None |
| Your Favorites | Same favorite set as Favorites | None |
| Recently Added | Only if the latest import has a recency signal (import timestamp or stable new ids). Otherwise hide the row. Do not invent popularity | None |

Hide any Home rail with zero items. Do not render an empty Continue Watching row. If every rail is empty (playlist loaded but nothing to show yet), show a single Live TV rail from catalog order.

Default focus: first card of the first visible rail. Content region focused, rail collapsed. After import success, same rule. Watch first focus: Pause/Play. Mini Guide first focus: current channel.

Channel names: one line, ellipsis. 47+ character names must not wrap the card or steal focus size.

No live hero decoder on Home.

Cards: logo, name, LIVE, optional quality/group. Focus visible from several meters (3–5 dp ring, scale 1.05–1.1). Spacing 16–24 dp.

#### Guide

Full catalog. Search control + Filters action. Filters open a TV dialog:

- Country, Category, Quality (All + values present in the loaded playlist)
- Apply commits; Back/Cancel leaves previous filters

EPG remains here. Mini Guide is not a Guide page.

#### Movies / Favorites / Settings

Reuse `VodTvScreen`, `TvFavoritesScreen`, `TvSettingsScreen` as destinations (not overlays on live). Playlist-sources dialog is a TV panel (list + add + delete), not a desktop modal with a covering keyboard.

Browse Network empty state:

- Find media shared on your network
- Windows / Mac / NAS / media server; same network
- Scan again / How it works

Do not keep “No supported media was found here.” as the only copy.

### Watch: transport overlay

Bottom overlay template. Width-capped (~70–80% of title-safe), bottom-centered, single row.

Actions: Pause/Play, Restart, Audio, Subtitles, Favourite, Info, More.

- Equal control height 56–72 dp. No `Wrap` onto a second row. Overflow goes to More (existing actions sheet).
- Focus rectangle fits the control (3–5 dp), not an oversized green box.
- Audio / Subtitles disabled when the stream has no tracks, not omitted.
- Favourite reflects stored state.
- Info = channel info. More = overflow (quality, diagnostics, help, settings, ways to watch) as today, restyled as a TV panel.
- Auto-hide ~5 s idle; any D-pad key shows chrome. Video stays visible behind a scrim, not a full-screen dim.
- No on-screen Back.

### Watch: Mini Guide

D-pad UP opens Mini Guide; DOWN recent-channels stays logos only (no second decoder on that rail).

- Horizontal rail. Window around current channel stays ~12.
- Unfocused: logo + name.
- Focused: after 500 ms settle, attach **one** muted preview player. Spinner until first frame. `LIVE` badge. No chrome on the preview.
- Focus move: stop previous preview, then start the new one.
- OK: stop preview, retune **main** Watch player, close Mini Guide.
- Back: close Mini Guide, release preview, main channel continues.
- If a second decoder cannot start, keep logo + error/spinner; never tear down the main player for a preview.
- Closing Mini Guide always releases the preview surface.

### TV scale

Logical dp on the Android TV 960×540 canvas. Verify 720p, 1080p, and 4K. Do not hardcode 1080p px.

| Token | Target |
| --- | --- |
| Rail collapsed / expanded | 80 / 240 |
| Title / body | 28 / 18 |
| Button height / card gap | 64 / 20 |
| Focus ring | 4 |
| Dialog padding / min target | 40 / 56 |
| Title-safe | keep `tvTitleSafeFraction` 5% on chrome; Watch video may bleed edge-to-edge |

Use `core_ui` tokens (`AiroTypography` / `AiroSpacing` / `AiroTheme`). No flavor-local `ThemeData`.

### Play Store dual form-factor

19 must install from the same internal/test track on Bravia **and** Pixel 9.

| Layer | 19 action |
| --- | --- |
| APK | Keep `leanback`/`touchscreen` `required="false"` and both launcher categories. Do not revert to TV-only `leanback required=true` |
| Play Console (human) | Enable Phone and TV form factors; upload phone **and** TV screenshots; testers; confirm device catalog lists Pixel 9 and the Bravia |
| Listing copy | TV-first Aika Stream is fine; must not imply TV-only devices |
| Pixel 9 UX | Compact/touch: add playlist, play, leave player stops audio, Aika Stream branding |
| Bravia UX | This spec’s 10-foot layer |

Sideload vs Play signing remains: a Pixel sideload will not upgrade in place to Play. Testers on the Play track must uninstall sideloads first.

### Branding

User-facing 19 chrome, launcher, splash, QR page, TV rail, Play listing, and in-app strings on this surface say **Aika Stream**. Audit and replace: Airo TV, AIRO TV, Airo Stream, Developers Coffee TV, Midas Stream, old launcher/splash/QR labels.

Out of scope: rewriting old CHANGELOG entries and historical QA evidence files.

### Feature Packet

**Primary owner agent:** TV Experience Architect
**Review agents:** Flutter Architect, Chief UX Officer, Playback Architect, Media Intelligence Architect, Chief QA Officer, Chief Release / DevEx Officer, Chief Security Officer (LAN QR pairing)
**Layer:** Mixed
**Sprint:** Aika Stream test OBB 19
**Parent roadmap:** Aika Stream Play listing `com.developerscoffee.tv.midas`

#### Critical Agent Gate

**Problem:** 18 on Bravia is a scaled explorer: D-pad trap, stretched player chrome, ghost audio because live never unmounts, Home is a channel grid, QR is buried, Play test track does not offer Pixel 9.
**User / actor:** Android TV tester (Bravia remote) and phone tester (Pixel 9) on the internal Play track.
**Framework or application layer:** Mixed. Journeys in `app/` + `feature_iptv`. Playback stop/release in `platform_player`. Focus in `core_remote_control` / TV shell. Play targeting is release + Console.
**Owning agent:** TV Experience Architect
**Reviewing agents:** as above
**Impacted modules/files:** `app/lib/core/app/tv_shell.dart`, `app/lib/core/app/` TV routes, `packages/feature_iptv` TV presentation (`iptv_screen`, `video_player_widget`, `tv_ux`, playlist QR/source sheets), `packages/platform_player` session lifecycle, `packages/platform_history` recent channels, `app/android/app/src/tv/AndroidManifest.xml` (verify only), `app/pubspec_tv.yaml` (19), Play listing docs
**Base branch/worktree:** `origin/main` (not the dirty local Anya worktree)
**Open questions:** None that block. Recently Added hides when there is no recency signal.
**Decision:** Ready after this spec is accepted

#### Cross-Agent Contract

**Provider:** Playback Architect (`platform_player`)
**Consumer:** TV Experience / Flutter (`TvShell`, Watch, Mini Guide)
**Interface:** Watch creates one main player session. Mini Guide may create one muted preview session. Destinations must not hold a session.
**Input:** channel id + URL from the loaded playlist; preview flag muted / no-controls
**Output:** playing / buffering / error / released
**State changes:** leaving Watch releases main + preview. Closing Mini Guide releases preview only.
**Errors:** preview failure does not stop main. Main failure stays on Watch with existing diagnostic/retry.
**Permissions:** existing INTERNET / network; QR pairing stays LAN-only.
**Privacy:** no new cloud playlist store. Pairing server already LAN-scoped; do not log submitted playlist URLs.
**Persistence:** recent + favorites keys unchanged. No new BYOC catalogue.
**Versioning:** `0.0.1+19`. Play has consumed 18.

#### Deterministic use cases

1. Cold start, no playlist, TV: landing with QR primary; no channel grid.
2. QR submit on same Wi-Fi: import runs, success card, modal closes, Home with Live TV (and other non-empty rails). Continue Watching stays hidden until a channel is watched.
3. Manual URL save: same close-and-land; keyboard does not cover Save.
4. Home Continue Watching OK: Watch plays; Home is silent after Back.
5. Back from Watch: audio and media session stop within the leave transition; Settings/Guide do not play audio.
6. LEFT from first Home card: rail focused and expanded. RIGHT: last card. Back from Home does not focus rail.
7. Watch OK chrome: bounded panel; Audio/Subtitles/Favourite/Info/More each show a distinct focus box that does not overlap neighbors.
8. UP Mini Guide: main keeps playing; focused card previews muted after 500 ms; OK switches main; Back closes preview.
9. D-pad across Mini Guide cards: at most one preview decoder.
10. Guide Filters: dialog apply/cancel; Home still has no filter chrome.
11. Browse Network with nothing shared: new empty state, not only “No supported media was found here.”
12. No “Airo TV” in TV chrome, launcher label, splash, or QR page.
13. Play internal track: install on Bravia and Pixel 9. Pixel 9 compact play, then Back, stops audio.

#### Automation flow

- Widget tests: rail LEFT/RIGHT/Back, Home empty vs dashboard, import success closes, Watch overlay layout (single row, focus size), Mini Guide single-preview attach/detach, Watch dispose stops player (fake player / test seam).
- Provider tests: leaving Watch clears session; preview stop on focus loss.
- Golden or layout tests at 720p and 1080p logical sizes for Home rails, Watch overlay, Mini Guide.
- Branding grep gate for user-facing TV strings (Airo TV / Midas Stream) on this surface.
- Host: `cd packages/feature_iptv && flutter test` plus `app/test/core/app/tv_shell_test.dart` and Watch widget tests.
- Device: Bravia (or Fire TV Stick per WORKFLOW.md) for ten-foot; Pixel 9 for compact + Play install. Name the environment on the issue.
- Play: human checklist that phone and TV form factors and both screenshot sets are saved before declaring 19 installable on Pixel 9.

#### Implementation boundaries

- **Always:** stop/release on Watch leave; one Mini Guide preview; QR-primary empty Home; Guide is catalog; tokens from `core_ui`; BYOC-only; prove with focused tests before CI matrices.
- **Ask first:** new dependencies, Play production track, `leanback required` flip, versionName bump, changing compact phone Home into the TV dashboard.
- **Never:** iptv-org presets in the listing build; keep live mounted under Settings; play every Mini Guide card; commit secrets; `[skip ci]` on executable TV changes.

### Child workstreams (still version 19)

One parent issue. Land as separate PRs on `main`. Cut the 19 OBB after the parent is green.

1. **Playback ownership** — invert `TvShell`; Watch route; stop/release; kill ghost audio.
2. **Rail + D-pad** — collapse/expand; LEFT/RIGHT/Back rules; title-safe.
3. **Watch chrome** — bounded overlay; per-action states.
4. **Home + onboarding** — QR landing, import success, dashboard rails, filters off Home.
5. **Mini Guide preview** — single muted decoder; DOWN recent stays logos.
6. **TV dialogs / Browse Network / branding**
7. **Play dual-form-factor + `0.0.1+19` cut** — Console human steps + version bump last.

### Tech stack and commands

Flutter TV flavor, Riverpod, existing `platform_player` / `feature_iptv` / `core_ui`. No new playback engine.

```bash
git fetch origin main
### branch from origin/main after the parent issue exists

cd packages/feature_iptv && flutter analyze && flutter test
cd app && flutter test test/core/app/tv_shell_test.dart

eval "$(scripts/aika_stream_version.sh)"
### 19 cut only after the packet is green:
### pubspec_tv.yaml version: 0.0.1+19
```

Device: Bravia (D-pad) and Pixel 9 (Play install + compact). Emulator only with explicit `AIRO_ALLOW_ANDROID_EMULATOR=true` on the issue.

### Success criteria

- 18 remains the found-in test OBB; 19 is the first OBB that contains this packet.
- Bravia: no ghost audio after leaving Watch; D-pad reaches rail from content; Home is dashboard or QR landing; Watch overlay is a bounded panel; Mini Guide previews only the focused card; UI says Aika Stream.
- Pixel 9: Play test track offers install; compact play then leave stops audio.
- Play Console: phone + TV form factors.
- Focused analyzer/tests for touched packages are green. Physical evidence named on the issue.

### Rollback

Leave 18 on the test track. Do not reuse 18. If 19 is bad, keep testers on 18 and cut 20 from `main` after revert or fix. Play never sees a reused versionCode.

## Review record

Autoplan intake: 2026-09-16. Base branch: `main`. SOURCE/ACTIVE plan: this file. Spec: `docs/superpowers/specs/2026-09-16-aika-stream-tv-19-design.md`. UI scope: yes. DX scope: yes (`dxRequired: true`). Codex outside voice: unavailable (CLI preflight blocked by host auto-review). Native CEO: in-host primary.

<!-- autoplan-accepted:ceo -->
- Invert `TvShell` overlay-on-live: Watch is a route; destinations must not hold a player. Verify: Back from Watch stops media session; Settings/Guide silent.
- One Mini Guide preview decoder, 500 ms settle, muted. Verify: widget test at most one preview; main never torn down on preview fail.
- Home is QR landing or silent rails; Guide is catalog. Verify: no-playlist test shows QR, not grid; Start Watching lands Home, does not auto-tune.
- Play 19 installs on Bravia and Pixel 9. Verify: Console phone+TV form factors; compact leave-player stops audio.
- Found in `0.0.1+18`, ship `0.0.1+19` from `origin/main`. Do not reuse 18. Do not implement from the Anya worktree.
<!-- /autoplan-accepted:ceo -->

### 0A Premise challenge

| Premise | Verdict |
| --- | --- |
| Ghost audio is `TvShell` keeping `/live` mounted under overlays | Valid. `tv_shell.dart` documents "Playback never stops." |
| Pixel 9 missing from the 18 test track is Console, not APK | Valid. Manifest already has both launchers and `leanback` not required. |
| Ten-foot Home must not be the channel grid | Valid. That grid is why D-pad traps and why first launch looks empty-broken. |
| One 19 OBB can carry P0–P2 | Accepted because the user locked C. Risk: testers wait on Mini Guide preview while ghost audio could ship earlier. Queued as taste, not a direction change. |
| Compact Pixel 9 stays explorer, not TV dashboard | Valid. Play phone screenshots need a usable phone UI. |

Doing nothing: testers keep 18, Bravia still has ghost audio, Pixel 9 still cannot install, Play review stays TV-shaped. Real pain, not hypothetical.

Wrong framing to avoid: "restyle the overlay." That leaves the live child mounted.

### 0B Existing code leverage

| Sub-problem | Reuse |
| --- | --- |
| QR onboarding | `TvPlaylistQrDialog`, `TvPlaylistPairingServer` |
| Continue Watching | `recentlyWatchedChannelsProvider` / `RecentlyWatchedStorage` |
| Mini Guide chrome | `_QuickBrowseOverlay` in `video_player_widget.dart` (add preview surface, do not invent UP) |
| Favorites / VOD / Settings screens | `TvFavoritesScreen`, `VodTvScreen`, `TvSettingsScreen` as destinations, not overlays |
| Rail destinations | `iptvNavigationDestinations` |
| Title-safe | `tvTitleSafeFraction` |
| Player session | `platform_player` + existing `VideoPlayerWidget` test seams |
| Dual form-factor APK | current TV manifest |

Rebuild only the shell ownership model. Do not rebuild pairing, recents, or the player engine.

### 0C Dream state

```
CURRENT (18)                    THIS PLAN (19)                 12-MONTH
Overlay-on-live explorer   →    Watch-owned TV OS            →  Same IA + EPG-smart
Ghost audio, grid Home          Silent Home, QR first            Home, VOD resume,
Play TV-only testers            Play TV+phone test track         production listing
Airo TV leftovers               Aika Stream chrome               Brand-clean stores
```

19 moves toward the 12-month TV OS. It does not include VOD resume or a true live hero. That is correct for this OBB.

### 0C-bis Approaches (auto-decided)

APPROACH A: Patch overlays. Effort S. Risk High. Rejected. Cannot stop audio.

APPROACH B: Dedicated TV layer, sequenced PRs, one 19 OBB. Effort L. Risk Med. Completeness 10/10. Chosen (P1+P5). Reuses pairing, recents, player.

APPROACH C: Long-lived 19 branch. Effort L. Risk High. Completeness 10/10 product, 4/10 SDLC. Rejected.

Taste (keep, surface at gate): shipping Mini Guide live preview in the same OBB as ghost-audio. Safer slice is workstreams 1–4+7 first; 5 can slip to 20 if Bravia decoder fails. User locked C, so 5 stays in 19 unless they cut it at the gate.

### 0F Mode

SELECTIVE EXPANSION (autoplan default for an existing-system enhancement). Plan scope is the spec. Expansions are candidates only; none added this pass because the user already took the full list.

### 0D Complexity

Touches well over 8 files (`tv_shell`, routes, `video_player_widget`, Home, QR, dialogs, player lifecycle, Play docs, version bump). Smell: yes. Minimum that still matches the Bravia notes: workstream 1 (stop audio) + 2 (D-pad) + 3 (overlay) + 7 (Play+19). Home dashboard, Mini Guide preview, and branding are the user's C-list, not the minimum. Keep them because C is locked. Sequence 1 before 4 so Home cannot remount live.

Delight not added: numeric channel entry, VOD resume, live Home hero, MultiView.

### Error and rescue

| Failure | User sees | Rescue |
| --- | --- | --- |
| Preview decoder fails | Logo + spinner/error on card | Main keeps playing |
| Playlist import fails | Stay on add flow with error | Modal does not close |
| QR LAN mismatch | Pairing error / expiry | Regenerate QR |
| Leave Watch, audio continues | Ghost audio (18 bug) | Treat as P0 fail of workstream 1 |
| Play still TV-only | Pixel 9 missing | Console form-factor checklist, not another AAB with `leanback required=true` |
| 19 bad | Testers broken | Stay on 18, cut 20, never reuse 18 |

### Failure modes

| Mode | Severity | Plan coverage |
| --- | --- | --- |
| Two Mini Guide decoders | High (Bravia thermal) | Specified one preview |
| Overlay still wraps | High (original bug) | No Wrap; overflow to More |
| Compact Pixel gets TV chrome | Med (Play phone UX) | Spec forbids dashboard on phone |
| Anya worktree used as base | High (wrong product) | Spec says `origin/main` |
| Branding grep hits CHANGELOG | Low | Historical files out of scope |

### NOT in scope

VOD resume Continue Watching; Pixel 9 TV dashboard; MultiView features; versionName bump; iptv-org presets; rewriting old CHANGELOG; live Home hero; persistent audio across destinations.

### What already exists

Covered in 0B. Plus Play listing docs and `aika-stream-release.yml`.

### Dream state delta

19 delivers the TV OS skeleton (rail, Watch ownership, Home vs Guide). 12-month still needs VOD resume, richer EPG in Mini Guide, and a production (not test) dual-form-factor listing.

### CEO dual voices

```
CEO DUAL VOICES — CONSENSUS TABLE:
  Dimension                            in-host  Codex   Consensus
  Premises valid?                      Yes      N/A     N/A
  Right problem?                       Yes      N/A     N/A
  Scope calibration?                   Risky C  N/A     N/A
  Alternatives explored?               Yes      N/A     N/A
  Competitive/market risks?            Partial  N/A     N/A
  6-month trajectory?                  Yes      N/A     N/A
```

Outside disabled/unavailable: six Consensus cells N/A, never CONFIRMED. Native findings stay.

### CEO completion summary

Right problem: invert live ownership, then restyle. Approach B. Mode: SELECTIVE EXPANSION with no extra cherry-picks. Blocker: do not implement on `agent/anya/1991-gguf-plan-repair`. File the parent issue from `origin/main` after spec approval. Codex pass not run.

<!-- autoplan-accepted:design -->
- Hide empty Home rails. Default focus: first card of first visible rail; Watch Pause/Play; Mini Guide current channel.
- Channel names one-line ellipsis. Watch overlay single row, overflow to More.
- Interaction states in the table below. D-pad is the a11y path; TalkBack is secondary.
<!-- /autoplan-accepted:design -->

### Design Step 0

Completeness before auto-fix: 7/10 (IA locked, missing empty-rail and state table). After hide-empty-rails + default focus: 8/10. A 10 would add goldens of Home/Watch/Mini Guide at 720p and 1080p plus TalkBack labels on every rail item.

No DESIGN.md. Tokens from `core_ui`: `AiroTypography`, `AiroSpacing` (unit 4, md 16, lg 24), `AiroTheme`, `AiroDisplayScale`. Reuse `TvFocusable`, `TvPlaylistQrDialog`, `_QuickBrowseOverlay`.

Classifier: OPERATE (TV app). Onboarding landing is still Operate, not a marketing site.

Mockups skipped: user chose traditional text planning; no DESIGN_READY this pass.

Focus areas: all 7 passes (autoplan P1).

### Design dual voices

```
DESIGN OUTSIDE VOICES — LITMUS SCORECARD:
  Check                                    in-host  Codex  Consensus
  Brand unmistakable first screen?         YES      N/A    N/A
  One strong visual anchor?                YES      N/A    N/A
  Scannable by headlines only?             YES      N/A    N/A
  Each section one job?                    YES      N/A    N/A
  Cards actually necessary?                YES      N/A    N/A
  Motion improves hierarchy?               NO       N/A    N/A
  Premium without decorative shadows?      YES      N/A    N/A
  Hard rejections                         none     N/A    N/A
```

Motion: auto-hide chrome and 500 ms preview settle only. No authored entrance. Taste, not a fail.

### Pass 1 Information Architecture — 9/10

Examined: five destinations, Home vs Guide split, Watch as overlay host, collapsed/expanded rail. Trunk test: Aika Stream mark + rail labels answer where you are.

Gap vs 10: compact Pixel 9 IA stays the old explorer. Specified on purpose. Not a TV IA hole.

ASCII (10-foot):

```
[rail]  Home: QR | or rails (CW? Live TV Favorites Recents)
        Guide: search + filters dialog + catalog/EPG
        Movies / Favorites / Settings: destination screens
        Watch: video + bounded transport + Mini Guide bottom rail
```

No issues that reopen locked IA.

### Pass 2 Interaction states — 8/10 after table

| Feature | Loading | Empty | Error | Success | Partial |
| --- | --- | --- | --- | --- | --- |
| Home no playlist | n/a | QR landing + secondary add | QR start fail: retry | n/a | n/a |
| Playlist import | progress on modal | n/a | stay open, retry | success card → Home | country metadata missing: omit those lines |
| Home rails | skeleton/placeholder on first load | hide rail | keep other rails | cards | Live TV only if others empty |
| Watch | buffering copy + logo | n/a | existing diagnostic/retry | playing | audio/sub disabled if no tracks |
| Mini Guide preview | spinner on focused card | n/a | logo + error; main continues | muted LIVE | settle 500 ms |
| Browse Network | scanning | How it works + Scan again | same empty + retry | media list | n/a |
| Guide filters | n/a | All with zero hits: no-match copy | n/a | apply | missing quality metadata: hide Quality |

### Pass 3 Journey — 8/10

```
STEP | USER DOES              | USER FEELS           | PLAN SPECIFIES
1    | TV app, no playlist    | stuck without URL    | QR primary
2    | Scan / add URL         | remote typing fear   | IME cannot cover Save
3    | Import finishes        | dump into grid (18)  | success then silent Home
4    | Open a channel         | wants video          | Watch route
5    | Back                   | ghost audio (18)     | stop + release
6    | UP while watching      | zap without leaving  | Mini Guide one preview
7    | LEFT from first card   | trapped in grid (18) | rail focus
```

5-sec: Aika Stream + QR or big focused card. 5-min: play and leave without audio leak. 5-year: BYOC TV OS, not a scaled phone grid.

### Pass 4 AI slop — 8/10

Mode OPERATE. Hard rejections: none. Home rails are the interaction (channel pick), not decorative SaaS cards. Copy is product language. Risk: green focus ring + LIVE badges becoming a neon glow look. Mitigation: 4 dp outline, `AiroTheme` accent, no glow blobs.

Litmus 6 Motion = NO. Cap below 10, not a hard fail.

### Pass 5 Design system — 8/10

Plan names `AiroTypography` / `AiroSpacing` / `AiroTheme` / `AiroDisplayScale`. Numeric TV targets (80/240 rail, 28/18 type) must map onto those tokens in implementation, not raw `fontSize: 28` in feature_iptv. Finding accepted: implementers use tokens; golden tests catch drift.

### Pass 6 Responsive & a11y — 8/10

TV: 720p / 1080p / 4K logical, 5% title-safe, 56 dp min target, D-pad spatial + explicit LEFT-to-rail. Pixel 9: existing compact; leave Watch stops audio. TalkBack: semanticLabel on rail, cards, transport (already `TvFocusable` pattern). Contrast: dark theme, no gray-on-scrim body under 16 logical px (plan 18 body).

No phone dashboard. No hover-only affordances.

### Pass 7 Unresolved (taste / gate)

| Decision | If deferred |
| --- | --- |
| Mini Guide preview in 19 vs 20 | Bravia decoder may fail; ghost audio can still ship |
| Map 28/18 type to which `AiroTypography` role | raw fontSize lint |
| Compact Pixel Home looks like 18 explorer | Play phone screenshots look old next to TV 19 |

No new product IA changes. User already locked C.

### Design completion summary

IA holds. Auto-fixed empty rails and default focus. Scores 8–9. Codex N/A.

**Phase 2 complete.** Codex unavailable. in-host issues: 3 (empty rails, default focus, token mapping). Consensus N/A.

<!-- autoplan-accepted:dx -->
- Branch from `origin/main`. Parent issue before code. `scripts/aika_stream_version.sh` only at workstream 7.
- Errors: import/QR/preview/player must say what failed and the next action.
- Play Console checklist is a first-class task, not a footnote.
<!-- /autoplan-accepted:dx -->

### DX persona (auto-decided)

```
TARGET DEVELOPER PERSONA
Who:       Airo TV implementer + release owner (same human in this repo)
Context:   Cut 19 after Bravia 18 failed UAT
Tolerance: one focused flutter test loop; will not run full GHA matrices
Expects:   worktree from main, issue number, pubspec_tv version owner, Play checklist
```

Mode: DX POLISH. This is not an external SDK. DX is the implementer path.

Empathy: I fetch main, not the Anya branch. I look for the issue. I need the first test command for ghost audio. If the plan says "invert TvShell" without the test seam, I will patch Back and ship 18 again.

TTHW target: under 15 min from cloned main+issue to a failing Watch-dispose test.

### DX passes (scores)

1. Getting started 6→8: first command is `git fetch origin main` + issue. Missing: exact `gh issue create` body lives in spec Feature Packet (enough).
2. API/CLI 7: `aika_stream_version.sh` exists; bump last.
3. Errors 7: preview vs main failure split is specified.
4. Docs 8: spec path named.
5. Upgrade 9: 18 stays, never reuse versionCode.
6. Dev env 5: current checkout is the wrong branch. Plan now screams origin/main.
7. Community 3: N/A internal test track. Not a finding for 19.
8. Measurement 6: physical evidence named on issue; no telemetry for ghost audio. Accept: widget test is the gate.

DX overall 7/10. TTHW 30 min today → 15 min with workstream-1 test named in Eng.

### DX dual voices

```
  Dimension                     in-host  Codex  Consensus
  Getting started < 5 min?      No       N/A    N/A
  Naming guessable?             Yes      N/A    N/A
  Errors actionable?            Yes      N/A    N/A
  Docs findable?                Yes      N/A    N/A
  Upgrade path safe?            Yes      N/A    N/A
  Dev env friction-free?        No       N/A    N/A
```

**Phase 2.5 complete.** DX 7/10. TTHW 15 min target. Codex unavailable.

<!-- autoplan-accepted:eng -->
- Workstream 1 test: fake player; Watch pop → `stop`+`release` called; Settings mounted with no session.
- Mini Guide: one preview controller; focus change disposes previous.
- No `/live` child under destination overlays.
- Tests: `flutter test` in `feature_iptv` and `app/test/core/app/tv_shell_test.dart`. Framework: Flutter test.
<!-- /autoplan-accepted:eng -->

### Eng architecture

```
platform_player session
        ^
        | create/stop/release
Watch route (only owner) ---- Mini Guide preview (muted, 1x)
        ^
TvShell destinations (no session)
  Home / Guide / Movies / Favorites / Settings
        ^
_TvNavigationRail (focus regions)
```

Coupling: Watch may keep using `VideoPlayerWidget`; shell must stop passing a live child. Security: QR stays LAN. Scaling: one extra decoder max.

### Eng code quality

DRY: reuse pairing, recents, `iptvNavigationDestinations`. Do not duplicate transport buttons as a second Wrap. Naming: Watch not `/live`. Complexity: `video_player_widget.dart` is already too large; Mini Guide preview should be a sibling widget, not another 400 lines inlined (P5).

### Eng tests (Flutter)

```
no playlist → Home QR                         widget
import success → modal gone, Home             widget
empty CW rail hidden                          widget
LEFT first card → rail                        widget tv_shell
Back Watch → stop/release                     widget + fake player
Settings no audio session                     provider
Mini Guide one preview / dispose on move      widget
overlay single row no wrap                    layout/golden 1080
Audio disabled without tracks                 widget
branding Airo TV absent in TV chrome          grep/test
compact Back stops audio                      widget (touch path)
```

### Eng performance

Two decoders only on Watch+Mini Guide. 500 ms debounce. Tear down AudioService. No Home hero decoder.

### Eng security

No new secrets. Do not log playlist URLs from QR. BYOC only.

### Eng dual voices

```
  Dimension                     in-host  Codex  Consensus
  Architecture sound?           Yes      N/A    N/A
  Test coverage sufficient?     After    N/A    N/A
  Performance risks addressed?  Yes      N/A    N/A
  Security threats covered?     Yes      N/A    N/A
  Error paths handled?          Yes      N/A    N/A
  Deployment risk manageable?   Yes      N/A    N/A
```

### Eng NOT in scope / exists

Same as CEO. Tests already exist for Mini Guide open, recents, tv_shell LEFT (extend, do not delete).

**Phase 3 complete.** Codex unavailable. in-host: Mini Guide extract widget, Watch dispose test. Consensus N/A.

### Cross-phase themes

1. Ownership of live playback is the product.
2. Wrong git base will ship the wrong app.
3. Dual-voice Codex never ran; treat scores as single-reviewer.
4. Full C-in-19 is the user's call and the main schedule risk.

### Implementation tasks (aggregates)

1. Parent GitHub issue on main (Feature Packet from spec).
2. Worktree from origin/main.
3. PR: TvShell destinations without live child; Watch dispose tests.
4. PR: rail collapse/expand + LEFT/RIGHT/Back.
5. PR: bounded Watch overlay; per-action states; goldens.
6. PR: Home QR + rails hide-empty; import success close.
7. PR: Mini Guide preview widget + one-decoder tests.
8. PR: dialogs, Browse Network empty, branding grep.
9. Play Console phone+TV; bump `0.0.1+19`; cut OBB.

<!-- AUTONOMOUS DECISION LOG -->
### Decision Audit Trail

| # | Phase | Decision | Classification | Principle | Rationale | Rejected |
|---|-------|----------|----------------|-----------|-----------|----------|
| 1 | CEO | Mode SELECTIVE EXPANSION | Mechanical | autoplan override | Existing-system enhancement default | EXPANSION / HOLD / REDUCTION |
| 2 | CEO | Approach B sequenced PRs + one 19 OBB | Mechanical | P1 P5 | Matches locked spec; overlay patch cannot stop audio | A patch, C long branch |
| 3 | CEO | Keep full C list in 19 | Taste | user lock | User chose C; Mini Guide in same OBB is the risk | Split preview to 20 |
| 4 | CEO | Skip Codex this pass | Mechanical | host block | Preflight `all` probe blocked; retain native | Dual-voice CONFIRMED |
| 5 | Design | Hide empty Home rails + default focus | Mechanical | P1 P5 | Empty Continue Watching is 18-quality TV | Show empty row |
| 6 | Design | Skip mockups | Mechanical | user lock | Traditional text planning | gstack designer |
| 7 | Design | Token-map type sizes in impl | Mechanical | P5 | Avoid raw fontSize vs core_ui | Hardcode 28/18 |
| 8 | DX | Persona = TV implementer/release owner | Mechanical | P6 | Internal OBB, not an SDK | External integrator |
| 9 | Eng | Extract Mini Guide preview widget | Mechanical | P5 | video_player_widget.dart is already oversized | Inline more overlay code |



# Spec: Aika Stream TV 0.0.1+19

**Status:** Approved — 2026-09-16 (user + autoplan gate A)
**Date:** 2026-09-16
**Found in:** `0.0.1+18` (Play internal/test OBB, Bravia)
**Ships in:** `0.0.1+19` (next test OBB; do not bump past 19 until this packet is clean)
**Package:** `com.developerscoffee.tv.midas`
**GitHub:** [#2014](https://github.com/DevelopersCoffee/airo/issues/2014)

## Objective

Make Aika Stream a dedicated Android TV product: D-pad focus, viewing-distance scale, persistent navigation, and a Watch surface that owns live playback. Stop treating the ten-foot UI as the mobile/web explorer scaled up.

Testers on the same 19 OBB must be able to install from Play on a **Sony Bravia** and a **Pixel 9**. 18 stays the found-in build. Do not reuse versionCode 18.

## Locked decisions

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

## Non-goals

- A second Aika Stream package or a phone-only listing.
- Rewriting the Pixel 9 compact explorer into the TV dashboard.
- True VOD resume in Continue Watching (watch-progress row is later).
- Playing more than one Mini Guide preview at a time.
- Bundled playlists, iptv-org presets, or any Play policy regression of BYOC.
- Rewriting historical CHANGELOG / evidence that still says “Airo TV”.
- MultiView feature work (leaving Watch still tears down MultiView sessions because Watch owns playback).
- Bumping `versionName` off `0.0.1` in this packet.

## Why 18 behaves this way

`TvShell` (`app/lib/core/app/tv_shell.dart`) mounts `/live` under overlays and documents “VIDEO LAYER always present, never destroyed” / “Playback never stops.” Home is that live route. Guide/Movies/Favorites/Settings paint on top and keep the decoder. That is the Bravia ghost-audio bug, the grid-as-Home, and the focus trap: content and rail are stacked on a player that never releases.

The TV transport bar in `video_player_widget.dart` is a full-bleed `Wrap` (Pause, Restart, Audio, Subtitles, Favourite, Info). On real panels it wraps, overlaps video, and inflates the focus ring.

Mini Guide already opens on D-pad UP. Cards are 96×130 logos. There is no preview decoder.

QR LAN pairing (`TvPlaylistQrDialog` + `TvPlaylistPairingServer`) already exists and is not the primary empty state.

Manifest already has `leanback`/`touchscreen` `required="false"` and both `LAUNCHER` and `LEANBACK_LAUNCHER`. Pixel 9 missing from the 18 test track is a Play Console form-factor / screenshot / tester gap, not a missing activity.

## Approaches considered

1. **Patch `TvShell` overlays** — fastest for chrome-only bugs; cannot stop audio or make Home a dashboard without fighting the retained live child. Rejected.
2. **Dedicated TV interaction layer, sequenced PRs, one 19 OBB** — chosen. Watch is a real route. Destinations do not keep a hidden player.
3. **One long-lived 19 branch** — same product, weak SDLC, painful rebase. Rejected.

## Architecture

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

**Library browse amendment (2026-09-24):** `ChannelLibraryGrid` may hold one muted peek session — the same class as Mini Guide (control-free, `mixWithOthers: true`), behind `browseGridTvPeekEnabled` (default off). It is not a destination-owned Watch session. Leave Library, open Watch, Cast, or Mini Guide → stop and dispose the library peek. Library peek and Mini Guide preview must never coexist.

**Do not** keep `/live` mounted under destination overlays.

## Destinations

Five top-level items, same order as today’s `iptvNavigationDestinations`, restyled:

| Rail | TV job |
| --- | --- |
| Home | Onboarding or silent dashboard |
| Guide | Catalog, categories, search, Filters dialog, EPG |
| Movies | Playlist VOD. Empty state if none |
| Favorites | Favorite channels/content. Same ids as the Home rail |
| Settings | Playlists, Playback, Network, Appearance, About |

Logo mark + “Aika Stream” when the rail is expanded. Collapsed = icons only.

### Home — no playlist

Landing, not an empty grid.

- Title: Aika Stream. Line: Your media. Your player.
- Primary: large QR panel using existing LAN pairing. Copy: phone and TV on the same Wi-Fi.
- Secondary: Add playlist URL, USB, Browse Network.
- URL is “Or enter URL manually.” The IME must not cover Save/Cancel.

### Home — after import

Success card: playlist label, channel count, country/categories when known. Primary **Start Watching** dismisses the modal and lands on the **silent Home dashboard**. It does not auto-tune Watch. Country pick, if used, is inside this close-and-land flow.

### Home — with channels

Dashboard rails only. No persistent Search / country / category / sort chrome.

| Rail | Source | Decoder |
| --- | --- | --- |
| Continue Watching | `recentlyWatchedChannelsProvider` | None. OK → Watch |
| Live TV | First 8–12 channels in current catalog order. See all → Guide | None |
| Your Favorites | Same favorite set as Favorites | None |
| Recently Added | Only if the latest import has a recency signal (import timestamp or stable new ids). Otherwise hide the row. Do not invent popularity | None |

Hide any Home rail with zero items. Do not render an empty Continue Watching row. If every rail is empty (playlist loaded but nothing to show yet), show a single Live TV rail from catalog order.

Default focus: first card of the first visible rail. Content region focused, rail collapsed. After import success, same rule.

Channel names: one line, ellipsis. 47+ character names must not wrap the card or steal focus size.

No live hero decoder on Home.

Cards: logo, name, LIVE, optional quality/group. Focus visible from several meters (3–5 dp ring, scale 1.05–1.1). Spacing 16–24 dp.

### Guide

Full catalog. Search control + Filters action. Filters open a TV dialog:

- Country, Category, Quality (All + values present in the loaded playlist)
- Apply commits; Back/Cancel leaves previous filters

EPG remains here. Mini Guide is not a Guide page.

### Movies / Favorites / Settings

Reuse `VodTvScreen`, `TvFavoritesScreen`, `TvSettingsScreen` as destinations (not overlays on live). Playlist-sources dialog is a TV panel (list + add + delete), not a desktop modal with a covering keyboard.

Browse Network empty state:

- Find media shared on your network
- Windows / Mac / NAS / media server; same network
- Scan again / How it works

Do not keep “No supported media was found here.” as the only copy.

## Watch: transport overlay

Bottom overlay template. Width-capped (~70–80% of title-safe), bottom-centered, single row.

Actions: Pause/Play, Restart, Audio, Subtitles, Favourite, Info, More.

- Equal control height 56–72 dp. No `Wrap` onto a second row. Overflow goes to More (existing actions sheet).
- Focus rectangle fits the control (3–5 dp), not an oversized green box.
- Audio / Subtitles disabled when the stream has no tracks, not omitted.
- Favourite reflects stored state.
- Info = channel info. More = overflow (quality, diagnostics, help, settings, ways to watch) as today, restyled as a TV panel.
- Auto-hide ~5 s idle; any D-pad key shows chrome. Video stays visible behind a scrim, not a full-screen dim.
- No on-screen Back.

## Watch: Mini Guide

D-pad UP opens Mini Guide; DOWN recent-channels stays logos only (no second decoder on that rail).

- Horizontal rail. Window around current channel stays ~12.
- Unfocused: logo + name.
- Focused: after 500 ms settle, attach **one** muted preview player. Spinner until first frame. `LIVE` badge. No chrome on the preview.
- Focus move: stop previous preview, then start the new one.
- OK: stop preview, retune **main** Watch player, close Mini Guide.
- Back: close Mini Guide, release preview, main channel continues.
- If a second decoder cannot start, keep logo + error/spinner; never tear down the main player for a preview.
- Closing Mini Guide always releases the preview surface.

## TV scale

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

## Play Store dual form-factor

19 must install from the same internal/test track on Bravia **and** Pixel 9.

| Layer | 19 action |
| --- | --- |
| APK | Keep `leanback`/`touchscreen` `required="false"` and both launcher categories. Do not revert to TV-only `leanback required=true` |
| Play Console (human) | Enable Phone and TV form factors; upload phone **and** TV screenshots; testers; confirm device catalog lists Pixel 9 and the Bravia |
| Listing copy | TV-first Aika Stream is fine; must not imply TV-only devices |
| Pixel 9 UX | Compact/touch: add playlist, play, leave player stops audio, Aika Stream branding |
| Bravia UX | This spec’s 10-foot layer |

Sideload vs Play signing remains: a Pixel sideload will not upgrade in place to Play. Testers on the Play track must uninstall sideloads first.

## Branding

User-facing 19 chrome, launcher, splash, QR page, TV rail, Play listing, and in-app strings on this surface say **Aika Stream**. Audit and replace: Airo TV, AIRO TV, Airo Stream, Developers Coffee TV, Midas Stream, old launcher/splash/QR labels.

Out of scope: rewriting old CHANGELOG entries and historical QA evidence files.

## Feature Packet

**Primary owner agent:** TV Experience Architect
**Review agents:** Flutter Architect, Chief UX Officer, Playback Architect, Media Intelligence Architect, Chief QA Officer, Chief Release / DevEx Officer, Chief Security Officer (LAN QR pairing)
**Layer:** Mixed
**Sprint:** Aika Stream test OBB 19
**Parent roadmap:** Aika Stream Play listing `com.developerscoffee.tv.midas`

### Critical Agent Gate

**Problem:** 18 on Bravia is a scaled explorer: D-pad trap, stretched player chrome, ghost audio because live never unmounts, Home is a channel grid, QR is buried, Play test track does not offer Pixel 9.
**User / actor:** Android TV tester (Bravia remote) and phone tester (Pixel 9) on the internal Play track.
**Framework or application layer:** Mixed. Journeys in `app/` + `feature_iptv`. Playback stop/release in `platform_player`. Focus in `core_remote_control` / TV shell. Play targeting is release + Console.
**Owning agent:** TV Experience Architect
**Reviewing agents:** as above
**Impacted modules/files:** `app/lib/core/app/tv_shell.dart`, `app/lib/core/app/` TV routes, `packages/feature_iptv` TV presentation (`iptv_screen`, `video_player_widget`, `tv_ux`, playlist QR/source sheets), `packages/platform_player` session lifecycle, `packages/platform_history` recent channels, `app/android/app/src/tv/AndroidManifest.xml` (verify only), `app/pubspec_tv.yaml` (19), Play listing docs
**Base branch/worktree:** `origin/main` (not the dirty local Anya worktree)
**Open questions:** None that block. Recently Added hides when there is no recency signal.
**Decision:** Ready after this spec is accepted

### Cross-Agent Contract

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

### Deterministic use cases

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

### Automation flow

- Widget tests: rail LEFT/RIGHT/Back, Home empty vs dashboard, import success closes, Watch overlay layout (single row, focus size), Mini Guide single-preview attach/detach, Watch dispose stops player (fake player / test seam).
- Provider tests: leaving Watch clears session; preview stop on focus loss.
- Golden or layout tests at 720p and 1080p logical sizes for Home rails, Watch overlay, Mini Guide.
- Branding grep gate for user-facing TV strings (Airo TV / Midas Stream) on this surface.
- Host: `cd packages/feature_iptv && flutter test` plus `app/test/core/app/tv_shell_test.dart` and Watch widget tests.
- Device: Bravia (or Fire TV Stick per WORKFLOW.md) for ten-foot; Pixel 9 for compact + Play install. Name the environment on the issue.
- Play: human checklist that phone and TV form factors and both screenshot sets are saved before declaring 19 installable on Pixel 9.

### Implementation boundaries

- **Always:** stop/release on Watch leave; one Mini Guide preview; QR-primary empty Home; Guide is catalog; tokens from `core_ui`; BYOC-only; prove with focused tests before CI matrices.
- **Ask first:** new dependencies, Play production track, `leanback required` flip, versionName bump, changing compact phone Home into the TV dashboard.
- **Never:** iptv-org presets in the listing build; keep live mounted under Settings; play every Mini Guide card; commit secrets; `[skip ci]` on executable TV changes.

## Child workstreams (still version 19)

One parent issue. Land as separate PRs on `main`. Cut the 19 OBB after the parent is green.

1. **Playback ownership** — invert `TvShell`; Watch route; stop/release; kill ghost audio.
2. **Rail + D-pad** — collapse/expand; LEFT/RIGHT/Back rules; title-safe.
3. **Watch chrome** — bounded overlay; per-action states.
4. **Home + onboarding** — QR landing, import success, dashboard rails, filters off Home.
5. **Mini Guide preview** — single muted decoder; DOWN recent stays logos.
6. **TV dialogs / Browse Network / branding**
7. **Play dual-form-factor + `0.0.1+19` cut** — Console human steps + version bump last.

## Tech stack and commands

Flutter TV flavor, Riverpod, existing `platform_player` / `feature_iptv` / `core_ui`. No new playback engine.

```bash
git fetch origin main
# branch from origin/main after the parent issue exists

cd packages/feature_iptv && flutter analyze && flutter test
cd app && flutter test test/core/app/tv_shell_test.dart

eval "$(scripts/aika_stream_version.sh)"
# 19 cut only after the packet is green:
# pubspec_tv.yaml version: 0.0.1+19
```

Device: Bravia (D-pad) and Pixel 9 (Play install + compact). Emulator only with explicit `AIRO_ALLOW_ANDROID_EMULATOR=true` on the issue.

## Success criteria

- 18 remains the found-in test OBB; 19 is the first OBB that contains this packet.
- Bravia: no ghost audio after leaving Watch; D-pad reaches rail from content; Home is dashboard or QR landing; Watch overlay is a bounded panel; Mini Guide previews only the focused card; UI says Aika Stream.
- Pixel 9: Play test track offers install; compact play then leave stops audio.
- Play Console: phone + TV form factors.
- Focused analyzer/tests for touched packages are green. Physical evidence named on the issue.

## Rollback

Leave 18 on the test track. Do not reuse 18. If 19 is bad, keep testers on 18 and cut 20 from `main` after revert or fix. Play never sees a reused versionCode.

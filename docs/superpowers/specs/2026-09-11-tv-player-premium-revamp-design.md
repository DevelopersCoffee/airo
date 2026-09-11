# Airo TV Player — Premium UX Revamp

**Status:** Draft — pending user review
**Scope:** `packages/feature_iptv/lib/presentation/{tv_ux,screens,widgets}`, `packages/feature_iptv/lib/application/providers/multiview_provider.dart`, `packages/platform_favorites`, `packages/platform_player` (MultiView pool)
**Out of scope:** item 4 from the originating request (a "zoom to 720p spawns a blank 2nd multiview screen while playing music" report) — could not be reproduced from the current code (Quality selector, Aspect-ratio/zoom, and MultiView are three independent code paths with no cross-wiring; see Investigation Notes). Needs a restated repro before it can be scoped. Not included in any phase below.

## Context

Ten requested changes to the IPTV "Explorer" player (`AiroTvShell` + `iptv_screen.dart`), spanning the phone/tablet touch layout, the ten-foot D-pad layout, and the MultiView subsystem shared by both. The asks decompose into four independently shippable phases with no cross-phase dependencies except that Phase B's grid changes should land after Phase A's MultiView tile changes (both touch `channel_library_grid.dart`'s per-tile overlay).

## Investigation notes (current behavior)

- **MultiView capacity** is hardcoded per platform, not device-tier detected: `2` on Android/iOS/web, `4` on desktop, `1` on Fuchsia (`multiview_provider.dart:161-168`, `kAiroMultiviewHardCap = 4`). Matches the user's "2 screens" experience.
- **No replace-slot flow exists.** `MultiviewNotifier` only has `toggle`, `promote`, `swap`, `setLayout`. Hitting capacity just returns `MultiviewToggleResult.capacityReached` → a snackbar (`airo_tv_shell.dart:494-496`). `swap` reorders two already-open sessions; it never opens a new stream in place of an old one.
- **Empty multiview slots** (`_EmptySlot`, `multiview_stage.dart:156-179`) are a non-interactive bordered box — pure rendering gap-filler.
- **Removing a session from the stage itself** is not possible today — only the grid tile's toggle button (`channel_library_grid.dart:597-624`) or the long-press actions sheet (`_ChannelActionsSheet`, same file) can remove a channel from MultiView, both of which require leaving the stage and finding the tile again.
- **Favorites have zero ordering effect.** `sortChannels()` (`channel_filters_provider.dart:620-641`) switches only on the five `ChannelSortColumn` values; favorite status never enters the comparator. Favorites are stored standalone in `FavoriteChannelsStorage` (`platform_favorites`, SharedPreferences-backed, single `Set<String>` key) with no shared "channel preferences" box other packages can piggyback on.
- **The phone AppBar** (`iptv_screen.dart:1083-1113`, non-ten-foot branch only) carries five actions: Search, Movies & Shows, Playlist source (link icon = "IPTV URL"), Guide URL, Cast. The **hamburger drawer** (`IptvNavigationDrawer`) is explicitly phone/tablet-only by its own doc comment — the ten-foot layout uses `_TvNavigationRail` in `app/lib/core/app/tv_shell.dart` and never references the drawer.
- **"App settings" → channel toggle** is the "Explorer rows" dialog (`shell_settings_dialog.dart`), one `SwitchListTile` per `AiroTvControlRow` (`Channel, Stats, Filters, Hotbar, Playlist`), reached from the player-actions sheet.
- **Loading screen** (`tv_loading_screen.dart`) is a spinner and a text label on a static gradient — no channel logo, no animation.

## Market scan (informing, not dictating, the design)

- IPTV multiview UX in 2026 defaults to a 2×2 grid with capacity gated by device horsepower — matches our existing `MultiviewLayoutKind.quad` + hardcoded capacity; no change needed there, just the replace-on-full flow. ([Tuneline](https://tuneline.app/blog/iptv-picture-in-picture-multi-stream-guide), [IPVOS](https://ipvos.com/blog/iptv-multiview-complete-guide/))
- Netflix-style player chrome overlays auto-hide on ~5s idle, reappear on any input — validates Phase C's channel-name-overlay design; we'll use 5s to match convention (was 4s in the original proposal). ([streamflix reference implementation](https://github.com/chriz-3656/streamflix))
- YouTube TV lets viewers drag-reorder and hide individual channels in the guide — validates the "not for me" demotion direction in Phase B, and suggests a natural v2 extension (full hide, drag-to-reorder favorites) that we are **not** building now (YAGNI) but flag as backlog. ([Google support](https://support.google.com/youtubetv/community-guide/373293152/how-to-customize-your-guide-with-your-favorite-channels))
- Android/Fire TV design guidelines confirm 10-foot grids need visible focus scaling and adequate touch targets even as density increases — a constraint on Phase B's "one more column" compaction: card shrink must preserve the existing `TvFocusable` focus-scale affordance, not just shrink padding. ([Android Developers — TV layouts](https://developer.android.com/design/ui/tv/guides/styles/layouts))
- Bottom tab bars (Home/Search/Profile-style) are the standard mobile OTT pattern (Disney+, Max, Peacock) — validates Phase D scope as phone/tablet-only, not a TV pattern.

**Backlog ideas surfaced by research, not in scope for this spec** (flag for later, do not build now): system PiP on app-leave, drag-to-reorder favorites, a full per-channel "hide entirely" option alongside the softer "not for me" demotion.

## Phase A — MultiView replace/remove flow (items 1, 2, 3)

**Goal:** every MultiView action (add, remove, replace, fill-empty) is reachable from the stage itself, with no round trip to the grid.

1. **Remove without re-scrolling.** Add a small dismiss control to each active `MultiviewStage` tile (visible on focus, matching the existing `_PromotableSurface` long-press `_showTileControls` affordance) that calls `multiviewProvider.notifier.toggle(session.channel)` directly.
2. **Replace-slot-with-confirm.** Add `MultiviewNotifier.replace(String oldChannelId, IPTVChannel newChannel)`: removes the old session and adds the new one atomically (same pool operation, so the layout doesn't reflow). When `toggle()` returns `capacityReached`, replace the snackbar with a dialog listing current sessions by slot label ("Screen 1: BBC News", "Screen 2: ESPN") plus Cancel; picking one calls `replace`.
3. **Tappable empty slot.** `_EmptySlot` becomes a `TvFocusable` target. Selecting it opens a lightweight channel-picker sheet (reuses the existing filtered channel list, not a new grid); picking a channel calls the existing `toggle()`, which the pool naturally places into the first open slot.

**Testing:** widget tests for the new dialog's slot-selection → `replace()` call; provider unit tests for `replace()`'s atomicity (old session gone, new session present, same layout); no regression to `swap`/`promote`.

## Phase B — Channel grid compaction & "not for me" (items 6, 10)

1. **Remove the persistent add-to-queue button** from `_ChannelTile` (`channel_library_grid.dart:597-624`). The long-press `_ChannelActionsSheet` already has "Add/remove split view" and favorite — it becomes the sole path for both touch (long-press) and D-pad (secondary action key, already wired via `TvFocusable.onSecondaryAction`). Freed corner space lets us shrink `_cardWidth`/`_cardHeight` modestly and recompute `_columnCountFor` so common TV widths gain one column, while keeping `TvFocusable`'s focus-scale affordance untouched (per the Fire/Android TV guideline above — compaction must not shrink below the minimum comfortable touch/D-pad target).
2. **"Not for me" flag**, mirroring `FavoriteChannelsStorage` exactly: a new `NotForMeChannelsStorage` (own SharedPreferences key `iptv_not_for_me_channel_ids`), `notForMeChannelIdsProvider`, `isChannelNotForMeProvider`, `channelNotForMeTogglerProvider`. Exposed as a new row in `_ChannelActionsSheet`. Ordering: `ChannelBrowserSnapshotCache.resolve()` stable-partitions the sorted list — favorites first, normal middle, not-for-me last — applied after `sortChannels()`, regardless of the active sort column (per your confirmed answer). If a channel is both favorited and not-for-me, favorite wins (rare edge case, no UI needed for it).

**Testing:** grid golden/layout test at a couple of representative TV widths confirming the extra column and unchanged focus-scale visuals; snapshot-cache unit test for the three-way partition (favorite / normal / not-for-me) across all five sort columns.

## Phase C — Player chrome cleanup (items 5, 7, 8, 9)

1. **Kill the "Channel" row toggle** in the Explorer-rows settings dialog. Replace the always-visible `ChannelInfoBar` row with a transient overlay on the video stage: channel logo + name + LIVE badge, `AnimatedOpacity` fade in on channel change or any remote/touch input, auto-hide after 5s idle (matches the Netflix-style convention above). Reuses the existing `ChannelLogo` widget and `_VideoStageWithActions`-style `Positioned` overlay pattern already in `airo_tv_shell.dart` — no new asset pipeline.
2. **Loading screen gets a channel logo** (`tv_loading_screen.dart`) instead of spinner-only, so a loading channel is legible rather than looking stuck/blank.
3. **Zoom-out completion transition:** when the stream reports ready, the loading logo scales down and fades as the video frame fades in (~300-350ms, easeOut) — one new `AnimationController`-backed sequence (everything else in this phase is implicit `Animated*` widgets).
4. **Clean top bar:** remove "Playlist source" (link/IPTV URL) and "Guide URL" icons from the phone `AppBar` (`iptv_screen.dart:1097-1106`); both actions move into the Explorer-rows settings sheet as new rows.

**Testing:** widget test confirming the overlay shows on channel change and on synthetic input, then auto-hides after the idle window (use a fake `Timer`/`Clock`); loading-screen golden test with a logo present; AppBar widget test asserting the two icons are gone and Settings surfaces them instead.

## Phase D — Floating bottom nav, phone/tablet only (item 11)

Scope confirmed: the ten-foot layout's `_TvNavigationRail` is untouched — this only replaces the phone/tablet `IptvNavigationDrawer` + AppBar icon row.

1. Remove `Scaffold.drawer` (`IptvNavigationDrawer`) and the AppBar's action icon row, except Cast (kept top-right, sole remaining top-bar icon, only when `isGoogleCastSenderPlatform`).
2. Add a floating bottom bar: **Home**, **Search**, **My Aika**. Home resets to the top of the channel list/clears transient filters (today's `onHome: () {}` is a no-op — this phase gives it real behavior for the first time). Search opens the existing `_showSearchSheet`.
3. **My Aika** opens an overflow sheet with today's drawer contents minus Home/Guide: Settings, Movies & Shows, Favorites, Play local file on TV. (Guide URL already moved into Explorer-rows settings in Phase C.)

**Testing:** widget test confirming the drawer/AppBar icons are gone on phone width and present-as-before on ten-foot width (no regression to `_TvNavigationRail`); My Aika sheet contains exactly the expected four rows.

## Visual language (all phases)

No new palette — reuse the existing dark cinematic tokens already in this codebase (`#020419` panel background, `Colors.black.withValues(alpha: 0.56/0.68)` scrims, `AiroBadge`/`AiroSpacing` tokens). Motion stays implicit (`AnimatedOpacity`/`AnimatedScale`, ~200-350ms easeOut) except the one explicit `AnimationController` for the loading zoom-out sequence in Phase C. Scrim gradients behind the new overlay (Phase C) and floating nav (Phase D) for legibility over arbitrary video content, consistent with the existing `_StageAction` circular-scrim treatment.

## Build order

A → B → C → D. A carries the highest API-surface risk (new provider method) and should land and soak first; D is the most isolated (phone-only, no shared-component touches) and can slot in last without blocking anything.

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
- YouTube TV lets viewers drag-reorder and hide individual channels in the guide — validates the "not for me" demotion direction in Phase B, and directly informed "Optional extras" Extra 1 (drag-to-reorder favorites), which you opted into. A further extension (full per-channel "hide entirely") is flagged as backlog instead. ([Google support](https://support.google.com/youtubetv/community-guide/373293152/how-to-customize-your-guide-with-your-favorite-channels))
- Android/Fire TV design guidelines confirm 10-foot grids need visible focus scaling and adequate touch targets even as density increases — a constraint on Phase B's "one more column" compaction: card shrink must preserve the existing `TvFocusable` focus-scale affordance, not just shrink padding. ([Android Developers — TV layouts](https://developer.android.com/design/ui/tv/guides/styles/layouts))
- Bottom tab bars (Home/Search/Profile-style) are the standard mobile OTT pattern (Disney+, Max, Peacock) — validates Phase D scope as phone/tablet-only, not a TV pattern.

**Backlog ideas surfaced by research, not in scope for this spec** (flag for later, do not build now): a full per-channel "hide entirely" option alongside the softer "not for me" demotion; a mini EPG "what's on now/next" preview on long-press/D-pad-hold of a grid tile (the app already has full EPG data and timeline widgets — `epg_program_progress.dart`, `iptv_guide_screen.dart` — this just isn't surfaced inline on the grid yet, deferred because it's a new interaction surface that deserves its own design pass); quick channel-number entry via remote digit-keys (deferred, not skipped outright — `IPTVChannel` has no channel-number field today, so this is a parser + model + migration project, not a UI add-on, and doesn't fit this round's chrome-focused scope). System PiP on app-leave is already shipped (`#1986`) — not a gap.

## Phase A — MultiView replace/remove flow (items 1, 2, 3)

**Goal:** every MultiView action (add, remove, replace, fill-empty) is reachable from the stage itself, with no round trip to the grid.

1. **Remove without re-scrolling.** Add a small dismiss control to each active `MultiviewStage` tile (visible on focus, matching the existing `_PromotableSurface` long-press `_showTileControls` affordance) that calls `multiviewProvider.notifier.toggle(session.channel)` directly.
2. **Replace-slot-with-confirm.** Add `MultiviewNotifier.replace(String oldChannelId, IPTVChannel newChannel)`, returning the same `MultiviewToggleResult` enum `toggle()` uses. **Correctness note (caught in review):** `AiroMultiviewPool.add()` rejects with `capacityReached` whenever the pool is already full (`airo_multiview_pool.dart:68-69`) — since `replace()` only runs when already at capacity, opening the new stream *before* freeing the old one would hit that same gate. `replace()` is therefore remove-old-then-add-new, not a true atomic swap: the old session is torn down first, then `add()` runs normally. If the new stream fails, the freed slot shows the same "Empty — tap to add" state Phase A.3 builds (not a claim of atomicity, reuses the recovery path being built anyway). When `toggle()` returns `capacityReached`, replace the snackbar with a dialog listing current sessions by slot label ("Screen 1: BBC News", "Screen 2: ESPN") plus Cancel; picking one calls `replace`.
3. **Tappable empty slot.** `_EmptySlot` becomes a `TvFocusable` target. Selecting it opens a lightweight channel-picker sheet (reuses the existing filtered channel list, not a new grid), **filtered to exclude channels already present in `multiviewChannelIds`** (caught in review: `toggle()` treats an already-open channel as "remove it," so an unfiltered picker would let a user "fill" the empty slot by accidentally closing that channel somewhere else). Picking a channel calls the existing `toggle()`, which the pool naturally places into the first open slot.

**Loading and empty states (design review):** while a replace or empty-slot pick is connecting, that tile shows the same loading treatment Phase C builds for the main player (channel logo + spinner) — reused, not a second bespoke loading UI. If the channel picker sheet (Phase A.3) has nothing left to offer (every channel already open elsewhere or excluded by filters), it shows the same empty-state treatment `channel_library_grid.dart`'s `_NoMatchesView` already uses for "no channels match" — reused pattern, not new copy to write from scratch.

**User journey — hitting capacity (design review storyboard):**
```
STEP                          | USER DOES              | USER FEELS           | PLAN SPECIFIES?
-------------------------------|-------------------------|-----------------------|------------------
1. Already at capacity         | Taps "add" on a 3rd     | Neutral, exploring    | (existing capacity gate)
                                 channel
2. Hits the gate                | Sees replace dialog     | Mild friction, but    | Dialog names both
                                 ("Screen 1: X / Screen    given a clear choice,   current channels by
                                 2: Y")                    not just blocked        name — no guessing
3. Picks a slot to replace      | Taps "Screen 2"         | Committed, expects    | replace() called
                                                            it to just work
4. New stream connects          | Watches Screen 2's       | Brief suspense,       | Loading treatment
                                 tile                       not confusion — it's   (above), same as
                                                            clearly loading, not    main player
                                                            broken
5a. Success                     | New channel plays        | Satisfied — the flow  | —
5b. Failure                     | Sees "Empty — tap to     | Mildly disappointed,  | Empty-slot state
                                 add" in that slot          but not stuck: same    (Phase A.3), same
                                                            recovery path as any    recovery path
                                                            other empty slot
```

**Testing:** widget tests for the new dialog's slot-selection → `replace()` call, including the failure path (new stream fails → slot goes empty, not a phantom session); provider unit tests for `replace()`'s remove-then-add sequencing; widget test confirming the empty-slot picker excludes already-open channels; widget test for the picker's empty state when nothing is pickable; no regression to `swap`/`promote`.

## Phase B — Channel grid compaction & "not for me" (items 6, 10)

1. **Remove the persistent add-to-queue button** from `_ChannelTile` (`channel_library_grid.dart:597-624`). The long-press `_ChannelActionsSheet` already has "Add/remove split view" and favorite — it becomes the sole path for both touch (long-press) and D-pad (secondary action key, already wired via `TvFocusable.onSecondaryAction`). Freed corner space lets us shrink `_cardWidth`/`_cardHeight` modestly (starting point: ~172px → ~155px, a ~10% reduction, to gain the targeted extra column) and recompute `_columnCountFor` so common TV widths gain one column. **Design review note:** the binding constraint here isn't raw touch-target size (cards stay far above the 48dp minimum either way) — it's whether `TvFocusable`'s enlarged focus-scale state still clips or overlaps a neighboring tile at the new, smaller resting width. Verify in visual QA once built; adjust the shrink percentage if it clips, don't treat ~155px as a hard number.
2. **"Not for me" flag, unified with favorites into the widened `FavoriteChannelsStorage`** (architecture decision made during eng review — see below for why). Exposed as a new row in `_ChannelActionsSheet`. Ordering: `ChannelBrowserSnapshotCache.resolve()` stable-partitions the sorted list — favorites first, normal middle, not-for-me last — applied after `sortChannels()`, regardless of the active sort column (per your confirmed answer). **Favorite and not-for-me are mutually exclusive by construction**, not by convention (see below).

**Architecture — one storage, not two (caught in eng review):** the original spec had a new standalone `NotForMeChannelsStorage` alongside the existing `FavoriteChannelsStorage`, with exclusivity enforced only in `_ChannelActionsSheet`'s UI code. But `channel_info_bar.dart:180-208` (`_toggleFavorite`) already calls `channelFavoriteTogglerProvider` directly, bypassing that UI entirely — and a second review pass found three more direct call sites of the same provider (`tv_favorites_screen.dart:122`, `browse_screen.dart:60`, `mobile_favorites_screen.dart:114`). Enumerating "safe" call sites is a losing game — the real fix is root-cause, not per-site: **`FavoriteChannelsStorage` (name kept — see below) is widened to also own the not-for-me set**, and the fix lives in the shared `channelFavoriteTogglerProvider`/`channelNotForMeTogglerProvider` layer itself, so *every* call site — enumerated or not, today or added later — inherits exclusivity automatically without needing to know this migration happened. It exposes `setFavorite(id)` / `setNotForMe(id)` / `clearPreference(id)`, each a sequential read-modify-write across two SharedPreferences keys (`iptv_favorite_channel_ids`, `iptv_not_for_me_channel_ids`) — same consistency model the existing `toggleFavorite` already has (no new locking; a human tapping a toggle isn't a transactional-guarantee scenario, and this race has never been an issue in this codebase). `setFavorite`/`replaceAll` (the backup-import path) check membership before appending to the ordered list, so a duplicate id from a stale/re-run import can't sneak a channel into the list twice.

**Class name kept as `FavoriteChannelsStorage`** (not renamed to `ChannelPreferenceStorage`) — it's referenced as a concrete type, not just via provider, in `iptv_providers.dart` and `iptv_backup_state_store.dart` plus existing tests; renaming would force updating every typed reference for a naming preference with no functional gain. The class does more than its name suggests now — accepted tradeoff for the smaller diff.

**Favorites are stored ordered from day one.** Since this class already needs widening, its favorites side stores an ordered `List<String>` (not the old `Set<String>`) from the start — this is what makes "Optional extras → Extra 1" (drag-to-reorder) a pure UI addition later instead of its own storage migration.

**Cache invalidation:** `ChannelBrowserSnapshotCache.resolve()` currently memoizes on filters/sort/metadata only (`channel_filters_provider.dart:424-471`). It now takes `favoriteIds`/`notForMeIds` as explicit inputs and includes them in its memoization signature, same pattern as its existing filter/sort keys — otherwise toggling a favorite or not-for-me flag won't invalidate the cached grid order. **Performance (caught in eng review):** the three-way partition must convert the ordered favorites `List` to a `Set` once per `resolve()` call for O(1) membership checks while partitioning — a naive `list.contains()` per channel against an unconverted `List` would regress today's O(1) favorite lookup to O(n·m) against a catalogue the code's own comments describe as "thousands of rows."

**Testing:** grid golden/layout test at a couple of representative TV widths confirming the extra column and unchanged focus-scale visuals; snapshot-cache unit test for the three-way partition (favorite / normal / not-for-me) across all five sort columns, and a cache-invalidation test confirming a favorite/not-for-me toggle changes `resolve()`'s output on the next call; **a provider-level regression test on `channelFavoriteTogglerProvider`/`channelNotForMeTogglerProvider` directly** (not a per-screen widget test) proving exclusivity at the shared choke point every call site routes through — this is what makes enumeration of call sites unnecessary for correctness; storage test for dedup on repeated `setFavorite`/import; storage contract test for order preservation (not just membership).

## Phase C — Player chrome cleanup (items 5, 7, 8, 9)

1. **Kill the "Channel" row toggle** in the Explorer-rows settings dialog. Replace the always-visible `ChannelInfoBar` row with a transient overlay on the video stage: channel logo + name + LIVE badge, `AnimatedOpacity` fade in on channel change or any remote/touch input, auto-hide after 5s idle (matches the Netflix-style convention above). Reuses the existing `ChannelLogo` widget and `_VideoStageWithActions`-style `Positioned` overlay pattern already in `airo_tv_shell.dart` — no new asset pipeline. **Resolved (design review):** opening the player-actions sheet (Settings, Help, MultiView layout, etc.) immediately dismisses the overlay, same as an idle timeout — no two floating layers competing for the same screen corner.
2. **Loading screen gets a channel logo** (`tv_loading_screen.dart`) instead of spinner-only, so a loading channel is legible rather than looking stuck/blank.
3. **Zoom-out completion transition:** when the stream reports ready, the loading logo scales down and fades as the video frame fades in (~300-350ms, easeOut) — one new `AnimationController`-backed sequence (everything else in this phase is implicit `Animated*` widgets).
4. **Playlist source and Guide URL move into the Explorer-rows settings sheet** as new rows (both currently live in the phone `AppBar`, `iptv_screen.dart:1097-1106`). The AppBar icons themselves are **not** removed here — see Phase D below, which guts that whole row for the bottom nav a moment later; removing the icons twice in two phases was flagged in review as wasted, duplicate-tested work on the same widget.

**Testing:** widget test confirming the overlay shows on channel change and on synthetic input, then auto-hides after the idle window (use a fake `Timer`/`Clock`); loading-screen golden test with a logo present; settings-sheet widget test confirming the two new rows exist and work (AppBar-icon-removal is verified in Phase D's test instead, since that's where the icons actually disappear).

## Phase D — Floating bottom nav, phone/tablet only (item 11)

Scope confirmed: the ten-foot layout's `_TvNavigationRail` is untouched — this only replaces the phone/tablet `IptvNavigationDrawer` + AppBar icon row.

1. Remove `Scaffold.drawer` (`IptvNavigationDrawer`) and **the entire AppBar action icon row** (Search, Movies & Shows, Playlist source, Guide URL — the last two already relocated to settings in Phase C, so this is the one and only edit to that row), except Cast (kept top-right, sole remaining top-bar icon, only when `isGoogleCastSenderPlatform`).
2. **Bespoke floating bottom bar** — **correction (caught while writing the implementation plan, verified against actual source):** `AdaptiveNavigation` does not exist. `docs/ui/RESPONSIVE_STANDARDS.md`'s "Bottom nav (mobile) → Navigation rail (desktop)" code block is an illustrative example, never implemented — `app/lib/shared/widgets/responsive_center.dart` only defines `ResponsiveCenter`, `ResponsiveBreakpoints`, `AdaptiveLayout`, `ResponsiveGrid` (confirmed by grep across the whole repo: zero matches for `AdaptiveNavigation`). The design review's "reuse it" finding was based on a false premise; reverted to the original plan. Build a new, focused widget instead: three destinations — **Home**, **Search**, **My Aika** — styled as the premium floating pill (full control over shape/elevation/scrim, no fighting a nonexistent component's defaults). Home resets to the top of the channel list/clears transient filters (today's `onHome: () {}` is a no-op — this phase gives it real behavior for the first time). Search opens the existing `_showSearchSheet`.
3. **My Aika** opens `AdaptiveBottomSheet.show` (same file) with today's drawer contents minus Home/Guide: Settings, Movies & Shows, Favorites, Play local file on TV. (Guide URL already moved into Explorer-rows settings in Phase C.)

**Testing:** widget test confirming the drawer and every AppBar action icon except Cast are gone on phone width, and present-as-before on ten-foot width (no regression to `_TvNavigationRail`); My Aika sheet contains exactly the expected four rows.

## Optional extras (opt-in, not part of the original 10 asks)

These two items were surfaced during market research and cherry-picked by you during review — flagged here as their own section, not folded into the numbered phases above, because (per review feedback) a storage-contract migration and a new data-backed rail are a different shape of work than the chrome-cleanup asks and shouldn't dilute the bounded, independently-shippable scope of Phases A-D.

### Extra 1 — Drag-to-reorder favorites

Favorites stop being alpha-sorted-within-group and become a user-orderable list. **The storage-contract migration this used to require is no longer needed here** — Phase B's widened `FavoriteChannelsStorage` already persists favorites as an ordered `List<String>` from day one (see Phase B.2). This extra is now purely a UI addition on top of already-ordered data: drag handles in the favorites-filtered grid view (touch); a D-pad "move up/move down" pair in `_ChannelActionsSheet` (ten-foot — no native drag gesture on a remote), calling a new `FavoriteChannelsStorage.reorderFavorite(id, newIndex)`. **Focus behavior:** after a move-up/move-down action, D-pad focus stays on the same channel at its new position — standard list-reorder convention, matches existing `TvFocusable` usage elsewhere.

**Testing:** widget test for both reorder paths (drag and D-pad move); widget test confirming focus follows the moved item; backup/restore round-trip test confirming favorite order survives export→import (this exercises Phase B's storage, but the round-trip only matters once order is user-editable, so it's listed here).

### Extra 2 — "Jump back in" rail

`core_watch_progress` is already wired into `feature_iptv` (`rails_provider.dart`), so this is a UI addition on existing data, not new plumbing. Add a "Jump back in" rail above (or folded into) the channel grid on both layouts, sourced from the existing watch-progress rail provider, filtered to channels still in the current playlist/filters. Selecting a tile resumes that channel exactly like a normal grid tile (`onChannelSelected`).

**Testing:** provider test confirming the rail only shows channels present in the current filtered set (a channel removed from the playlist shouldn't leave a dead tile); widget test for empty state (no watch history yet — rail renders nothing, not an empty shelf).

## Information architecture (design review)

No DESIGN.md exists in this repo — there's no formal token/component system to calibrate against, only the dark cinematic conventions already established in this code (reused throughout, see Visual language below). Not a blocker for this spec since every new element explicitly reuses an existing token or pattern rather than inventing new ones; worth a `/design-consultation` pass at some point to formalize what's already de facto standard, but that's separate scope from this revamp.

Screen composition, phone/tablet (existing structure, unchanged — only the pieces named below are new):
```
┌─────────────────────────────┐
│  [Cast icon only, if avail.] │  ← AppBar: everything else removed (Phase D)
├─────────────────────────────┤
│                               │
│       Video hero frame        │  ← NEW: channel-name overlay, transient (Phase C)
│                               │
├─────────────────────────────┤
│  Explorer chrome rows         │  ← unchanged (Stats/Hotbar/Filter, existing)
├─────────────────────────────┤
│  Channel grid                 │  ← compacted (Phase B), NEW: jump-back-in
│                               │     rail above it (Extra 2)
├─────────────────────────────┤
│  Home │ Search │ My Aika      │  ← NEW: AdaptiveNavigation (Phase D)
└─────────────────────────────┘
```
First/second/third: video is the primary focus (existing hierarchy, unchanged), channel identity is secondary (now a transient overlay instead of a permanent row — an explicit demotion, matching the "clean player" ask), navigation is tertiary and always accessible at the bottom.

**Accessibility convention (design review):** every new interactive element (Phase A's tile dismiss/empty-slot controls, Phase B's not-for-me row, Phase D's nav destinations) uses the same `TvFocusable` `semanticLabel`/`semanticHint` pattern already used by every existing focusable element in this codebase — not a new convention to invent, just don't skip it on the new ones.

## Visual language (all phases)

No new palette — reuse the existing dark cinematic tokens already in this codebase (`#020419` panel background, `Colors.black.withValues(alpha: 0.56/0.68)` scrims, `AiroBadge`/`AiroSpacing` tokens). Motion stays implicit (`AnimatedOpacity`/`AnimatedScale`, ~200-350ms easeOut) except the one explicit `AnimationController` for the loading zoom-out sequence in Phase C. Scrim gradients behind the new overlay (Phase C) and floating nav (Phase D) for legibility over arbitrary video content, consistent with the existing `_StageAction` circular-scrim treatment.

## Build order

A → B → C → D, then the two optional extras whenever you want them (Extra 1 pairs naturally with Phase B since it touches the same favorite-ordering code; Extra 2 is fully independent and can land anytime). A carries the highest API-surface risk (new provider method) and should land and soak first; D is the most isolated (phone-only nav) and can slot in last without blocking anything.

Per-phase implementation approach: **just-in-time extraction**, not an upfront rewrite. `AiroTvShell` (967 lines, 13 commits in the last 30 days — a genuine churn hotspot) is not restructured wholesale before Phase A starts. Instead, each phase pulls its own piece out into a focused widget file as it touches it — Phase A's tile controls into `MultiviewStage`'s own file (already separate), Phase C's channel overlay into a new `_ChannelNameOverlay` widget instead of another inline `Positioned` block in `airo_tv_shell.dart`. This keeps every phase shippable on its own while stopping the hotspot from accreting further inline complexity.

## Test coverage diagram (eng review)

```
CODE PATHS                                                    STATUS
[Phase A] MultiviewNotifier
  ├── replace() remove-old→add-new                            [PLANNED] provider test
  │   ├── new stream succeeds                                 [PLANNED] happy path
  │   └── new stream fails → slot empty                       [PLANNED] failure path (was a GAP before review)
  ├── empty-slot picker filtered by multiviewChannelIds        [PLANNED] widget test (was a GAP before review)
  └── toggle()/swap()/promote() (existing)                     [EXISTING] no regression test added — should add one

[Phase B] FavoriteChannelsStorage, widened (post-eng-review; name kept, class does more)
  ├── setFavorite(id) clears notForMe                            [PLANNED] provider-level regression test (covers every
  ├── setNotForMe(id) clears favorite                             call site, enumerated or not — see rationale above)
  ├── setFavorite/replaceAll dedup on repeated id                [PLANNED] storage test (was a GAP before review)
  ├── ChannelBrowserSnapshotCache.resolve() 3-way partition      [PLANNED] unit test, all 5 sort columns, O(1) lookup verified
  └── cache invalidation on favorite/notForMe toggle             [PLANNED] unit test (was a GAP before review)

[Phase C] Channel-name overlay + loading logo
  ├── overlay shows on channel change / input, hides at 5s idle [PLANNED] widget test w/ fake Timer
  ├── loading screen renders channel logo                       [PLANNED] golden test
  └── zoom-out transition on stream-ready                       [GAP] no test specified for the AnimationController
                                                                         sequence itself (only the loading-screen static state)

[Phase D] Bottom nav / AppBar removal
  ├── drawer + AppBar icons gone (phone), unchanged (TV)        [PLANNED] widget test
  └── My Aika sheet contents                                    [PLANNED] widget test

[Extra 1] Drag-to-reorder favorites
  ├── drag path (touch) / move-up-down path (D-pad)             [PLANNED] widget test both paths
  ├── focus follows moved item                                  [PLANNED] widget test
  └── backup/restore order round-trip                           [PLANNED] integration test

[Extra 2] Jump-back-in rail
  ├── filtered to current playlist/filters                      [PLANNED] provider test
  └── empty state                                                [PLANNED] widget test

COVERAGE: 19/21 planned paths have a specified test (90%). 2 gaps below.
```

**Gaps found (added to the plan, per Test Review requirements):**
1. **[GAP, now fixed]** Phase C's zoom-out `AnimationController` sequence had no test in the original spec — added: a widget test driving the controller through a full run (start → mid → complete) asserting the logo's scale/opacity at each checkpoint and that it disposes cleanly on rapid channel switches (switching channel again mid-animation must not leak the old controller — a real risk with `AnimationController`s tied to async stream-ready callbacks).
2. **[REGRESSION, IRON RULE — mandatory, not optional]** Every existing call site of `channelFavoriteTogglerProvider` (`channel_info_bar.dart`, `tv_favorites_screen.dart`, `browse_screen.dart`, `mobile_favorites_screen.dart`, and any not yet enumerated) changes behavior the moment `FavoriteChannelsStorage` is widened — favoriting now also clears `notForMe`. This is modification of existing, shipped behavior, so per the Test Review's regression rule a test is mandatory regardless of severity. Per the root-cause fix above, one **provider-level** test on `channelFavoriteTogglerProvider` itself covers all of them at the shared choke point — no per-screen widget test needed for this specific behavior.

Both gaps are folded into the relevant phase's Testing bullet above (Phase C and Phase B respectively) — not deferred.

## NOT in scope
- **Item 4** (the "yrf music" / zoom-720p / blank multiview screen report) — could not be reproduced from the code; needs a restated repro (see top of doc).
- **Mini EPG "what's on now/next" preview** — deferred, new interaction surface deserves its own design pass (see Backlog).
- **Quick channel-number entry** — skipped, `IPTVChannel` has no channel-number field; real cost is a parser + model + migration project, not chrome work.
- **Full per-channel "hide entirely"** — deferred alongside the softer "not for me" demotion (see Backlog).
- **System PiP on app-leave** — not in scope because it already shipped (`#1986`), not a gap.
- **Device-tier-aware MultiView capacity** (currently hardcoded 2/4/1 per platform) — out of scope; this spec works within the existing capacity model (that's precisely what the replace-slot flow is for), doesn't change how capacity itself is computed.

## What already exists (reused, not rebuilt)
- `MultiviewStage`'s `_EmptySlot`, `_PromotableSurface`, and long-press `_showTileControls` — extended, not replaced, for Phase A.
- `_ChannelActionsSheet` (long-press menu) — becomes the sole multiview-toggle and favoriting surface for Phase B.1, already had the long-press wiring for both touch and D-pad.
- `FavoriteChannelsStorage`'s SharedPreferences/`KeyValueStore` pattern and public name — widened in place to also own the not-for-me set, not replaced with a new class.
- `ChannelLogo` widget and `_VideoStageWithActions`'s `Positioned`-overlay pattern — reused verbatim for Phase C's channel-name overlay, no new asset pipeline.
- `core_watch_progress` + `rails_provider.dart` — Extra 2 is pure UI on top of this existing, already-wired data source.
- `_showSearchSheet` — reused as-is for Phase D's Search nav button.
- `AdaptiveBottomSheet` (`app/lib/shared/widgets/adaptive_dialog.dart`, verified real) — reused for Phase D's "My Aika" sheet. `AdaptiveNavigation` is **not** reused for the bottom bar itself — verified it doesn't exist (see Phase D correction); that part is new, bespoke code.

## Worktree parallelization strategy

| Step | Modules touched | Depends on |
|------|------------------|------------|
| Phase A (MultiView replace/remove) | `platform_player` (pool), `feature_iptv/application/providers` (multiview), `feature_iptv/presentation/tv_ux/sections` (multiview_stage) | — |
| Phase B (grid + preferences) | `platform_favorites` (unified storage), `feature_iptv/application/providers` (channel_filters), `feature_iptv/presentation/tv_ux/sections` (channel_library_grid) | — |
| Phase C (chrome cleanup) | `feature_iptv/presentation/tv_ux` (shell, loading screen, settings dialog) | — |
| Phase D (bottom nav) | `feature_iptv/presentation/screens` (iptv_screen), `feature_iptv/presentation/widgets` (nav drawer removal) | — |
| Extra 1 (reorder favorites) | `platform_favorites`, `feature_iptv/presentation/tv_ux/sections` (channel_library_grid) | Phase B (shares the widened `FavoriteChannelsStorage`) |
| Extra 2 (jump-back rail) | `feature_iptv/application/providers` (rails), `feature_iptv/presentation/tv_ux` | — |

**Lanes:** A, C, and D touch disjoint modules and have no dependency on each other or on B — **Lane 1: A**, **Lane 2: C**, **Lane 3: D** can all run in parallel worktrees. **Lane 4: B**, once merged, unblocks **Extra 1** (same lane, sequential after B). **Extra 2** is fully independent and can run in any lane or its own (**Lane 5**). Only conflict risk: A and B both touch `feature_iptv/presentation/tv_ux/sections/channel_library_grid.dart` (A's empty-slot picker reuses the grid's filtering; B removes the per-tile button from the same file) — coordinate those two lanes' merges in either order, but merge one before starting the other's grid edits to avoid a conflict, or accept a small manual merge.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | clean (issues_found → fixed) | Mode: SELECTIVE EXPANSION. 4 architecture/correctness findings (favorites API contract, snapshot-cache invalidation, replace() failure path, favorite/not-for-me exclusivity) — all resolved. 4 market-informed expansion candidates surfaced, cherry-picked: 2 included (jump-back-in rail, drag-to-reorder favorites, split into "Optional extras"), 1 deferred (mini EPG preview), 1 skipped (channel-number entry, data-model cost too high). |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | not run (quota) | Codex CLI authenticated but exhausted its usage quota mid-run on both attempts (ChatGPT plan limit, resets 2026-09-15) before producing content. Both outside-voice passes fell back to a Claude subagent — same model family, not a true cross-model check; treat as weaker signal than a real second model. |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | clean (issues_found → fixed) | 3 architecture/quality findings: mutual-exclusion enforcement moved from UI code to the shared provider layer (root-cause fix covering all call sites, including 3 more than originally enumerated); storage class kept as `FavoriteChannelsStorage` rather than renamed, to avoid breaking typed references; O(n·m) partition-performance regression caught and fixed (Set-based lookup). Plus dedup gap and a missing AnimationController test, both fixed. Test coverage diagram: 19/21 planned paths covered pre-fix, both gaps closed. Parallelization: 5 lanes, 4 parallel-capable (A/C/D/Extra 2), 1 sequential dependency (Extra 1 after B). |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | clean (issues_found → fixed) | No mockups generated — gstack designer binary present but no OpenAI key configured; ran text-only per the skill's documented fallback. Score 6.7/10 → 8.7/10 across 6 rated passes. Found: `AdaptiveNavigation`/`AdaptiveBottomSheet` already exist in `core_ui` for exactly Phase D's pattern — spec was building bespoke, now reuses them. Added loading/empty states to Phase A's replace flow, a user-journey storyboard for the capacity-reached path, an information-architecture diagram, a touch-target/focus-scale note for Phase B's grid compaction, and resolved one unresolved decision (overlay vs. player-actions-sheet stacking — sheet wins). No DESIGN.md exists; flagged as non-blocking, `/design-consultation` recommended separately. |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | — |

**CODEX:** Not run — CLI hit its usage quota before producing review content on both the CEO-review and eng-review outside-voice passes. Both fell back to a fresh-context Claude subagent per each skill's documented fallback rule. Re-run either `/codex review` or ask for a fresh outside-voice pass after 2026-09-15 if a true cross-model check matters before shipping.

**CROSS-MODEL:** N/A this run (no genuine second model available) — all outside-voice passes were same-family Claude subagents, not scored against Codex.

**Post-review correction:** the Design Review row's `AdaptiveNavigation` reuse finding was based on a false premise — verified against actual source while writing the implementation plan, `AdaptiveNavigation` does not exist anywhere in the repo (`RESPONSIVE_STANDARDS.md`'s code block is illustrative, never implemented). Phase D reverted to a bespoke bottom bar; `AdaptiveBottomSheet` (verified real) is still reused for "My Aika." See Phase D in the spec body for the corrected text.

**VERDICT:** CEO + ENG + DESIGN CLEARED — ready to implement (with the Phase D correction above applied).

NO UNRESOLVED DECISIONS

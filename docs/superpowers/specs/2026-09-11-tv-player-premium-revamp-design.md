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

**Testing:** widget tests for the new dialog's slot-selection → `replace()` call, including the failure path (new stream fails → slot goes empty, not a phantom session); provider unit tests for `replace()`'s remove-then-add sequencing; widget test confirming the empty-slot picker excludes already-open channels; no regression to `swap`/`promote`.

## Phase B — Channel grid compaction & "not for me" (items 6, 10)

1. **Remove the persistent add-to-queue button** from `_ChannelTile` (`channel_library_grid.dart:597-624`). The long-press `_ChannelActionsSheet` already has "Add/remove split view" and favorite — it becomes the sole path for both touch (long-press) and D-pad (secondary action key, already wired via `TvFocusable.onSecondaryAction`). Freed corner space lets us shrink `_cardWidth`/`_cardHeight` modestly and recompute `_columnCountFor` so common TV widths gain one column, while keeping `TvFocusable`'s focus-scale affordance untouched (per the Fire/Android TV guideline above — compaction must not shrink below the minimum comfortable touch/D-pad target).
2. **"Not for me" flag**, mirroring `FavoriteChannelsStorage` exactly: a new `NotForMeChannelsStorage` (own SharedPreferences key `iptv_not_for_me_channel_ids`), `notForMeChannelIdsProvider`, `isChannelNotForMeProvider`, `channelNotForMeTogglerProvider`. Exposed as a new row in `_ChannelActionsSheet`. Ordering: `ChannelBrowserSnapshotCache.resolve()` stable-partitions the sorted list — favorites first, normal middle, not-for-me last — applied after `sortChannels()`, regardless of the active sort column (per your confirmed answer). **Favorite and not-for-me are mutually exclusive**: toggling one clears the other (setting "not for me" on a favorited channel un-favorites it, and vice versa) — no channel can be in both sets, so the sort tiebreak question never arises.

**Cache invalidation:** `ChannelBrowserSnapshotCache.resolve()` currently memoizes on filters/sort/metadata only (`channel_filters_provider.dart:424-471`). It now takes `favoriteIds`/`notForMeIds` as explicit inputs and includes them in its memoization signature, same pattern as its existing filter/sort keys — otherwise toggling a favorite or not-for-me flag won't invalidate the cached grid order.

**Testing:** grid golden/layout test at a couple of representative TV widths confirming the extra column and unchanged focus-scale visuals; snapshot-cache unit test for the three-way partition (favorite / normal / not-for-me) across all five sort columns, and a cache-invalidation test confirming a favorite/not-for-me toggle changes `resolve()`'s output on the next call.

## Phase C — Player chrome cleanup (items 5, 7, 8, 9)

1. **Kill the "Channel" row toggle** in the Explorer-rows settings dialog. Replace the always-visible `ChannelInfoBar` row with a transient overlay on the video stage: channel logo + name + LIVE badge, `AnimatedOpacity` fade in on channel change or any remote/touch input, auto-hide after 5s idle (matches the Netflix-style convention above). Reuses the existing `ChannelLogo` widget and `_VideoStageWithActions`-style `Positioned` overlay pattern already in `airo_tv_shell.dart` — no new asset pipeline.
2. **Loading screen gets a channel logo** (`tv_loading_screen.dart`) instead of spinner-only, so a loading channel is legible rather than looking stuck/blank.
3. **Zoom-out completion transition:** when the stream reports ready, the loading logo scales down and fades as the video frame fades in (~300-350ms, easeOut) — one new `AnimationController`-backed sequence (everything else in this phase is implicit `Animated*` widgets).
4. **Playlist source and Guide URL move into the Explorer-rows settings sheet** as new rows (both currently live in the phone `AppBar`, `iptv_screen.dart:1097-1106`). The AppBar icons themselves are **not** removed here — see Phase D below, which guts that whole row for the bottom nav a moment later; removing the icons twice in two phases was flagged in review as wasted, duplicate-tested work on the same widget.

**Testing:** widget test confirming the overlay shows on channel change and on synthetic input, then auto-hides after the idle window (use a fake `Timer`/`Clock`); loading-screen golden test with a logo present; settings-sheet widget test confirming the two new rows exist and work (AppBar-icon-removal is verified in Phase D's test instead, since that's where the icons actually disappear).

## Phase D — Floating bottom nav, phone/tablet only (item 11)

Scope confirmed: the ten-foot layout's `_TvNavigationRail` is untouched — this only replaces the phone/tablet `IptvNavigationDrawer` + AppBar icon row.

1. Remove `Scaffold.drawer` (`IptvNavigationDrawer`) and **the entire AppBar action icon row** (Search, Movies & Shows, Playlist source, Guide URL — the last two already relocated to settings in Phase C, so this is the one and only edit to that row), except Cast (kept top-right, sole remaining top-bar icon, only when `isGoogleCastSenderPlatform`).
2. Add a floating bottom bar: **Home**, **Search**, **My Aika**. Home resets to the top of the channel list/clears transient filters (today's `onHome: () {}` is a no-op — this phase gives it real behavior for the first time). Search opens the existing `_showSearchSheet`.
3. **My Aika** opens an overflow sheet with today's drawer contents minus Home/Guide: Settings, Movies & Shows, Favorites, Play local file on TV. (Guide URL already moved into Explorer-rows settings in Phase C.)

**Testing:** widget test confirming the drawer and every AppBar action icon except Cast are gone on phone width, and present-as-before on ten-foot width (no regression to `_TvNavigationRail`); My Aika sheet contains exactly the expected four rows.

## Optional extras (opt-in, not part of the original 10 asks)

These two items were surfaced during market research and cherry-picked by you during review — flagged here as their own section, not folded into the numbered phases above, because (per review feedback) a storage-contract migration and a new data-backed rail are a different shape of work than the chrome-cleanup asks and shouldn't dilute the bounded, independently-shippable scope of Phases A-D.

### Extra 1 — Drag-to-reorder favorites

Favorites stop being alpha-sorted-within-group and become a user-orderable list. This changes `FavoriteChannelsStorage`'s public contract from an unordered `Set<String>` (`favorite_channels_storage.dart:20-24`, currently documented "in no particular order") to an ordered `List<String>`. **Blast radius (caught in review as undercounted — do not trust a hardcoded file list):** grep every `favoriteChannelIdsProvider`/`isChannelFavoriteProvider` call site and every local `Set<String>` favorite variable at implementation time (confirmed at least: `iptv_providers.dart`, `airo_tv_shell.dart`, `guide_providers.dart`, `local_iptv_search_providers.dart`, `cast_multiview_layouts_provider.dart`, `video_player_widget.dart`, `favorite_reimport_review_banner.dart`, `channel_library_grid.dart:58`, and backup/restore's `iptv_backup_state_store.dart` + `backup_restore_section.dart` — this list is a starting point, not a ceiling). Backup/restore must round-trip order, not just membership — `replaceAll` takes an ordered `Iterable<String>` and preserves it verbatim instead of funneling through a `Set`. Drag handles in the favorites-filtered grid view (touch); a D-pad "move up/move down" pair in `_ChannelActionsSheet` (ten-foot — no native drag gesture on a remote). **Focus behavior (gap caught in review):** after a move-up/move-down action, D-pad focus stays on the same channel at its new position — standard list-reorder convention, matches existing `TvFocusable` usage elsewhere.

**Testing:** storage contract test for `FavoriteChannelsStorage` returning/persisting order (not just membership); backup/restore round-trip test confirming favorite order survives export→import; widget test for both reorder paths (drag and D-pad move); widget test confirming focus follows the moved item; widget test for the mutual-exclusion toggle behavior against "not for me" (Phase B.2).

### Extra 2 — "Jump back in" rail

`core_watch_progress` is already wired into `feature_iptv` (`rails_provider.dart`), so this is a UI addition on existing data, not new plumbing. Add a "Jump back in" rail above (or folded into) the channel grid on both layouts, sourced from the existing watch-progress rail provider, filtered to channels still in the current playlist/filters. Selecting a tile resumes that channel exactly like a normal grid tile (`onChannelSelected`).

**Testing:** provider test confirming the rail only shows channels present in the current filtered set (a channel removed from the playlist shouldn't leave a dead tile); widget test for empty state (no watch history yet — rail renders nothing, not an empty shelf).

## Visual language (all phases)

No new palette — reuse the existing dark cinematic tokens already in this codebase (`#020419` panel background, `Colors.black.withValues(alpha: 0.56/0.68)` scrims, `AiroBadge`/`AiroSpacing` tokens). Motion stays implicit (`AnimatedOpacity`/`AnimatedScale`, ~200-350ms easeOut) except the one explicit `AnimationController` for the loading zoom-out sequence in Phase C. Scrim gradients behind the new overlay (Phase C) and floating nav (Phase D) for legibility over arbitrary video content, consistent with the existing `_StageAction` circular-scrim treatment.

## Build order

A → B → C → D, then the two optional extras whenever you want them (Extra 1 pairs naturally with Phase B since it touches the same favorite-ordering code; Extra 2 is fully independent and can land anytime). A carries the highest API-surface risk (new provider method) and should land and soak first; D is the most isolated (phone-only nav) and can slot in last without blocking anything.

Per-phase implementation approach: **just-in-time extraction**, not an upfront rewrite. `AiroTvShell` (967 lines, 13 commits in the last 30 days — a genuine churn hotspot) is not restructured wholesale before Phase A starts. Instead, each phase pulls its own piece out into a focused widget file as it touches it — Phase A's tile controls into `MultiviewStage`'s own file (already separate), Phase C's channel overlay into a new `_ChannelNameOverlay` widget instead of another inline `Positioned` block in `airo_tv_shell.dart`. This keeps every phase shippable on its own while stopping the hotspot from accreting further inline complexity.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 1 | issues_found → fixed | Mode: SELECTIVE EXPANSION. 4 architecture/correctness findings (favorites API contract, snapshot-cache invalidation, replace() failure path, favorite/not-for-me exclusivity) — all resolved in spec. 4 market-informed expansion candidates surfaced, cherry-picked: 2 included (jump-back-in rail, drag-to-reorder favorites, split into "Optional extras"), 1 deferred (mini EPG preview), 1 skipped (channel-number entry, data-model cost too high). |
| Outside Voice (Claude subagent) | fallback — Codex hit usage limit before producing a review | Independent 2nd opinion | 1 | issues_found → fixed | 2 correctness bugs in Phase A as originally specced (replace() infeasible against the pool's real capacity gate; empty-slot picker could silently close an already-open channel) — both fixed. 1 scope-framing tension (extras diluting the bounded-phase premise) — resolved by splitting into "Optional extras" section. 1 build-order inefficiency (Phase C/D double-editing the same AppBar row) — resolved by merging the AppBar edit into Phase D only. 1 minor gap (D-pad reorder focus behavior) — spec'd explicitly. |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 | not run | — |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not run | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | — |

**CODEX:** Codex CLI was authenticated and attempted the outside-voice pass but exhausted its usage quota mid-run (ChatGPT plan limit, resets 2026-09-15) after only reading local skill files — it produced no actual review content. Fell back to a Claude subagent per the skill's documented fallback rule; that subagent's findings are the "Outside Voice" row above.

**VERDICT:** CEO review clear, no unresolved decisions — ready for `/plan-eng-review` before implementation begins (required gate, not yet run). Design review recommended given the UI scope (Sections covering overlay/nav/grid changes) but not blocking.

NO UNRESOLVED DECISIONS

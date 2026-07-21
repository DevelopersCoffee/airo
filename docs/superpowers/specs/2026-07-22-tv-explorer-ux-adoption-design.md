# TV Explorer UX Adoption — Design

**Date:** 2026-07-22
**Status:** Approved (approach + phasing confirmed by Uday)
**Reference:** https://tvexplorer.live (Watson TV Explorer v4.20) — screenshots captured 2026-07-22

## Goal

Adopt TV Explorer's responsive live-TV UX in Airo across all surfaces (phone,
tablet, desktop, web, TV/D-pad), keep the big video area as the anchor, and
auto-resume the last-watched live channel after a short branded splash.

## Non-goals

- No changes to playback engine, stream resolution, or failover logic.
- No fake popularity/stats data (Epic #950 rule).
- No new package — everything lives in `feature_iptv` presentation/application
  layers, reusing `core_ui` primitives.

## Approach (chosen: Adaptive shell)

One `TvExplorerShell` layout in `feature_iptv`, breakpoint-driven:

| Breakpoint | Layout |
|---|---|
| `<600dp` width (phone portrait) | Stacked: video top → channel info bar → hotbar → filter chip row → channel list |
| `≥600dp` pointer/touch (tablet/desktop/web) | Wide: large video, info bar, filter row, dense multi-column channel table (Name / Category / Country / Language / type icon) |
| TV (D-pad) | Same visual structure; every chip/row is a `Focusable`; dialogs are D-pad traversable; remote overlay maps to remote keys |

Rejected alternatives:
- Patching `iptv_screen.dart` and `iptv_tv_screen.dart` separately — duplicates
  layout logic, drifts over time.
- New `feature_tv_explorer` package — module churn without benefit; IPTV state
  already lives in `feature_iptv`.

## Components

Each section is its own file under
`packages/feature_iptv/lib/presentation/tv_explorer/`:

- `tv_explorer_shell.dart` — LayoutBuilder breakpoint switch; composes sections.
- `sections/video_stage.dart` — big video area (wraps existing
  `video_player_widget`), splash mosaic overlay, remote overlay host.
- `sections/channel_info_bar.dart` — logo, name, country flag, LIVE badge,
  favorite / like / share / ways-to-watch actions.
- `sections/filter_row.dart` — Search / Category / Country / Language chips;
  active filter highlighted (e.g. "🇮🇳 India" filled state).
- `sections/filter_dialogs.dart` — one dialog widget per filter, list of
  options with icons/flags, optional A-Z sort toggle, X to close. D-pad
  traversable on TV.
- `sections/channel_table.dart` — dense rows; columns collapse by breakpoint
  (phone: name + category; desktop: all four). Left edge shows availability
  strip (green/red) fed by `stream_availability_probe` results when present.
- `sections/remote_overlay.dart` — circular VOL +/- , CH up/down, random
  channel, mute; auto-hides; on TV maps to remote hardware keys instead of
  drawing buttons.
- `sections/ways_to_watch_dialog.dart` — Fit Screen / Full Screen / Floating
  Window (PiP) / Cast to TV (reuses `cast_device_picker_sheet` flow).
- `sections/hotbar.dart` — user-pinned quick channels row (drag/long-press to
  pin later; this pass renders pinned list + empty state).

## State & persistence

Pattern: `sharedPreferencesProvider` + StateNotifier (mirrors
`TvFontModeNotifier` / `VideoAspectRatioNotifier`).

- `lastChannelProvider` — persists stable channel id + source playlist id on
  every successful tune. Key: `iptv_last_channel`.
- `channelFiltersProvider` — in-session filter state (search text, category,
  country, language). Persisted keys: `iptv_filter_*` so filters survive
  restart (TV Explorer keeps them).
- `controlRowVisibilityProvider` — settings toggles for Channel / Stats /
  Filter / Hotbar / Playlist rows. Keys: `iptv_row_<name>_visible`.
- `hotbarChannelsProvider` — ordered pinned channel ids. Key: `iptv_hotbar`.

Filter metadata source: channel category from M3U `group-title`; country and
language from channel metadata where available (EPG / iptv-org enrichment).
Filters degrade gracefully — a filter chip hides when zero channels carry that
metadata dimension.

## Resume flow (Phase 1)

1. App opens IPTV surface → splash mosaic (branded still/grid, Airo TV logo)
   renders instantly over video stage.
2. `lastChannelProvider` read; if channel still exists in current channel
   list, tune starts loading behind splash immediately.
3. Splash dismisses at ~3 s OR when first frame renders, whichever is later
   (cap 6 s so a dead stream never traps splash).
4. Any tap / key / D-pad press skips splash instantly.
5. No last channel or channel gone → splash dismisses to normal browse state,
   nothing auto-plays.

Live channels resume at the live edge — "where it left off" means the same
channel, not a timeshift position.

## Error handling

- Last channel tune fails → fall back to browse state with existing error
  surface; never loop retries behind splash (bounded failover rule).
- Filter dialog with zero results → empty-state row "No channels match",
  clear-filter affordance.
- Cast unavailable → "No cast devices available" disabled row (as TV Explorer).

## Testing

- Widget tests per section (breakpoint rendering: phone/desktop/TV variants).
- Unit tests: `lastChannelProvider` persistence + resume decision logic
  (missing channel, stale playlist, cap timeout).
- Filter logic unit tests: combined filters, metadata-missing degradation.
- TV focus traversal test per dialog (existing `tv_focusable_test` patterns).
- Goldens optional for filter row + channel table at two breakpoints.

## Phasing (one PR each, dogfood between)

1. **Resume last channel** — `lastChannelProvider`, splash mosaic, auto-play
   ~3 s, skip-on-input.
2. **Filter row + dialogs + channel table** — responsive shell introduced
   here; existing screens route into `TvExplorerShell`. Includes (gap
   analysis round 2): column sorting (tap header to sort, tap again to
   reverse), saved filters (heart panel stores current filter combo; heart
   tints when any saved state active — key `iptv_saved_filters`), and hotbar
   bookmarks that store channel + filter combos, not just channels.
3. **Remote overlay** — touch controls + TV key mapping. Includes random
   channel (dice) button drawing from the currently filtered set.
4. **Ways to Watch** — fit/full/PiP/cast dialog.
5. **Settings control-row toggles + stats bar + help** — visibility prefs +
   settings UI. Stats row reskins the existing playback diagnostics overlay
   as a toggleable shell row (codec, resolution, bitrate — real data only,
   no fake stats per Epic #950). Contextual `?` help entries and a
   "What's New" dialog fed from the changelog.
6. **Multiview** — TV icon per channel row adds the channel to a multi-player
   stage; 3+ channels render one featured player plus a thumbnail strip.
   Player-pool cap (4 streams) and per-platform decoder budget enforced;
   thumbnails may drop to keyframe-only refresh on constrained devices.
7. **Deep links + screenshot share** — share button copies a link that
   auto-plays the channel on open (channel-only and channel+filter combo
   forms); screenshot of current frame to clipboard / share sheet where the
   platform allows.

Phase 2 is the structural one; 3–5 slot into shell sections; 6–7 build on
the stabilized shell.

## Backlog (explicitly out of this spec — file as issues)

- Sync favorites/hotbar across devices (wire into existing core_cloud/auth).
- Phone-as-remote for cast sessions (extends CV-033 groundwork).
- World map country explorer.
- Split view (cast one channel, watch another locally).
- Mirror mode (same channel phone + TV).
- DVR (record live stream to file, channel switch mid-record).

## Metadata enrichment note

TV Explorer's channel database is public iptv-org
(https://github.com/iptv-org/iptv). Airo can enrich user playlists with
iptv-org country/language/category metadata (match by stream URL or channel
id) — directly mitigates the sparse-metadata risk on Country/Language
filters. Enrichment lands with Phase 2.

## Risks

- `iptv_tv_screen.dart` (2691 lines) migration to shell must not regress
  D-pad focus — Phase 2 keeps old TV screen behind a flag until dogfood pass.
- Country/language metadata sparse in user playlists → filters may hide;
  acceptable, documented above.
- PiP (floating window) platform support varies — desktop/web fit+full ship
  first; PiP only where platform APIs exist (Android PiP, macOS floating).

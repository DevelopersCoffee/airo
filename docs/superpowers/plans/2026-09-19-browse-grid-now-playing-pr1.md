# Plan: PR1 now-playing text on the channel library grid

Date: 2026-09-19
Branch: `exp/browse-grid-live-preview` from `origin/main` (worktree `.worktrees/browse-grid-live-preview`)
Design: `docs/designs/browse-grid-live-preview.md`
Mode: SCOPE_REDUCED (eng review)

PR1 ships EPG now-playing titles on library tiles. Live peek is PR2, not this plan.

## Decisions from review

- Scope: split. This PR is text only. Peek / `browseGridTvPeekEnabled` / TV 19 amendment wait. Captured in `TODOS.md`.
- Architecture 1A: Library watches `guidePagedWindowProvider` and may cold-start the 6h window.
- Fail-closed: empty map **only when `window == null`**. Ignore `forwardLoadFailed` / `isLoadingForward` so a later page failure does not wipe now-titles (outside voice D5).
- Code quality 2A + D6: Keep `ChannelLibraryGrid` as `State`. Wrap the **whole** `MediaCard` / local card in a `Consumer` that `select`s `map[channel.id]`. Do not change `core_ui` MediaCard. Do not inject a parent map.
- Tests 3A: Provider unit tests plus grid widget tests. No-EPG category subtitle is a **CRITICAL** regression.
- Mapper `now` is the `nowTickerProvider` tick value, not a fresh `DateTime.now()`.
- Trim titles; omit blank/`" "`. If two programs air at once, use the first airing in list order. Duplicate `tvg-id` keeps Guide's first-channel-wins remap; add a test so sibling rows staying category is expected.
- D8: `semanticLabel` is `name` plus now-title when present.
- D7: overnight 6h drift is accepted; not a TODO.
- Cross-model: did not reopen cold-start. Did not inject metadata-style map.

## What already exists

- `queryGuideWindowWithOverrides` remaps EPG ids to `IPTVChannel.id` (`guide_window_query.dart:21-62`). Reuse. Do not build a second matcher.
- `guidePagedWindowProvider` + `nowTickerProvider` (30s) in `guide_providers.dart`.
- `epgProgramIsAiring` in `epg_program_progress.dart`.
- `_ChannelTile._subtitleFor` joins category · flag · language (`channel_library_grid.dart:892-899`). Replace that string with the now-title when the map has a key; otherwise keep it.
- Guide grids already index `CompactEpgWindow.entries` by `channelId` (`epg_timeline_grid.dart:90-93`).

## NOT in scope

- Live peek, overlay `AndroidView`, `browseGridTvPeekEnabled`, dispose-before-Watch (`focusPlayDelay`). Rationale: PR2; decoder work must not stall titles.
- Reels / MultiView mosaic. Rationale: killed in office-hours.
- Phone hold-to-peek. Rationale: v1.1.
- Visible-id-only EPG query. Rationale: second stack; cold-start of the existing window was chosen.
- Raising dense 5-up row extent to force a subtitle. Rationale: keep dropping subtitle; no overflow.
- New binary / CI flavor. Rationale: in-app change on existing Aika Stream pipeline.
- Overnight 6h window drift (titles revert to category). Rationale: D7; ticker still updates programs inside the loaded window.

## Data flow

```
iptvChannels + xmltv repo
        |
        v
guidePagedWindowProvider  ---- cold-start when Library first watches
        |
        v
browseNowPlayingByChannelIdProvider
  watches window + nowTicker (tick Instant is `now`)
  empty map iff window == null
  first airing program, trimmed title
        |
        v
Consumer(select: map[id]) wrapping MediaCard / local card
  subtitle: title ?? _subtitleFor
  semanticLabel: name + optional title
```

## Implementation

1. Worktree from `origin/main`: `.worktrees/browse-grid-live-preview`, branch `exp/browse-grid-live-preview`.
2. Add `browseNowPlayingByChannelIdProvider` next to `guidePagedWindowProvider` in `guide_providers.dart`.
   - Watch `guidePagedWindowProvider` and `nowTickerProvider`.
   - If `window == null`, return `const {}`. Do **not** empty the map because `forwardLoadFailed` or `isLoadingForward` is true.
   - `now` for `epgProgramIsAiring` is the ticker's `DateTime`, not wall clock.
   - For each `CompactEpgWindowEntry`, first program where `epgProgramIsAiring` (list order).
   - Trim; skip empty titles. Key is `entry.channelId`.
3. Wrap each channel **card** (`MediaCard`, `_CompactGridMediaCard`, `_HorizontalMediaCard`) in a `Consumer` that selects `map[channel.id]`. Pass `subtitle: title ?? _subtitleFor(...)`. Set `semanticLabel` to name, plus title when present. Do **not** convert `_ChannelLibraryGridState` to `ConsumerState`. Do **not** `watch` the full map in `build`.
4. Dense layouts that already pass `subtitle: null` stay null.
5. Tests:
   - `guide_providers` / new `browse_now_playing_provider_test.dart`: null window, load fail, remap match, not airing, empty title omitted, ticker updates title when a program ends.
   - `channel_library_grid_test.dart`: override the map (or window) — matched tile shows title; unmatched keeps category (**REGRESSION**); dense grid no overflow; `forwardLoadFailed` with a non-null window still shows now-title; TalkBack label includes title.

## Failure modes

| Failure | User sees | Test | Handling |
|---|---|---|---|
| No XMLTV / null window | Category subtitle (today) | Yes | Empty map |
| `forwardLoadFailed` but `window` set | Now-titles from loaded hours | Yes | Do not empty map |
| Total load fail (`window == null`) | Category, no banner | Yes | Empty map |
| Overnight past 6h window | Category until notifier rebuilds | No (accepted D7) | Documented |
| Unmatched tvg-id | Category | Yes | Omit key |
| Empty program title | Category | Yes | Omit key |
| 10k-channel first-open hitch | Brief category, then titles | Provider test only | Accepted; parse is existing Guide path |
| 30s ticker rebuilds all tiles | Jank | Widget: only matched leaf rebuilds if we can spy; otherwise code review | Consumer select |

No silent-and-untested gap on the title path. First-open hitch is accepted, not silent: titles appear when the window lands.

## Parallelization

Sequential implementation, no parallelization opportunity. Provider then subtitle then tests, all in `feature_iptv`.

## Implementation Tasks

- [ ] **T1 (P1, human: ~2h / CC: ~15min)** — `feature_iptv` — Add `browseNowPlayingByChannelIdProvider`
  - Surfaced by: Architecture 1A
  - Files: `packages/feature_iptv/lib/application/providers/guide_providers.dart`
  - Verify: `flutter test packages/feature_iptv/test --name nowPlaying`
- [ ] **T2 (P1, human: ~2h / CC: ~15min)** — `feature_iptv` — Consumer subtitle select on library tiles
  - Surfaced by: Code quality 2A
  - Files: `packages/feature_iptv/lib/presentation/tv_ux/sections/channel_library_grid.dart`
  - Verify: widget tests; no `ConsumerStatefulWidget` conversion of the grid
- [ ] **T3 (P1, human: ~3h / CC: ~20min)** — `feature_iptv` — Provider + widget tests including no-EPG regression
  - Surfaced by: Test 3A
  - Files: `packages/feature_iptv/test/iptv/application/providers/browse_now_playing_provider_test.dart`, `packages/feature_iptv/test/iptv/presentation/tv_ux/channel_library_grid_test.dart`
  - Verify: `flutter test` those files
- [ ] **T3 (P1, human: ~3h / CC: ~20min)** — `feature_iptv` — Provider + widget tests including no-EPG regression
  - Surfaced by: Test 3A
  - Files: `packages/feature_iptv/test/iptv/application/providers/browse_now_playing_provider_test.dart`, `packages/feature_iptv/test/iptv/presentation/tv_ux/channel_library_grid_test.dart`
  - Verify: `flutter test` those files
- [ ] **T4 (P1, human: ~1h / CC: ~10min)** — `feature_iptv` — semanticLabel includes now-title
  - Surfaced by: Outside voice D8
  - Files: `packages/feature_iptv/lib/presentation/tv_ux/sections/channel_library_grid.dart`
  - Verify: widget semantics test

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Outside Review | in-host Claude subagent (Codex CLI not fully probed) | Independent 2nd opinion | 1 | issues_found | fail-closed bug, MediaCard slot, 6h drift, TalkBack |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | issues_open | 4 issues folded, 0 unresolved |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **OUTSIDE COVERAGE:** provider=in-host, phase=plan-review, outside_status=unavailable (Codex not used; native subagent ran). Findings accepted: D5 fail-closed, D6 wrap MediaCard, D8 semantics. D7 drift deferred. Cold-start not reopened.
- **VERDICT:** ENG review ran SCOPE_REDUCED — ready to implement PR1 on a main worktree. Design review optional (subtitle copy). Peek remains TODO.

NO UNRESOLVED DECISIONS

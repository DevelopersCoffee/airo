# Airo TV UX Phase 2 — Responsive Shell Execution Plan

> **Issue:** #1038  
> **Base:** `origin/main` at `72fff696`  
> **Scope:** Structural live-TV browsing only; playback and failover contracts stay unchanged.

## Architecture

`AiroTvShell` becomes the single responsive composition point for live-channel
browsing. It receives existing playback/channel dependencies and a channel
selection callback, then composes the video stage, current-channel details,
shortcut row, filters, and channel table. The legacy TV screen is selected
only while `AIRO_TV_UX_SHELL` is false; dogfood must pass before enabling it
by default for D-pad devices.

New application state remains within `feature_iptv` and uses the established
`sharedPreferencesProvider` + `StateNotifier` pattern:

- `channelFiltersProvider`: search/category/country/language values stored as
  additive `iptv_filter_*` keys.
- `channelSortProvider`: session-only table column and direction.
- `savedFiltersProvider`: ordered named filter snapshots in `iptv_saved_filters`.
- `hotbarChannelsProvider`: ordered channel-and-filter bookmarks in
  `iptv_hotbar`.

The shell filters only metadata present in a playlist or confirmed by the
metadata-enrichment adapter. It never treats defaults as real country or
language data. The adapter matches a record by canonical stream URL first,
then stable channel identifier; an unavailable source results in no enriched
dimension, never invented metadata. Any metadata parsing/hydration larger
than 50 KB runs through the existing worker boundary rather than the UI
isolate.

## TDD Steps

1. Add failing provider tests for combined filters, empty metadata dimensions,
   persistence across a fresh container, and deterministic sort/reverse
   behavior. Implement immutable filter/sort state and the persisted
   notifiers until these tests pass.
2. Add failing tests for saved filter snapshots and channel-plus-filter
   shortcuts, including duplicate and missing-channel cases. Implement the
   two preference-backed notifiers and restore behavior until green.
3. Add a failing metadata-adapter test for stream-URL/id matches and missing
   records. Implement the adapter and derived view metadata without adding
   network work to a widget or fabricating country/language values.
4. Add failing `FilterRow` and dialog widget tests for visible dimensions,
   active labels, alphabetical toggle, no-match/clear behavior, and focus
   traversal. Implement `filter_row.dart` and `filter_dialogs.dart` with
   `TvFocusable` around every D-pad target until green.
5. Add failing channel-table widget tests for compact/wide columns,
   availability strips, sort activation, and channel selection. Implement
   `channel_table.dart` until green.
6. Add failing responsive-shell tests at compact, wide, and TV breakpoints.
   Implement `channel_info_bar.dart`, `hotbar.dart`, and `airo_tv_shell.dart`
   until green; use existing player components rather than duplicating
   playback logic.
7. Add the guarded route selection and tests proving compact/wide screens use
   the shell while the legacy D-pad surface remains selected unless the
   compile-time flag is enabled.
8. Run focused tests after each slice, then formatting, `flutter analyze`,
   full `flutter test`, `git diff --check`, the code-review checklist, and
   macOS dogfood using the documented TV runner.

## File Map

- `lib/application/providers/channel_filters_provider.dart`
- `lib/application/providers/channel_sort_provider.dart`
- `lib/application/providers/saved_filters_provider.dart`
- `lib/application/providers/hotbar_channels_provider.dart`
- `lib/application/channel_metadata_enrichment.dart`
- `lib/presentation/tv_ux/airo_tv_shell.dart`
- `lib/presentation/tv_ux/sections/channel_info_bar.dart`
- `lib/presentation/tv_ux/sections/filter_row.dart`
- `lib/presentation/tv_ux/sections/filter_dialogs.dart`
- `lib/presentation/tv_ux/sections/channel_table.dart`
- `lib/presentation/tv_ux/sections/hotbar.dart`
- Focused provider and widget tests beside the current package tests.

## Verification Matrix

| Behavior | Automated proof | Manual proof |
| --- | --- | --- |
| compact / wide / TV layouts | three shell breakpoints | macOS render |
| filter and persistence | provider tests + mock preferences | restart and verify values |
| sort/filter composition | provider and table tests | header activation |
| dialog D-pad traversal | key-event focus test per dialog | remote keyboard traversal |
| availability display | table fixture test | existing scan result visibility |
| guarded TV migration | route/flag test | legacy UI remains available |

## Rollback

Set `AIRO_TV_UX_SHELL=false` to keep the legacy D-pad screen active. New
preferences are additive and safely ignored by older builds.

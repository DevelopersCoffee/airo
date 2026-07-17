---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] CV-015: V2 Program Guide Timeline and Windowed EPG'
labels: 'agent/media, agent/mobile-ui, agent/framework, P1, enhancement, community-voice, v2-adopted, sprint-2'
assignees: ''
---

## Agent

**Primary agent:** agent/media
**Review agents:** agent/framework, agent/mobile-ui, agent/security-privacy, agent/qa-automation, agent/release-devex

## Task Details

**Estimate (hours):** 20

**Priority:** P1

**V2 milestone decision:** Adopt bounded.

## Description

Build a performant program guide for user-provided IPTV data by applying the useful NodeCast ideas in a Flutter/Rust shape: virtualized visible rows, bounded time windows, Rust XMLTV parsing/current-next selection, local indexes, debounced guide search, and repaint-only current-time updates.

The attached NodeCast review is correct that the value is not the browser DOM implementation. The value is windowing, caching, indexing, and incremental rendering. Airo should keep those ideas while using existing `platform_epg`, `rust/airo_core`, and Flutter TV UI boundaries.

### Community Signal

Program guides are a core IPTV expectation. Users want guide browsing to feel instant even when their playlist has thousands of channels and XMLTV contains many days of programs.

### EPG Data Source

The timetable per channel comes from user-provided XMLTV-format EPG data. XMLTV provides:

- `<channel>` records with stable channel id, display name, and optional icon.
- `<programme>` records with `channel`, `start`, `stop`, `<title>`, and optional `<desc>`.

The v2 guide data flow should be:

```text
User-authorized IPTV provider or EPG URL
  -> XMLTV file
  -> Rust XMLTV parser
  -> local timetable index/cache
  -> platform_epg guide repository
  -> feature_iptv guide grid
```

The guide grid must query by channel id and time range. It should not scan or render every programme for every channel.

### Current State

- `rust/airo_core/src/api/xmltv.rs` already parses XMLTV and supports current/next selection from file paths.
- `packages/platform_epg` owns compact EPG contracts, redacted source references, snapshot codecs, and XMLTV compact repositories.
- `packages/feature_iptv` already consumes `CompactEpgRepository` and renders compact current EPG in TV surfaces.
- The current UI does not define a full windowed timeline guide contract.
- Current Rust XMLTV parsing keeps programme channel id, start, stop, and title. Full guide implementation may need to extend the native model to include channel definitions, icons, and programme descriptions.

### Current Milestone Scope

1. Define a guide window query model: visible channel ids, start time, end time, now, and time-zone/display options.
2. Extend or add a repository boundary that returns bounded guide rows for a channel/time window without loading the entire XMLTV dataset into Flutter UI.
3. Use existing Rust XMLTV/file-path parsing where possible; Flutter must not parse XMLTV.
4. Parse XMLTV timestamps in the standard `YYYYMMDDHHmmss +ZZZZ` form, normalize them to UTC internally, and display them in the user/device time zone.
5. Store/index programme blocks by channel id and time range with fields equivalent to `channel_id`, `source_id`, `start_time`, `end_time`, `title`, `description`, and raw sanitized metadata.
6. Ingest large XMLTV files in bounded batches so huge guide files do not allocate one massive programme list in Flutter.
7. Implement a Flutter TV guide surface using virtualized channel rows and bounded horizontal time windows.
8. Add a current-time indicator that updates by repaint/timer without rebuilding every program row.
9. Add deterministic search/filter hooks that can reuse CV-006 local search without AI.

### Non-Goals

- No Xtream or Stalker provider implementation in this issue.
- No server-side EPG cache, Docker, Home Server, or background LAN sync.
- No AI/SLM guide queries.
- No recording/DVR commands from guide cells.
- No requirement to build a custom `RenderEPGTimeline` in the first slice; use Flutter slivers/custom painting only where tests prove widgets are too expensive.
- No GPU texture/image/video architecture work.
- No external provider guide data beyond user-provided XMLTV/playlist metadata.

## Feature Packet

**Primary owner agent:** Media Agent
**Review agents:** Framework Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent
**Layer:** Mixed
**Sprint:** V2 IPTV guide hardening
**Parent roadmap:** `.github/issues/COMMUNITY_VOICE_ROADMAP.md`

### Critical Agent Gate

**Problem:** A full program guide must remain responsive with large user-provided playlists and XMLTV files.
**User / actor:** Android TV/mobile user browsing guide data from an authorized BYOC playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Media Agent.
**Reviewing agents:** Framework Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent.
**Impacted modules/files:** `rust/airo_core`, `packages/platform_epg`, `packages/feature_iptv`, `packages/platform_playlist`, `packages/platform_benchmarks`.
**Base branch/worktree:** confirmed from latest `origin/main`: yes.
**Open questions:** Whether the first implementation should be compact current/next plus upcoming windows, or a wider same-day timeline window.
**Decision:** Ready for bounded guide-window contract and UI slice.

### Cross-Agent Contract

**Provider agent:** Framework Agent and Media Agent.
**Consumer agent:** Mobile UI Agent.
**Interface/API:** Guide window query/repository and TV guide view model.
**Input shape:** Channel ids, start/end time, reference `now`, local XMLTV/EPG source, optional search/filter text, optional channel metadata from XMLTV or playlist.
**Output shape:** Ordered guide rows, each with channel metadata and program blocks intersecting the requested time window.
**State changes:** Rebuildable local EPG timetable index/cache only.
**Errors:** Missing EPG, stale EPG, malformed XMLTV, invalid time window, cache miss, source redaction failure.
**Permissions:** Internet only for user-specified guide/media URLs through existing BYOC flow.
**Privacy/redaction:** Raw guide URLs, local paths, credentials, and local IPs must not appear in source refs, logs, or UI diagnostics.
**Persistence:** Local rebuildable timetable index/cache keyed by source and channel id. SQLite is acceptable if it fits the platform data boundary; do not add a database dependency inside presentation code.
**Versioning/migration:** Cache/index can be cleared on schema mismatch and rebuilt from user-derived sources.
**Tests required:** Window query bounds, XMLTV fixture ingestion, stale/unavailable states, TV focus/navigation, no full-guide UI load.

### Timetable Storage Shape

Implementation can choose the repository backing store, but the logical data model must support this shape:

```sql
epg_channels(
  channel_id,
  source_id,
  display_name,
  icon_url,
  raw_data
)

epg_programs(
  channel_id,
  source_id,
  start_time,
  end_time,
  title,
  description,
  raw_data
)
```

Required lookup pattern:

```text
WHERE channel_id IN visible_channel_ids
  AND end_time > window_start
  AND start_time < window_end
ORDER BY channel_order, start_time
```

Program block width in the guide is proportional to duration within the visible window. A 30-minute programme and a 60-minute programme should not render with the same width unless the visible window clips them to the same duration.

## Deterministic Use Cases

### UC-001: Open guide with compact data
**Actor:** Android TV user.
**Preconditions:** Playlist and compact EPG/current-next data exist.
**Trigger:** User opens Guide.
**Happy path:** Visible channel rows render with current/next or bounded program blocks.
**Alternate paths:** Missing EPG shows a clear unavailable state while channel rows remain browsable.
**Failure paths:** Stale cache shows stale state and refresh affordance.
**Data created/updated/deleted:** Local guide snapshot/window cache.
**Privacy expectations:** Source references remain redacted.

### UC-002: Scroll through thousands of channels
**Actor:** Android TV user.
**Preconditions:** Large playlist and guide fixture are available.
**Trigger:** User scrolls vertically through the guide.
**Happy path:** UI requests only visible/near-visible channel rows and keeps focus responsive.
**Alternate paths:** Missing program rows show empty blocks, not errors.
**Failure paths:** Repository timeout shows recoverable guide state.
**Data created/updated/deleted:** Optional local viewport cache.
**Privacy expectations:** No external guide provider is queried.

### UC-003: Move guide time window
**Actor:** Android TV user.
**Preconditions:** Guide is open.
**Trigger:** User moves left/right or jumps forward/backward in time.
**Happy path:** Repository loads only the requested time window and the current-time indicator repaints accurately.
**Alternate paths:** Out-of-range time shows empty future/past state.
**Failure paths:** Invalid window is rejected before repository call.
**Data created/updated/deleted:** Local guide window cache.
**Privacy expectations:** No credentialed source values are displayed.

### UC-004: Programme blocks come from XMLTV timetable
**Actor:** Android TV user browsing Guide.
**Preconditions:** XMLTV contains `<programme channel="sports.one" start="20260715120000 +0000" stop="20260715123000 +0000"><title>Sports Live</title><desc>...</desc></programme>`.
**Trigger:** User opens the guide around 12:00 UTC for `sports.one`.
**Happy path:** The guide row for `sports.one` shows "Sports Live" from 12:00 to 12:30 with width proportional to 30 minutes.
**Alternate paths:** Missing `stop` uses the approved default duration; missing description leaves details empty.
**Failure paths:** Invalid start/stop is skipped and counted in ingest stats.
**Data created/updated/deleted:** Local `epg_programs`-equivalent record.
**Privacy expectations:** Raw source URL and credentials remain redacted.

## Automation Flow

### AUTO-001: Guide window repository
**Given:** XMLTV fixture with multiple channels and overlapping programs.
**When:** A guide query requests a two-hour window for selected channel ids.
**Then:** Only programs intersecting that window are returned in stable order.
**Fixtures:** Local XMLTV fixture and channel id list.
**Mocks/stubs:** Fake clock.
**Assertions:** Window intersection, channel order, current/next flags, stale/unavailable states, duration values.
**Cleanup:** Reset repository.

### AUTO-002: XMLTV timestamp and field parsing
**Given:** XMLTV with `<channel>` and `<programme>` records using `YYYYMMDDHHmmss +ZZZZ` timestamps, titles, descriptions, and icons.
**When:** Native XMLTV ingestion runs.
**Then:** Channel metadata and programme fields are normalized into timetable records.
**Fixtures:** Local XMLTV fixture with timezone offsets and missing optional fields.
**Mocks/stubs:** No network.
**Assertions:** UTC-normalized start/end, channel id mapping, title, description, icon, invalid timestamp skip count.
**Cleanup:** None.

### AUTO-003: Large guide window benchmark
**Given:** Generated XMLTV fixture with thousands of channels and many programs.
**When:** Guide window query runs through native/file-backed path.
**Then:** Query returns bounded rows without loading the entire guide into UI state.
**Fixtures:** Generated XMLTV file.
**Mocks/stubs:** Local file input, no network.
**Assertions:** Row count, program count, duration budget, no full-guide allocation in UI.
**Cleanup:** Delete generated fixture.

### AUTO-004: Batched XMLTV ingestion
**Given:** Generated XMLTV fixture with more than 100,000 programme rows.
**When:** Ingestion runs.
**Then:** Programmes are processed in bounded batches and written to the local timetable cache/index incrementally.
**Fixtures:** Generated XMLTV file.
**Mocks/stubs:** Fake timetable store.
**Assertions:** Batch count, inserted row count, skipped row count, peak batch size, no single giant Flutter list.
**Cleanup:** Delete generated fixture and reset fake store.

### AUTO-005: TV guide focus and rendering
**Given:** Fake guide repository with many rows and program blocks.
**When:** TV guide opens, scrolls vertically, and moves time horizontally.
**Then:** Focus remains visible, text does not overflow, and widget/render count stays bounded.
**Fixtures:** Fake guide rows.
**Mocks/stubs:** Fake repository and fake clock.
**Assertions:** Focus traversal, current-time indicator position, no overflow, bounded rendered rows, block widths proportional to visible duration.
**Cleanup:** None.

### AUTO-006: Source redaction guard
**Given:** Credentialed URL, local path, local IP, and safe redacted source labels.
**When:** Guide source refs are created and diagnostics render.
**Then:** Unsafe values are rejected and safe labels are displayed without secrets.
**Fixtures:** Source strings.
**Mocks/stubs:** None.
**Assertions:** Rejection codes and rendered redacted source.
**Cleanup:** None.

## Acceptance Criteria

- [ ] Guide window query model is defined with channel ids, start/end time, and reference `now`.
- [ ] XMLTV `<channel>` and `<programme>` fields are mapped into channel metadata and timetable programme records.
- [ ] XMLTV timestamps in `YYYYMMDDHHmmss +ZZZZ` form normalize to UTC and display correctly in local/device time.
- [ ] Large XMLTV ingestion can run in bounded batches and write incrementally to the local timetable cache/index.
- [ ] Repository returns bounded guide rows/program blocks and does not expose full XMLTV parsing to Flutter UI.
- [ ] Existing Rust XMLTV/current-next/file-backed boundaries are reused or extended.
- [ ] TV guide UI virtualizes visible channel rows and supports bounded horizontal time movement.
- [ ] Program block widths are proportional to visible programme duration.
- [ ] Current-time indicator updates without rebuilding every guide row.
- [ ] Missing/stale EPG states are explicit and user-safe.
- [ ] Source refs and diagnostics redact URLs, local paths, local IPs, and credentials.
- [ ] Tests cover XMLTV field parsing, timestamp normalization, window bounds, large fixture behavior, focus/navigation, duration-width mapping, and redaction.

## Files to Consider

```text
rust/airo_core/src/api/xmltv.rs
packages/platform_epg/lib/src/compact_epg_models.dart
packages/platform_epg/lib/src/xmltv_compact_epg_repository.dart
packages/platform_epg/lib/src/compact_epg_snapshot_repository.dart
packages/feature_iptv/lib/application/providers/iptv_providers.dart
packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart
packages/feature_iptv/lib/presentation/widgets/tv_channel_grid.dart
packages/platform_benchmarks
```

## Validation

- [ ] Focused `platform_epg` tests pass.
- [ ] Rust XMLTV tests pass if native parsing changes.
- [ ] Focused `feature_iptv` TV widget tests pass if guide UI changes.
- [ ] Host-only benchmark evidence is recorded for large guide fixtures.
- [ ] Broad CI matrix is not required for this slice.

## Release Note Required?

Yes - "Adds a faster windowed program guide for user-provided guide data."

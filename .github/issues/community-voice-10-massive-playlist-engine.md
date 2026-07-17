---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] CV-010: V2 Large Playlist Engine and Virtualized Channel Lists'
labels: 'agent/framework, agent/media, P0, enhancement, community-voice, v2-adopted, sprint-1'
assignees: ''
---

## Agent

**Primary agent:** agent/framework
**Review agents:** agent/media, agent/mobile-ui, agent/security-privacy, agent/qa-automation, agent/release-devex

## Task Details

**Estimate (hours):** 20

**Priority:** P0

**V2 milestone decision:** Adopt now.

## Description

Make very large user-provided M3U/M3U8 playlists usable in Airo TV v2 without blocking the UI, exhausting memory, or breaking the Play Store BYOC posture.

### Community Signal

Users of IPTV players complain that playlists with 7,000 to 30,000+ entries make apps slow, freeze during import, or crash while scrolling. This is directly relevant to v2 because the app only becomes useful after a user imports their own authorized playlist.

### Current State

- `rust/airo_core/src/api/m3u.rs` already contains a Rust M3U parser exposed through Flutter Rust Bridge.
- `rust/airo_core/src/api/xmltv.rs` already contains XMLTV parsing/current-next helpers.
- `packages/platform_playlist_import` has import pipeline and large playlist worker models.
- `packages/feature_iptv` already has TV channel grid/list widgets.
- Existing v2 packet requires BYOC behavior and no bundled playlist sources.

### Current Milestone Scope

1. Extend the existing Rust parser path and worker boundary instead of adding a second parser stack.
2. Add deterministic large-playlist fixtures and benchmarks around 30,000+ entries.
3. Persist/cache parsed records in a rebuildable local format that supports paging/search without keeping the whole playlist in widget state.
4. Ensure IPTV list/grid UI uses stable virtualized rendering and does not decode logos outside the visible window.
5. Record import stats: total entries, skipped rows, malformed rows, parse duration, cache duration.

### Non-Goals

- No bundled or default IPTV playlist.
- No cloud playlist sync.
- No Home Server or Docker cache.
- No external provider catalog.
- No full database migration unless the implementation issue proves the existing cache cannot meet the target.

## Feature Packet

**Primary owner agent:** Framework Agent
**Review agents:** Media Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent
**Layer:** Mixed
**Sprint:** V2 Play Store readiness and IPTV performance hardening
**Parent roadmap:** `.github/issues/COMMUNITY_VOICE_ROADMAP.md`

### Critical Agent Gate

**Problem:** Large user-provided playlists must import, search, and render without UI stalls or memory growth.
**User / actor:** Android TV/mobile user importing an authorized large M3U playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Framework Agent.
**Reviewing agents:** Media Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent.
**Impacted modules/files:** `rust/airo_core`, `packages/platform_playlist_import`, `packages/platform_playlist`, `packages/feature_iptv`, `packages/platform_benchmarks`.
**Base branch/worktree:** confirmed from latest `origin/main`: yes.
**Open questions:** Whether the existing structured cache is sufficient for paging, or whether a small local index is required.
**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Framework Agent.
**Consumer agent:** Media Agent and Mobile UI Agent.
**Interface/API:** Rust M3U parser, playlist import pipeline, paged playlist repository, TV list/grid data providers.
**Input shape:** User-derived M3U content or file path from a validated HTTP(S) playlist fetch.
**Output shape:** Parsed playlist records, parse stats, cache stats, paged channel query results.
**State changes:** Local user-derived playlist cache/index only.
**Errors:** Malformed EXTINF rows, unsupported URL schemes, network fetch failure, cache write failure, cache quota exceeded.
**Permissions:** Internet only for user-specified playlist URL. No broad storage permission.
**Privacy/redaction:** Playlist URLs and credentials must be redacted in stats/logs.
**Persistence:** Rebuildable local cache/index. Clearing app data clears all imported content.
**Versioning/migration:** Existing v2 cache remains readable or safely rebuilds from the user playlist URL.
**Tests required:** Rust parser tests, package import tests, benchmark fixture, widget virtualization test.

## Deterministic Use Cases

### UC-001: Import 30,000 channel playlist
**Actor:** User with an authorized large playlist.
**Preconditions:** Valid HTTPS M3U URL is saved.
**Trigger:** User imports or refreshes playlist.
**Happy path:** Parser returns all valid entries with stats, cache updates locally, UI remains responsive.
**Alternate paths:** Malformed entries are skipped with counts.
**Failure paths:** Fetch failure keeps prior user-derived cache if one exists.
**Data created/updated/deleted:** Local playlist cache/index.
**Privacy expectations:** URL credentials are redacted from diagnostics.

### UC-002: Scroll large channel list
**Actor:** Android TV user.
**Preconditions:** Large playlist has been imported.
**Trigger:** User scrolls rapidly through channel grid/list.
**Happy path:** Rows are paged and virtualized; logo decoding is bounded to visible/near-visible rows.
**Alternate paths:** Missing logos show placeholders.
**Failure paths:** Cache read failure shows recoverable reload state.
**Data created/updated/deleted:** Optional local viewport/cache telemetry.
**Privacy expectations:** No playlist content leaves the device.

## Automation Flow

### AUTO-001: Rust large playlist benchmark
**Given:** Generated 30,000-entry M3U fixture.
**When:** Rust parser benchmark runs.
**Then:** Parser returns deterministic count and duration stats within the accepted budget.
**Fixtures:** Generated local M3U fixture.
**Mocks/stubs:** No network.
**Assertions:** Entry count, skipped count, parse duration, no panic.
**Cleanup:** Delete generated fixture.

### AUTO-002: Package import pipeline
**Given:** Package-local large playlist fixture.
**When:** `platform_playlist_import` imports through the v2 path.
**Then:** Parsed records and stats reach the repository without bundled source usage.
**Fixtures:** Local playlist file.
**Mocks/stubs:** Fake playlist fetcher.
**Assertions:** Output records, stats, cache write calls, URL redaction.
**Cleanup:** Reset local cache.

### AUTO-003: Virtualized TV list
**Given:** Fake repository with 30,000 channel records.
**When:** TV channel list/grid widget builds and scrolls.
**Then:** Visible rows render without text overflow or full-list widget creation.
**Fixtures:** Fake channel records.
**Mocks/stubs:** Fake image provider.
**Assertions:** Stable focus, bounded rendered row count, no overflow.
**Cleanup:** None.

## Acceptance Criteria

- [ ] Existing Rust parser path is used; no second parser stack is introduced.
- [ ] 30,000-entry fixture imports through package-level code without blocking UI code.
- [ ] Import returns stats for parsed, skipped, malformed, and duration values.
- [ ] Playlist data can be queried in pages or bounded chunks.
- [ ] Channel list/grid renders from paged data with stable focus and no full-list widget allocation.
- [ ] Logs and diagnostics redact playlist credentials.
- [ ] Focused tests and benchmarks are added for parser, import pipeline, and virtualized rendering.

## Files to Consider

```text
rust/airo_core/src/api/m3u.rs
rust/airo_core/benches/m3u_parser.rs
packages/platform_playlist_import/lib/src/pipeline/import_pipeline.dart
packages/platform_playlist_import/lib/src/pipeline/large_playlist_worker_models.dart
packages/platform_playlist/lib/src/providers/playlist_provider.dart
packages/feature_iptv/lib/presentation/widgets/channel_list_widget.dart
packages/feature_iptv/lib/presentation/widgets/tv_channel_grid.dart
packages/platform_benchmarks
```

## Validation

- [ ] Rust parser unit tests pass.
- [ ] Rust benchmark produces large fixture evidence.
- [ ] Focused Flutter package tests pass for touched packages.
- [ ] Host-only validation is recorded; broad CI matrix is not required for this slice.

## Release Note Required?

Yes - "Improves large user playlist import and scrolling performance."

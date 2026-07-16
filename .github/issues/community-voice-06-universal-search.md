---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] CV-006: V2 Local IPTV Search and Metadata Index'
labels: 'agent/media, P1, enhancement, community-voice, v2-adopted, sprint-2'
assignees: ''
---

## Agent

**Primary agent:** agent/media
**Review agents:** agent/framework, agent/mobile-ui, agent/security-privacy, agent/qa-automation

## Task Details

**Estimate (hours):** 16

**Priority:** P1

**V2 milestone decision:** Adopt bounded.

## Description

Build fast local search over user-derived IPTV data: playlist channels, groups, EPG programs, favorites, and watch history. This issue intentionally narrows "universal search" to data already available in v2.

### Community Signal

Users want search that is faster than remote-control letter-by-letter browsing. The useful v2 slice is local, private, and works with the playlist the user imported.

### Current State

- `packages/platform_playlist` owns playlist models/repositories.
- `packages/platform_epg` owns compact EPG snapshot models/repositories.
- `packages/platform_favorites` and `packages/platform_history` own local user state.
- `packages/feature_iptv` has IPTV search/voice UI seams.

### Current Milestone Scope

1. Define a local IPTV search index model over playlist rows, groups, EPG titles, favorites, and recent channels.
2. Query only local user-derived data.
3. Rank exact matches, prefix matches, favorites, and recent channels deterministically.
4. Return results quickly enough for TV search-as-you-type.
5. Keep the API compatible with future semantic/AI search, but do not require an LLM.

### Non-Goals

- No YouTube, Plex, Jellyfin, DLNA, podcast, radio, or local network drive search.
- No remote metadata provider.
- No cloud search.
- No semantic LLM parser in this issue.

## Feature Packet

**Primary owner agent:** Media Agent
**Review agents:** Framework Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent
**Layer:** Mixed
**Sprint:** V2 IPTV search hardening
**Parent roadmap:** `.github/issues/COMMUNITY_VOICE_ROADMAP.md`

### Critical Agent Gate

**Problem:** Users need fast search across local IPTV data without external providers or account dependencies.
**User / actor:** Mobile or TV user with an imported playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Media Agent.
**Reviewing agents:** Framework Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent.
**Impacted modules/files:** `packages/platform_playlist`, `packages/platform_epg`, `packages/platform_favorites`, `packages/platform_history`, `packages/feature_iptv`.
**Base branch/worktree:** confirmed from latest `origin/v2`: yes.
**Open questions:** Whether the index is built eagerly after playlist import or lazily on first search.
**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Media Agent.
**Consumer agent:** Mobile UI Agent.
**Interface/API:** Local IPTV search index and query service.
**Input shape:** Query text, optional filters, playlist records, EPG records, favorites, recent channels.
**Output shape:** Ranked local search results with type, title, subtitle, channel/program id, and play/open action.
**State changes:** Rebuildable local search index/cache.
**Errors:** Empty query, empty index, stale playlist id, EPG snapshot missing, timeout.
**Permissions:** No new permissions.
**Privacy/redaction:** Search query and playlist data remain local.
**Persistence:** Local rebuildable index.
**Versioning/migration:** Index can be cleared and rebuilt on schema/version mismatch.
**Tests required:** Ranking, filtering, timeout, empty state, privacy/no-network test.

## Deterministic Use Cases

### UC-001: Search channel by name
**Actor:** TV user.
**Preconditions:** Playlist imported.
**Trigger:** User enters a channel name prefix.
**Happy path:** Matching channels appear before weaker substring matches.
**Alternate paths:** Favorite/recent matches receive deterministic score boost.
**Failure paths:** Empty index shows setup/empty state.
**Data created/updated/deleted:** Optional local search index.
**Privacy expectations:** No network request is made.

### UC-002: Search EPG program
**Actor:** User looking for a live program.
**Preconditions:** Compact EPG snapshot exists.
**Trigger:** User searches a program title.
**Happy path:** Result opens the channel/program context.
**Alternate paths:** Missing EPG falls back to channel search.
**Failure paths:** Stale index rebuilds.
**Data created/updated/deleted:** Local index rebuild timestamp.
**Privacy expectations:** Query stays local.

## Automation Flow

### AUTO-001: Local search ranking
**Given:** Playlist, EPG, favorite, and history fixtures.
**When:** Search runs for exact, prefix, typo-like, and group queries.
**Then:** Results are ranked deterministically.
**Fixtures:** Local records.
**Mocks/stubs:** Fake repositories.
**Assertions:** Result order, result type, no network calls.
**Cleanup:** Reset fake index.

### AUTO-002: Search timeout and empty state
**Given:** Slow fake repository and empty index fixtures.
**When:** Query runs under the UI timeout budget.
**Then:** Service returns timeout/empty states without blocking UI.
**Fixtures:** Fake clock and fake repository.
**Mocks/stubs:** Fake index.
**Assertions:** Timeout state and empty state.
**Cleanup:** Reset fake clock.

### AUTO-003: IPTV search UI
**Given:** Fake search service.
**When:** User types with a TV remote or mobile keyboard.
**Then:** UI displays grouped results without overflow or focus traps.
**Fixtures:** Widget test data.
**Mocks/stubs:** Fake service.
**Assertions:** Focus order, result labels, no overflow.
**Cleanup:** None.

## Acceptance Criteria

- [ ] Search uses only local user-derived playlist, EPG, favorites, and history data.
- [ ] Results include channel and EPG program result types.
- [ ] Ranking is deterministic and covered by tests.
- [ ] Empty/stale index states are handled.
- [ ] No external provider calls are made.
- [ ] UI search state is responsive and TV-focus safe.

## Files to Consider

```text
packages/platform_playlist/lib/src/models/playlist.dart
packages/platform_playlist/lib/src/repositories/playlist_repository.dart
packages/platform_epg/lib/src/compact_epg_models.dart
packages/platform_favorites
packages/platform_history
packages/feature_iptv/lib/application/providers/voice_search_provider.dart
packages/feature_iptv/lib/presentation/widgets/voice_search_overlay.dart
packages/feature_iptv/lib/presentation/widgets/tv_channel_grid_with_voice_search.dart
```

## Validation

- [ ] Focused package tests cover ranking and no-network behavior.
- [ ] Focused widget tests cover TV search UI if touched.
- [ ] Host-only validation is recorded.

## Release Note Required?

Yes - "Adds faster local search across imported playlist and guide data."

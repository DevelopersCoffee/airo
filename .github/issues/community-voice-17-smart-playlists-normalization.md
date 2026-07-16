---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] CV-017: V2 Smart Playlists and Canonical Channels'
labels: 'agent/media, agent/mobile-ui, agent/framework, P1, enhancement, community-voice, v2-adopted, sprint-2'
assignees: ''
---

## Agent

**Primary agent:** agent/media
**Review agents:** agent/framework, agent/mobile-ui, agent/security-privacy, agent/qa-automation, agent/release-devex

## Task Details

**Estimate (hours):** 18

**Priority:** P1

**V2 milestone decision:** Adopt bounded.

## Description

Let users turn a huge BYOC playlist into a small, clean, cable-TV-like experience without editing the raw playlist. Airo should support local Smart Playlists and canonical channel aliases so the user can hide clutter, keep preferred channels, and prepare the foundation for future provider replacement.

### Reddit Product Signal

The provided Reddit analysis says users care more about player experience than provider choice. The recurring requests are:

- English channels only.
- No movie/VOD bloat.
- No adult/radio/shopping clutter.
- Stable cable-TV style UI.
- Provider should be replaceable without rebuilding everything.

The current v2 slice should implement deterministic local rules and channel identity. AI setup and full migration come later.

### Current State

- `packages/platform_channels` owns `IPTVChannel`, URL policy, and channel search index boundaries.
- `packages/platform_playlist_import` parses M3U/M3U8 playlist rows.
- `packages/feature_iptv` renders channel lists/grids and filters.
- CV-010 handles large playlist import and virtualization.
- CV-006 handles local search.

### Current Milestone Scope

1. Define a `SmartPlaylistRule` model for local filters: language, category/group include/exclude, live/VOD/radio type, adult exclusion, minimum resolution label, name contains/excludes, and explicit channel ids.
2. Define a `CanonicalChannel` model with stable local id, display name, aliases, source channel ids/URLs, group/category, language, and quality hints.
3. Normalize obvious provider variants into aliases, such as `ESPN HD`, `ESPN FHD`, `ESPN US`, and `ESPN Backup`, without deleting raw playlist rows.
4. Create a local "My TV" package view that can include explicit picks plus rule-derived channels.
5. Add empty-state diagnostics explaining which rule excluded everything.
6. Keep all rules and aliases local and rebuildable.

### Non-Goals

- No AI/SLM rule generation in this issue.
- No cloud sync of smart playlist rules.
- No automatic provider replacement/migration.
- No provider marketplace or provider recommendations.
- No bundled channel lists or first-party package presets.
- No remote metadata enrichment.

## Feature Packet

**Primary owner agent:** Media Agent
**Review agents:** Framework Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent
**Layer:** Mixed
**Sprint:** V2 IPTV content management hardening
**Parent roadmap:** `.github/issues/COMMUNITY_VOICE_ROADMAP.md`

### Critical Agent Gate

**Problem:** Users with large playlists need a small, clean channel experience without manually editing provider files.
**User / actor:** Android TV/mobile user importing a large authorized playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Media Agent.
**Reviewing agents:** Framework Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent.
**Impacted modules/files:** `packages/platform_channels`, `packages/platform_playlist_import`, `packages/platform_playlist`, `packages/feature_iptv`.
**Base branch/worktree:** confirmed from latest `origin/v2`: yes.
**Open questions:** Exact language and content-type inference available from current M3U metadata.
**Decision:** Ready for deterministic local rules and canonical alias model.

### Cross-Agent Contract

**Provider agent:** Media Agent and Framework Agent.
**Consumer agent:** Mobile UI Agent.
**Interface/API:** Smart playlist rule evaluator, canonical channel normalizer, filtered package repository/provider.
**Input shape:** Imported playlist channels, M3U metadata, local rule set, explicit user selections.
**Output shape:** Filtered channel ids, canonical channel groups, rule diagnostics, package view model.
**State changes:** Local smart playlist rules, explicit channel picks, local canonical alias records.
**Errors:** Invalid rule, empty result, conflicting rules, stale channel id, unsupported metadata field.
**Permissions:** No new permissions.
**Privacy/redaction:** Rules and aliases stay local; raw playlist URLs are redacted.
**Persistence:** Local rebuildable rules and aliases. Clearing app data clears them.
**Versioning/migration:** Rule schema version required; unknown rule fields are ignored with diagnostics.
**Tests required:** Rule evaluation, alias normalization, empty-state diagnostics, TV focus, no-network behavior.

## Deterministic Use Cases

### UC-001: Create "My TV" from explicit channels
**Actor:** User with a large playlist.
**Preconditions:** Playlist contains thousands of channels.
**Trigger:** User selects BBC, ESPN, CNN, HBO, and Discovery for "My TV".
**Happy path:** The package view shows only selected canonical channels.
**Alternate paths:** Missing source channel shows stale alias state and offers removal.
**Failure paths:** Corrupt rule store falls back to raw playlist with warning.
**Data created/updated/deleted:** Local smart playlist and canonical aliases.
**Privacy expectations:** No provider contact beyond playback/import.

### UC-002: Filter English live TV only
**Actor:** User reducing clutter.
**Preconditions:** Playlist contains mixed languages, VOD, radio, adult, and live groups.
**Trigger:** User creates a rule: language English, live only, no VOD, no radio, no adult.
**Happy path:** Filtered view includes only matching live channels.
**Alternate paths:** Unknown language channels can be included or excluded based on rule setting.
**Failure paths:** Empty result shows rule diagnostics.
**Data created/updated/deleted:** Local rule state.
**Privacy expectations:** No model or cloud call.

### UC-003: Normalize duplicate channel variants
**Actor:** User searching for ESPN.
**Preconditions:** Playlist contains `ESPN HD`, `ESPN US`, `ESPN FHD`, and `ESPN Backup`.
**Trigger:** Normalizer runs after import.
**Happy path:** A canonical `ESPN` channel groups aliases while preserving all source rows for fallback/manual selection.
**Alternate paths:** Ambiguous names remain separate and are flagged as low-confidence aliases.
**Failure paths:** No aliasing is safer than destructive merge.
**Data created/updated/deleted:** Local canonical alias records.
**Privacy expectations:** Raw stream URLs are not displayed in alias diagnostics.

## Automation Flow

### AUTO-001: Rule evaluator
**Given:** Fixture playlist with English, Hindi, Spanish, VOD, radio, adult, HD, SD, live, and shopping channels.
**When:** Smart playlist rules run.
**Then:** Included/excluded channel ids match expected results.
**Fixtures:** Package-local channel records.
**Mocks/stubs:** No network.
**Assertions:** Rule result, exclusion reasons, schema version.
**Cleanup:** Reset fake rule store.

### AUTO-002: Canonical alias normalization
**Given:** Fixture variants such as `ESPN HD`, `ESPN US`, `ESPN FHD`, `ESPN Backup`, and unrelated similar names.
**When:** Normalizer runs.
**Then:** Safe variants are grouped, ambiguous variants stay separate, and raw rows are preserved.
**Fixtures:** Channel name/group metadata.
**Mocks/stubs:** No model.
**Assertions:** Canonical id, alias ids, confidence class, no destructive merge.
**Cleanup:** Reset fake alias store.

### AUTO-003: TV package UI
**Given:** Fake filtered package with 60 channels from a 30,000-channel playlist.
**When:** User opens IPTV and switches between raw playlist and "My TV".
**Then:** Focus remains stable and only the filtered set renders in package view.
**Fixtures:** Fake channels and rules.
**Mocks/stubs:** Fake repository.
**Assertions:** Channel count, focus state, empty-state diagnostics, no overflow.
**Cleanup:** None.

## Acceptance Criteria

- [ ] Smart playlist rule model exists with schema version and deterministic evaluation.
- [ ] Canonical channel model exists with aliases and source row preservation.
- [ ] User can create at least one local package view such as "My TV".
- [ ] Rule filters can exclude VOD, radio, adult groups, non-matching language/category/name, and low-resolution labels where metadata exists.
- [ ] Alias normalization groups obvious duplicate variants without destructive merge.
- [ ] Empty package state explains which rules excluded channels.
- [ ] No AI/model/cloud call is required.
- [ ] Tests cover rule evaluation, alias grouping, empty states, and TV UI package switching.

## Files to Consider

```text
packages/platform_channels/lib/src/models/iptv_channel.dart
packages/platform_channels/lib/src/search/channel_search_index.dart
packages/platform_playlist_import/lib/src/m3u_parser_service.dart
packages/platform_playlist_import/lib/src/pipeline/import_pipeline.dart
packages/platform_playlist/lib/src/models/playlist.dart
packages/feature_iptv/lib/application/providers/iptv_providers.dart
packages/feature_iptv/lib/presentation/widgets/channel_list_widget.dart
packages/feature_iptv/lib/presentation/widgets/tv_channel_grid.dart
```

## Validation

- [ ] Focused platform package tests pass.
- [ ] Focused `feature_iptv` widget tests pass if package switching UI changes.
- [ ] Host-only validation is recorded.
- [ ] Broad CI matrix is not required for this slice.

## Release Note Required?

Yes - "Adds local smart playlist filtering to reduce large playlist clutter."

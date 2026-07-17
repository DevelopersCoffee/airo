---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] CV-012: V2 Provider Capability, Health, and Metadata Cache'
labels: 'agent/media, agent/framework, P1, enhancement, community-voice, v2-adopted, sprint-1'
assignees: ''
---

## Agent

**Primary agent:** agent/media
**Review agents:** agent/framework, agent/security-privacy, agent/qa-automation, agent/release-devex, agent/mobile-ui

## Task Details

**Estimate (hours):** 14

**Priority:** P1

**V2 milestone decision:** Adopt bounded.

## Description

Improve user-provided IPTV reliability by caching EPG/logo data locally, enforcing safe URL/header policy, measuring source/provider health, and showing a local capability report. This issue replaces the earlier broad "smart proxy bypass" idea with a Play Store-safe v2 scope.

### Community Signal

Users complain that channel logos, EPG rows, and zapping metadata load slowly or repeatedly. Reddit feedback adds a more strategic pain point: users do not trust providers, and they often cannot tell whether buffering is caused by the provider, CDN, Wi-Fi, ISP, decoder, or app. Some streams also need user-agent/referer handling, but v2 must avoid language or behavior that implies bypassing restrictions.

### Current State

- `packages/platform_epg` has compact EPG snapshot models/repository.
- `packages/platform_player` has cast proxy benchmark models and services.
- `packages/platform_streams` currently has live-edge service boundaries.
- `packages/core_media_routing` already has route health, latency, bandwidth, and reliability scoring primitives.
- `packages/feature_iptv` consumes user-derived channel and EPG data.

### Current Milestone Scope

1. Cache user-derived EPG snapshots and channel logos with size/TTL limits.
2. Add safe stream header policy only for user-specified playlist/media URLs.
3. Build a local provider/source capability report from observed BYOC data: live channels, VOD/series presence if represented in the playlist, EPG availability, multi-audio/subtitle observations, catch-up/timeshift hints where metadata exists.
4. Track provider health locally: API/playlist/EPG fetch latency, manifest response timing, segment download timing where available, buffer event rate, HTTP failure class, last success, last failure.
5. Produce a local health score class and user-safe likely-cause hint for CV-001 diagnostics.
6. Make cache and metrics rebuildable and safe to clear.
7. Redact playlist credentials in cache keys, diagnostics, health reports, and logs.

### Non-Goals

- No Docker/Home Server proxy.
- No CORS/ISP/provider bypass feature.
- No DRM, geo, paywall, or authorization circumvention.
- No broad background crawler.
- No external metadata provider integration.
- No multi-provider automatic failover.
- No provider marketplace, provider recommendation, or provider ranking.
- No AI/SLM diagnosis in this issue.

## Feature Packet

**Primary owner agent:** Media Agent
**Review agents:** Framework Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent, Mobile UI Agent
**Layer:** Mixed
**Sprint:** V2 IPTV performance hardening
**Parent roadmap:** `.github/issues/COMMUNITY_VOICE_ROADMAP.md`

### Critical Agent Gate

**Problem:** EPG/logo metadata should be fast, and provider/source reliability should be explainable without unsafe proxy behavior or extra product surfaces.
**User / actor:** User browsing an authorized BYOC playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Media Agent.
**Reviewing agents:** Framework Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent, Mobile UI Agent.
**Impacted modules/files:** `packages/platform_epg`, `packages/platform_streams`, `packages/platform_player`, `packages/core_media_routing`, `packages/feature_iptv`.
**Base branch/worktree:** confirmed from latest `origin/main`: yes.
**Open questions:** Exact cache quota defaults for low-storage Android TV devices; which stream timing metrics are available from the current playback adapter.
**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Media Agent.
**Consumer agent:** Mobile UI Agent.
**Interface/API:** Metadata cache repository, stream header policy model, provider capability model, provider health model.
**Input shape:** User-derived channel logo URLs, XMLTV/EPG files, stream URLs, playlist import stats, optional user-configured request headers, playback/segment/buffer timing samples where available.
**Output shape:** Cache hit/miss result, sanitized local cache key, provider capability report, provider health snapshot, likely-cause hint.
**State changes:** Local metadata cache, local capability report, and local health snapshot.
**Errors:** Invalid URL, unsupported scheme, cache quota exceeded, fetch timeout, HTTP error, malformed XMLTV.
**Permissions:** Internet for user-specified metadata/media URLs only.
**Privacy/redaction:** Cache keys must not store raw credentials. Logs redact query strings and credentials.
**Persistence:** Local rebuildable cache with TTL/quota.
**Versioning/migration:** Cache schema can be cleared on version mismatch.
**Tests required:** Cache key redaction, TTL/quota behavior, capability detection, health-score mapping, likely-cause mapping, EPG snapshot compatibility.

### Provider Capability Report

The capability report should be local and observational. It should not call provider APIs beyond the user-specified source path unless a future issue approves an explicit provider integration.

Minimum fields:

```text
source_id
observed_live_tv
observed_vod
observed_series
observed_epg
observed_catchup_hint
observed_multi_audio
observed_subtitles
playlist_entry_count
epg_programme_count
last_observed_at
```

### Provider Health Signals

Minimum local signals:

```text
playlist_fetch_latency
epg_fetch_latency
manifest_response_latency
segment_download_latency
buffer_event_count
http_failure_class
last_success_at
last_failure_at
health_score_class
likely_cause_hint
```

Health score must be explanatory, not a public provider ranking.

## Deterministic Use Cases

### UC-001: Logo cache hit
**Actor:** User scrolling channel list.
**Preconditions:** Channel logo was previously fetched from user playlist metadata.
**Trigger:** Channel row becomes visible.
**Happy path:** Logo is served from local cache or bounded image cache without refetching.
**Alternate paths:** Missing logo uses placeholder.
**Failure paths:** Corrupt cache entry is evicted and retried later.
**Data created/updated/deleted:** Local logo cache entry.
**Privacy expectations:** Raw credentialed URL is not used as a visible cache key.

### UC-002: EPG snapshot refresh
**Actor:** User opening TV guide.
**Preconditions:** User has an XMLTV/EPG URL or file from playlist metadata.
**Trigger:** EPG cache is stale.
**Happy path:** Refresh runs through existing EPG boundaries and writes compact snapshot.
**Alternate paths:** Existing non-expired snapshot is reused.
**Failure paths:** Fetch or parse failure leaves prior snapshot if available.
**Data created/updated/deleted:** Local compact EPG snapshot.
**Privacy expectations:** EPG source URL is redacted in diagnostics.

### UC-003: Provider capability report
**Actor:** User after importing a playlist.
**Preconditions:** Playlist import and optional EPG import have completed.
**Trigger:** User opens source details or diagnostics.
**Happy path:** Airo shows observed capabilities such as Live TV, EPG, VOD/series presence, multi-audio/subtitle observations, and entry counts.
**Alternate paths:** Unknown capabilities are shown as unknown, not unsupported.
**Failure paths:** Malformed playlist/EPG shows import stats and safe error class.
**Data created/updated/deleted:** Local capability report.
**Privacy expectations:** Source URL and credentials are redacted.

### UC-004: Health report explains likely cause
**Actor:** User experiencing buffering.
**Preconditions:** Playback produced buffer events and timing samples.
**Trigger:** User opens diagnostics or playback fails.
**Happy path:** Airo shows likely cause such as high provider/CDN latency, network offline, authorization failure, or decoder unsupported.
**Alternate paths:** Too few samples shows "not enough data".
**Failure paths:** Conflicting signals show multiple possible causes without overclaiming.
**Data created/updated/deleted:** Local health snapshot.
**Privacy expectations:** No raw stream URL is shown.

## Automation Flow

### AUTO-001: Cache key redaction
**Given:** Credentialed playlist/logo/EPG URLs.
**When:** Cache key builder runs.
**Then:** Keys are stable but do not include username, password, or raw query string.
**Fixtures:** URL strings.
**Mocks/stubs:** None.
**Assertions:** Key equality where expected, no secret substrings.
**Cleanup:** None.

### AUTO-002: Cache TTL and quota
**Given:** Fake cache clock and fake storage quota.
**When:** Cache entries are read, expired, and evicted.
**Then:** Repository returns hit/miss/evicted states deterministically.
**Fixtures:** Fake metadata entries.
**Mocks/stubs:** Fake clock and fake storage.
**Assertions:** TTL handling, quota eviction, corrupt entry recovery.
**Cleanup:** Reset fake storage.

### AUTO-003: Provider health state
**Given:** Fake stream/metadata request results.
**When:** Health mapper records success, timeout, 401, 404, 429, and 5xx.
**Then:** It emits stable health states for diagnostics and UI.
**Fixtures:** Fake request results.
**Mocks/stubs:** Fake network client.
**Assertions:** Health code, retry hint, timestamp.
**Cleanup:** None.

### AUTO-004: Capability report
**Given:** Playlist and EPG import stats plus fake track observations.
**When:** Capability report builder runs.
**Then:** It emits observed/unknown capability flags without provider-specific API calls.
**Fixtures:** Fake playlist rows, fake EPG stats, fake playback track samples.
**Mocks/stubs:** No network.
**Assertions:** Live/VOD/series/EPG/multi-audio/subtitle flags, counts, unknown handling, redaction.
**Cleanup:** Reset fake report store.

### AUTO-005: Likely-cause mapping
**Given:** Fake health samples for provider timeout, Wi-Fi/network offline, high segment latency, decoder unsupported, and too few samples.
**When:** Diagnostic mapper runs.
**Then:** It emits user-safe likely-cause hints without overclaiming.
**Fixtures:** Fake metric samples.
**Mocks/stubs:** Fake clock.
**Assertions:** Cause class, confidence class, display copy, no credential leakage.
**Cleanup:** Reset fake metric store.

## Acceptance Criteria

- [ ] Metadata cache stores user-derived EPG/logo data with TTL and quota limits.
- [ ] Cache keys and diagnostics redact credentials and query strings.
- [ ] Existing compact EPG snapshot path is reused where possible.
- [ ] Stream/header policy accepts only safe, user-derived HTTP(S) targets.
- [ ] Provider capability report is built from observed local playlist/EPG/playback data.
- [ ] Provider health snapshot includes latency/failure/buffer signals where available.
- [ ] Likely-cause hints are available to CV-001 playback diagnostics.
- [ ] Health score is local and explanatory, not provider ranking or recommendation.
- [ ] Tests cover cache redaction, TTL/quota, corrupt entry recovery, capability detection, health mapping, and likely-cause mapping.

## Files to Consider

```text
packages/platform_epg/lib/src/compact_epg_snapshot_repository.dart
packages/platform_epg/lib/src/xmltv_compact_epg_repository.dart
packages/platform_streams/lib/platform_streams.dart
packages/core_media_routing/lib/src/media_route_scoring_models.dart
packages/platform_player/lib/src/models/cast_proxy_benchmark_models.dart
packages/platform_player/lib/src/services/cast_http_proxy.dart
packages/feature_iptv/lib/presentation/widgets/channel_list_widget.dart
packages/feature_iptv/lib/presentation/widgets/tv_channel_grid.dart
```

## Validation

- [ ] Focused package tests pass for touched packages.
- [ ] Host-only cache tests use fake storage/network.
- [ ] No broad CI matrix required.

## Release Note Required?

Yes - "Improves EPG and logo loading with local, privacy-safe metadata caching."

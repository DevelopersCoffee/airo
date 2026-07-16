---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] CV-016: V2 Playback Track Selection and VOD Timeline'
labels: 'agent/media, agent/mobile-ui, P1, enhancement, community-voice, v2-adopted, sprint-2'
assignees: ''
---

## Agent

**Primary agent:** agent/media
**Review agents:** agent/mobile-ui, agent/framework, agent/security-privacy, agent/qa-automation, agent/release-devex

## Task Details

**Estimate (hours):** 14

**Priority:** P1

**V2 milestone decision:** Adopt bounded.

## Description

Expose existing playback-engine capabilities for audio tracks, subtitle tracks, VOD duration, and seek controls in Airo TV v2. This issue absorbs repeated NodeCast TV issue lessons without taking on server transcoding or a native playback rewrite.

### NodeCast Issue Signal

- #140, #122, and #72: users cannot change audio language or subtitles during playback.
- #143 and #74: VOD items, especially recordings of live events, need visible total duration and reliable seek/timeline behavior.
- #129: stream opening can accidentally consume more than one provider connection, so playback controls must not create duplicate sessions.

### Current State

- `packages/platform_player` already defines `AiroPlaybackTrackKind`, `AiroPlaybackTrackOption`, `selectTrack`, `seek`, and playback state models.
- `packages/feature_iptv` has player widgets and TV player controls.
- `packages/platform_streams` has `StreamingState.duration`, `position`, and live/DVR state concepts.

### Current Milestone Scope

1. Show available audio and subtitle tracks in playback controls when the engine reports them.
2. Let users switch audio/subtitle tracks through `AiroPlaybackEngine.selectTrack`.
3. Persist local preferred audio/subtitle language where an existing settings/preference boundary exists.
4. Show total duration and valid seek state for VOD/progressive content.
5. Guard seek controls for live streams, unknown duration, and unseekable streams.
6. Ensure track selection, seek, and channel changes do not create duplicate active playback sessions.

### Non-Goals

- No online subtitle downloader.
- No server-side transcoding, FFmpeg, VAAPI/QSV/NVENC, or hardware encoder work.
- No native playback engine rewrite.
- No DRM/protected playback support.
- No recording/download feature.

## Feature Packet

**Primary owner agent:** Media Agent
**Review agents:** Mobile UI Agent, Framework Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent
**Layer:** Mixed
**Sprint:** V2 playback usability hardening
**Parent roadmap:** `.github/issues/COMMUNITY_VOICE_ROADMAP.md`

### Critical Agent Gate

**Problem:** Users need predictable audio/subtitle selection and VOD timeline controls without duplicate stream sessions.
**User / actor:** User watching VOD or live content from an authorized BYOC playlist.
**Framework or application layer:** Mixed.
**Owning agent:** Media Agent.
**Reviewing agents:** Mobile UI Agent, Framework Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent.
**Impacted modules/files:** `packages/platform_player`, `packages/platform_streams`, `packages/feature_iptv`.
**Base branch/worktree:** confirmed from latest `origin/v2`: yes.
**Open questions:** Which current playback adapter can report track metadata and seekability on each platform.
**Decision:** Ready for bounded controls and fake-engine tests.

### Cross-Agent Contract

**Provider agent:** Media Agent.
**Consumer agent:** Mobile UI Agent.
**Interface/API:** Playback state, track list, selected track ids, seek/duration state, active session lifecycle.
**Input shape:** Available tracks, selected track id, position, duration, seek request, stream kind.
**Output shape:** Updated selected track, seek result, duration label, unavailable-control state.
**State changes:** Session playback state and optional local track-language preference.
**Errors:** Track unavailable, seek unsupported, duration unknown, operation rejected, duplicate session warning.
**Permissions:** No new permissions.
**Privacy/redaction:** Playback diagnostics never expose raw media URLs or credentials.
**Persistence:** Local language/track preference only if an existing preference store is reused.
**Versioning/migration:** Missing preference defaults to engine-selected track.
**Tests required:** Track list UI, selected track persistence, seek bounds, live/unseekable guard, duplicate session prevention.

## Deterministic Use Cases

### UC-001: User switches audio language
**Actor:** User watching VOD with multiple audio tracks.
**Preconditions:** Playback engine reports English and French audio tracks.
**Trigger:** User selects French.
**Happy path:** UI calls `selectTrack(audio, french)` and selected state updates.
**Alternate paths:** Preferred language auto-selects when available.
**Failure paths:** Missing track reports `trackUnavailable` without crashing.
**Data created/updated/deleted:** Optional local audio language preference.
**Privacy expectations:** Track labels can display; media URL stays redacted.

### UC-002: User enables subtitles
**Actor:** User watching content with embedded subtitle tracks.
**Preconditions:** Playback engine reports subtitle tracks.
**Trigger:** User selects a subtitle track or disables subtitles.
**Happy path:** UI calls `selectTrack(subtitle, trackId)` or disables selection through the approved engine contract.
**Alternate paths:** Missing subtitles hide/disable subtitle controls.
**Failure paths:** Engine rejection shows user-safe message.
**Data created/updated/deleted:** Optional local subtitle preference.
**Privacy expectations:** Preference stays local.

### UC-003: VOD timeline seek
**Actor:** User watching a movie or recorded event.
**Preconditions:** Playback state has known duration and seekable position.
**Trigger:** User scrubs or jumps forward/backward.
**Happy path:** Seek stays within `[0, duration]` and UI shows total duration.
**Alternate paths:** Live stream shows live/behind-live controls instead of VOD scrubber.
**Failure paths:** Unknown duration disables scrubber and shows no generic error.
**Data created/updated/deleted:** Playback position state.
**Privacy expectations:** No URL logging.

## Automation Flow

### AUTO-001: Track selection controls
**Given:** Fake playback engine with audio and subtitle tracks.
**When:** User opens controls and changes selected tracks.
**Then:** The engine receives the expected `selectTrack` calls and UI updates selected labels.
**Fixtures:** Fake track list.
**Mocks/stubs:** `FakeAiroPlaybackEngine`.
**Assertions:** Selected track ids, disabled unavailable tracks, user-safe error.
**Cleanup:** Dispose fake engine.

### AUTO-002: VOD seek bounds
**Given:** Fake VOD state with 90-minute duration.
**When:** User seeks before zero, inside range, and beyond duration.
**Then:** Request is clamped or rejected by contract and UI remains stable.
**Fixtures:** Fake VOD state.
**Mocks/stubs:** Fake playback engine.
**Assertions:** Seek position, duration label, disabled state for unknown duration.
**Cleanup:** Dispose fake engine.

### AUTO-003: Single session under control actions
**Given:** Fake playback surface.
**When:** User changes track, seeks, then switches channel.
**Then:** Track/seek actions do not open new sessions; channel switch closes prior session before opening next.
**Fixtures:** Fake channels and playback requests.
**Mocks/stubs:** Fake session tracker.
**Assertions:** Active session count, open/stop order, no duplicate stream open.
**Cleanup:** Dispose fake engine.

## Acceptance Criteria

- [ ] Audio track choices render when available and can be selected.
- [ ] Subtitle track choices render when available and can be selected/disabled.
- [ ] VOD total duration is visible when known.
- [ ] Seek controls are bounded for VOD and disabled or replaced for live/unknown-duration streams.
- [ ] Track/seek controls do not create duplicate playback sessions.
- [ ] User-safe errors appear for unavailable tracks or unsupported seek.
- [ ] Focused package/widget tests cover track selection, VOD seek, and session lifecycle.

## Files to Consider

```text
packages/platform_player/lib/src/models/playback_engine_models.dart
packages/platform_player/lib/src/services/airo_playback_engine.dart
packages/platform_player/lib/src/services/fake_playback_engine.dart
packages/platform_streams/lib/src/services/live_edge_detector.dart
packages/platform_player/lib/src/models/streaming_state.dart
packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart
packages/feature_iptv/lib/presentation/widgets/tv_player_controls.dart
```

## Validation

- [ ] Focused `platform_player` tests pass.
- [ ] Focused `feature_iptv` widget tests pass if controls change.
- [ ] Host-only validation is recorded.
- [ ] Broad CI matrix is not required for this slice.

## Release Note Required?

Yes - "Adds audio/subtitle track controls and clearer VOD timeline behavior."

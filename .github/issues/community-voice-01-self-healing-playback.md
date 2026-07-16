---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] CV-001: V2 Playback Diagnostics and Bounded Recovery'
labels: 'agent/media, P0, enhancement, community-voice, v2-adopted, sprint-1'
assignees: ''
---

## Agent

**Primary agent:** agent/media
**Review agents:** agent/framework, agent/mobile-ui, agent/security-privacy, agent/qa-automation, agent/release-devex

## Task Details

**Estimate (hours):** 18

**Priority:** P0

**V2 milestone decision:** Adopt bounded.

## Description

Add playback diagnostics and safe retry behavior for user-provided IPTV streams. The goal is to replace generic black-screen/failure states with actionable local diagnostics and bounded recovery that does not require a playback-engine rewrite.

### Community Signal

Competitor reviews repeatedly mention buffering, frozen channels, unexplained failures, audio/video drops, and users not knowing whether the problem is their device, Wi-Fi, or provider.

NodeCast TV issue review adds three concrete failure classes to guard against:

- Streams that start and then stop after a short time.
- A single channel opening more than one provider connection.
- Hardware/transcode-specific failures that users experience as black screens.

### Current State

- `packages/platform_player` exposes playback engine models and services.
- `packages/feature_iptv` owns IPTV player UI and TV controls.
- Existing errors are too high-level for user-visible troubleshooting.

### Current Milestone Scope

1. Define a small playback diagnostic model and error taxonomy.
2. Add retry policy for transient network/player failures with max attempts and backoff.
3. Add session/connection lifecycle checks so channel switches, retries, and player disposal do not leave duplicate active sessions.
4. Surface diagnostics in UI as concise user-facing states and optional debug overlay.
5. Redact playlist credentials from any diagnostic output.
6. Keep recovery inside existing playback engine/service boundaries.

### Non-Goals

- No VLC/ExoPlayer/AVPlayer dynamic switching in this issue.
- No mirror discovery unless alternate URLs already exist in the user playlist.
- No full Rust FFI playback controller.
- No claim to fix provider outages, DRM, paywall, geo, or ISP restrictions.

## Feature Packet

**Primary owner agent:** Media Agent
**Review agents:** Framework Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent
**Layer:** Mixed
**Sprint:** V2 Play Store readiness and IPTV reliability hardening
**Parent roadmap:** `.github/issues/COMMUNITY_VOICE_ROADMAP.md`

### Critical Agent Gate

**Problem:** Users need clear playback failure causes and bounded automatic recovery for transient stream failures.
**User / actor:** User watching an authorized BYOC playlist channel.
**Framework or application layer:** Mixed.
**Owning agent:** Media Agent.
**Reviewing agents:** Framework Agent, Mobile UI Agent, Security and Privacy Agent, QA Automation Agent, Release and DevEx Agent.
**Impacted modules/files:** `packages/platform_player`, `packages/platform_streams`, `packages/feature_iptv`.
**Base branch/worktree:** confirmed from latest `origin/v2`: yes.
**Open questions:** Exact engine-specific error codes available from current platform player adapters.
**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Media Agent.
**Consumer agent:** Mobile UI Agent.
**Interface/API:** Playback diagnostic model, retry decision model, player state stream.
**Input shape:** Player events, stream URL metadata, HTTP status class, buffering state, retry count, session id, open/close events.
**Output shape:** Diagnostic state, user-safe error code, retry action, overlay snapshot, active session count.
**State changes:** Local in-memory playback session state; optional local redacted diagnostic event.
**Errors:** DNS/network timeout, HTTP 401/403/404/429/5xx, unsupported codec, player initialization failure, stalled buffer.
**Permissions:** No new permissions.
**Privacy/redaction:** Strip credentials and query strings from displayed/logged URLs.
**Persistence:** Diagnostics are session scoped unless an explicit local diagnostic export feature is added later.
**Versioning/migration:** No migration.
**Tests required:** Diagnostic mapping tests, retry state-machine tests, player UI state tests.

## Deterministic Use Cases

### UC-001: Transient network timeout recovers
**Actor:** IPTV user.
**Preconditions:** Playback started from a valid user playlist URL.
**Trigger:** Fake player emits timeout/stall.
**Happy path:** Retry policy attempts reconnect within max attempts and updates UI to "Reconnecting".
**Alternate paths:** User cancels retry by changing channel.
**Failure paths:** Max attempts reached shows a final diagnostic state.
**Data created/updated/deleted:** Session diagnostic state.
**Privacy expectations:** No URL credentials are shown.

### UC-002: Provider authorization error does not loop
**Actor:** IPTV user.
**Preconditions:** Stream returns 401 or 403.
**Trigger:** Player reports authorization failure.
**Happy path:** App shows provider/auth diagnostic and does not retry endlessly.
**Alternate paths:** User refreshes playlist manually.
**Failure paths:** None.
**Data created/updated/deleted:** Session diagnostic state.
**Privacy expectations:** Provider URL is redacted.

### UC-003: Channel switch does not leak connections
**Actor:** IPTV user changing channels.
**Preconditions:** Channel A is playing.
**Trigger:** User switches to Channel B or retry opens a replacement stream.
**Happy path:** Channel A session is stopped/disposed before Channel B becomes active, leaving one active playback session.
**Alternate paths:** Failed disposal is surfaced as a diagnostic detail.
**Failure paths:** Duplicate session detection emits a warning and closes the older session.
**Data created/updated/deleted:** Session lifecycle state.
**Privacy expectations:** Session diagnostics do not include raw URLs.

## Automation Flow

### AUTO-001: Diagnostic mapping
**Given:** Fake playback errors for timeout, 401, 404, 429, 5xx, and unsupported codec.
**When:** Diagnostic mapper runs.
**Then:** Each error maps to a stable user-safe diagnostic code.
**Fixtures:** Fake player events.
**Mocks/stubs:** Fake playback engine.
**Assertions:** Code, severity, retry eligibility, redacted message.
**Cleanup:** None.

### AUTO-002: Retry policy
**Given:** A transient timeout sequence.
**When:** Retry state machine advances.
**Then:** It retries up to max attempts with backoff, then stops.
**Fixtures:** Fake clock.
**Mocks/stubs:** Fake player controller.
**Assertions:** Attempt count, delay sequence, terminal state.
**Cleanup:** Reset fake clock.

### AUTO-003: IPTV player UI state
**Given:** Fake diagnostic stream.
**When:** UI receives buffering, reconnecting, and final failure states.
**Then:** It shows concise TV-safe copy and no text overflow.
**Fixtures:** Widget test channel.
**Mocks/stubs:** Fake playback service.
**Assertions:** Visible labels, focus safety, no overflow.
**Cleanup:** None.

### AUTO-004: Single active session lifecycle
**Given:** Fake playback engine with observable open/stop/dispose calls.
**When:** User changes channels, retries, and then stops playback.
**Then:** The service does not keep two active sessions for the same playback surface.
**Fixtures:** Fake channels and fake engine.
**Mocks/stubs:** Fake session tracker.
**Assertions:** Open count, stop/dispose order, active session count, redacted diagnostic event.
**Cleanup:** Dispose fake engine.

## Acceptance Criteria

- [ ] Diagnostic model includes stable codes for network, provider, playlist, and decoder/player failures.
- [ ] Retry policy handles transient network stalls with a bounded max attempt count.
- [ ] Non-retryable provider/auth failures do not loop.
- [ ] Channel switch/retry lifecycle leaves only one active playback session per surface.
- [ ] Short-run stream stops map to a stable diagnostic state instead of a generic black screen.
- [ ] UI presents clear recovery/failure states and optional diagnostic details.
- [ ] All displayed/logged URLs redact credentials and query strings.
- [ ] Focused tests cover mapping, retry policy, and UI states.

## Files to Consider

```text
packages/platform_player/lib/src/models/playback_engine_models.dart
packages/platform_player/lib/src/models/streaming_state.dart
packages/platform_player/lib/src/services/airo_playback_engine.dart
packages/platform_player/lib/src/services/iptv_streaming_service.dart
packages/platform_streams/lib/src/services/live_edge_detector.dart
packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart
packages/feature_iptv/lib/presentation/widgets/tv_player_controls.dart
```

## Validation

- [ ] Focused `platform_player` tests pass.
- [ ] Focused `feature_iptv` widget tests pass if UI changes.
- [ ] Host-only validation is recorded.

## Release Note Required?

Yes - "Adds clearer playback diagnostics and bounded reconnect behavior for user-provided streams."

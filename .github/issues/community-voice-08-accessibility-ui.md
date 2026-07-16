---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] CV-008: V2 TV Accessibility, Surf Mode, and Captions'
labels: 'agent/mobile-ui, agent/media, P1, enhancement, community-voice, v2-adopted, sprint-2'
assignees: ''
---

## Agent

**Primary agent:** agent/mobile-ui
**Review agents:** agent/media, agent/framework, agent/qa-automation, agent/security-privacy

## Task Details

**Estimate (hours):** 16

**Priority:** P1

**V2 milestone decision:** Adopt bounded.

## Description

Improve Airo TV's living-room usability with TV font modes, D-pad surf mode, persistent caption preferences, and focus-safe controls. This issue keeps accessibility local and avoids online subtitle-provider scope.

### Community Signal

IPTV users complain about small text, awkward remote navigation, and captions that must be re-enabled after every stream change.

### Current State

- `packages/core_ui` owns shared UI primitives.
- `packages/feature_iptv` has TV screen, TV channel grid, TV controls, voice search overlay, and video player widgets.
- `packages/platform_player` exposes playback engine models and fake/unavailable engines.

### Current Milestone Scope

1. Add TV font/accessibility mode state that can be consumed by IPTV UI.
2. Add D-pad surf mode: Up/Down changes channel while playback remains primary.
3. Persist caption language/enabled preference locally and reapply to streams when tracks are available.
4. Add tests for focus traversal, overflow, and preference persistence.

### Non-Goals

- No online subtitle downloader or OpenSubtitles integration.
- No new account/profile accessibility sync.
- No app-wide redesign outside the touched TV/IPTV surfaces.
- No broad storage permission for subtitle files.

## Feature Packet

**Primary owner agent:** Mobile UI Agent
**Review agents:** Media Agent, Framework Agent, QA Automation Agent, Security and Privacy Agent
**Layer:** Mixed
**Sprint:** V2 TV usability hardening
**Parent roadmap:** `.github/issues/COMMUNITY_VOICE_ROADMAP.md`

### Critical Agent Gate

**Problem:** TV users need readable UI, reliable remote navigation, and captions that persist across stream changes.
**User / actor:** Android TV user watching user-provided playlist channels.
**Framework or application layer:** Mixed.
**Owning agent:** Mobile UI Agent.
**Reviewing agents:** Media Agent, Framework Agent, QA Automation Agent, Security and Privacy Agent.
**Impacted modules/files:** `packages/core_ui`, `packages/feature_iptv`, `packages/platform_player`.
**Base branch/worktree:** confirmed from latest `origin/v2`: yes.
**Open questions:** Whether caption preference already has an app settings store to reuse.
**Decision:** Ready.

### Cross-Agent Contract

**Provider agent:** Mobile UI Agent and Media Agent.
**Consumer agent:** IPTV UI and playback controls.
**Interface/API:** TV accessibility preference model, surf-mode controller, caption preference model.
**Input shape:** D-pad key events, user-selected font mode, channel list, available caption/audio tracks.
**Output shape:** Focus movement, channel selection intent, caption preference application result.
**State changes:** Local UI preference and caption preference.
**Errors:** No channel in direction, unavailable caption track, preference write failure.
**Permissions:** No new permissions.
**Privacy/redaction:** Preferences stay local.
**Persistence:** Local preferences.
**Versioning/migration:** Missing preference defaults to standard mode and captions off/unset.
**Tests required:** Widget focus tests, overflow checks, surf-mode state tests, caption preference tests.

## Deterministic Use Cases

### UC-001: Large TV font mode
**Actor:** Android TV user.
**Preconditions:** IPTV screen is open.
**Trigger:** User selects Large or Extra Large TV font mode.
**Happy path:** Channel grid/list/control text scales without overflow and focus remains visible.
**Alternate paths:** Very long channel names truncate gracefully.
**Failure paths:** Preference write failure leaves current mode and reports non-blocking error.
**Data created/updated/deleted:** Local accessibility preference.
**Privacy expectations:** Preference stays local.

### UC-002: D-pad surf mode
**Actor:** Android TV user watching a channel.
**Preconditions:** Channel list has previous/next channels.
**Trigger:** User presses D-pad Up or Down.
**Happy path:** Selection moves to adjacent channel and shows compact info banner without trapping focus.
**Alternate paths:** Boundary channel keeps current channel and shows no-op feedback.
**Failure paths:** Playback failure routes to CV-001 diagnostics.
**Data created/updated/deleted:** Recent channel/history state through existing providers.
**Privacy expectations:** No new network call beyond playback.

### UC-003: Caption preference persists
**Actor:** User who prefers captions.
**Preconditions:** Caption preference is enabled and stream has matching track.
**Trigger:** User changes channel.
**Happy path:** Preferred caption track is enabled automatically when available.
**Alternate paths:** Missing track leaves captions off and keeps preference.
**Failure paths:** Player error emits diagnostic state.
**Data created/updated/deleted:** Local caption preference.
**Privacy expectations:** Preference stays local.

## Automation Flow

### AUTO-001: Font mode widget test
**Given:** IPTV TV widgets with long channel names.
**When:** Standard, Large, and Extra Large modes render.
**Then:** Text does not overflow and focus highlight remains visible.
**Fixtures:** Fake channel list.
**Mocks/stubs:** Fake accessibility preference.
**Assertions:** No overflow, visible focus, stable layout.
**Cleanup:** None.

### AUTO-002: Surf mode key handling
**Given:** Fake channel list and fake playback controller.
**When:** D-pad Up/Down events are dispatched.
**Then:** Adjacent channel intent is emitted and boundary cases are safe.
**Fixtures:** Fake channels.
**Mocks/stubs:** Fake controller.
**Assertions:** Selected channel id, no focus trap.
**Cleanup:** Reset fake controller.

### AUTO-003: Caption preference
**Given:** Fake playback engine with caption tracks.
**When:** User toggles captions and changes channel.
**Then:** Preferred caption language is applied when available.
**Fixtures:** Fake track list.
**Mocks/stubs:** Fake playback engine.
**Assertions:** Preference write, track selection call, fallback behavior.
**Cleanup:** Reset preferences.

## Acceptance Criteria

- [ ] TV font mode state is defined and consumed by IPTV TV UI.
- [ ] Long text remains readable without overflow in TV channel/control surfaces.
- [ ] D-pad surf mode changes channels predictably and preserves focus safety.
- [ ] Caption preference persists locally and is applied when tracks are available.
- [ ] No online subtitle provider is added.
- [ ] Widget/unit tests cover font modes, surf mode, and caption preference.

## Files to Consider

```text
packages/core_ui/lib/src/theme
packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart
packages/feature_iptv/lib/presentation/widgets/tv_channel_grid.dart
packages/feature_iptv/lib/presentation/widgets/tv_player_controls.dart
packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart
packages/platform_player/lib/src/models/playback_engine_models.dart
packages/platform_player/lib/src/services/airo_playback_engine.dart
```

## Validation

- [ ] Focused widget tests pass for touched TV UI.
- [ ] Focused `platform_player` tests pass if caption logic changes.
- [ ] Host-only validation is recorded.

## Release Note Required?

Yes - "Improves TV readability, remote channel surfing, and caption preference handling."

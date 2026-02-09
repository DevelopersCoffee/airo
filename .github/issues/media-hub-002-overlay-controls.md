---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-002: Player Overlay Controls'
labels: 'agent/mobile-ui, P0, enhancement, media-hub, sprint-1'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 8

**Priority:** P0

## Description

Implement overlay controls that appear on tap/hover with auto-hide behavior.

### Current State
- Static controls visible at all times
- No auto-hide behavior
- Controls cluttering video playback

### Proposed Enhancement
1. Controls visible on tap (mobile) or hover (web)
2. Controls fade in/out with 300ms animation
3. Auto-hide after 4 seconds of inactivity
4. Actions: Play/Pause (center), Favorite, Fullscreen, Settings
5. Timer resets on any interaction

### User Value
- Clean viewing experience
- Controls available when needed
- Platform-appropriate interactions

## Acceptance Criteria
- [ ] Controls visible on tap (mobile) or hover (web)
- [ ] Controls fade in/out with 300ms animation
- [ ] Auto-hide after 4 seconds of inactivity
- [ ] Play/Pause button centered
- [ ] Favorite, Fullscreen, Settings buttons in appropriate positions
- [ ] Timer resets on any interaction

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/player_overlay_controls.dart (new)
app/lib/features/media_hub/presentation/widgets/collapsible_player_container.dart (modify)
app/test/features/media_hub/presentation/widgets/player_overlay_controls_test.dart (new)
```

## Dependencies
- MH-001: Collapsible Hero Player Container

## Release Note Required?
no


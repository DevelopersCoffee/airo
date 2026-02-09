---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-006: Segmented Mode Switch'
labels: 'agent/mobile-ui, P0, enhancement, media-hub, sprint-2'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 8

**Priority:** P0

## Description

Replace tab bar with segmented control for Music/TV mode switching.

### Current State
- Tab bar with Music/TV tabs in `media_hub_screen.dart`
- Mode switch feels heavy and slow
- No visual indication of current mode in player area

### Proposed Enhancement
1. Segmented control with icons + labels: 🎵 Music, 📺 TV
2. Strong active indicator (underline + primary color)
3. Smooth transition animation (300ms)
4. Mode switch does NOT stop playback unless source incompatible
5. State persists via Riverpod provider

### User Value
- Instant, obvious mode switching
- Continuity of playback when switching modes
- Clear visual feedback

## Acceptance Criteria
- [ ] Segmented control with icons + labels: 🎵 Music, 📺 TV
- [ ] Strong active indicator (underline + primary color)
- [ ] Smooth transition animation (300ms)
- [ ] Mode switch does NOT stop playback unless source incompatible
- [ ] State persists via `selectedMediaModeProvider`
- [ ] Category chips update based on mode

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/media_mode_switch.dart (new)
app/lib/features/media_hub/presentation/screens/media_hub_screen.dart (modify)
app/lib/features/media_hub/application/providers/media_hub_providers.dart (exists)
app/test/features/media_hub/presentation/widgets/media_mode_switch_test.dart (new)
```

## Dependencies
- None

## Release Note Required?
yes - New UI: Music/TV toggle for faster mode switching


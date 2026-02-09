---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-014: Micro-Interactions & Animations'
labels: 'agent/mobile-ui, P2, enhancement, media-hub, sprint-4'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 8

**Priority:** P2

## Description

Add polish through micro-interactions and animations.

### Current State
- Minimal animations
- No haptic feedback
- Abrupt transitions

### Proposed Enhancement
1. Player collapse animation (300ms, easeOutCubic)
2. Chip selection animation (200ms, easeOut)
3. Mode switch animation (300ms, easeInOut)
4. Controls fade (300ms, linear)
5. Thumbnail fade-in (200ms)
6. Haptic feedback on tap (mobile)

### User Value
- Polished, professional feel
- Responsive tactile feedback
- Smooth transitions

## Acceptance Criteria
- [ ] Player collapse animation (300ms, easeOutCubic)
- [ ] Chip selection animation (200ms, easeOut)
- [ ] Mode switch animation (300ms, easeInOut)
- [ ] Controls fade (300ms, linear)
- [ ] Thumbnail fade-in (200ms)
- [ ] Haptic feedback on tap (mobile)

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/collapsible_player_container.dart (modify)
app/lib/features/media_hub/presentation/widgets/category_chip.dart (modify)
app/lib/features/media_hub/presentation/widgets/media_mode_switch.dart (modify)
app/lib/features/media_hub/presentation/widgets/player_overlay_controls.dart (modify)
app/lib/features/media_hub/presentation/widgets/media_content_card.dart (modify)
```

## Dependencies
- All Sprint 1-3 tickets

## Release Note Required?
no - Polish and refinement


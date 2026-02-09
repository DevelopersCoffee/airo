---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-009: Recently Played Section'
labels: 'agent/mobile-ui, P1, enhancement, media-hub, sprint-2'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 4

**Priority:** P1

## Description

Show recently played content section.

### Current State
- No history of played content
- Users must search for previously played content

### Proposed Enhancement
1. Horizontal carousel showing last 20 items
2. Sorted by most recent first
3. Filters by current mode (Music/TV)

### User Value
- Quick access to recently played content
- Visual history of listening/watching activity

## Acceptance Criteria
- [ ] Horizontal carousel showing last 20 items
- [ ] Sorted by most recent first
- [ ] Filters by current mode (Music/TV)
- [ ] Reuses PersonalizationCarousel component

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/personalization_carousel.dart (modify)
app/lib/features/media_hub/presentation/screens/media_hub_screen.dart (modify)
```

## Dependencies
- MH-007: Personalization State Management
- MH-008: Continue Watching Section (for shared carousel component)

## Release Note Required?
yes - New feature: Recently Played section


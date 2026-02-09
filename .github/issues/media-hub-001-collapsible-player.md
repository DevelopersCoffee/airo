---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-001: Collapsible Hero Player Container'
labels: 'agent/mobile-ui, P0, enhancement, media-hub, sprint-1'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 12

**Priority:** P0

## Description

Implement a collapsible player container that resizes based on scroll position. This is the foundation for the "player never blocks discovery" principle.

### Current State
- Fixed height player in `media_hub_screen.dart`
- No scroll-based behavior
- Player takes too much screen real estate

### Proposed Enhancement
1. Create `CollapsiblePlayerContainer` widget
2. Default collapsed height is ~65-70% of current height (200px mobile, 280px tablet)
3. Player collapses smoothly on content scroll (300ms, easeOutCubic)
4. Player expands to fullscreen on button tap
5. State persists when navigating between tabs
6. Scroll controller shared with discovery content

### User Value
- More content visible during discovery
- Player remains accessible without blocking browsing
- Smooth, responsive feel

## Acceptance Criteria
- [ ] Default collapsed height is ~65-70% of current height (200px mobile, 280px tablet)
- [ ] Player collapses smoothly on content scroll (300ms, easeOutCubic)
- [ ] Player expands to fullscreen on button tap
- [ ] State persists when navigating between tabs
- [ ] Scroll controller shared with discovery content
- [ ] Works correctly on both mobile and tablet breakpoints

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/collapsible_player_container.dart (new)
app/lib/features/media_hub/presentation/screens/media_hub_screen.dart (modify)
app/lib/features/media_hub/application/providers/media_hub_providers.dart (modify)
app/test/features/media_hub/presentation/widgets/collapsible_player_container_test.dart (new)
```

## Dependencies
- None (foundational feature)

## Release Note Required?
yes - Major UI enhancement: Collapsible player for better content discovery


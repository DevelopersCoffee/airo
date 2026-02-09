---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-008: Continue Watching Section'
labels: 'agent/mobile-ui, P0, enhancement, media-hub, sprint-2'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 8

**Priority:** P0

## Description

Show Continue Watching/Listening section with resume capability.

### Current State
- No continue watching section
- No resume from last position
- Users must manually find and restart content

### Proposed Enhancement
1. Horizontal carousel at top of discovery
2. Shows partially watched/listened content
3. Progress bar on cards
4. Tap resumes from last position
5. Only shows content with >10 seconds played

### User Value
- Magical resume experience
- Quick access to interrupted content
- Visual progress indication

## Acceptance Criteria
- [ ] Horizontal carousel at top of discovery
- [ ] Shows partially watched/listened content
- [ ] Progress bar on cards
- [ ] Tap resumes from last position (not start from beginning)
- [ ] Only shows content with >10 seconds played
- [ ] Filters by current mode (Music/TV)

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/personalization_carousel.dart (new)
app/lib/features/media_hub/presentation/widgets/media_content_card.dart (modify - add progress bar)
app/lib/features/media_hub/presentation/screens/media_hub_screen.dart (modify)
app/test/features/media_hub/presentation/widgets/personalization_carousel_test.dart (new)
```

## Dependencies
- MH-007: Personalization State Management

## Release Note Required?
yes - New feature: Continue Watching/Listening with resume


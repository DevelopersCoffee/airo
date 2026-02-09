---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-004: Media Content Card Widget'
labels: 'agent/mobile-ui, P0, enhancement, media-hub, sprint-1'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 12

**Priority:** P0

## Description

Replace text rows with visual content cards for better discovery.

### Current State
- Simple list tiles for channel/track display
- No visual thumbnails
- No LIVE badges or viewer counts

### Proposed Enhancement
1. Card displays: Channel/Artist image, Title, Genre tag
2. LIVE badge for TV live content
3. Optional viewer count display
4. Lazy-load thumbnails with fade-in (200ms)
5. TV layout: 2-column grid
6. Music layout: horizontal carousel

### User Value
- Visual content discovery
- Clear content type indicators
- Faster scanning of available content

## Acceptance Criteria
- [ ] Card displays: Channel/Artist image, Title, Genre tag
- [ ] LIVE badge for TV live content
- [ ] Optional viewer count display
- [ ] Lazy-load thumbnails with fade-in (200ms)
- [ ] TV layout: 2-column grid
- [ ] Music layout: horizontal carousel
- [ ] Loading skeleton state

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/media_content_card.dart (new)
app/lib/features/media_hub/presentation/widgets/content_grid.dart (new)
app/lib/features/media_hub/presentation/widgets/content_carousel.dart (new)
app/test/features/media_hub/presentation/widgets/media_content_card_test.dart (new)
```

## Dependencies
- MH-005: Unified Media Content Model

## Release Note Required?
yes - New UI: Visual content cards for Music and TV


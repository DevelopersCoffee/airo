---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-011: Category Chips Bar'
labels: 'agent/mobile-ui, P0, enhancement, media-hub, sprint-3'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 8

**Priority:** P0

## Description

Horizontal scrollable category chips for content filtering.

### Current State
- Category dropdown selector
- Not easily accessible during browsing
- No visual indication of available categories

### Proposed Enhancement
1. TV categories: Live, Movies, Kids, Music, Regional, News
2. Music categories: Trending, Regional, Indie, Devotional, Chill, Focus
3. Chips contextual to active mode
4. Active chip highlighted with animation (200ms)
5. Selection filters content instantly

### User Value
- Quick category filtering
- Visual discovery of available categories
- One-tap filtering

## Acceptance Criteria
- [ ] TV: Live, Movies, Kids, Music, Regional, News
- [ ] Music: Trending, Regional, Indie, Devotional, Chill, Focus
- [ ] Chips contextual to active mode
- [ ] Active chip highlighted with animation (200ms)
- [ ] Selection filters content instantly
- [ ] Horizontal scroll with edge fade

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/category_chips_bar.dart (new)
app/lib/features/media_hub/presentation/widgets/category_chip.dart (new)
app/lib/features/media_hub/presentation/screens/media_hub_screen.dart (modify)
app/test/features/media_hub/presentation/widgets/category_chips_bar_test.dart (new)
```

## Dependencies
- MH-006: Segmented Mode Switch
- MH-012: Discovery State Management

## Release Note Required?
yes - New UI: Category chips for quick content filtering


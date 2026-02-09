---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-013: Smart Search'
labels: 'agent/mobile-ui, P1, enhancement, media-hub, sprint-3'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 12

**Priority:** P1

## Description

Unified search across Music and TV content.

### Current State
- Separate search for Music and TV
- No recent searches
- No suggestions

### Proposed Enhancement
1. Placeholder: "Search channels, artists, genres…"
2. On focus: Recent searches, Suggested categories, Trending
3. Results grouped by type (Music/TV)
4. Debounced search (300ms)
5. Minimum 2 characters before search

### User Value
- Unified search experience
- Quick access to recent searches
- Smart suggestions

## Acceptance Criteria
- [ ] Placeholder: "Search channels, artists, genres…"
- [ ] On focus: Recent searches, Suggested categories, Trending
- [ ] Results grouped by type (Music/TV)
- [ ] Debounced search (300ms)
- [ ] Minimum 2 characters before search
- [ ] Recent searches persist

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/media_search_bar.dart (new)
app/lib/features/media_hub/presentation/screens/search_results_screen.dart (new)
app/lib/features/media_hub/application/providers/search_provider.dart (new)
app/test/features/media_hub/presentation/widgets/media_search_bar_test.dart (new)
```

## Dependencies
- MH-012: Discovery State Management

## Release Note Required?
yes - New feature: Unified search across Music and TV


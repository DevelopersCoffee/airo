---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-005: Unified Media Content Model'
labels: 'agent/mobile-ui, P0, enhancement, media-hub, sprint-1'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 8

**Priority:** P0

## Description

Create unified content model that bridges Music and TV content.

### Current State
- Separate `MusicTrack` and `IPTVChannel` models
- No unified abstraction for Media Hub
- Difficulty in creating unified UI components

### Proposed Enhancement
1. `UnifiedMediaContent` model with all required fields
2. Factory methods: `fromChannel()`, `fromTrack()`
3. Resume functionality support (lastPosition, canResume)
4. Equatable for efficient state comparison

### Implementation Status
**COMPLETED** - Models already created:
- `app/lib/features/media_hub/domain/models/unified_media_content.dart`
- `app/lib/features/media_hub/domain/models/media_mode.dart`
- `app/lib/features/media_hub/domain/models/media_category.dart`

This ticket is for verification and testing of the created models.

## Acceptance Criteria
- [x] `UnifiedMediaContent` model with all required fields
- [x] Factory methods: `fromChannel()`, `fromTrack()`
- [x] Resume functionality support (lastPosition, canResume)
- [x] Equatable for efficient state comparison
- [ ] Unit tests for all models
- [ ] Integration with discovery provider

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/domain/models/unified_media_content.dart (exists)
app/lib/features/media_hub/domain/models/media_mode.dart (exists)
app/lib/features/media_hub/domain/models/media_category.dart (exists)
app/test/features/media_hub/domain/models/unified_media_content_test.dart (new)
app/test/features/media_hub/domain/models/media_category_test.dart (new)
```

## Dependencies
- None (foundational feature)

## Release Note Required?
no - Internal architecture improvement


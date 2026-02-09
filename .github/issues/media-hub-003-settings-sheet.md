---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] MH-003: Settings Bottom Sheet'
labels: 'agent/mobile-ui, P1, enhancement, media-hub, sprint-1'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 8

**Priority:** P1

## Description

Create a settings panel for quality, audio, and playback speed.

### Current State
- No settings panel for playback options
- No quality selection
- No playback speed control

### Proposed Enhancement
1. Opens as modal bottom sheet
2. Quality options: Auto, 480p, 720p, 1080p
3. Audio language selector (if multiple available)
4. Playback speed (Music mode only): 0.5x, 1x, 1.5x, 2x
5. User preferences persist across sessions

### User Value
- Control over playback quality
- Audio language preference
- Speed adjustment for podcasts/music

## Acceptance Criteria
- [ ] Opens as modal bottom sheet
- [ ] Quality options: Auto, 480p, 720p, 1080p
- [ ] Audio language selector (if multiple available)
- [ ] Playback speed (Music mode only): 0.5x, 1x, 1.5x, 2x
- [ ] User preferences persist across sessions via SharedPreferences

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/media_hub/presentation/widgets/settings_bottom_sheet.dart (new)
app/lib/features/media_hub/domain/models/quality_settings.dart (exists)
app/lib/features/media_hub/application/providers/quality_settings_provider.dart (exists)
app/test/features/media_hub/presentation/widgets/settings_bottom_sheet_test.dart (new)
```

## Dependencies
- MH-002: Player Overlay Controls

## Release Note Required?
yes - New feature: Playback quality and speed settings


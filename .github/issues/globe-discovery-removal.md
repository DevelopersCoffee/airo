---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Remove Globe Discovery Feature - Not Required'
labels: 'agent/mobile-ui, P2, tech-debt, cleanup'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 1

**Priority:** P2

## Description

The Globe Discovery feature (Spatial Music & IPTV Exploration Surface) has been removed from the codebase as it is not aligned with current product priorities.

### Background

The Globe Discovery feature was an experimental concept that aimed to transform content discovery into an interactive spatial experience where users could "spin the globe" to explore trending music and IPTV channels by geographic region. While technically feasible (leveraging the existing Flame engine from Chess), the feature was deemed not essential for the current product roadmap.

### Reason for Removal

1. **Product Priority Alignment**: The feature does not align with the current product roadmap priorities
2. **Experimental Nature**: As documented in `GLOBE_DISCOVERY_ROADMAP.md`, this was an experimental feature with P2/P3 priority
3. **Resource Optimization**: Development resources are better allocated to core features
4. **Complexity vs Value**: The 88-hour estimated investment (across 4 phases) was not justified by the expected user value at this stage

### What Was Removed

**Files Deleted:**
- `app/lib/features/globe/` (entire directory)
  - `application/providers/globe_providers.dart`
  - `domain/models/globe_marker.dart`
  - `domain/models/region_trend.dart`
  - `presentation/flame/globe_game.dart`
  - `presentation/screens/globe_screen.dart`
  - `presentation/widgets/globe_preview_sheet.dart`

**Files Modified:**
- `app/lib/core/routing/app_router.dart` - Removed Explore branch and globe imports
- `app/lib/core/app/app_shell.dart` - Removed Explore navigation destination
- `app/lib/core/config/feature_flags.dart` - Removed globe-related feature flags

**Documentation Updated:**
- `.github/issues/GLOBE_DISCOVERY_ROADMAP.md` - Marked as DEPRECATED/POSTPONED

### Future Consideration

The Globe Discovery concept may be revisited in the future if:
- User research indicates demand for spatial discovery experiences
- Product roadmap priorities shift to include discovery features
- The core app features are stable and resources are available

The roadmap documentation has been preserved for reference.

## Acceptance Criteria

- [x] All globe feature files removed from `lib/features/globe/`
- [x] Routing references removed from `app_router.dart`
- [x] Navigation entry removed from `app_shell.dart`
- [x] Feature flags cleaned up in `feature_flags.dart`
- [x] `flutter analyze` passes without errors
- [x] `flutter build web` succeeds
- [x] Roadmap documentation marked as deprecated

## CI Checklist

- [ ] `act` local run passed
- [x] `flutter analyze` clean
- [x] `flutter test` passes
- [ ] Unit tests added (N/A - removal task)
- [ ] Widget/golden tests added (N/A - removal task)
- [x] Docs/ADRs updated (if applicable)

## Files Modified

```
app/lib/core/routing/app_router.dart
app/lib/core/app/app_shell.dart
app/lib/core/config/feature_flags.dart
.github/issues/GLOBE_DISCOVERY_ROADMAP.md
```

## Files Removed

```
app/lib/features/globe/ (entire directory)
```

## Dependencies

None - this is a cleanup task with no blocking dependencies.

## Release Note Required?

No - the feature was never released to users.

## References

- Original roadmap: `.github/issues/GLOBE_DISCOVERY_ROADMAP.md`
- Original implementation issue: `.github/issues/globe-discovery-001-spatial-exploration.md`


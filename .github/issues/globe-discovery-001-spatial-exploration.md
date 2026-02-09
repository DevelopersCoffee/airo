---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Globe Discovery - Spatial Music & IPTV Exploration Surface'
labels: 'agent/mobile-ui, P2, enhancement, experimental, web-first, deprecated'
assignees: ''
---

> ⚠️ **STATUS: DEPRECATED / REMOVED**
>
> **Date:** 2026-02-09
>
> This feature was implemented but subsequently removed as it does not align with current product priorities.
> See: `.github/issues/globe-discovery-removal.md` for details.

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 28 (broken down by phase below)

**Priority:** P2 (experimental feature)

## Description

Implement a 2D/2.5D interactive globe for discovering trending music and IPTV channels by geographic region. This is a "Spin the Globe" discovery experience that provides a playful, spatial way to explore global content.

### Current State
- No spatial discovery surface exists
- Users rely on lists and search for content discovery
- Trending content lacks geographic context
- Discovery feels passive, not playful

### Proposed Enhancement
1. **Flame-based 2.5D globe** with drag/rotate gestures and inertia
2. **Regional markers** showing trending music and TV content by geography
3. **Tap-to-preview** bottom sheet with content details
4. **Integration with existing mini-players** (`MiniPlayer` + `IPTVMiniPlayer`)
5. **New `/globe` route** accessible from `/music` and `/iptv` screens
6. **Feature-flagged** with `kEnableGlobeDiscovery` constant

### User Value
- Playful discovery experience ("toy-like" interaction)
- Global context for trending content (where is this popular?)
- Signature differentiator from competitors
- Increased exploration and session length

### Technical Approach
- **Rendering:** Use existing Flame engine (`flame: ^1.35.0`) - already integrated for Chess
- **State Management:** Leverage existing Riverpod patterns
- **Playback:** Integrate with current `MusicController` and `IPTVStreamingService`
- **Navigation:** Add route via existing `GoRouter` shell
- **Platform:** Web-first (CanvasKit renderer), mobile to follow

## Acceptance Criteria

### Core Functionality
- [ ] Globe renders at 60fps on web (Chrome + CanvasKit)
- [ ] Drag gesture rotates globe smoothly with inertia physics
- [ ] Pinch gesture zooms (limited range: 0.8x - 1.5x)
- [ ] Tap on marker opens bottom sheet with content preview
- [ ] "Play" button in preview triggers existing mini-player
- [ ] Music markers use accent color A, TV markers use accent color B
- [ ] Marker size reflects popularity weight (0.0 - 1.0)

### Integration
- [ ] Entry point button visible in Music screen AppBar
- [ ] Entry point button visible in IPTV screen AppBar
- [ ] Globe minimizes when playback starts, mini-player takes over
- [ ] Feature flag `kEnableGlobeDiscovery` allows enable/disable without code changes

### Performance & Quality
- [ ] Bundle size increase < 500KB
- [ ] No breaking changes to existing music/IPTV features
- [ ] Works on web platform (mobile/desktop to follow in Phase 2)
- [ ] Graceful fallback if FPS drops below 55 (reduce marker count)

## Implementation Phases

### Phase 1: Globe Rendering + Rotation Gestures (8 hours)
- Create `GlobeGame` Flame game class with sphere projection
- Implement drag-to-rotate with velocity-based inertia
- Add dark background with subtle atmosphere glow
- Basic pinch-to-zoom with constraints

### Phase 2: Marker System + Tap Detection (6 hours)
- Create `GlobeMarker` data model with lat/lng, type, weight
- Implement marker rendering with size based on weight
- Add hit-testing for marker tap detection
- Color-code markers by content type (music vs TV)

### Phase 3: Preview Bottom Sheet (4 hours)
- Create `GlobePreviewSheet` widget
- Display region name, top 5 tracks/channels
- Add "Play" and "Shuffle" action buttons
- Swipe-down to dismiss behavior

### Phase 4: Mini-Player Integration (4 hours)
- Connect preview "Play" to `MusicController.playTrack()`
- Connect preview "Watch" to `IPTVStreamingService.playChannel()`
- Ensure mini-player appears after playback starts
- Handle globe screen state during playback

### Phase 5: Entry Points in Music/IPTV Screens (2 hours)
- Add globe icon button to `MusicScreen` AppBar
- Add globe icon button to `IPTVScreen` AppBar
- Add `/globe` route to `AppRouter`
- Conditional visibility based on feature flag

### Phase 6: Performance Optimization + Feature Flag (4 hours)
- Create `feature_flags.dart` with `kEnableGlobeDiscovery`
- Add FPS monitoring and adaptive quality
- Implement marker count reduction on low FPS
- Document performance benchmarks

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added for globe game logic
- [ ] Widget tests added for globe screen
- [ ] Performance benchmarks documented (FPS, bundle size)
- [ ] Feature flag tested (on/off states)

## Files to Modify

```
NEW FILES:
app/lib/features/globe/presentation/screens/globe_screen.dart
app/lib/features/globe/presentation/flame/globe_game.dart
app/lib/features/globe/presentation/widgets/globe_preview_sheet.dart
app/lib/features/globe/domain/models/globe_marker.dart
app/lib/features/globe/domain/models/region_trend.dart
app/lib/features/globe/application/providers/globe_provider.dart
app/lib/core/config/feature_flags.dart
app/test/features/globe/presentation/flame/globe_game_test.dart
app/test/features/globe/presentation/screens/globe_screen_test.dart

MODIFIED FILES:
app/lib/core/routing/app_router.dart (add /globe route)
app/lib/core/routing/route_names.dart (add globe route name)
app/lib/features/music/presentation/screens/music_screen.dart (add globe entry button)
app/lib/features/iptv/presentation/screens/iptv_screen.dart (add globe entry button)
```

## Dependencies
- No new package dependencies required (uses existing `flame: ^1.35.0`)
- Integrates with: `MusicController`, `IPTVStreamingService`, `AppRouter`, `MiniPlayer`, `IPTVMiniPlayer`
- No blocking issues

## Risks & Mitigations

| Risk | Probability | Mitigation |
|------|-------------|------------|
| Performance < 60fps | Medium | 2D fallback mode, adaptive marker count |
| Gesture conflicts with scroll | Low | Dedicated screen, not overlay |
| User confusion about purpose | Medium | Clear "Explore" labeling, onboarding tooltip |
| Scope creep | High | Strict phase boundaries, feature flag for rollback |
| Motion sickness | Low | Reduced motion accessibility option |

## Release Note Required?
yes - 🌍 NEW: Globe Discovery (Web Beta) - Explore trending music and TV channels by spinning an interactive globe. Tap any region to preview and play content. Access via Music or IPTV screens.


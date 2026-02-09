# Globe Discovery - Spatial Exploration Roadmap

> ⚠️ **STATUS: DEPRECATED / POSTPONED**
>
> **Date:** 2026-02-09
>
> This feature has been removed from the current product roadmap. The implementation was completed for Phase 1 but subsequently removed as it does not align with current product priorities.
>
> **Reason:** Resource optimization - development efforts are being focused on core features.
>
> **Future:** This roadmap is preserved for reference. The concept may be revisited when:
> - User research indicates demand for spatial discovery experiences
> - Product roadmap priorities shift to include discovery features
> - Core app features are stable and resources are available
>
> See: `.github/issues/globe-discovery-removal.md` for removal details.

---

## Vision
Transform content discovery from passive list browsing into an interactive, playful spatial experience where users "spin the globe" to explore trending music and IPTV channels by geographic region.

## Core Principle
**Discovery should feel like play, not work.**

---

## Phase 1: Web Prototype (P2) - 4 weeks

### Issue #001: Spatial Music & IPTV Exploration Surface
**Estimate:** 28 hours | **Priority:** P2 | **Platform:** Web-first

Sub-tasks:
- Phase 1.1: Globe Rendering + Rotation Gestures (8 hours)
- Phase 1.2: Marker System + Tap Detection (6 hours)
- Phase 1.3: Preview Bottom Sheet (4 hours)
- Phase 1.4: Mini-Player Integration (4 hours)
- Phase 1.5: Entry Points in Music/IPTV Screens (2 hours)
- Phase 1.6: Performance Optimization + Feature Flag (4 hours)

**Phase 1 Total:** 28 hours (~3.5 days)

---

## Phase 2: Dynamic Data (P2) - 2 weeks

### Issue #002: Region Trends API Integration
**Estimate:** 16 hours | **Priority:** P2
- Define backend API contract for regional trends
- Implement mock data service for development
- Add caching layer for trend data
- Real-time marker updates

### Issue #003: Content Type Toggle
**Estimate:** 8 hours | **Priority:** P2
- Music/TV mode switch on globe screen
- Marker filtering by content type
- Smooth transition animations
- Persist user preference

**Phase 2 Total:** 24 hours (~3 days)

---

## Phase 3: Mobile Optimization (P2) - 2 weeks

### Issue #004: Mobile Gesture Refinement
**Estimate:** 12 hours | **Priority:** P2
- Touch gesture optimization for mobile
- Haptic feedback on marker tap
- Reduced motion mode for accessibility
- Battery-conscious rendering

### Issue #005: Adaptive Performance
**Estimate:** 8 hours | **Priority:** P2
- Device capability detection
- Automatic quality adjustment
- 2D fallback for low-end devices
- FPS monitoring and alerts

**Phase 3 Total:** 20 hours (~2.5 days)

---

## Phase 4: Polish & Analytics (P3) - 2 weeks

### Issue #006: Micro-Interactions
**Estimate:** 8 hours | **Priority:** P3
- Marker pulse animations
- Globe auto-spin on idle
- Preview sheet transitions
- Loading state animations

### Issue #007: Discovery Analytics
**Estimate:** 8 hours | **Priority:** P3
- Globe opens per session
- Marker tap tracking
- Time spent spinning
- Tap-to-play conversion rate

**Phase 4 Total:** 16 hours (~2 days)

---

## Dependency Graph

```
Phase 1 (Web Prototype)
┌─────────────────────────────────────────────────────────────┐
│  #001 Globe Discovery ──────────────────────────────────────│
│    ├── 1.1 Globe Rendering                                  │
│    ├── 1.2 Marker System                                    │
│    ├── 1.3 Preview Sheet                                    │
│    ├── 1.4 Mini-Player Integration                          │
│    ├── 1.5 Entry Points                                     │
│    └── 1.6 Performance + Feature Flag                       │
└─────────────────────────────────────────────────────────────┘
                            │
Phase 2 (Dynamic Data)      ▼
┌─────────────────────────────────────────────────────────────┐
│  #002 Region Trends API ────────► #003 Content Type Toggle  │
└─────────────────────────────────────────────────────────────┘
                            │
Phase 3 (Mobile)            ▼
┌─────────────────────────────────────────────────────────────┐
│  #004 Mobile Gestures ──────────► #005 Adaptive Performance │
└─────────────────────────────────────────────────────────────┘
                            │
Phase 4 (Polish)            ▼
┌─────────────────────────────────────────────────────────────┐
│  #006 Micro-Interactions        #007 Discovery Analytics    │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Architecture Decisions

### 1. Flame Engine for Rendering
Use existing Flame integration (from Chess) for:
- Canvas-based 2.5D globe projection
- Gesture handling (pan, pinch, tap)
- 60fps rendering target
- No additional dependencies

### 2. Feature Flag Strategy
`kEnableGlobeDiscovery` constant enables:
- Gradual rollout
- A/B testing capability
- Quick rollback if issues arise
- Platform-specific enablement

### 3. Web-First Development
Start with web platform because:
- CanvasKit provides GPU acceleration
- Chrome DevTools for performance profiling
- Faster iteration with hot reload
- No app store deployment for testing

### 4. Integration Over Replacement
Globe is a discovery layer, not a replacement:
- Existing mini-players handle playback
- Existing providers manage state
- Existing routes remain unchanged
- Additive feature, not destructive

---

## Success Metrics

1. **Engagement:** Globe opens per session > 0.5
2. **Discovery:** Tap-to-play conversion > 30%
3. **Performance:** 60fps on 90% of web sessions
4. **Retention:** Users who use globe return 2x more
5. **Delight:** NPS score for feature > 50

---

## Total Roadmap Summary

| Phase | Focus | Hours | Priority |
|-------|-------|-------|----------|
| Phase 1 | Web Prototype | 28 | P2 |
| Phase 2 | Dynamic Data | 24 | P2 |
| Phase 3 | Mobile Optimization | 20 | P2 |
| Phase 4 | Polish & Analytics | 16 | P3 |
| **Total** | | **88 hours** | |

---

## How to Create Issues

1. Copy content from `globe-discovery-00X-*.md` files
2. Create issue on GitHub: https://github.com/DevelopersCoffee/airo_super_app/issues/new
3. Apply labels: `agent/mobile-ui`, `P2`, `experimental`, `web-first`
4. Add to project board: https://github.com/orgs/DevelopersCoffee/projects/2


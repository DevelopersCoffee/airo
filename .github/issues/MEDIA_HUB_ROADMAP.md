# Media Hub Streaming Surface - Engineering Roadmap

## Overview

Media Hub Streaming Surface redesign for unified Music + TV experience.

**Core Principle:** Media is ambient, not dominant.

**Total:** 20 tickets | 77 story points | 4 sprints

## Critical Success Criteria

1. Player never blocks discovery
2. Resume behavior feels magical
3. Mode switching is instant and obvious

## Sprint Breakdown

### Sprint 1: Foundation (19 points)
- MH-001: Collapsible Hero Player Container (5 pts) - P0
- MH-002: Player Overlay Controls (3 pts) - P0
- MH-003: Settings Bottom Sheet (3 pts) - P1
- MH-004: Media Content Card Widget (5 pts) - P0
- MH-005: Unified Media Content Model (3 pts) - P0

### Sprint 2: Mode Switching & Personalization (15 points)
- MH-006: Segmented Mode Switch (3 pts) - P0
- MH-007: Personalization State Management (5 pts) - P1
- MH-008: Continue Watching Section (3 pts) - P0
- MH-009: Recently Played Section (2 pts) - P1
- MH-010: Favorites Section (2 pts) - P1

### Sprint 3: Discovery & Search (11 points)
- MH-011: Category Chips Bar (3 pts) - P0
- MH-012: Discovery State Management (3 pts) - P1
- MH-013: Smart Search (5 pts) - P1

### Sprint 4: Polish & Platform (12 points)
- MH-014: Micro-Interactions & Animations (3 pts) - P2
- MH-015: Mini Player Bar (3 pts) - P1
- MH-016: Responsive Layouts (3 pts) - P1
- MH-017: Accessibility Compliance (3 pts) - P1

### Platform-Specific (12 points)
- MH-AND-001: Android Foreground Service (5 pts) - P1
- MH-IOS-001: iOS System Integration (5 pts) - P1
- MH-WEB-001: Web Keyboard Shortcuts (2 pts) - P2

## Dependency Graph

```
MH-005 → MH-004, MH-007
MH-007 → MH-008, MH-009, MH-010
MH-001 → MH-002 → MH-003
MH-006 → MH-011
MH-012 → MH-011, MH-013
MH-001 → MH-015
```

## Related Documentation

- [Widget Architecture](../../docs/features/media-hub/WIDGET_ARCHITECTURE.md)
- [State Models](../../docs/features/media-hub/STATE_MODELS.md)
- [Acceptance Tests](../../docs/features/media-hub/ACCEPTANCE_TESTS.md)
- [Engineering Tickets](../../docs/features/media-hub/ENGINEERING_TICKETS.md)


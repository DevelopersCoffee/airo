# Media Hub Widget Architecture

## Overview

This document defines the Flutter widget architecture for the unified Music + TV Streaming surface, following the existing Domain-Driven Design patterns in the Airo codebase.

---

## Architecture Principles

### 1. Domain-Driven Design (DDD) Structure
```
features/media_hub/
├── domain/           # Core business logic
│   ├── models/       # Data models & entities
│   ├── services/     # Abstract service interfaces
│   └── repositories/ # Abstract data access interfaces
├── application/      # State management
│   └── providers/    # Riverpod providers
├── data/             # External data sources
│   ├── repositories/ # Concrete implementations
│   └── datasources/  # API/local data sources
└── presentation/     # UI layer
    ├── screens/      # Full-screen widgets
    ├── widgets/      # Reusable components
    └── controllers/  # UI logic controllers
```

### 2. State Management: Riverpod
- Use `StateNotifierProvider` for complex state
- Use `StreamProvider` for real-time player state
- Use `FutureProvider` for async data loading
- Use `StateProvider` for simple UI state (mode toggle, selected category)

---

## Widget Hierarchy

```
MediaHubScreen (Root)
├── MediaModeSwitch (🎵 Music / 📺 TV)
├── HeroPlayerArea
│   ├── CollapsiblePlayerContainer
│   │   ├── MusicHeroPlayer (when Music mode)
│   │   └── TVHeroPlayer (when TV mode)
│   └── PlayerOverlayControls
│       ├── PlayPauseButton (center)
│       ├── FavoriteButton
│       ├── FullscreenButton
│       └── SettingsButton → SettingsBottomSheet
├── CategoryChipsBar (horizontal scroll)
│   └── CategoryChip × N
├── DiscoveryContent (scrollable)
│   ├── PersonalizationSection
│   │   ├── ContinueWatchingCarousel
│   │   ├── RecentlyPlayedCarousel
│   │   └── FavoritesCarousel
│   └── ContentGridSection
│       └── MediaContentCard × N
└── MiniPlayerBar (persistent, above bottom nav)
    └── MiniPlayerControls
```

---

## Core Widget Components

### 1. MediaModeSwitch
**Purpose:** Segmented control for Music/TV mode switching

```dart
class MediaModeSwitch extends ConsumerWidget {
  // Uses selectedMediaModeProvider
  // Icons + labels: 🎵 Music | 📺 TV
  // Strong active indicator (underline + color)
  // Does NOT stop playback unless source incompatible
}
```

**State:** `selectedMediaModeProvider` → `StateProvider<MediaMode>`

### 2. CollapsiblePlayerContainer
**Purpose:** Hero player with collapse/expand behavior

```dart
class CollapsiblePlayerContainer extends ConsumerStatefulWidget {
  // Default height: 65-70% of original
  // Collapses smoothly on scroll
  // State persists when navigating tabs
  // expand → fullscreen transition
}
```

**Properties:**
- `collapsedHeight`: ~200px (mobile), ~300px (tablet/web)
- `expandedHeight`: Full viewport
- `scrollController`: For collapse-on-scroll behavior

### 3. PlayerOverlayControls
**Purpose:** Overlay controls visible on tap/hover

```dart
class PlayerOverlayControls extends StatelessWidget {
  // Fade-in on interaction
  // Auto-hide after 4 seconds
  // Actions: Play/Pause, Favorite, Fullscreen, Settings
}
```

### 4. SettingsBottomSheet
**Purpose:** Quality & audio settings panel

```dart
class SettingsBottomSheet extends ConsumerWidget {
  // Quality: Auto / 480p / 720p / 1080p
  // Audio language (if available)
  // Playback speed (Music only)
  // Persists user preference
}
```

### 5. CategoryChipsBar
**Purpose:** Horizontal scrollable category filter

```dart
class CategoryChipsBar extends ConsumerWidget {
  // TV: Live, Movies, Kids, Music, Regional, News
  // Music: Trending, Regional, Indie, Devotional, Chill, Focus
  // Contextual to active mode
  // Active chip highlighted
}
```

### 6. MediaContentCard
**Purpose:** Visual card for channels/tracks

```dart
class MediaContentCard extends StatelessWidget {
  // Channel/Artist image (primary)
  // Title
  // Genre tag
  // LIVE badge (TV only)
  // Optional viewer count
  // Lazy-load thumbnails
}
```

### 7. PersonalizationCarousel
**Purpose:** Horizontal carousel for personalized content

```dart
class PersonalizationCarousel extends ConsumerWidget {
  // Continue Watching/Listening
  // Recently Played
  // Favorites
  // Resume from last position
  // Persist across devices
}
```

### 8. MiniPlayerBar
**Purpose:** Persistent mini player above bottom navigation

```dart
class MiniPlayerBar extends ConsumerWidget {
  // Shows current playing media
  // Quick controls: Play/Pause, Next
  // Tap to expand to full player
  // Collapses above nav bar
}
```

---

## Widget Composition Patterns

### Pattern 1: Mode-Aware Content
```dart
Widget build(BuildContext context, WidgetRef ref) {
  final mode = ref.watch(selectedMediaModeProvider);

  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    child: mode == MediaMode.music
        ? const MusicContent(key: ValueKey('music'))
        : const TVContent(key: ValueKey('tv')),
  );
}
```

### Pattern 2: Collapse-on-Scroll
```dart
class _CollapsiblePlayerState extends ConsumerState<CollapsiblePlayer> {
  late ScrollController _scrollController;
  double _playerHeight = 1.0; // 1.0 = expanded, 0.65 = collapsed

  void _onScroll() {
    final offset = _scrollController.offset;
    setState(() {
      _playerHeight = (1.0 - (offset / 200)).clamp(0.65, 1.0);
    });
  }
}
```

### Pattern 3: Overlay Controls with Auto-Hide
```dart
class _OverlayControlsState extends State<OverlayControls> {
  Timer? _hideTimer;
  bool _visible = true;

  void _showControls() {
    setState(() => _visible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }
}
```

---

## Responsive Layouts

### Mobile (< 600dp)
- Single column content grid
- Player height: 200px collapsed
- Full-width category chips
- Mini player: 64px height

### Tablet (600dp - 1200dp)
- 2-column content grid (TV)
- 3-column horizontal carousel (Music)
- Player height: 280px collapsed
- Mini player: 72px height

### Desktop/Web (> 1200dp)
- 3-4 column content grid
- Max-width container (1400px)
- Player with keyboard shortcuts
- Hover states for all interactive elements

---

## Accessibility Requirements

- Touch targets ≥ 44px (11mm)
- Color contrast ≥ 4.5:1 (WCAG AA)
- Semantic labels for all controls
- Dynamic text support
- Clear focus indicators (web)
- Screen reader compatible

---

## Animation Specifications

| Animation | Duration | Curve |
|-----------|----------|-------|
| Player collapse | 300ms | easeOutCubic |
| Chip selection | 200ms | easeOut |
| Mode switch | 300ms | easeInOut |
| Controls fade | 300ms | linear |
| Card thumbnail | 200ms | fadeIn |
| Mini player slide | 250ms | easeOut |



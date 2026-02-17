# TV Accessibility Guide

This document describes the accessibility features implemented for Android TV and Fire TV in the IPTV Media Hub.

## Overview

The TV UI follows WCAG 2.1 AA standards and aligns with acceptance tests CP-AC-001 through CP-AC-004 from the Media Hub PRD.

## Acceptance Test Alignment

### CP-AC-001: Touch Target Size

**Requirement:** Interactive elements must have touch targets ≥ 44px (11mm) for mobile, ≥ 56dp for TV.

**Implementation:**
- TV minimum target size: **56dp** (defined in `TvUiDimensions.tv()`)
- TV control button size: **64dp** (larger than minimum)
- Fire TV uses same dimensions with safe zone padding

**Location:** `app/lib/core/tv/tv_providers.dart`

```dart
factory TvUiDimensions.tv() => const TvUiDimensions._(
  minTargetSize: 56.0,
  controlButtonSize: 64.0,
  // ...
);
```

### CP-AC-002: Color Contrast

**Requirement:** Text and icons must have contrast ratio ≥ 4.5:1 (WCAG AA).

**Implementation:**
- Primary text: `Colors.white` on dark backgrounds (>16:1 contrast)
- Secondary text: `Colors.white70` on dark backgrounds (~11:1 contrast)
- Tertiary text: `Colors.white54` on dark backgrounds (~7:1 contrast)
- Focus indicators: 3dp border with glow effect for visibility

**Color Combinations Used:**
| Foreground | Background | Contrast Ratio | Status |
|------------|------------|----------------|--------|
| White | Black87 (#212121) | ~16:1 | ✓ PASS |
| White | Black45 (#737373) | ~4.5:1 | ✓ PASS |
| White70 | Black87 | ~11:1 | ✓ PASS |
| White54 | Black87 | ~7:1 | ✓ PASS |
| Green | Dark Grey | ~5:1 | ✓ PASS |

### CP-AC-003: Screen Reader Labels

**Requirement:** Interactive elements must have semantic labels announced by screen readers.

**Implementation:**

The `TvFocusable` widget supports screen reader labels via:
- `semanticLabel`: Primary label announced by TalkBack
- `semanticHint`: Action description (e.g., "Press OK to play")
- `semanticButton`: Indicates element is a button
- `announceFocus`: Enables explicit focus announcements

**Location:** `app/lib/core/tv/tv_focusable.dart`

```dart
TvFocusable(
  semanticLabel: 'Play button',
  semanticHint: 'Press OK to activate',
  semanticButton: true,
  onSelect: _play,
  child: Icon(Icons.play_arrow),
)
```

**TV Player Controls:**
- Play/Pause button: "Play" / "Pause" label
- Rewind button: "Rewind 10s" label
- Forward button: "Forward 10s" label
- Go Live button: "Go Live" label
- Mute button: "Mute" / "Unmute" label

**Channel Cards:**
- Channel name as semantic label
- "currently playing" suffix for active channel
- "Press OK to play channel" hint

### CP-AC-004: Dynamic Text Support

**Requirement:** Text must scale appropriately with system font size settings.

**Implementation:**
- TV uses 1.25x text scale factor for 10ft viewing distance
- All text sizes multiplied by `dimensions.textScaleFactor`

**Location:** `app/lib/core/tv/tv_providers.dart`

```dart
factory TvUiDimensions.tv() => const TvUiDimensions._(
  textScaleFactor: 1.25,
  // ...
);
```

## Focus Indicators

TV focus indicators provide visual feedback for D-pad navigation:

| Property | Value | Purpose |
|----------|-------|---------|
| Border Width | 3dp | Visible focus outline |
| Border Radius | 8dp | Rounded corners |
| Scale Factor | 1.05x | Slight enlargement when focused |
| Glow Spread | 4dp | Additional visibility |
| Animation Duration | 200ms | Smooth transitions |

**Location:** `app/lib/core/tv/tv_focus_manager.dart`

## Testing with TalkBack

To test accessibility on Android TV:

1. Enable TalkBack in Settings > Accessibility
2. Navigate the UI using D-pad
3. Verify labels are announced correctly
4. Verify focus moves logically between elements

**Expected Behavior:**
- Focus changes announce the semantic label
- Buttons announce "button" role
- Hints describe available actions
- Playing channels announce "currently playing"

## Test Coverage

Accessibility tests are located in:
`app/test/core/tv/tv_integration_test.dart`

Test groups:
- `CP-AC-001: Touch Target Size` - 4 tests
- `CP-AC-002: Color Contrast` - 2 tests
- `CP-AC-003: Screen Reader Labels` - 2 tests
- `CP-AC-004: Dynamic Text Support` - 3 tests

Run tests:
```bash
flutter test test/core/tv/tv_integration_test.dart
```

## Related Documentation

- [Fire TV Testing Guide](./FIRE_TV_TESTING_GUIDE.md)
- [Acceptance Tests](./ACCEPTANCE_TESTS.md)
- [TV Components](../../app/lib/core/tv/tv.dart)


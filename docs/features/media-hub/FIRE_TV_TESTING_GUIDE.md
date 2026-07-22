# Fire TV Testing Guide

## Overview

This guide provides comprehensive testing procedures for Fire TV support in the Airo TV Media Hub feature. Fire TV devices require specific testing for platform detection, safe zones, remote button mapping, and D-pad navigation.

---

## Prerequisites

### Required Tools

1. **Android Studio** with AVD Manager
2. **Fire TV Emulator** or physical Fire TV device
3. **ADB (Android Debug Bridge)** for device communication
4. **Flutter 3.35.7+** installed and configured

### Setting Up Fire TV Emulator

1. Open Android Studio → Tools → AVD Manager
2. Click "Create Virtual Device"
3. Select "TV" category
4. Choose "Fire TV Stick 4K" or create custom TV profile:
   - Resolution: 1920x1080
   - Density: tvdpi (213dpi)
   - RAM: 1.5GB (Fire TV Stick) or 2GB (Fire TV Cube)
5. Select system image: Android TV API 30+ (x86_64)
6. Name the emulator: `Fire_TV_Stick_4K`

### Alternative: Amazon Fire TV Emulator

Download from [Amazon Developer Portal](https://developer.amazon.com/apps-and-games/fire-tv):

```bash
# Download and extract Fire TV emulator
unzip fire-tv-emulator.zip
./fire-tv-emulator/emulator -avd Fire_TV_Stick_4K
```

---

## Running the App on Fire TV

### Using Make Commands

```bash
# List available emulators
make emulators

# Run on Fire TV emulator (auto-detect)
make run-firetv

# Run on specific Fire TV emulator by name
make run-firetv-emulator

# Build Fire TV optimized APK
make build-firetv
```

### Using Flutter Directly

```bash
# List devices
flutter devices

# Run on Fire TV emulator
cd app && flutter run -d emulator-5554

# Run on physical Fire TV (via ADB)
adb connect 192.168.1.100:5555  # Fire TV IP
cd app && flutter run -d 192.168.1.100:5555
```

### Connecting to Physical Fire TV

1. On Fire TV: Settings → My Fire TV → Developer Options
2. Enable "ADB Debugging" and "Apps from Unknown Sources"
3. Note the IP address from Settings → My Fire TV → About → Network
4. Connect via ADB:

```bash
adb connect <fire-tv-ip>:5555
flutter run -d <fire-tv-ip>:5555
```

---

## Test Cases

### 1. Platform Detection Testing

**Test ID:** `FTV-PD-001`
**Objective:** Verify Fire TV is correctly detected as `TvPlatform.fireTv`

**Steps:**
1. Launch app on Fire TV emulator
2. Navigate to IPTV/Media Hub screen
3. Open debug overlay (if available) or check logs

**Verification:**
```dart
// Expected behavior in code:
final tvPlatform = await DeviceFormFactorDetector.getTvPlatform();
expect(tvPlatform, equals(TvPlatform.fireTv));

final isFireTv = await DeviceFormFactorDetector.isFireTv();
expect(isFireTv, isTrue);
```

**Logcat Verification:**
```bash
adb logcat | grep -i "TvPlatform\|FireTV\|device_info"
# Should show: TvPlatform: fireTv detected
```

**Expected Results:**
- [ ] `DeviceFormFactor.tv` is returned
- [ ] `TvPlatform.fireTv` is detected (not `androidTv` or `genericTv`)
- [ ] `isFireTv()` returns `true`
- [ ] Fire TV specific providers load correctly

---

### 2. Safe Zone Testing

**Test ID:** `FTV-SZ-001`
**Objective:** Verify Fire TV safe zones (48dp horizontal, 27dp vertical) are applied

**Steps:**
1. Launch app on Fire TV
2. Navigate to channel grid
3. Verify content is not clipped at screen edges

**Visual Verification:**
```
+--------------------------------------------------+
|                                                  |
|    48dp →  ┌──────────────────────────┐  ← 48dp |
|            │                          │          |
|     27dp ↓ │    CONTENT AREA         │  ↑ 27dp |
|            │                          │          |
|            └──────────────────────────┘          |
|                                                  |
+--------------------------------------------------+
```

**Code Verification:**
```dart
// Check TvUiDimensions.fireTv() is used
final dimensions = TvUiDimensions.fireTv();
expect(dimensions.safeZone.left, equals(48.0));
expect(dimensions.safeZone.right, equals(48.0));
expect(dimensions.safeZone.top, equals(27.0));
expect(dimensions.safeZone.bottom, equals(27.0));
```

**Expected Results:**
- [ ] Channel grid has 48dp left/right padding
- [ ] Channel grid has 27dp top/bottom padding
- [ ] UI elements are not clipped at edges
- [ ] Focus indicators are fully visible within safe zone

---

### 3. Remote Button Testing

**Test ID:** `FTV-RB-001`
**Objective:** Verify Fire TV remote buttons are correctly mapped

#### Voice Search Button

**Steps:**
1. Navigate to channel grid
2. Press Voice/Alexa button on remote (or keyboard shortcut in emulator)
3. Verify voice search overlay appears

**Keyboard Shortcuts (Emulator):**
- Voice Search: `F1` or `browserSearch` key

**Expected Results:**
- [ ] Voice search overlay appears
- [ ] `TvInputKey.voiceSearch` is triggered
- [ ] App handles voice search gracefully (even if not implemented)

#### Channel Up/Down Buttons

**Steps:**
1. Start video playback
2. Press Channel Up button
3. Press Channel Down button

**Keyboard Shortcuts (Emulator):**
- Channel Up: `PageUp` or `channelUp`
- Channel Down: `PageDown` or `channelDown`

**Expected Results:**
- [ ] Channel Up switches to next channel in list
- [ ] Channel Down switches to previous channel in list
- [ ] `TvInputKey.channelUp` and `TvInputKey.channelDown` are triggered

#### Media Control Buttons

**Steps:**
1. Start video playback
2. Test Play/Pause, Fast Forward, Rewind buttons

**Keyboard Shortcuts (Emulator):**
- Play/Pause: `Space` or `P`
- Fast Forward: `Right Arrow` (long press) or `F`
- Rewind: `Left Arrow` (long press) or `R`

**Expected Results:**
- [ ] Play/Pause toggles playback
- [ ] Fast Forward seeks forward 10 seconds
- [ ] Rewind seeks backward 10 seconds

---

### 4. D-pad Navigation Testing

**Test ID:** `FTV-DN-001`
**Objective:** Verify D-pad navigation works correctly on Fire TV

#### Arrow Key Navigation

**Steps:**
1. Navigate to channel grid
2. Use D-pad arrows to move focus
3. Verify focus moves in correct direction

**Expected Behavior:**
```
    ↑ (UP)
      │
←────┼────→
LEFT │ RIGHT
      │
    ↓ (DOWN)
```

**Expected Results:**
- [ ] UP arrow moves focus up
- [ ] DOWN arrow moves focus down
- [ ] LEFT arrow moves focus left
- [ ] RIGHT arrow moves focus right
- [ ] Focus wraps at grid boundaries (if enabled)

#### Select/Enter Button

**Steps:**
1. Focus on a channel card
2. Press CENTER/SELECT button

**Expected Results:**
- [ ] Channel starts playing
- [ ] `TvInputKey.select` is triggered
- [ ] Visual feedback on selection

#### Back Button

**Steps:**
1. Navigate deep into app (e.g., channel → player → fullscreen)
2. Press BACK button repeatedly

**Expected Results:**
- [ ] Back navigates to previous screen
- [ ] Back exits fullscreen before exiting player
- [ ] Back from home screen shows exit dialog (if implemented)

---

### 5. Focus Indicators Testing

**Test ID:** `FTV-FI-001`
**Objective:** Verify focus indicators are visible and correct on Fire TV

**Focus Indicator Specifications:**
- Border: 3dp width, primary color
- Scale: 1.05x enlargement
- Glow: 4dp spread, primary color with 50% opacity

**Steps:**
1. Navigate to channel grid
2. Move focus between items
3. Verify focus indicator is clearly visible

**Expected Results:**
- [ ] Focused item has visible border (3dp)
- [ ] Focused item is slightly enlarged (1.05x)
- [ ] Focused item has subtle glow effect
- [ ] Focus transitions are smooth (animation duration)
- [ ] Focus is visible from 10-foot viewing distance

---

### 6. Performance Testing

**Test ID:** `FTV-PF-001`
**Objective:** Verify app performs well on Fire TV hardware

#### Scroll Performance

**Steps:**
1. Navigate to channel grid with 100+ channels
2. Scroll rapidly using D-pad
3. Measure smoothness

**Expected Results:**
- [ ] Grid scrolls at 60fps
- [ ] No visible jank or stuttering
- [ ] Thumbnails load progressively

#### Input Responsiveness

**Steps:**
1. Navigate using D-pad
2. Measure time from input to visual response

**Expected Results:**
- [ ] Focus changes within 100ms
- [ ] No missed inputs during rapid navigation
- [ ] Debouncing prevents accidental multi-selection

#### Memory Usage

**Steps:**
1. Use Android Profiler to monitor memory
2. Navigate through app for 5+ minutes
3. Check for memory leaks

**Expected Results:**
- [ ] Memory stays below 150MB
- [ ] No memory leaks during navigation
- [ ] Video player releases memory when stopped

---

## Troubleshooting

### Common Issues

#### Fire TV Not Detected as Fire TV

**Symptom:** `TvPlatform.androidTv` returned instead of `TvPlatform.fireTv`

**Solution:**
1. Check platform channel implementation in `android/app/src/main/kotlin/`
2. Verify `Build.MANUFACTURER` check includes "Amazon"
3. Check logcat for platform detection errors

```kotlin
// Expected in Android native code
if (Build.MANUFACTURER.equals("Amazon", ignoreCase = true)) {
    return "fireTv"
}
```

#### Safe Zones Not Applied

**Symptom:** UI elements are clipped at screen edges

**Solution:**
1. Verify `fireTvSafeZoneProvider` is used
2. Check `TvChannelGrid` uses `TvUiDimensions.fireTv()`
3. Ensure padding is applied to root container

#### D-pad Not Responding

**Symptom:** Arrow keys don't move focus

**Solution:**
1. Check `TvInputHandler` is wrapping the widget tree
2. Verify `Focus` widgets are properly configured
3. Check `FocusNode` is attached and not disposed

#### Voice Search Not Working

**Symptom:** Voice button does nothing

**Solution:**
1. Verify `TvInputKey.voiceSearch` mapping is correct
2. Check voice search handler is implemented
3. Test with `LogicalKeyboardKey.browserSearch` in emulator

---

## Testing Checklist

### Pre-Testing Setup
- [ ] Fire TV emulator/device is running
- [ ] ADB connection is established
- [ ] App is installed and launched

### Platform Detection
- [ ] FTV-PD-001: Platform detected as `TvPlatform.fireTv`
- [ ] Device form factor is `DeviceFormFactor.tv`

### Safe Zones
- [ ] FTV-SZ-001: 48dp horizontal padding applied
- [ ] FTV-SZ-001: 27dp vertical padding applied
- [ ] UI elements not clipped

### Remote Buttons
- [ ] FTV-RB-001: Voice search button triggers overlay
- [ ] FTV-RB-001: Channel Up/Down changes channels
- [ ] FTV-RB-001: Play/Pause works during playback
- [ ] FTV-RB-001: Fast Forward/Rewind seeks correctly

### D-pad Navigation
- [ ] FTV-DN-001: Arrow keys move focus correctly
- [ ] FTV-DN-001: Select/Enter activates items
- [ ] FTV-DN-001: Back navigates correctly
- [ ] FTV-DN-001: Focus wrap-around works (if enabled)

### Focus Indicators
- [ ] FTV-FI-001: Focus border visible (3dp)
- [ ] FTV-FI-001: Focus scale applied (1.05x)
- [ ] FTV-FI-001: Focus glow visible
- [ ] FTV-FI-001: Visible from 10ft distance

### Performance
- [ ] FTV-PF-001: 60fps scrolling
- [ ] FTV-PF-001: <100ms input latency
- [ ] FTV-PF-001: <150MB memory usage
- [ ] FTV-PF-001: No memory leaks

---

## Related Documentation

- [ACCEPTANCE_TESTS.md](./ACCEPTANCE_TESTS.md) - Full acceptance test matrix
- [TV Input Handler](../../../app/lib/core/tv/tv_input_handler.dart) - D-pad key mapping
- [Device Form Factor](../../../app/lib/core/platform/device_form_factor.dart) - Platform detection
- [TV Channel Grid](../../../app/lib/features/iptv/presentation/widgets/tv_channel_grid.dart) - Channel grid widget

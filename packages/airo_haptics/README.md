# airo_haptics

A cross-platform Flutter haptics engine with semantic feedback, custom patterns, device capability detection, accessibility-aware behavior, and native platform optimization.

> **One Flutter API, native implementation on every eligible platform, capability-aware behavior, zero-crash fallback, excellent DX, and production-grade testing.**

## Native Platform Support Matrix

| Platform | V1 Target | Native Implementation Engine |
| --- | --- | --- |
| **Android** | ⭐ Full | Kotlin + Vibrator / VibrationEffect / Composition |
| **iOS** | ⭐ Full | Swift + UIKit Feedback Generators / Core Haptics |
| **macOS** | ⭐ Full (Force Touch) | Swift + NSHapticFeedbackManager |
| **Windows** | ⭐ Full (where supported) | Native Windows.Devices.Haptics API |
| **Web** | ⭐ Basic | Web Vibration API (`navigator.vibrate`) |
| **Linux** | ⭐ Backend Abstraction | Native backend capability detection |
| **Fuchsia** | Safe Fallback | Zero-crash Stub |

---

## Features

- **Semantic & Interaction API**: Direct high-level triggers (`selection`, `light`, `medium`, `heavy`, `success`, `warning`, `error`, `soft`, `rigid`, `focus`, `press`, `longPress`, `navigation`, `toggleOn`, `toggleOff`, `confirm`, `reject`, `delete`, `refresh`, `completion`, `failure`, `boundary`).
- **Capability Detection**: Detailed device telemetry via `await AiroHaptics.capabilities`.
- **Custom Pattern Engine**: Compose transient and continuous haptic pulse sequences (`AiroHapticEvent`) or use built-in wave presets (`doubleClick`, `successWave`, `errorAlert`, `heartbeat`, `rampUp`).
- **Smart Engine Controls**: Time-window throttling (`minThrottleDuration`), event coalescing for high-frequency D-pad/scroll interactions, and priority resolution (`decorative`, `normal`, `important`, `critical`).
- **Accessibility & Settings**: `AiroHapticSettings` to configure global scale, master toggle, and respect system accessibility preferences.
- **Testing Fakes**: `RecordingAiroHaptics` and `FakeAiroHaptics` in `package:airo_haptics/testing.dart`.

---

## Quick Start

```dart
import 'package:airo_haptics/airo_haptics.dart';

// Semantic feedback
await AiroHaptics.success();
await AiroHaptics.focus();
await AiroHaptics.selection();

// Physical impact shortcuts
await AiroHaptics.heavy();
await AiroHaptics.soft();

// Play a pattern
final pattern = AiroHapticPattern.doubleClick();
await AiroHaptics.play(pattern);

// Capability detection
final caps = await AiroHaptics.capabilities;
print('Native backend: ${caps.backend}');
```

---

## Testing

```dart
import 'package:airo_haptics/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verify haptic feedback recorded', () async {
    final fake = FakeAiroHaptics();
    AiroHapticsPlatform.instance = fake;

    await AiroHaptics.success();

    expect(fake.invocations.single.feedbackType, AiroHapticFeedbackType.success);
  });
}
```

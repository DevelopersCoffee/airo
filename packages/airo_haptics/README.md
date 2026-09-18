# airo_haptics

A cross-platform Flutter haptics engine with semantic feedback, custom patterns, dynamic parameter updates, ADSR continuous envelopes, Apple AHAP parsing, Haptic Sessions, tuning profiles, device capability detection, accessibility-aware behavior, and native platform optimization.

> **One Flutter API, native implementation on every eligible platform, capability-aware behavior, zero-crash fallback, excellent DX, and production-grade testing.**

## Native Platform Support Matrix

| Platform | Tier 1 Target | Native Implementation Engine |
| --- | --- | --- |
| **Android** | ⭐ Full | Kotlin + `VibratorManager` / `VibrationEffect.Composition` / Predefined Effects |
| **iOS** | ⭐ Full | Swift + `UIKitFeedbackGenerator` / `CHHapticEngine` (Reset & Dynamic Controls) |
| **macOS** | ⭐ Full | Swift + AppKit `NSHapticFeedbackManager` (Force Touch Detection) |
| **Windows** | ⭐ Full | Native C++ Plugin & WinRT Haptic Capability Detection |
| **Web** | ⭐ Basic | Web Vibration API (`navigator.vibrate` / `dart:js_interop`) |
| **Linux** | ⭐ Backend Abstraction | Native GTK backend capability detection |
| **Fuchsia** | Safe Fallback | Zero-crash Stub |

---

## Features & Tiers

- **Semantic & Interaction Shortcuts**: Direct high-level triggers (`selection`, `light`, `medium`, `heavy`, `success`, `warning`, `error`, `soft`, `rigid`, `focus`, `press`, `longPress`, `navigation`, `toggleOn`, `toggleOff`, `confirm`, `reject`, `delete`, `refresh`, `completion`, `failure`, `boundary`).
- **Dynamic Parameter Player**: Create controllable players with live intensity/sharpness updates (`player.update(intensity: 0.8, sharpness: 0.5)`).
- **Haptic Sessions**: Scoped session lifecycle ownership (`AiroHapticSession`) managing queueing, priority, throttling, coalescing, and cancellation.
- **ADSR Envelopes**: Shape continuous haptics with Attack-Decay-Sustain-Release (`AiroHapticEnvelope`).
- **AHAP & JSON Design Format**: Parse Apple AHAP design patterns (`AiroHapticPattern.fromAhap(...)`) seamlessly across all platforms.
- **Tuning Profiles**: `AiroHapticProfile` presets (`defaultProfile`, `minimal`, `gaming`, `accessibility`, `tv`, `media`, `assistant`).
- **Capability Engine**: Detailed device telemetry via `await AiroHaptics.capabilities`.
- **Testing Suite**: `FakeAiroHaptics` and assertion helpers (`expectHapticPlayed`, `expectNoHapticPlayed`, `expectHapticPatternPlayed`).

---

## Quick Start

```dart
import 'package:airo_haptics/airo_haptics.dart';

// Semantic feedback
await AiroHaptics.success();
await AiroHaptics.focus();
await AiroHaptics.selection();

// Controllable Player with Live Updates
final player = await AiroHaptics.createPlayer(AiroHapticPattern.doubleClick());
await player.start();
await player.update(intensity: 0.8, sharpness: 0.3);
player.stop();

// First-Class Haptic Session
final session = await AiroHaptics.startSession();
await session.playContinuous(
  intensity: 0.7,
  envelope: const AiroHapticEnvelope(
    attack: Duration(milliseconds: 30),
    decay: Duration(milliseconds: 80),
    sustain: 0.6,
    release: Duration(milliseconds: 150),
  ),
);
await session.stop();

// Tuning Profiles
AiroHaptics.profile = AiroHapticProfile.tv;
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

    expectHapticPlayed(fake, AiroHapticFeedbackType.success);
  });
}
```

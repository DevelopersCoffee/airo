# airo_haptics Migration Record

## Context

`airo_haptics` was created as a standalone cross-platform Flutter federated haptics engine, replacing standard platform vibration calls with a 3-layer architecture (Semantic Feedback, Physical Impact Shortcuts, Custom/Continuous Pattern Engine), capability detection, priority resolution, throttling, coalescing, and testing fakes.

## V1 Scope Definition

> **One Flutter API, native implementation on every eligible platform, capability-aware behavior, zero-crash fallback, excellent DX, and production-grade testing.**

### Native Support Matrix

| Platform | V1 Target | Native Implementation Engine |
| --- | --- | --- |
| **Android** | ⭐ Full | Kotlin + Vibrator / VibrationEffect / Composition |
| **iOS** | ⭐ Full | Swift + UIKit Feedback Generators / Core Haptics |
| **macOS** | ⭐ Full (Force Touch) | Swift + NSHapticFeedbackManager |
| **Windows** | ⭐ Full (where supported) | Native Windows.Devices.Haptics API |
| **Web** | ⭐ Basic | Web Vibration API (`navigator.vibrate`) |
| **Linux** | ⭐ Backend Abstraction | Native backend capability detection |
| **Fuchsia** | Safe Fallback | Zero-crash Stub |

## Package Architecture

1. `packages/airo_haptics_platform_interface` (v1.0.0):
   - Defines `AiroHapticsPlatform` extending `PlatformInterface`.
   - Data models: `AiroHapticCapabilities`, `AiroHapticDevicePlatform`, `AiroHapticEvent`, `AiroHapticPattern`, `AiroHapticOptions`, `AiroHapticSettings`, `AiroHapticTheme`, `AiroHapticDiagnostics`, `AiroHapticException`.
   - Engine helpers: `AiroHapticThrottle`, `AiroHapticCoalescer`, `AiroHapticResolver`, `AiroHapticPlayer`.
   - Testing fakes: `FakeAiroHapticPlatform`, `FakeAiroHaptics`, `RecordingAiroHaptics`.

2. `packages/airo_haptics` (v1.0.0):
   - Standalone open-source Flutter engine client.
   - Entry facade `AiroHaptics` with semantic & interaction shortcuts (`selection()`, `light()`, `medium()`, `heavy()`, `success()`, `warning()`, `error()`, `soft()`, `rigid()`, `focus()`, `press()`, `longPress()`, `navigation()`, `toggleOn()`, `toggleOff()`, `confirm()`, `reject()`, `delete()`, `refresh()`, `completion()`, `failure()`, `boundary()`).
   - Test helper export `testing.dart`.
   - Interactive Haptic Lab app in `example/example.dart`.

3. `packages/platform_haptics` (v1.0.0):
   - Monorepo shim package re-exporting `airo_haptics`.

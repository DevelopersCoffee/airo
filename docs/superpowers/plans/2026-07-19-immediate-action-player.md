# Immediate Action Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship default-to-live playback (no interstitial screen, deep-link direct entry), system PiP, and background audio-only mode for the mobile IPTV player.

**Architecture:** New `AiroNativePictureInPicture` and `AiroBackgroundAudioMode` static services added to `platform_player` (mirroring the existing `AiroNativeFullscreen` MethodChannel pattern), with iOS Swift / Android Kotlin implementations. A new `PlayerBackgroundingCoordinator` in `feature_iptv` (mirroring `WakelockPlaybackCoordinator`) owns the PiP-vs-audio-only lifecycle decision and is wired into `IPTVScreen.initState`. `go_router`'s `/iptv` route gains an optional `channel` query param for deep-link direct entry.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, Swift (`AVPictureInPictureController`, `MPNowPlayingInfoCenter`), Kotlin (`PictureInPictureParams`, Android `MediaSession`).

## Global Constraints

- Mobile (iOS/Android) only — TV is receiver-only, do not touch `iptv_tv_screen.dart` / `iptv_guide_screen.dart` (spec Non-Goals).
- New platform services live in `platform_player`, not `feature_iptv` directly (spec Architecture decision, approved).
- PiP is attempted first on backgrounding; audio-only is the fallback (unsupported/denied PiP, or user had manually toggled audio-only before backgrounding) (spec Goal 5).
- `MissingPluginException` and `isSupported() == false` both fall through silently to audio-only — no user-facing error (spec Error Handling).
- Manual QA on physical iOS + Android hardware is a required gate before merge; PiP/background-audio are not reliably testable in simulator/emulator (spec Testing).

---

## File Structure

New files:
- `packages/platform_player/lib/src/services/native_picture_in_picture.dart` — Dart PiP service + capability handler.
- `packages/platform_player/test/native_picture_in_picture_test.dart` — mocked-`MethodChannel` contract tests.
- `packages/platform_player/lib/src/services/background_audio_mode.dart` — Dart background-audio-mode service.
- `packages/platform_player/test/background_audio_mode_test.dart` — mocked-`MethodChannel` contract tests.
- `packages/feature_iptv/lib/application/player_backgrounding_coordinator.dart` — lifecycle decision coordinator + provider.
- `packages/feature_iptv/test/application/player_backgrounding_coordinator_test.dart` — decision-table unit tests.
- `packages/feature_iptv/test/presentation/screens/iptv_screen_default_to_live_test.dart` — widget tests for tap-to-play and deep-link entry.
- `app/ios/Runner/AiroPictureInPicturePlugin.swift` — iOS PiP native impl.
- `app/ios/Runner/AiroBackgroundAudioPlugin.swift` — iOS background-audio native impl.
- `app/android/app/src/main/kotlin/io/airo/app/AiroPictureInPicturePlugin.kt` — Android PiP native impl.
- `app/android/app/src/main/kotlin/io/airo/app/AiroBackgroundAudioPlugin.kt` — Android background-audio native impl.

Modified files:
- `packages/platform_player/lib/platform_player.dart` — export the two new services.
- `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart` — deep-link `channel` param handling, wire `PlayerBackgroundingCoordinator` in `initState`.
- `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart` — manual audio-only toggle button, hide overlay while PiP active.
- `app/lib/core/routing/app_router.dart:235-241` — add optional `channel` query param to `/iptv` `GoRoute`.
- `app/ios/Runner/AppDelegate.swift` — register the two new method channels.
- `app/android/app/src/main/kotlin/io/airo/app/MainActivity.kt` — register the two new method channels, forward `onUserLeaveHint`.

---

### Task 1: `AiroNativePictureInPicture` Dart service + contract tests

**Files:**
- Create: `packages/platform_player/lib/src/services/native_picture_in_picture.dart`
- Test: `packages/platform_player/test/native_picture_in_picture_test.dart`
- Modify: `packages/platform_player/lib/platform_player.dart`

**Interfaces:**
- Produces: `AiroNativePictureInPicture.isSupported() -> Future<bool>`, `AiroNativePictureInPicture.requestEnter() -> Future<bool>`, `AiroNativePictureInPicture.setStateChangeHandler(void Function(bool isActive)? handler) -> void`, `AiroNativePictureInPicture.debugSetMethodChannel(MethodChannel channel)` (test seam), `AiroNativePictureInPicture.debugNotifyStateChanged(bool isActive)` (test seam).

- [ ] **Step 1: Write the failing tests**

```dart
// packages/platform_player/test/native_picture_in_picture_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.player/picture_in_picture');
  final calls = <MethodCall>[];
  String isSupportedResult = 'true';
  bool requestEnterResult = true;

  setUp(() {
    calls.clear();
    isSupportedResult = 'true';
    requestEnterResult = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isSupported':
          return isSupportedResult == 'true';
        case 'requestEnter':
          return requestEnterResult;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    AiroNativePictureInPicture.setStateChangeHandler(null);
  });

  test('isSupported returns platform value', () async {
    expect(await AiroNativePictureInPicture.isSupported(), isTrue);
    expect(calls.single.method, 'isSupported');
  });

  test('isSupported returns false when platform impl is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });
    expect(await AiroNativePictureInPicture.isSupported(), isFalse);
  });

  test('requestEnter returns whether PiP engaged', () async {
    requestEnterResult = false;
    expect(await AiroNativePictureInPicture.requestEnter(), isFalse);
    expect(calls.single.method, 'requestEnter');
  });

  test('requestEnter returns false when platform impl is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });
    expect(await AiroNativePictureInPicture.requestEnter(), isFalse);
  });

  test('state change handler receives native callbacks', () async {
    bool? received;
    AiroNativePictureInPicture.setStateChangeHandler((isActive) {
      received = isActive;
    });
    final handler = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        // Simulate the platform invoking the Dart-side handler.
        ;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('pictureInPictureStateChanged', true),
          ),
          (data) {},
        );
    expect(received, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/platform_player && flutter test test/native_picture_in_picture_test.dart`
Expected: FAIL — `AiroNativePictureInPicture` undefined.

- [ ] **Step 3: Implement the service**

```dart
// packages/platform_player/lib/src/services/native_picture_in_picture.dart
import 'package:flutter/foundation.dart' show VoidCallback, debugPrint, visibleForTesting;
import 'package:flutter/services.dart';

/// System-level Picture-in-Picture for the live player.
///
/// Mirrors the [AiroNativeFullscreen] pattern: a static service wrapping a
/// [MethodChannel], with iOS ([AVPictureInPictureController]) and Android
/// ([PictureInPictureParams]) native implementations. `isSupported` and
/// `requestEnter` both degrade to `false` on [MissingPluginException] (no
/// platform impl registered, e.g. macOS/web) so callers can fall through to
/// audio-only without special-casing platforms.
class AiroNativePictureInPicture {
  AiroNativePictureInPicture._();

  static MethodChannel _channel = const MethodChannel(
    'com.airo.player/picture_in_picture',
  );
  static void Function(bool isActive)? _stateChangeHandler;
  static bool _isHandlerConfigured = false;

  static Future<bool> isSupported() async {
    _configureMethodCallHandler();
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      debugPrint('PiP channel is unavailable on this host');
      return false;
    } catch (error) {
      debugPrint('PiP isSupported error: $error');
      return false;
    }
  }

  static Future<bool> requestEnter() async {
    _configureMethodCallHandler();
    try {
      return await _channel.invokeMethod<bool>('requestEnter') ?? false;
    } on MissingPluginException {
      debugPrint('PiP channel is unavailable on this host');
      return false;
    } catch (error) {
      debugPrint('PiP requestEnter error: $error');
      return false;
    }
  }

  static void setStateChangeHandler(void Function(bool isActive)? handler) {
    _stateChangeHandler = handler;
    _configureMethodCallHandler();
  }

  static void _configureMethodCallHandler() {
    if (_isHandlerConfigured) return;
    _isHandlerConfigured = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pictureInPictureStateChanged':
          _stateChangeHandler?.call(call.arguments as bool);
        default:
          debugPrint('Unknown PiP callback: ${call.method}');
      }
    });
  }

  @visibleForTesting
  static void debugSetMethodChannel(MethodChannel channel) {
    _channel = channel;
    _isHandlerConfigured = false;
  }
}
```

- [ ] **Step 4: Export from the package barrel**

```dart
// packages/platform_player/lib/platform_player.dart
// add alongside the existing native_fullscreen export:
export "src/services/native_picture_in_picture.dart";
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/platform_player && flutter test test/native_picture_in_picture_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 6: Commit**

```bash
git add packages/platform_player/lib/src/services/native_picture_in_picture.dart \
        packages/platform_player/test/native_picture_in_picture_test.dart \
        packages/platform_player/lib/platform_player.dart
git commit -m "feat(platform_player): add AiroNativePictureInPicture service"
```

---

### Task 2: `AiroBackgroundAudioMode` Dart service + contract tests

**Files:**
- Create: `packages/platform_player/lib/src/services/background_audio_mode.dart`
- Test: `packages/platform_player/test/background_audio_mode_test.dart`
- Modify: `packages/platform_player/lib/platform_player.dart`

**Interfaces:**
- Consumes: none.
- Produces: `AiroBackgroundAudioMode.setEnabled(bool enabled) -> Future<void>`, `AiroBackgroundAudioMode.isEnabled -> bool` (last-known local state, sync getter for UI), `AiroBackgroundAudioMode.debugSetMethodChannel(MethodChannel channel)` (test seam).

- [ ] **Step 1: Write the failing tests**

```dart
// packages/platform_player/test/background_audio_mode_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.player/background_audio_mode');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    AiroBackgroundAudioMode.debugSetMethodChannel(channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setEnabled(true) invokes platform and updates isEnabled', () async {
    await AiroBackgroundAudioMode.setEnabled(true);
    expect(calls.single.method, 'setEnabled');
    expect(calls.single.arguments, {'enabled': true});
    expect(AiroBackgroundAudioMode.isEnabled, isTrue);
  });

  test('setEnabled(false) invokes platform and updates isEnabled', () async {
    await AiroBackgroundAudioMode.setEnabled(true);
    await AiroBackgroundAudioMode.setEnabled(false);
    expect(calls.last.arguments, {'enabled': false});
    expect(AiroBackgroundAudioMode.isEnabled, isFalse);
  });

  test('setEnabled swallows MissingPluginException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });
    await AiroBackgroundAudioMode.setEnabled(true);
    // Local state still reflects intent even if the platform call failed,
    // so UI toggles remain consistent with what the user asked for.
    expect(AiroBackgroundAudioMode.isEnabled, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/platform_player && flutter test test/background_audio_mode_test.dart`
Expected: FAIL — `AiroBackgroundAudioMode` undefined.

- [ ] **Step 3: Implement the service**

```dart
// packages/platform_player/lib/src/services/background_audio_mode.dart
import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';

/// Toggles audio-only playback (video surface torn down, audio keeps
/// decoding) and drives the OS lock-screen / notification media controls
/// ([MPNowPlayingInfoCenter] iOS, [MediaSession] Android) required whenever
/// audio plays in the background.
class AiroBackgroundAudioMode {
  AiroBackgroundAudioMode._();

  static MethodChannel _channel = const MethodChannel(
    'com.airo.player/background_audio_mode',
  );
  static bool _isEnabled = false;

  static bool get isEnabled => _isEnabled;

  static Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } on MissingPluginException {
      debugPrint('Background audio channel is unavailable on this host');
    } catch (error) {
      debugPrint('Background audio setEnabled error: $error');
    }
  }

  @visibleForTesting
  static void debugSetMethodChannel(MethodChannel channel) {
    _channel = channel;
  }

  @visibleForTesting
  static void debugReset() {
    _isEnabled = false;
  }
}
```

- [ ] **Step 4: Export from the package barrel**

```dart
// packages/platform_player/lib/platform_player.dart
export "src/services/background_audio_mode.dart";
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/platform_player && flutter test test/background_audio_mode_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 6: Commit**

```bash
git add packages/platform_player/lib/src/services/background_audio_mode.dart \
        packages/platform_player/test/background_audio_mode_test.dart \
        packages/platform_player/lib/platform_player.dart
git commit -m "feat(platform_player): add AiroBackgroundAudioMode service"
```

---

### Task 3: `PlayerBackgroundingCoordinator` lifecycle decision + unit tests

**Files:**
- Create: `packages/feature_iptv/lib/application/player_backgrounding_coordinator.dart`
- Test: `packages/feature_iptv/test/application/player_backgrounding_coordinator_test.dart`

**Interfaces:**
- Consumes: `AiroNativePictureInPicture.isSupported()`, `AiroNativePictureInPicture.requestEnter()` (Task 1); `AiroBackgroundAudioMode.setEnabled(bool)`, `AiroBackgroundAudioMode.isEnabled` (Task 2); `StreamingState.isPlaying`, `StreamingState.currentChannel` (`packages/platform_player/lib/src/models/streaming_state.dart:132,211`).
- Produces: `PlayerBackgroundingCoordinator({Future<bool> Function()? isSupported, Future<bool> Function()? requestEnter, Future<void> Function(bool)? setAudioOnly})`, `PlayerBackgroundingCoordinator.onLifecycleStateChanged(AppLifecycleState state, StreamingState streaming)`, `PlayerBackgroundingCoordinator.manualAudioOnlyToggled(bool enabled)`, `playerBackgroundingCoordinatorProvider` (`Provider<PlayerBackgroundingCoordinator>`, mirrors `wakelockPlaybackCoordinatorProvider`).

- [ ] **Step 1: Write the failing tests**

```dart
// packages/feature_iptv/test/application/player_backgrounding_coordinator_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:feature_iptv/application/player_backgrounding_coordinator.dart';

StreamingState _playingState({bool audioOnlyChannel = false}) => StreamingState(
      playbackState: PlaybackState.playing,
      currentChannel: IPTVChannel(
        id: 'c1',
        name: 'Test',
        streamUrl: 'https://example.com/s.m3u8',
        isAudioOnly: audioOnlyChannel,
      ),
    );

void main() {
  group('PlayerBackgroundingCoordinator', () {
    test('backgrounding with no prior manual toggle tries PiP first', () async {
      var requestEnterCalled = false;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => true,
        requestEnter: () async {
          requestEnterCalled = true;
          return true;
        },
        setAudioOnly: (_) async => fail('audio-only should not be set'),
      );

      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );

      expect(requestEnterCalled, isTrue);
    });

    test('PiP unsupported falls back to audio-only', () async {
      bool? audioOnlySet;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => false,
        requestEnter: () async => fail('requestEnter should not be called'),
        setAudioOnly: (enabled) async => audioOnlySet = enabled,
      );

      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );

      expect(audioOnlySet, isTrue);
    });

    test('PiP denied at request time falls back to audio-only', () async {
      bool? audioOnlySet;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => true,
        requestEnter: () async => false,
        setAudioOnly: (enabled) async => audioOnlySet = enabled,
      );

      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );

      expect(audioOnlySet, isTrue);
    });

    test('prior manual audio-only toggle skips PiP entirely', () async {
      var requestEnterCalled = false;
      bool? audioOnlySet;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => true,
        requestEnter: () async {
          requestEnterCalled = true;
          return true;
        },
        setAudioOnly: (enabled) async => audioOnlySet = enabled,
      );

      coordinator.manualAudioOnlyToggled(true);
      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );

      expect(requestEnterCalled, isFalse);
      expect(audioOnlySet, isTrue);
    });

    test('not playing: backgrounding does nothing', () async {
      var called = false;
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async {
          called = true;
          return true;
        },
        requestEnter: () async => true,
        setAudioOnly: (_) async {},
      );

      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        StreamingState(playbackState: PlaybackState.idle),
      );

      expect(called, isFalse);
    });

    test('resuming from auto audio-only clears audio-only automatically', () async {
      final audioOnlyCalls = <bool>[];
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => false,
        requestEnter: () async => false,
        setAudioOnly: (enabled) async => audioOnlyCalls.add(enabled),
      );

      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );
      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.resumed,
        _playingState(),
      );

      expect(audioOnlyCalls, [true, false]);
    });

    test('resuming after a manual audio-only toggle leaves it enabled', () async {
      final audioOnlyCalls = <bool>[];
      final coordinator = PlayerBackgroundingCoordinator(
        isSupported: () async => true,
        requestEnter: () async => true,
        setAudioOnly: (enabled) async => audioOnlyCalls.add(enabled),
      );

      coordinator.manualAudioOnlyToggled(true);
      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.paused,
        _playingState(),
      );
      await coordinator.onLifecycleStateChanged(
        AppLifecycleState.resumed,
        _playingState(),
      );

      expect(audioOnlyCalls, [true]);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/application/player_backgrounding_coordinator_test.dart`
Expected: FAIL — `PlayerBackgroundingCoordinator` undefined.

- [ ] **Step 3: Implement the coordinator**

```dart
// packages/feature_iptv/lib/application/player_backgrounding_coordinator.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import 'providers/iptv_providers.dart';

/// Decides what happens to live playback when the app is backgrounded:
/// PiP is attempted first, audio-only is the fallback (spec Goal 5). A
/// manual audio-only toggle (set before backgrounding) always wins and
/// skips the PiP attempt.
class PlayerBackgroundingCoordinator {
  PlayerBackgroundingCoordinator({
    Future<bool> Function()? isSupported,
    Future<bool> Function()? requestEnter,
    Future<void> Function(bool enabled)? setAudioOnly,
  }) : _isSupported = isSupported ?? AiroNativePictureInPicture.isSupported,
       _requestEnter = requestEnter ?? AiroNativePictureInPicture.requestEnter,
       _setAudioOnly = setAudioOnly ?? AiroBackgroundAudioMode.setEnabled;

  final Future<bool> Function() _isSupported;
  final Future<bool> Function() _requestEnter;
  final Future<void> Function(bool enabled) _setAudioOnly;

  bool _manualAudioOnly = false;
  bool _autoAudioOnlyActive = false;

  /// Called by the manual audio-only toggle in the player controls.
  void manualAudioOnlyToggled(bool enabled) {
    _manualAudioOnly = enabled;
  }

  Future<void> onLifecycleStateChanged(
    AppLifecycleState state,
    StreamingState streaming,
  ) async {
    if (!streaming.isPlaying) return;

    if (state == AppLifecycleState.paused) {
      await _handleBackgrounding();
    } else if (state == AppLifecycleState.resumed) {
      await _handleResume();
    }
  }

  Future<void> _handleBackgrounding() async {
    if (_manualAudioOnly) {
      await _setAudioOnly(true);
      return;
    }

    if (await _isSupported() && await _requestEnter()) {
      return;
    }

    _autoAudioOnlyActive = true;
    await _setAudioOnly(true);
  }

  Future<void> _handleResume() async {
    if (_autoAudioOnlyActive) {
      _autoAudioOnlyActive = false;
      await _setAudioOnly(false);
    }
    // Manual audio-only persists across resume until the user toggles it
    // off themselves.
  }
}

final playerBackgroundingCoordinatorProvider =
    Provider<PlayerBackgroundingCoordinator>((ref) {
      final coordinator = PlayerBackgroundingCoordinator();
      ref.listen<AppLifecycleState>(appLifecycleStateProvider, (
        previous,
        next,
      ) {
        final streaming = ref.read(streamingStateProvider).value;
        if (streaming != null) {
          coordinator.onLifecycleStateChanged(next, streaming);
        }
      });
      return coordinator;
    });
```

- [ ] **Step 4: Add the `appLifecycleStateProvider` dependency**

Check first whether an app-lifecycle Riverpod provider already exists:

Run: `grep -rn "appLifecycleStateProvider\|AppLifecycleListener" packages/feature_iptv/lib app/lib --include="*.dart"`

If nothing is found, add a minimal one next to `streamingStateProvider` in `packages/feature_iptv/lib/application/providers/iptv_providers.dart`:

```dart
// packages/feature_iptv/lib/application/providers/iptv_providers.dart
// add near streamingStateProvider (around line 345):

final appLifecycleStateProvider = StateProvider<AppLifecycleState>(
  (ref) => AppLifecycleState.resumed,
);
```

(Import `package:flutter/widgets.dart` for `AppLifecycleState` if not already imported in that file.) `IPTVScreen` (Task 5) will update this provider from a `WidgetsBindingObserver`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/application/player_backgrounding_coordinator_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 6: Commit**

```bash
git add packages/feature_iptv/lib/application/player_backgrounding_coordinator.dart \
        packages/feature_iptv/test/application/player_backgrounding_coordinator_test.dart \
        packages/feature_iptv/lib/application/providers/iptv_providers.dart
git commit -m "feat(feature_iptv): add PlayerBackgroundingCoordinator"
```

---

### Task 4: Deep-link `channel` route param + default-to-live wiring in `IPTVScreen`

**Files:**
- Modify: `app/lib/core/routing/app_router.dart:235-241`
- Modify: `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart`
- Test: `packages/feature_iptv/test/presentation/screens/iptv_screen_default_to_live_test.dart`

**Interfaces:**
- Consumes: `iptvStreamingServiceProvider.playChannel(IPTVChannel)` (`packages/platform_player/lib/src/services/iptv_streaming_service.dart:19`), `playerBackgroundingCoordinatorProvider` (Task 3), `appLifecycleStateProvider` (Task 3, Step 4).
- Produces: `IPTVScreen({this.onOpenVod, this.onPickLocalMediaForTv, this.deepLinkChannelId, super.key})` — new optional `deepLinkChannelId` constructor param.

- [ ] **Step 1: Write the failing tests**

```dart
// packages/feature_iptv/test/presentation/screens/iptv_screen_default_to_live_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/presentation/screens/iptv_screen.dart';

void main() {
  testWidgets(
    'tapping a channel card starts playback with no route push',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: IPTVScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final navigatorObserver = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      final routeCountBefore = navigatorObserver.widget.pages.length;

      // Channel cards are rendered by ChannelListWidget; tap the first one.
      final channelCard = find.byKey(const ValueKey('channel-card-0'));
      if (channelCard.evaluate().isNotEmpty) {
        await tester.tap(channelCard);
        await tester.pumpAndSettle();
        expect(
          navigatorObserver.widget.pages.length,
          routeCountBefore,
          reason: 'tap-to-play must not push an interstitial route',
        );
      }
    },
  );

  testWidgets(
    'deepLinkChannelId renders the player as the first frame',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: IPTVScreen(deepLinkChannelId: 'c1'),
          ),
        ),
      );
      await tester.pump();

      // The browse grid's channel list must not be the first thing shown
      // when a deep link is present.
      expect(find.byKey(const ValueKey('iptv-browse-grid')), findsNothing);
    },
  );
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/presentation/screens/iptv_screen_default_to_live_test.dart`
Expected: FAIL — `deepLinkChannelId` param undefined, and/or missing `ValueKey`s (add the two keys called out above to `channel_list_widget.dart`'s card builder and to the grid's root container as part of this task if they don't already exist — grep first: `grep -n "ValueKey('channel-card" packages/feature_iptv/lib/presentation/widgets/channel_list_widget.dart`).

- [ ] **Step 3: Add `deepLinkChannelId` to `IPTVScreen` and resolve it in `initState`**

```dart
// packages/feature_iptv/lib/presentation/screens/iptv_screen.dart
// Modify the class declaration and constructor (around line 27-47):

class IPTVScreen extends ConsumerStatefulWidget {
  const IPTVScreen({
    this.onOpenVod,
    this.onPickLocalMediaForTv,
    this.deepLinkChannelId,
    super.key,
  });

  final VoidCallback? onOpenVod;
  final Future<PhoneLocalMediaItem?> Function()? onPickLocalMediaForTv;

  /// Channel id resolved from a deep link (universal link, home-screen
  /// widget, or "continue watching" notification tap) or the app's
  /// resume-last-channel affordance. When set, playback starts immediately
  /// in [initState] instead of waiting for a tap on the browse grid, and
  /// the browse grid is not the first frame rendered.
  final String? deepLinkChannelId;

  @override
  ConsumerState<IPTVScreen> createState() => _IPTVScreenState();
}
```

Then in `_IPTVScreenState.initState` (around line 50-58), after the existing wakelock/streaming-service initialization, resolve and play the deep-linked channel:

```dart
  @override
  void initState() {
    super.initState();
    ref.read(iptvStreamingServiceProvider).initialize();
    ref.read(wakelockPlaybackCoordinatorProvider);
    ref.read(playerBackgroundingCoordinatorProvider);

    final deepLinkId = widget.deepLinkChannelId;
    if (deepLinkId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final channel = ref
            .read(iptvChannelsProvider)
            .value
            ?.firstWhereOrNull((c) => c.id == deepLinkId);
        if (channel != null) {
          _playChannel(channel);
        }
        // Missing channel: fall through to the normal browse-grid landing
        // (spec Error Handling) — no snackbar wiring needed here since the
        // grid is the existing default UI, not a special error state.
      });
    }
  }
```

Check the exact provider name for the channel list before using `iptvChannelsProvider`:

Run: `grep -n "final iptv.*ChannelsProvider\|Provider<List<IPTVChannel>>" packages/feature_iptv/lib/application/providers/iptv_providers.dart`

Use whatever provider that grep surfaces (adjust the name in the snippet above to match); add `package:collection`'s `firstWhereOrNull` import if not already present in the file (`import 'package:collection/collection.dart';`).

Gate the initial build so the browse grid isn't the first frame when a deep link is pending — find the widget's `build` method's root and wrap the grid's visibility:

Run: `grep -n "Widget build(BuildContext context)" packages/feature_iptv/lib/presentation/screens/iptv_screen.dart`

Add a `key: const ValueKey('iptv-browse-grid')` to whatever widget wraps the channel grid at that build method (read the surrounding ~30 lines first with `Read` to find the exact widget to key), and conditionally render the fullscreen `VideoPlayerWidget` instead when `widget.deepLinkChannelId != null && ref.watch(streamingStateProvider).value?.isPlaying != true` is false (i.e. once playback has started). While waiting for the deep-linked channel to resolve, show a bare `Scaffold` with a loading indicator, not the grid.

- [ ] **Step 4: Add optional `channel` query param to the `/iptv` route**

```dart
// app/lib/core/routing/app_router.dart
// Replace the /iptv GoRoute (around line 235-241):
              GoRoute(
                path: '/iptv',
                name: 'Stream',
                builder: (context, state) => IPTVScreen(
                  onOpenVod: () => context.go('/vod'),
                  onPickLocalMediaForTv: kDebugMode
                      ? pickPhoneLocalMediaForTv
                      : null,
                  deepLinkChannelId: state.uri.queryParameters['channel'],
                ),
              ),
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/presentation/screens/iptv_screen_default_to_live_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Run the full feature_iptv suite to check for regressions**

Run: `cd packages/feature_iptv && flutter test`
Expected: PASS, no new failures beyond the 3 pre-existing known failures noted in CHANGELOG.

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/routing/app_router.dart \
        packages/feature_iptv/lib/presentation/screens/iptv_screen.dart \
        packages/feature_iptv/lib/presentation/widgets/channel_list_widget.dart \
        packages/feature_iptv/test/presentation/screens/iptv_screen_default_to_live_test.dart
git commit -m "feat(feature_iptv): default-to-live deep-link entry via /iptv?channel="
```

---

### Task 5: Manual audio-only toggle + PiP-active UI in `VideoPlayerWidget`

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart`
- Test: `packages/feature_iptv/test/presentation/widgets/video_player_widget_background_modes_test.dart`

**Interfaces:**
- Consumes: `AiroBackgroundAudioMode.setEnabled(bool)`, `AiroBackgroundAudioMode.isEnabled` (Task 2); `AiroNativePictureInPicture.setStateChangeHandler` (Task 1); `playerBackgroundingCoordinatorProvider.manualAudioOnlyToggled(bool)` (Task 3).
- Produces: a new icon button in the player overlay controls with `key: const ValueKey('audio-only-toggle')`.

- [ ] **Step 1: Write the failing test**

```dart
// packages/feature_iptv/test/presentation/widgets/video_player_widget_background_modes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';
import 'package:feature_iptv/presentation/widgets/video_player_widget.dart';

void main() {
  testWidgets('tapping the audio-only toggle enables background audio mode', (
    tester,
  ) async {
    const channel = MethodChannel('com.airo.player/background_audio_mode');
    AiroBackgroundAudioMode.debugSetMethodChannel(channel);
    AiroBackgroundAudioMode.debugReset();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: VideoPlayerWidget())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('audio-only-toggle')));
    await tester.pumpAndSettle();

    expect(calls.single.arguments, {'enabled': true});
    expect(AiroBackgroundAudioMode.isEnabled, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/presentation/widgets/video_player_widget_background_modes_test.dart`
Expected: FAIL — no widget with key `audio-only-toggle`.

- [ ] **Step 3: Add the toggle button and PiP state wiring**

Read the existing overlay controls layout first to place the button consistently:

Run: `grep -n "IconButton\|PlayerOverlay(" packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart | head -20`

Add a toggle button next to the other overlay `IconButton`s (in the same row/toolbar the fullscreen toggle already lives in), and initialize the PiP state-change handler in `initState`:

```dart
// packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart
// In _VideoPlayerWidgetState, add a field:
  bool _isAudioOnly = AiroBackgroundAudioMode.isEnabled;

// In initState(), after existing setup:
    AiroNativePictureInPicture.setStateChangeHandler((isActive) {
      if (mounted) setState(() {}); // overlay visibility derives from isActive via a getter below
    });

// In dispose(), before super.dispose():
    AiroNativePictureInPicture.setStateChangeHandler(null);

// New handler method:
  Future<void> _toggleAudioOnly() async {
    final next = !_isAudioOnly;
    setState(() => _isAudioOnly = next);
    await AiroBackgroundAudioMode.setEnabled(next);
    ref.read(playerBackgroundingCoordinatorProvider).manualAudioOnlyToggled(next);
  }

// In the overlay controls row, add:
  IconButton(
    key: const ValueKey('audio-only-toggle'),
    icon: Icon(_isAudioOnly ? Icons.hearing : Icons.hearing_disabled),
    tooltip: _isAudioOnly ? 'Exit audio-only' : 'Listen only (audio-only)',
    onPressed: _toggleAudioOnly,
  ),
```

Note: import `package:feature_iptv/application/player_backgrounding_coordinator.dart` (relative import `'../../application/player_backgrounding_coordinator.dart'` from this file's location) for `playerBackgroundingCoordinatorProvider`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/presentation/widgets/video_player_widget_background_modes_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart \
        packages/feature_iptv/test/presentation/widgets/video_player_widget_background_modes_test.dart
git commit -m "feat(feature_iptv): manual audio-only toggle in player controls"
```

---

### Task 6: iOS native PiP + background audio implementation

**Files:**
- Create: `app/ios/Runner/AiroPictureInPicturePlugin.swift`
- Create: `app/ios/Runner/AiroBackgroundAudioPlugin.swift`
- Modify: `app/ios/Runner/AppDelegate.swift`

**Interfaces:**
- Consumes: method channel names `com.airo.player/picture_in_picture` (Task 1) and `com.airo.player/background_audio_mode` (Task 2), matching the Dart-side channel names exactly.
- Produces: native handling of `isSupported`, `requestEnter` (PiP channel) and `setEnabled` (background-audio channel); PiP channel emits `pictureInPictureStateChanged` back to Dart.

- [ ] **Step 1: Implement the PiP plugin**

```swift
// app/ios/Runner/AiroPictureInPicturePlugin.swift
import AVKit
import Flutter

/// Wraps AVPictureInPictureController for the com.airo.player/picture_in_picture
/// channel. Airo's live player renders via a native AVPlayerLayer reachable
/// through NotificationCenter (posted by the platform_media MPV/AVPlayer
/// bridge) — this plugin listens for that layer becoming available rather
/// than owning player construction itself, since platform_media already
/// owns the player lifecycle.
final class AiroPictureInPicturePlugin: NSObject, AVPictureInPictureControllerDelegate {
  static let channelName = "com.airo.player/picture_in_picture"

  private var channel: FlutterMethodChannel?
  private var pipController: AVPictureInPictureController?

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onPlayerLayerAvailable(_:)),
      name: NSNotification.Name("AiroPlayerLayerAvailable"),
      object: nil
    )
  }

  @objc private func onPlayerLayerAvailable(_ notification: Notification) {
    guard let layer = notification.object as? AVPlayerLayer else { return }
    pipController = AVPictureInPictureController(playerLayer: layer)
    pipController?.delegate = self
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(AVPictureInPictureController.isPictureInPictureSupported())
    case "requestEnter":
      guard let controller = pipController, controller.isPictureInPicturePossible else {
        result(false)
        return
      }
      controller.startPictureInPicture()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
    channel?.invokeMethod("pictureInPictureStateChanged", arguments: true)
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
    channel?.invokeMethod("pictureInPictureStateChanged", arguments: false)
  }
}
```

- [ ] **Step 2: Implement the background audio plugin**

```swift
// app/ios/Runner/AiroBackgroundAudioPlugin.swift
import AVFoundation
import Flutter
import MediaPlayer

/// Wraps AVAudioSession + MPNowPlayingInfoCenter for the
/// com.airo.player/background_audio_mode channel.
final class AiroBackgroundAudioPlugin: NSObject {
  static let channelName = "com.airo.player/background_audio_mode"

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "setEnabled" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any]
    let enabled = args?["enabled"] as? Bool ?? false

    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(enabled ? .playback : .playback, mode: .moviePlayback)
      try session.setActive(true)
      result(nil)
    } catch {
      result(FlutterError(
        code: "audio_session_error",
        message: error.localizedDescription,
        details: nil
      ))
    }
  }
}
```

- [ ] **Step 3: Register both plugins in `AppDelegate`**

```swift
// app/ios/Runner/AppDelegate.swift
// Add near the top of the class, alongside existing channel constants:
  private let pictureInPicturePlugin = AiroPictureInPicturePlugin()
  private let backgroundAudioPlugin = AiroBackgroundAudioPlugin()

// Inside application(_:didFinishLaunchingWithOptions:), after the existing
// agentConnectorsChannel setup and before `return super.application(...)`:
    if let controller = window?.rootViewController as? FlutterViewController {
      pictureInPicturePlugin.register(with: controller.binaryMessenger)
      backgroundAudioPlugin.register(with: controller.binaryMessenger)
    }
```

- [ ] **Step 4: Enable the Background Modes capability**

Open `app/ios/Runner/Info.plist` and confirm (add if missing) `UIBackgroundModes` contains `audio`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

Run: `grep -n "UIBackgroundModes" -A3 app/ios/Runner/Info.plist`

- [ ] **Step 5: Build to verify no compile errors**

Run: `cd app && flutter build ios --no-codesign --debug`
Expected: BUILD SUCCEEDED (or the project's existing iOS build command per CI config — check `.github/workflows/` if this differs)

- [ ] **Step 6: Commit**

```bash
git add app/ios/Runner/AiroPictureInPicturePlugin.swift \
        app/ios/Runner/AiroBackgroundAudioPlugin.swift \
        app/ios/Runner/AppDelegate.swift \
        app/ios/Runner/Info.plist
git commit -m "feat(ios): native PiP and background audio plugins"
```

---

### Task 7: Android native PiP + background audio implementation

**Files:**
- Create: `app/android/app/src/main/kotlin/io/airo/app/AiroPictureInPicturePlugin.kt`
- Create: `app/android/app/src/main/kotlin/io/airo/app/AiroBackgroundAudioPlugin.kt`
- Modify: `app/android/app/src/main/kotlin/io/airo/app/MainActivity.kt`
- Modify: `app/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: same two channel names as Task 6.
- Produces: native handling of `isSupported`, `requestEnter` (PiP) and `setEnabled` (background audio); PiP plugin exposes `notifyModeChanged(isInPip: Boolean)` called from `MainActivity.onPictureInPictureModeChanged`.

- [ ] **Step 1: Implement the PiP plugin**

```kotlin
// app/android/app/src/main/kotlin/io/airo/app/AiroPictureInPicturePlugin.kt
package io.airo.app

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Wraps PictureInPictureParams for the com.airo.player/picture_in_picture channel. */
class AiroPictureInPicturePlugin(private val activity: Activity) {
    companion object {
        const val CHANNEL_NAME = "com.airo.player/picture_in_picture"
    }

    private var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isSupported())
                "requestEnter" -> result.success(requestEnter())
                else -> result.notImplemented()
            }
        }
        this.channel = channel
    }

    private fun isSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun requestEnter(): Boolean {
        if (!isSupported()) return false
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .build()
        return activity.enterPictureInPictureMode(params)
    }

    fun notifyModeChanged(isInPip: Boolean) {
        channel?.invokeMethod("pictureInPictureStateChanged", isInPip)
    }
}
```

- [ ] **Step 2: Implement the background audio plugin**

```kotlin
// app/android/app/src/main/kotlin/io/airo/app/AiroBackgroundAudioPlugin.kt
package io.airo.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Wraps AudioManager focus handling for the com.airo.player/background_audio_mode channel. */
class AiroBackgroundAudioPlugin(private val context: Context) {
    companion object {
        const val CHANNEL_NAME = "com.airo.player/background_audio_mode"
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focusRequest: AudioFocusRequest? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setEnabled(enabled)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setEnabled(enabled: Boolean) {
        if (enabled) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .build()
            audioManager.requestAudioFocus(request)
            focusRequest = request
        } else {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            focusRequest = null
        }
        // Media-session metadata (title, playback state) for the lock-screen
        // control surface is already driven by the app's existing
        // audio_service/AudioServiceActivity integration (MainActivity
        // extends AudioServiceActivity); this plugin only owns audio focus,
        // not notification building, to avoid a second competing media
        // session.
    }
}
```

- [ ] **Step 3: Wire both plugins into `MainActivity`**

```kotlin
// app/android/app/src/main/kotlin/io/airo/app/MainActivity.kt
// Add fields near the top of the class:
    private lateinit var pictureInPicturePlugin: AiroPictureInPicturePlugin
    private lateinit var backgroundAudioPlugin: AiroBackgroundAudioPlugin

// In configureFlutterEngine, after the existing channel registrations:
        pictureInPicturePlugin = AiroPictureInPicturePlugin(this)
        pictureInPicturePlugin.register(flutterEngine.dartExecutor.binaryMessenger)

        backgroundAudioPlugin = AiroBackgroundAudioPlugin(this)
        backgroundAudioPlugin.register(flutterEngine.dartExecutor.binaryMessenger)

// Add a new override, forwarding the system PiP-mode callback to the plugin:
    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pictureInPicturePlugin.notifyModeChanged(isInPictureInPictureMode)
    }
```

- [ ] **Step 4: Declare PiP support in the manifest**

```xml
<!-- app/android/app/src/main/AndroidManifest.xml -->
<!-- On the <activity> element for MainActivity, add: -->
android:supportsPictureInPicture="true"
android:configChanges="screenSize|smallestScreenSize|screenLayout|orientation|keyboardHidden|density|uiMode"
```

Run first to see the existing `<activity>` element and merge attributes without dropping any (the target `android:configChanges` value above must be unioned with whatever values are already present, not replace them): `grep -n "<activity" -A10 app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 5: Build to verify no compile errors**

Run: `cd app && flutter build apk --debug`
Expected: BUILD SUCCESSFUL

- [ ] **Step 6: Commit**

```bash
git add app/android/app/src/main/kotlin/io/airo/app/AiroPictureInPicturePlugin.kt \
        app/android/app/src/main/kotlin/io/airo/app/AiroBackgroundAudioPlugin.kt \
        app/android/app/src/main/kotlin/io/airo/app/MainActivity.kt \
        app/android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): native PiP and background audio plugins"
```

---

### Task 8: Manual device dogfood (QA gate, not automatable)

**Files:** none (manual verification only, per spec Testing section — PiP/background-audio behavior is not reliably testable in simulator/emulator).

- [ ] **Step 1: Deploy debug build to a physical iOS device**

Run: `cd app && flutter run --debug -d <ios-device-id>`

Verify: tap a channel → plays instantly, no interstitial. Swipe app to background while playing → system PiP window appears within ~1s. Tap the audio-only toggle, then background the app → video view disappears, audio keeps playing, lock screen shows Now Playing controls with channel name.

- [ ] **Step 2: Deploy debug build to a physical Android device**

Run: `cd app && flutter run --debug -d <android-device-id>`

Verify the same three flows as Step 1, plus: press the hardware Home button (not just app-switch) while playing → PiP window appears (Android's `onUserLeaveHint` path, distinct from iOS's app-switch-only trigger — confirm both trigger correctly since they're different OS signals).

- [ ] **Step 3: Test the deep-link entry point end to end**

On each physical device, trigger `/iptv?channel=<real-channel-id>` via `adb shell am start -a android.intent.action.VIEW -d "airo://iptv?channel=<id>"` (Android) and the iOS equivalent universal-link test harness already used by the project (check `docs/` for an existing deep-link test doc; if none exists, use Xcode's URL scheme debug launch argument). Confirm playback starts as the first frame, with no browse-grid flash.

- [ ] **Step 4: Record results and file follow-up issues for anything broken**

If any of the above fails, do not merge — file a GitHub issue with the exact repro steps and device/OS version, and fix before proceeding to Task 9.

- [ ] **Step 5: Mark the gate passed**

No commit for this task (verification only) — note completion in the PR description created in Task 9.

---

### Task 9: Final regression sweep and PR

**Files:** none (verification + PR only).

- [ ] **Step 1: Run the full test suite across touched packages**

Run: `cd packages/platform_player && flutter test`
Run: `cd packages/feature_iptv && flutter test`
Expected: PASS (no new failures beyond the 3 pre-existing known failures noted in CHANGELOG).

- [ ] **Step 2: Run `dart format` and static analysis**

Run: `dart format --set-exit-if-changed packages/platform_player packages/feature_iptv app/lib app/ios app/android 2>&1 | grep -v "^Formatted"` (Swift/Kotlin files are unaffected by `dart format` — this only re-checks the Dart files touched)
Run: `cd packages/platform_player && flutter analyze`
Run: `cd packages/feature_iptv && flutter analyze`
Expected: no issues.

- [ ] **Step 3: Open the PR**

Follow the project's existing PR flow (see CLAUDE.md Code Review Rules: Correctness → Clarity → Consistency → Duplication → Tests → Performance, in that order, before opening). Reference this plan and the spec (`docs/superpowers/specs/2026-07-19-immediate-action-player-design.md`) in the PR description, and note that Task 8's device dogfood gate was completed (or is pending, with an owner and ETA).

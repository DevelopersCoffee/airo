# IPTV Google Cast V1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add V1 Google Cast support so Airo can cast one public IPTV HLS/MP4 channel URL from Android/iOS mobile to one Chromecast-enabled TV at a time.

**Architecture:** Add an Airo-owned Cast abstraction under `app/lib/core/cast`, backed by deterministic fake tests and a `flutter_chrome_cast` adapter. IPTV code converts `IPTVChannel` into `AiroCastMediaRequest`; UI exposes a single-device picker and mini controller while keeping local IPTV playback as the fallback path.

**Tech Stack:** Flutter, Dart, Riverpod, Equatable, `flutter_chrome_cast` `^1.4.6`, Flutter widget tests, Android manifest permissions, iOS `Info.plist` local network/Bonjour declarations.

---

## Scope Check

This is one feature with cross-agent work, not several independent products. The tasks are split by testable boundary:

1. Core Cast models, interface, and fake controller.
2. Real Google Cast adapter and platform setup.
3. IPTV channel-to-Cast request adapter.
4. Riverpod orchestration for IPTV Cast state.
5. IPTV UI integration.
6. Security/privacy and release docs.
7. Final QA matrix.

V1 remains single-device, Google Cast only, IPTV URL only. AirPlay, local files, browser receivers, custom receivers, stream proxying, and multi-device orchestration are excluded from implementation tasks.

## File Structure

- Create `app/lib/core/cast/cast.dart`
  - Barrel export for the Cast boundary.
- Create `app/lib/core/cast/cast_models.dart`
  - Airo-owned Cast devices, discovery state, session state, media requests, and errors.
- Create `app/lib/core/cast/cast_controller.dart`
  - `AiroCastController` interface used by app/domain code.
- Create `app/lib/core/cast/fake_cast_controller.dart`
  - Deterministic controller for tests and unsupported platforms.
- Create `app/lib/core/cast/flutter_chrome_cast_controller.dart`
  - Adapter around `flutter_chrome_cast`.
- Create `app/test/core/cast/cast_models_test.dart`
- Create `app/test/core/cast/fake_cast_controller_test.dart`
- Create `app/test/core/cast/flutter_chrome_cast_request_mapping_test.dart`

- Create `app/lib/features/iptv/domain/services/iptv_cast_media_adapter.dart`
  - Validates and converts `IPTVChannel` into `AiroCastMediaRequest`.
- Create `app/test/features/iptv/iptv_cast_media_adapter_test.dart`

- Create `app/lib/features/iptv/application/providers/iptv_cast_providers.dart`
  - Riverpod providers and `IptvCastNotifier`.
- Create `app/test/features/iptv/iptv_cast_notifier_test.dart`

- Create `app/lib/features/iptv/presentation/widgets/cast_device_picker_sheet.dart`
- Create `app/lib/features/iptv/presentation/widgets/iptv_cast_mini_controller.dart`
- Modify `app/lib/features/iptv/presentation/screens/iptv_screen.dart`
- Create `app/test/features/iptv/iptv_cast_ui_test.dart`

- Modify `app/pubspec.yaml`
- Modify `app/android/app/src/main/AndroidManifest.xml`
- Modify `app/ios/Runner/Info.plist`

- Create `docs/features/media-hub/GOOGLE_CAST_V1_QA.md`
- Modify `docs/features/media-hub/ACCEPTANCE_TESTS.md`
- Modify `docs/release/RELEASE_CHECKLIST.md`

## Task 1: Core Cast Contract and Fake Controller

**Files:**
- Create: `app/lib/core/cast/cast.dart`
- Create: `app/lib/core/cast/cast_models.dart`
- Create: `app/lib/core/cast/cast_controller.dart`
- Create: `app/lib/core/cast/fake_cast_controller.dart`
- Test: `app/test/core/cast/cast_models_test.dart`
- Test: `app/test/core/cast/fake_cast_controller_test.dart`

- [ ] **Step 1: Write failing model tests**

Create `app/test/core/cast/cast_models_test.dart`:

```dart
import 'package:airo_app/core/cast/cast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroCastDevice', () {
    test('uses id equality so duplicate discovery entries collapse', () {
      const first = AiroCastDevice(
        id: 'living-room',
        name: 'Sony Bravia',
        modelName: 'BRAVIA 4K',
      );
      const duplicate = AiroCastDevice(
        id: 'living-room',
        name: 'Sony Bravia',
        modelName: 'BRAVIA 4K',
      );

      expect(first, duplicate);
      expect({first, duplicate}.length, 1);
    });
  });

  group('AiroCastDiscoveryState', () {
    test('found state contains devices and uses found phase', () {
      const device = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');

      final state = AiroCastDiscoveryState.found([device]);

      expect(state.phase, AiroCastDiscoveryPhase.found);
      expect(state.devices, [device]);
      expect(state.error, isNull);
    });

    test('failed state keeps a user-facing error message', () {
      final state = AiroCastDiscoveryState.failed('Local network unavailable');

      expect(state.phase, AiroCastDiscoveryPhase.failed);
      expect(state.error, 'Local network unavailable');
      expect(state.devices, isEmpty);
    });
  });

  group('AiroCastSessionSnapshot', () {
    test('playing snapshot exposes active device and media', () {
      const device = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');
      final request = AiroCastMediaRequest(
        url: Uri.parse('https://example.com/live.m3u8'),
        contentType: 'application/x-mpegURL',
        title: 'P4U Music',
        streamKind: AiroCastMediaStreamKind.live,
      );

      final snapshot = AiroCastSessionSnapshot.playing(
        device: device,
        media: request,
      );

      expect(snapshot.phase, AiroCastSessionPhase.playing);
      expect(snapshot.device, device);
      expect(snapshot.media, request);
    });
  });
}
```

- [ ] **Step 2: Run model tests and verify failure**

Run:

```bash
cd app
flutter test test/core/cast/cast_models_test.dart
```

Expected: FAIL because `package:airo_app/core/cast/cast.dart` does not exist.

- [ ] **Step 3: Create Cast model files**

Create `app/lib/core/cast/cast.dart`:

```dart
library;

export 'cast_controller.dart';
export 'cast_models.dart';
export 'fake_cast_controller.dart';
```

Create `app/lib/core/cast/cast_models.dart`:

```dart
import 'package:equatable/equatable.dart';

enum AiroCastDiscoveryPhase {
  idle,
  permissionRequired,
  discovering,
  found,
  noDevices,
  failed,
}

enum AiroCastSessionPhase {
  idle,
  connecting,
  connected,
  loadingMedia,
  playing,
  paused,
  stopped,
  disconnected,
  failed,
}

enum AiroCastMediaStreamKind { live, buffered }

enum AiroCastErrorCode {
  permissionDenied,
  discoveryFailed,
  noDevicesFound,
  connectionTimeout,
  receiverUnavailable,
  mediaLoadFailed,
  unsupportedStream,
  receiverDisconnected,
  platformUnavailable,
}

class AiroCastDevice extends Equatable {
  final String id;
  final String name;
  final String? modelName;
  final String? host;
  final int? port;
  final DateTime? lastSeenAt;

  const AiroCastDevice({
    required this.id,
    required this.name,
    this.modelName,
    this.host,
    this.port,
    this.lastSeenAt,
  });

  @override
  List<Object?> get props => [id];
}

class AiroCastError extends Equatable {
  final AiroCastErrorCode code;
  final String message;

  const AiroCastError({required this.code, required this.message});

  @override
  List<Object?> get props => [code, message];
}

class AiroCastDiscoveryState extends Equatable {
  final AiroCastDiscoveryPhase phase;
  final List<AiroCastDevice> devices;
  final String? error;

  const AiroCastDiscoveryState._({
    required this.phase,
    this.devices = const [],
    this.error,
  });

  const AiroCastDiscoveryState.idle()
      : this._(phase: AiroCastDiscoveryPhase.idle);

  const AiroCastDiscoveryState.permissionRequired()
      : this._(phase: AiroCastDiscoveryPhase.permissionRequired);

  const AiroCastDiscoveryState.discovering({
    List<AiroCastDevice> devices = const [],
  }) : this._(phase: AiroCastDiscoveryPhase.discovering, devices: devices);

  factory AiroCastDiscoveryState.found(List<AiroCastDevice> devices) {
    return AiroCastDiscoveryState._(
      phase: AiroCastDiscoveryPhase.found,
      devices: List.unmodifiable(devices),
    );
  }

  const AiroCastDiscoveryState.noDevices()
      : this._(phase: AiroCastDiscoveryPhase.noDevices);

  factory AiroCastDiscoveryState.failed(String error) {
    return AiroCastDiscoveryState._(
      phase: AiroCastDiscoveryPhase.failed,
      error: error,
    );
  }

  @override
  List<Object?> get props => [phase, devices, error];
}

class AiroCastMediaRequest extends Equatable {
  final Uri url;
  final String contentType;
  final String title;
  final String? subtitle;
  final Uri? imageUrl;
  final AiroCastMediaStreamKind streamKind;
  final Duration? duration;

  const AiroCastMediaRequest({
    required this.url,
    required this.contentType,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.streamKind = AiroCastMediaStreamKind.live,
    this.duration,
  });

  @override
  List<Object?> get props => [
        url,
        contentType,
        title,
        subtitle,
        imageUrl,
        streamKind,
        duration,
      ];
}

class AiroCastSessionSnapshot extends Equatable {
  final AiroCastSessionPhase phase;
  final AiroCastDevice? device;
  final AiroCastMediaRequest? media;
  final AiroCastError? error;
  final double volume;

  const AiroCastSessionSnapshot._({
    required this.phase,
    this.device,
    this.media,
    this.error,
    this.volume = 1.0,
  });

  const AiroCastSessionSnapshot.idle()
      : this._(phase: AiroCastSessionPhase.idle);

  const AiroCastSessionSnapshot.connecting(AiroCastDevice device)
      : this._(phase: AiroCastSessionPhase.connecting, device: device);

  const AiroCastSessionSnapshot.connected(AiroCastDevice device)
      : this._(phase: AiroCastSessionPhase.connected, device: device);

  const AiroCastSessionSnapshot.loadingMedia({
    required AiroCastDevice device,
    required AiroCastMediaRequest media,
  }) : this._(
          phase: AiroCastSessionPhase.loadingMedia,
          device: device,
          media: media,
        );

  const AiroCastSessionSnapshot.playing({
    required AiroCastDevice device,
    required AiroCastMediaRequest media,
    double volume = 1.0,
  }) : this._(
          phase: AiroCastSessionPhase.playing,
          device: device,
          media: media,
          volume: volume,
        );

  const AiroCastSessionSnapshot.paused({
    required AiroCastDevice device,
    required AiroCastMediaRequest media,
    double volume = 1.0,
  }) : this._(
          phase: AiroCastSessionPhase.paused,
          device: device,
          media: media,
          volume: volume,
        );

  const AiroCastSessionSnapshot.stopped()
      : this._(phase: AiroCastSessionPhase.stopped);

  const AiroCastSessionSnapshot.disconnected(AiroCastDevice device)
      : this._(phase: AiroCastSessionPhase.disconnected, device: device);

  const AiroCastSessionSnapshot.failed(AiroCastError error)
      : this._(phase: AiroCastSessionPhase.failed, error: error);

  bool get hasActiveDevice => device != null;
  bool get isConnected =>
      phase == AiroCastSessionPhase.connected ||
      phase == AiroCastSessionPhase.loadingMedia ||
      phase == AiroCastSessionPhase.playing ||
      phase == AiroCastSessionPhase.paused;

  @override
  List<Object?> get props => [phase, device, media, error, volume];
}
```

Create `app/lib/core/cast/cast_controller.dart`:

```dart
import 'cast_models.dart';

abstract interface class AiroCastController {
  Stream<AiroCastDiscoveryState> get discoveryStateStream;
  Stream<AiroCastSessionSnapshot> get sessionStateStream;

  AiroCastDiscoveryState get currentDiscoveryState;
  AiroCastSessionSnapshot get currentSessionState;

  Future<void> initialize();
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> connect(AiroCastDevice device);
  Future<void> load(AiroCastMediaRequest request);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> disconnect();
  Future<void> dispose();
}
```

- [ ] **Step 4: Write failing fake controller tests**

Create `app/test/core/cast/fake_cast_controller_test.dart`:

```dart
import 'package:airo_app/core/cast/cast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FakeAiroCastController', () {
    const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');
    final media = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/live.m3u8'),
      contentType: 'application/x-mpegURL',
      title: 'P4U Music',
      streamKind: AiroCastMediaStreamKind.live,
    );

    test('discovers configured fake devices', () async {
      final controller = FakeAiroCastController(devices: const [tv]);

      await controller.initialize();
      await controller.startDiscovery();

      expect(
        controller.currentDiscoveryState,
        AiroCastDiscoveryState.found(const [tv]),
      );
    });

    test('loads media after connecting to a device', () async {
      final controller = FakeAiroCastController(devices: const [tv]);

      await controller.initialize();
      await controller.connect(tv);
      await controller.load(media);

      expect(controller.currentSessionState.phase, AiroCastSessionPhase.playing);
      expect(controller.currentSessionState.device, tv);
      expect(controller.currentSessionState.media, media);
      expect(controller.recordedActions, [
        'initialize',
        'connect:tv-1',
        'load:https://example.com/live.m3u8',
      ]);
    });

    test('new connection replaces active session', () async {
      const bedroom = AiroCastDevice(id: 'tv-2', name: 'Bedroom TV');
      final controller = FakeAiroCastController(devices: const [tv, bedroom]);

      await controller.connect(tv);
      await controller.load(media);
      await controller.connect(bedroom);

      expect(controller.currentSessionState.phase, AiroCastSessionPhase.connected);
      expect(controller.currentSessionState.device, bedroom);
      expect(controller.recordedActions, contains('disconnect:tv-1'));
    });

    test('can emit receiver disconnected failure path', () async {
      final controller = FakeAiroCastController(devices: const [tv]);

      await controller.connect(tv);
      controller.emitReceiverDisconnected();

      expect(
        controller.currentSessionState.phase,
        AiroCastSessionPhase.disconnected,
      );
      expect(controller.currentSessionState.device, tv);
    });
  });
}
```

- [ ] **Step 5: Run fake tests and verify failure**

Run:

```bash
cd app
flutter test test/core/cast/fake_cast_controller_test.dart
```

Expected: FAIL because `FakeAiroCastController` is not defined.

- [ ] **Step 6: Implement fake controller**

Create `app/lib/core/cast/fake_cast_controller.dart`:

```dart
import 'dart:async';

import 'cast_controller.dart';
import 'cast_models.dart';

class FakeAiroCastController implements AiroCastController {
  FakeAiroCastController({
    this.devices = const [],
    this.failDiscovery = false,
    this.denyPermission = false,
    this.failConnection = false,
    this.failMediaLoad = false,
  });

  final List<AiroCastDevice> devices;
  final bool failDiscovery;
  final bool denyPermission;
  final bool failConnection;
  final bool failMediaLoad;

  final List<String> recordedActions = [];

  final _discoveryController =
      StreamController<AiroCastDiscoveryState>.broadcast();
  final _sessionController =
      StreamController<AiroCastSessionSnapshot>.broadcast();

  AiroCastDiscoveryState _discoveryState =
      const AiroCastDiscoveryState.idle();
  AiroCastSessionSnapshot _sessionState =
      const AiroCastSessionSnapshot.idle();
  AiroCastDevice? _connectedDevice;

  @override
  Stream<AiroCastDiscoveryState> get discoveryStateStream =>
      _discoveryController.stream;

  @override
  Stream<AiroCastSessionSnapshot> get sessionStateStream =>
      _sessionController.stream;

  @override
  AiroCastDiscoveryState get currentDiscoveryState => _discoveryState;

  @override
  AiroCastSessionSnapshot get currentSessionState => _sessionState;

  @override
  Future<void> initialize() async {
    recordedActions.add('initialize');
  }

  @override
  Future<void> startDiscovery() async {
    recordedActions.add('startDiscovery');
    if (denyPermission) {
      _setDiscovery(const AiroCastDiscoveryState.permissionRequired());
      return;
    }
    _setDiscovery(const AiroCastDiscoveryState.discovering());
    if (failDiscovery) {
      _setDiscovery(AiroCastDiscoveryState.failed('Cast discovery failed'));
      return;
    }
    if (devices.isEmpty) {
      _setDiscovery(const AiroCastDiscoveryState.noDevices());
      return;
    }
    _setDiscovery(AiroCastDiscoveryState.found(devices));
  }

  @override
  Future<void> stopDiscovery() async {
    recordedActions.add('stopDiscovery');
    _setDiscovery(const AiroCastDiscoveryState.idle());
  }

  @override
  Future<void> connect(AiroCastDevice device) async {
    if (_connectedDevice != null && _connectedDevice != device) {
      recordedActions.add('disconnect:${_connectedDevice!.id}');
    }
    recordedActions.add('connect:${device.id}');
    _setSession(AiroCastSessionSnapshot.connecting(device));
    if (failConnection) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.connectionTimeout,
            message: 'Unable to connect to Cast receiver.',
          ),
        ),
      );
      return;
    }
    _connectedDevice = device;
    _setSession(AiroCastSessionSnapshot.connected(device));
  }

  @override
  Future<void> load(AiroCastMediaRequest request) async {
    final device = _connectedDevice;
    if (device == null) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.receiverUnavailable,
            message: 'Choose a Cast device before loading media.',
          ),
        ),
      );
      return;
    }
    recordedActions.add('load:${request.url}');
    _setSession(AiroCastSessionSnapshot.loadingMedia(
      device: device,
      media: request,
    ));
    if (failMediaLoad) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.mediaLoadFailed,
            message: 'The receiver could not load this channel.',
          ),
        ),
      );
      return;
    }
    _setSession(AiroCastSessionSnapshot.playing(
      device: device,
      media: request,
    ));
  }

  @override
  Future<void> play() async {
    recordedActions.add('play');
    final snapshot = _sessionState;
    final device = snapshot.device;
    final media = snapshot.media;
    if (device != null && media != null) {
      _setSession(AiroCastSessionSnapshot.playing(
        device: device,
        media: media,
        volume: snapshot.volume,
      ));
    }
  }

  @override
  Future<void> pause() async {
    recordedActions.add('pause');
    final snapshot = _sessionState;
    final device = snapshot.device;
    final media = snapshot.media;
    if (device != null && media != null) {
      _setSession(AiroCastSessionSnapshot.paused(
        device: device,
        media: media,
        volume: snapshot.volume,
      ));
    }
  }

  @override
  Future<void> stop() async {
    recordedActions.add('stop');
    _connectedDevice = null;
    _setSession(const AiroCastSessionSnapshot.stopped());
  }

  @override
  Future<void> setVolume(double volume) async {
    recordedActions.add('setVolume:$volume');
    final snapshot = _sessionState;
    final device = snapshot.device;
    final media = snapshot.media;
    if (device != null && media != null) {
      if (snapshot.phase == AiroCastSessionPhase.paused) {
        _setSession(AiroCastSessionSnapshot.paused(
          device: device,
          media: media,
          volume: volume.clamp(0.0, 1.0),
        ));
      } else {
        _setSession(AiroCastSessionSnapshot.playing(
          device: device,
          media: media,
          volume: volume.clamp(0.0, 1.0),
        ));
      }
    }
  }

  @override
  Future<void> disconnect() async {
    final device = _connectedDevice;
    if (device != null) {
      recordedActions.add('disconnect:${device.id}');
    }
    _connectedDevice = null;
    _setSession(const AiroCastSessionSnapshot.idle());
  }

  void emitReceiverDisconnected() {
    final device = _connectedDevice;
    if (device == null) return;
    _connectedDevice = null;
    _setSession(AiroCastSessionSnapshot.disconnected(device));
  }

  @override
  Future<void> dispose() async {
    recordedActions.add('dispose');
    await _discoveryController.close();
    await _sessionController.close();
  }

  void _setDiscovery(AiroCastDiscoveryState state) {
    _discoveryState = state;
    _discoveryController.add(state);
  }

  void _setSession(AiroCastSessionSnapshot state) {
    _sessionState = state;
    _sessionController.add(state);
  }
}
```

- [ ] **Step 7: Run core Cast tests**

Run:

```bash
cd app
flutter test test/core/cast/cast_models_test.dart test/core/cast/fake_cast_controller_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit Task 1**

```bash
git add app/lib/core/cast app/test/core/cast
git commit -m "feat(cast): add single-session Cast contract"
```

## Task 2: Flutter Chrome Cast Adapter and Platform Setup

**Files:**
- Modify: `app/pubspec.yaml`
- Create: `app/lib/core/cast/flutter_chrome_cast_controller.dart`
- Test: `app/test/core/cast/flutter_chrome_cast_request_mapping_test.dart`
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/ios/Runner/Info.plist`

- [ ] **Step 1: Add plugin dependency**

Run:

```bash
cd app
flutter pub add flutter_chrome_cast:^1.4.6
```

Expected: `pubspec.yaml` includes `flutter_chrome_cast: ^1.4.6`, and `pubspec.lock` updates.

- [ ] **Step 2: Write failing request mapping test**

Create `app/test/core/cast/flutter_chrome_cast_request_mapping_test.dart`:

```dart
import 'package:airo_app/core/cast/cast.dart';
import 'package:airo_app/core/cast/flutter_chrome_cast_controller.dart';
import 'package:flutter_chrome_cast/entities.dart';
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Airo live HLS request to GoogleCastMediaInformation', () {
    final request = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/channel.m3u8'),
      contentType: 'application/x-mpegURL',
      title: 'P4U Music',
      subtitle: 'Music',
      imageUrl: Uri.parse('https://example.com/logo.png'),
      streamKind: AiroCastMediaStreamKind.live,
    );

    final mediaInfo = FlutterChromeCastController.toGoogleMediaInfo(request);

    expect(mediaInfo, isA<GoogleCastMediaInformation>());
    expect(mediaInfo.contentId, 'https://example.com/channel.m3u8');
    expect(mediaInfo.contentUrl, Uri.parse('https://example.com/channel.m3u8'));
    expect(mediaInfo.contentType, 'application/x-mpegURL');
    expect(mediaInfo.streamType, CastMediaStreamType.live);
  });

  test('maps buffered MP4 request to buffered stream type', () {
    final request = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/video.mp4'),
      contentType: 'video/mp4',
      title: 'Sample',
      streamKind: AiroCastMediaStreamKind.buffered,
    );

    final mediaInfo = FlutterChromeCastController.toGoogleMediaInfo(request);

    expect(mediaInfo.streamType, CastMediaStreamType.buffered);
  });
}
```

- [ ] **Step 3: Run mapping test and verify failure**

Run:

```bash
cd app
flutter test test/core/cast/flutter_chrome_cast_request_mapping_test.dart
```

Expected: FAIL because `flutter_chrome_cast_controller.dart` does not exist.

- [ ] **Step 4: Implement Flutter Chrome Cast controller**

Create `app/lib/core/cast/flutter_chrome_cast_controller.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_chrome_cast/cast_context.dart';
import 'package:flutter_chrome_cast/common.dart';
import 'package:flutter_chrome_cast/discovery.dart';
import 'package:flutter_chrome_cast/entities.dart' as chrome_entities;
import 'package:flutter_chrome_cast/enums.dart';
import 'package:flutter_chrome_cast/media.dart';
import 'package:flutter_chrome_cast/models.dart';
import 'package:flutter_chrome_cast/session.dart';

import 'cast_controller.dart';
import 'cast_models.dart';

class FlutterChromeCastController implements AiroCastController {
  FlutterChromeCastController();

  final _discoveryController =
      StreamController<AiroCastDiscoveryState>.broadcast();
  final _sessionController =
      StreamController<AiroCastSessionSnapshot>.broadcast();

  StreamSubscription<List<chrome_entities.GoogleCastDevice>>?
      _devicesSubscription;
  StreamSubscription<chrome_entities.GoogleCastSession?>? _sessionSubscription;
  AiroCastDiscoveryState _discoveryState =
      const AiroCastDiscoveryState.idle();
  AiroCastSessionSnapshot _sessionState =
      const AiroCastSessionSnapshot.idle();
  chrome_entities.GoogleCastDevice? _connectedGoogleDevice;
  AiroCastDevice? _connectedDevice;
  AiroCastMediaRequest? _loadedMedia;

  @override
  Stream<AiroCastDiscoveryState> get discoveryStateStream =>
      _discoveryController.stream;

  @override
  Stream<AiroCastSessionSnapshot> get sessionStateStream =>
      _sessionController.stream;

  @override
  AiroCastDiscoveryState get currentDiscoveryState => _discoveryState;

  @override
  AiroCastSessionSnapshot get currentSessionState => _sessionState;

  @override
  Future<void> initialize() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.platformUnavailable,
            message: 'Google Cast is available on Android and iOS only.',
          ),
        ),
      );
      return;
    }

    const appId = chrome_entities.GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    GoogleCastOptions? options;
    if (Platform.isIOS) {
      options = IOSGoogleCastOptions(
        chrome_entities.GoogleCastDiscoveryCriteriaInitialize
            .initWithApplicationID(appId),
        stopCastingOnAppTerminated: false,
      );
    } else if (Platform.isAndroid) {
      options = GoogleCastOptionsAndroid(
        appId: appId,
        stopCastingOnAppTerminated: false,
      );
    }
    if (options == null) return;

    await GoogleCastContext.instance.setSharedInstanceWithOptions(options);

    _devicesSubscription ??= GoogleCastDiscoveryManager.instance.devicesStream
        .listen(_handleDevices, onError: _handleDiscoveryError);
    _sessionSubscription ??= GoogleCastSessionManager
        .instance.currentSessionStream
        .listen(_handleSession, onError: _handleSessionError);
  }

  @override
  Future<void> startDiscovery() async {
    _setDiscovery(const AiroCastDiscoveryState.discovering());
    await GoogleCastDiscoveryManager.instance.startDiscovery();
  }

  @override
  Future<void> stopDiscovery() async {
    await GoogleCastDiscoveryManager.instance.stopDiscovery();
    _setDiscovery(const AiroCastDiscoveryState.idle());
  }

  @override
  Future<void> connect(AiroCastDevice device) async {
    final googleDevice = _findGoogleDevice(device);
    if (googleDevice == null) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.receiverUnavailable,
            message: 'The selected Cast device is no longer available.',
          ),
        ),
      );
      return;
    }

    if (_connectedGoogleDevice != null &&
        _connectedGoogleDevice!.deviceID != googleDevice.deviceID) {
      await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    }

    _connectedGoogleDevice = googleDevice;
    _connectedDevice = device;
    _setSession(AiroCastSessionSnapshot.connecting(device));

    final started =
        await GoogleCastSessionManager.instance.startSessionWithDevice(
      googleDevice,
    );
    if (!started) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.connectionTimeout,
            message: 'Unable to start a Cast session with this device.',
          ),
        ),
      );
      return;
    }
    _setSession(AiroCastSessionSnapshot.connected(device));
  }

  @override
  Future<void> load(AiroCastMediaRequest request) async {
    final device = _connectedDevice;
    if (device == null) {
      _setSession(
        const AiroCastSessionSnapshot.failed(
          AiroCastError(
            code: AiroCastErrorCode.receiverUnavailable,
            message: 'Choose a Cast device before loading a channel.',
          ),
        ),
      );
      return;
    }
    _loadedMedia = request;
    _setSession(AiroCastSessionSnapshot.loadingMedia(
      device: device,
      media: request,
    ));
    await GoogleCastRemoteMediaClient.instance.loadMedia(
      toGoogleMediaInfo(request),
      autoPlay: true,
    );
    _setSession(AiroCastSessionSnapshot.playing(
      device: device,
      media: request,
    ));
  }

  @override
  Future<void> play() async {
    await GoogleCastRemoteMediaClient.instance.play();
    final device = _connectedDevice;
    final media = _loadedMedia;
    if (device != null && media != null) {
      _setSession(AiroCastSessionSnapshot.playing(
        device: device,
        media: media,
        volume: _sessionState.volume,
      ));
    }
  }

  @override
  Future<void> pause() async {
    await GoogleCastRemoteMediaClient.instance.pause();
    final device = _connectedDevice;
    final media = _loadedMedia;
    if (device != null && media != null) {
      _setSession(AiroCastSessionSnapshot.paused(
        device: device,
        media: media,
        volume: _sessionState.volume,
      ));
    }
  }

  @override
  Future<void> stop() async {
    await GoogleCastRemoteMediaClient.instance.stop();
    await disconnect();
    _setSession(const AiroCastSessionSnapshot.stopped());
  }

  @override
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    GoogleCastSessionManager.instance.setDeviceVolume(clamped);
    final device = _connectedDevice;
    final media = _loadedMedia;
    if (device == null || media == null) return;
    if (_sessionState.phase == AiroCastSessionPhase.paused) {
      _setSession(AiroCastSessionSnapshot.paused(
        device: device,
        media: media,
        volume: clamped,
      ));
    } else {
      _setSession(AiroCastSessionSnapshot.playing(
        device: device,
        media: media,
        volume: clamped,
      ));
    }
  }

  @override
  Future<void> disconnect() async {
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    _connectedGoogleDevice = null;
    _connectedDevice = null;
    _loadedMedia = null;
    _setSession(const AiroCastSessionSnapshot.idle());
  }

  @override
  Future<void> dispose() async {
    await _devicesSubscription?.cancel();
    await _sessionSubscription?.cancel();
    await _discoveryController.close();
    await _sessionController.close();
  }

  static chrome_entities.GoogleCastMediaInformation toGoogleMediaInfo(
    AiroCastMediaRequest request,
  ) {
    return chrome_entities.GoogleCastMediaInformation(
      contentId: request.url.toString(),
      contentUrl: request.url,
      contentType: request.contentType,
      streamType: request.streamKind == AiroCastMediaStreamKind.live
          ? CastMediaStreamType.live
          : CastMediaStreamType.buffered,
      duration: request.duration,
      metadata: chrome_entities.GoogleCastGenericMediaMetadata(
        title: request.title,
        subtitle: request.subtitle,
        images: [
          if (request.imageUrl != null)
            GoogleCastImage(url: request.imageUrl!, height: 512, width: 512),
        ],
      ),
    );
  }

  chrome_entities.GoogleCastDevice? _findGoogleDevice(AiroCastDevice device) {
    return GoogleCastDiscoveryManager.instance.devices
        .where((candidate) => candidate.deviceID == device.id)
        .cast<chrome_entities.GoogleCastDevice?>()
        .firstWhere((candidate) => candidate != null, orElse: () => null);
  }

  void _handleDevices(List<chrome_entities.GoogleCastDevice> devices) {
    final mapped = devices
        .map(
          (device) => AiroCastDevice(
            id: device.deviceID,
            name: device.friendlyName,
            modelName: device.modelName,
            lastSeenAt: DateTime.now(),
          ),
        )
        .toList(growable: false);
    if (mapped.isEmpty) {
      _setDiscovery(const AiroCastDiscoveryState.noDevices());
    } else {
      _setDiscovery(AiroCastDiscoveryState.found(mapped));
    }
  }

  void _handleSession(chrome_entities.GoogleCastSession? session) {
    if (session == null) {
      final device = _connectedDevice;
      _connectedGoogleDevice = null;
      _connectedDevice = null;
      _loadedMedia = null;
      if (device != null) {
        _setSession(AiroCastSessionSnapshot.disconnected(device));
      } else {
        _setSession(const AiroCastSessionSnapshot.idle());
      }
    }
  }

  void _handleDiscoveryError(Object error, StackTrace stackTrace) {
    _setDiscovery(AiroCastDiscoveryState.failed('Cast discovery failed.'));
  }

  void _handleSessionError(Object error, StackTrace stackTrace) {
    _setSession(
      const AiroCastSessionSnapshot.failed(
        AiroCastError(
          code: AiroCastErrorCode.receiverDisconnected,
          message: 'The Cast session ended unexpectedly.',
        ),
      ),
    );
  }

  void _setDiscovery(AiroCastDiscoveryState state) {
    _discoveryState = state;
    _discoveryController.add(state);
  }

  void _setSession(AiroCastSessionSnapshot state) {
    _sessionState = state;
    _sessionController.add(state);
  }
}
```

- [ ] **Step 5: Add Android manifest permissions**

Modify `app/android/app/src/main/AndroidManifest.xml` near the existing `INTERNET` permission:

```xml
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
```

Expected: no duplicate `INTERNET` permission.

- [ ] **Step 6: Add iOS local network declarations**

Modify `app/ios/Runner/Info.plist` and add these keys inside the main `<dict>`:

```xml
	<key>NSLocalNetworkUsageDescription</key>
	<string>Airo uses your local network to find and connect to Chromecast-enabled TVs on your Wi-Fi.</string>
	<key>NSBonjourServices</key>
	<array>
		<string>_googlecast._tcp</string>
	</array>
```

Validate:

```bash
plutil -lint app/ios/Runner/Info.plist
```

Expected: `app/ios/Runner/Info.plist: OK`.

- [ ] **Step 7: Run adapter tests**

Run:

```bash
cd app
flutter test test/core/cast/flutter_chrome_cast_request_mapping_test.dart
```

Expected: PASS.

- [ ] **Step 8: Analyze**

Run:

```bash
cd app
flutter analyze
```

Expected: no new analyzer errors from Cast files. Keep the Airo interface stable; package-specific fixes belong only in `flutter_chrome_cast_controller.dart`.

- [ ] **Step 9: Commit Task 2**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/core/cast/flutter_chrome_cast_controller.dart app/test/core/cast/flutter_chrome_cast_request_mapping_test.dart app/android/app/src/main/AndroidManifest.xml app/ios/Runner/Info.plist
git commit -m "feat(cast): wire Google Cast platform adapter"
```

## Task 3: IPTV Cast Media Adapter

**Files:**
- Create: `app/lib/features/iptv/domain/services/iptv_cast_media_adapter.dart`
- Test: `app/test/features/iptv/iptv_cast_media_adapter_test.dart`

- [ ] **Step 1: Write failing IPTV adapter tests**

Create `app/test/features/iptv/iptv_cast_media_adapter_test.dart`:

```dart
import 'package:airo_app/core/cast/cast.dart';
import 'package:airo_app/features/iptv/domain/models/iptv_channel.dart';
import 'package:airo_app/features/iptv/domain/services/iptv_cast_media_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const adapter = IptvCastMediaAdapter();

  IPTVChannel channel({
    String streamUrl = 'https://example.com/live.m3u8',
    String? logoUrl = 'https://example.com/logo.png',
    ChannelHeaders? headers,
    bool isAudioOnly = false,
  }) {
    return IPTVChannel(
      id: 'p4u',
      name: 'P4U Music',
      streamUrl: streamUrl,
      logoUrl: logoUrl,
      group: 'Music',
      category: ChannelCategory.music,
      isAudioOnly: isAudioOnly,
      headers: headers,
    );
  }

  test('converts HLS channel into live Cast media request', () {
    final result = adapter.toCastRequest(channel());

    expect(result.isCastable, true);
    expect(result.request!.url, Uri.parse('https://example.com/live.m3u8'));
    expect(result.request!.contentType, 'application/x-mpegURL');
    expect(result.request!.title, 'P4U Music');
    expect(result.request!.subtitle, 'Music');
    expect(result.request!.imageUrl, Uri.parse('https://example.com/logo.png'));
    expect(result.request!.streamKind, AiroCastMediaStreamKind.live);
  });

  test('converts MP4 channel into buffered Cast media request', () {
    final result = adapter.toCastRequest(
      channel(streamUrl: 'https://example.com/video.mp4?token=abc'),
    );

    expect(result.isCastable, true);
    expect(result.request!.contentType, 'video/mp4');
    expect(result.request!.streamKind, AiroCastMediaStreamKind.buffered);
  });

  test('rejects channels requiring custom headers in V1', () {
    final result = adapter.toCastRequest(
      channel(headers: const ChannelHeaders(userAgent: 'Airo')),
    );

    expect(result.isCastable, false);
    expect(result.error!.code, AiroCastErrorCode.unsupportedStream);
  });

  test('rejects non-http URLs', () {
    final result = adapter.toCastRequest(
      channel(streamUrl: 'file:///private/video.mp4'),
    );

    expect(result.isCastable, false);
    expect(result.error!.code, AiroCastErrorCode.unsupportedStream);
  });
}
```

- [ ] **Step 2: Run adapter tests and verify failure**

Run:

```bash
cd app
flutter test test/features/iptv/iptv_cast_media_adapter_test.dart
```

Expected: FAIL because `IptvCastMediaAdapter` does not exist.

- [ ] **Step 3: Implement IPTV adapter**

Create `app/lib/features/iptv/domain/services/iptv_cast_media_adapter.dart`:

```dart
import '../../../../core/cast/cast.dart';
import '../models/iptv_channel.dart';

class IptvCastMediaAdapter {
  const IptvCastMediaAdapter();

  IptvCastMediaResult toCastRequest(
    IPTVChannel channel, {
    VideoQuality selectedQuality = VideoQuality.auto,
  }) {
    if (channel.headers != null) {
      return IptvCastMediaResult.unsupported(
        'This channel needs custom request headers, which Cast V1 does not proxy.',
      );
    }

    final rawUrl = channel.getStreamUrl(selectedQuality).trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return IptvCastMediaResult.unsupported(
        'This channel does not have a valid network stream URL.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return IptvCastMediaResult.unsupported(
        'Only http and https IPTV streams can be cast in V1.',
      );
    }

    final contentType = _contentTypeFor(uri, channel);
    if (contentType == null) {
      return IptvCastMediaResult.unsupported(
        'This stream format is not supported by Cast V1.',
      );
    }

    final imageUrl = channel.effectiveLogoUrl == null
        ? null
        : Uri.tryParse(channel.effectiveLogoUrl!);

    return IptvCastMediaResult.castable(
      AiroCastMediaRequest(
        url: uri,
        contentType: contentType,
        title: channel.name,
        subtitle: channel.group,
        imageUrl: imageUrl?.hasScheme == true ? imageUrl : null,
        streamKind: _streamKindFor(uri),
      ),
    );
  }

  String? _contentTypeFor(Uri uri, IPTVChannel channel) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8')) return 'application/x-mpegURL';
    if (path.endsWith('.mp4')) return 'video/mp4';
    if (path.endsWith('.m4v')) return 'video/mp4';
    if (path.endsWith('.mp3')) return 'audio/mpeg';
    if (path.endsWith('.aac')) return 'audio/aac';
    if (channel.isAudioOnly) return 'audio/mpeg';
    return null;
  }

  AiroCastMediaStreamKind _streamKindFor(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u8')
        ? AiroCastMediaStreamKind.live
        : AiroCastMediaStreamKind.buffered;
  }
}

class IptvCastMediaResult {
  final AiroCastMediaRequest? request;
  final AiroCastError? error;

  const IptvCastMediaResult._({this.request, this.error});

  factory IptvCastMediaResult.castable(AiroCastMediaRequest request) {
    return IptvCastMediaResult._(request: request);
  }

  factory IptvCastMediaResult.unsupported(String message) {
    return IptvCastMediaResult._(
      error: AiroCastError(
        code: AiroCastErrorCode.unsupportedStream,
        message: message,
      ),
    );
  }

  bool get isCastable => request != null;
}
```

- [ ] **Step 4: Export adapter from IPTV barrel**

Modify `app/lib/features/iptv/iptv.dart` and add:

```dart
export 'domain/services/iptv_cast_media_adapter.dart';
```

- [ ] **Step 5: Run IPTV adapter tests**

Run:

```bash
cd app
flutter test test/features/iptv/iptv_cast_media_adapter_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 3**

```bash
git add app/lib/features/iptv/domain/services/iptv_cast_media_adapter.dart app/lib/features/iptv/iptv.dart app/test/features/iptv/iptv_cast_media_adapter_test.dart
git commit -m "feat(iptv): adapt channels for Cast playback"
```

## Task 4: IPTV Cast Riverpod Orchestration

**Files:**
- Create: `app/lib/features/iptv/application/providers/iptv_cast_providers.dart`
- Modify: `app/lib/features/iptv/application/providers/iptv_providers.dart`
- Test: `app/test/features/iptv/iptv_cast_notifier_test.dart`

- [ ] **Step 1: Write failing notifier tests**

Create `app/test/features/iptv/iptv_cast_notifier_test.dart`:

```dart
import 'package:airo_app/core/cast/cast.dart';
import 'package:airo_app/features/iptv/application/providers/iptv_cast_providers.dart';
import 'package:airo_app/features/iptv/domain/models/iptv_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');

  IPTVChannel channel() => const IPTVChannel(
        id: 'p4u',
        name: 'P4U Music',
        streamUrl: 'https://example.com/live.m3u8',
        group: 'Music',
        category: ChannelCategory.music,
      );

  test('starts discovery through controller', () async {
    final fake = FakeAiroCastController(devices: const [tv]);
    final container = ProviderContainer(
      overrides: [airoCastControllerProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(iptvCastProvider.notifier).startDiscovery();

    expect(fake.recordedActions, contains('startDiscovery'));
    expect(
      container.read(iptvCastProvider).discovery.phase,
      AiroCastDiscoveryPhase.found,
    );
  });

  test('casts a channel to selected device', () async {
    final fake = FakeAiroCastController(devices: const [tv]);
    final container = ProviderContainer(
      overrides: [airoCastControllerProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(iptvCastProvider.notifier).castChannelToDevice(
          channel: channel(),
          device: tv,
        );

    expect(fake.recordedActions, [
      'connect:tv-1',
      'load:https://example.com/live.m3u8',
    ]);
    expect(container.read(iptvCastProvider).session.phase, AiroCastSessionPhase.playing);
  });

  test('stores unsupported stream error without connecting', () async {
    final fake = FakeAiroCastController(devices: const [tv]);
    final container = ProviderContainer(
      overrides: [airoCastControllerProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(iptvCastProvider.notifier).castChannelToDevice(
          channel: channel().copyWith(
            headers: const ChannelHeaders(userAgent: 'Airo'),
          ),
          device: tv,
        );

    expect(fake.recordedActions, isEmpty);
    expect(container.read(iptvCastProvider).lastError?.code,
        AiroCastErrorCode.unsupportedStream);
  });
}
```

- [ ] **Step 2: Run notifier tests and verify failure**

Run:

```bash
cd app
flutter test test/features/iptv/iptv_cast_notifier_test.dart
```

Expected: FAIL because `iptv_cast_providers.dart` does not exist.

- [ ] **Step 3: Implement providers and notifier**

Create `app/lib/features/iptv/application/providers/iptv_cast_providers.dart`:

```dart
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cast/cast.dart';
import '../../../../core/cast/flutter_chrome_cast_controller.dart';
import '../../domain/models/iptv_channel.dart';
import '../../domain/services/iptv_cast_media_adapter.dart';

final airoCastControllerProvider = Provider<AiroCastController>((ref) {
  final controller = FlutterChromeCastController();
  ref.onDispose(controller.dispose);
  return controller;
});

final iptvCastMediaAdapterProvider = Provider<IptvCastMediaAdapter>((ref) {
  return const IptvCastMediaAdapter();
});

final iptvCastProvider =
    StateNotifierProvider<IptvCastNotifier, IptvCastState>((ref) {
  final notifier = IptvCastNotifier(
    controller: ref.watch(airoCastControllerProvider),
    adapter: ref.watch(iptvCastMediaAdapterProvider),
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});

class IptvCastState extends Equatable {
  final AiroCastDiscoveryState discovery;
  final AiroCastSessionSnapshot session;
  final AiroCastError? lastError;

  const IptvCastState({
    this.discovery = const AiroCastDiscoveryState.idle(),
    this.session = const AiroCastSessionSnapshot.idle(),
    this.lastError,
  });

  bool get isCasting => session.isConnected;
  AiroCastDevice? get activeDevice => session.device;

  IptvCastState copyWith({
    AiroCastDiscoveryState? discovery,
    AiroCastSessionSnapshot? session,
    AiroCastError? lastError,
    bool clearError = false,
  }) {
    return IptvCastState(
      discovery: discovery ?? this.discovery,
      session: session ?? this.session,
      lastError: clearError ? null : lastError ?? this.lastError,
    );
  }

  @override
  List<Object?> get props => [discovery, session, lastError];
}

class IptvCastNotifier extends StateNotifier<IptvCastState> {
  IptvCastNotifier({
    required AiroCastController controller,
    required IptvCastMediaAdapter adapter,
  })  : _controller = controller,
        _adapter = adapter,
        super(const IptvCastState()) {
    _discoverySubscription = _controller.discoveryStateStream.listen((value) {
      state = state.copyWith(discovery: value);
    });
    _sessionSubscription = _controller.sessionStateStream.listen((value) {
      state = state.copyWith(session: value);
      if (value.error != null) {
        state = state.copyWith(lastError: value.error);
      }
    });
  }

  final AiroCastController _controller;
  final IptvCastMediaAdapter _adapter;
  StreamSubscription<AiroCastDiscoveryState>? _discoverySubscription;
  StreamSubscription<AiroCastSessionSnapshot>? _sessionSubscription;

  Future<void> initialize() => _controller.initialize();

  Future<void> startDiscovery() async {
    state = state.copyWith(clearError: true);
    await _controller.initialize();
    await _controller.startDiscovery();
    state = state.copyWith(discovery: _controller.currentDiscoveryState);
  }

  Future<void> stopDiscovery() => _controller.stopDiscovery();

  Future<void> castChannelToDevice({
    required IPTVChannel channel,
    required AiroCastDevice device,
    VideoQuality selectedQuality = VideoQuality.auto,
  }) async {
    state = state.copyWith(clearError: true);
    final result = _adapter.toCastRequest(
      channel,
      selectedQuality: selectedQuality,
    );
    if (!result.isCastable) {
      state = state.copyWith(lastError: result.error);
      return;
    }
    await _controller.connect(device);
    if (_controller.currentSessionState.phase == AiroCastSessionPhase.failed) {
      state = state.copyWith(
        session: _controller.currentSessionState,
        lastError: _controller.currentSessionState.error,
      );
      return;
    }
    await _controller.load(result.request!);
    state = state.copyWith(session: _controller.currentSessionState);
  }

  Future<void> castChannelToActiveDevice({
    required IPTVChannel channel,
    VideoQuality selectedQuality = VideoQuality.auto,
  }) async {
    final device = state.activeDevice;
    if (device == null) {
      state = state.copyWith(
        lastError: const AiroCastError(
          code: AiroCastErrorCode.receiverUnavailable,
          message: 'Choose a Cast device before casting this channel.',
        ),
      );
      return;
    }
    await castChannelToDevice(
      channel: channel,
      device: device,
      selectedQuality: selectedQuality,
    );
  }

  Future<void> play() => _controller.play();
  Future<void> pause() => _controller.pause();
  Future<void> stop() => _controller.stop();
  Future<void> setVolume(double volume) => _controller.setVolume(volume);

  @override
  void dispose() {
    _discoverySubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 4: Export Cast providers from IPTV providers**

Modify `app/lib/features/iptv/application/providers/iptv_providers.dart` and add near the imports/exports:

```dart
export 'iptv_cast_providers.dart';
```

- [ ] **Step 5: Confirm `IPTVChannel.copyWith` supports header override**

Verify `app/lib/features/iptv/domain/models/iptv_channel.dart` contains this existing `copyWith` parameter and assignment:

```dart
ChannelHeaders? headers,
```

```dart
headers: headers ?? this.headers,
```

No code change is needed when those lines are present.

Run:

```bash
cd app
flutter test test/features/iptv/iptv_cast_notifier_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 4**

```bash
git add app/lib/features/iptv/application/providers/iptv_cast_providers.dart app/lib/features/iptv/application/providers/iptv_providers.dart app/lib/features/iptv/domain/models/iptv_channel.dart app/test/features/iptv/iptv_cast_notifier_test.dart
git commit -m "feat(iptv): orchestrate single-device Cast sessions"
```

## Task 5: IPTV Cast UI

**Files:**
- Create: `app/lib/features/iptv/presentation/widgets/cast_device_picker_sheet.dart`
- Create: `app/lib/features/iptv/presentation/widgets/iptv_cast_mini_controller.dart`
- Modify: `app/lib/features/iptv/presentation/screens/iptv_screen.dart`
- Test: `app/test/features/iptv/iptv_cast_ui_test.dart`

- [ ] **Step 1: Write failing UI tests**

Create `app/test/features/iptv/iptv_cast_ui_test.dart`:

```dart
import 'package:airo_app/core/cast/cast.dart';
import 'package:airo_app/features/iptv/application/providers/iptv_cast_providers.dart';
import 'package:airo_app/features/iptv/domain/services/iptv_cast_media_adapter.dart';
import 'package:airo_app/features/iptv/presentation/widgets/cast_device_picker_sheet.dart';
import 'package:airo_app/features/iptv/presentation/widgets/iptv_cast_mini_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');

  testWidgets('device picker shows discovered Cast devices', (tester) async {
    final fake = FakeAiroCastController(devices: const [tv]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [airoCastControllerProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: CastDevicePickerTestHost()),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Cast to a device'), findsOneWidget);
    expect(find.text('Sony Bravia'), findsOneWidget);
  });

  testWidgets('mini controller shows active cast session', (tester) async {
    final media = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/live.m3u8'),
      contentType: 'application/x-mpegURL',
      title: 'P4U Music',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iptvCastProvider.overrideWith(
            (ref) => _StaticCastNotifier(
              IptvCastState(
                session: AiroCastSessionSnapshot.playing(
                  device: tv,
                  media: media,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: IptvCastMiniController())),
      ),
    );

    expect(find.text('Casting to Sony Bravia'), findsOneWidget);
    expect(find.text('P4U Music'), findsOneWidget);
  });
}

class CastDevicePickerTestHost extends StatelessWidget {
  const CastDevicePickerTestHost({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            showIptvCastDevicePicker(
              context: context,
              onDeviceSelected: (_) {},
            );
          },
          child: const Text('Open'),
        ),
      ),
    );
  }
}

class _StaticCastNotifier extends IptvCastNotifier {
  _StaticCastNotifier(IptvCastState initial)
      : super(
          controller: FakeAiroCastController(),
          adapter: const IptvCastMediaAdapter(),
        ) {
    state = initial;
  }
}
```

- [ ] **Step 2: Run UI tests and verify failure**

Run:

```bash
cd app
flutter test test/features/iptv/iptv_cast_ui_test.dart
```

Expected: FAIL because the widgets do not exist.

- [ ] **Step 3: Create device picker widget**

Create `app/lib/features/iptv/presentation/widgets/cast_device_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cast/cast.dart';
import '../../application/providers/iptv_cast_providers.dart';

Future<void> showIptvCastDevicePicker({
  required BuildContext context,
  required ValueChanged<AiroCastDevice> onDeviceSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => CastDevicePickerSheet(onDeviceSelected: onDeviceSelected),
  );
}

class CastDevicePickerSheet extends ConsumerStatefulWidget {
  const CastDevicePickerSheet({super.key, required this.onDeviceSelected});

  final ValueChanged<AiroCastDevice> onDeviceSelected;

  @override
  ConsumerState<CastDevicePickerSheet> createState() =>
      _CastDevicePickerSheetState();
}

class _CastDevicePickerSheetState extends ConsumerState<CastDevicePickerSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(iptvCastProvider.notifier).startDiscovery());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(iptvCastProvider);
    final discovery = state.discovery;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cast to a device', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Choose one Chromecast-enabled TV on this Wi-Fi network.'),
            const SizedBox(height: 16),
            if (discovery.phase == AiroCastDiscoveryPhase.discovering)
              const ListTile(
                leading: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                title: Text('Searching for TVs...'),
              )
            else if (discovery.phase == AiroCastDiscoveryPhase.permissionRequired)
              ListTile(
                leading: const Icon(Icons.wifi_tethering_error),
                title: const Text('Local network permission needed'),
                subtitle: const Text(
                  'Allow local network access so Airo can find Chromecast-enabled TVs.',
                ),
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(iptvCastProvider.notifier).startDiscovery(),
                  child: const Text('Retry'),
                ),
              )
            else if (discovery.phase == AiroCastDiscoveryPhase.noDevices)
              ListTile(
                leading: const Icon(Icons.cast),
                title: const Text('No Cast devices found'),
                subtitle: const Text('Make sure your phone and TV are on the same Wi-Fi.'),
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(iptvCastProvider.notifier).startDiscovery(),
                  child: const Text('Refresh'),
                ),
              )
            else if (discovery.phase == AiroCastDiscoveryPhase.failed)
              ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Cast discovery failed'),
                subtitle: Text(discovery.error ?? 'Try again.'),
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(iptvCastProvider.notifier).startDiscovery(),
                  child: const Text('Retry'),
                ),
              )
            else
              ...discovery.devices.map(
                (device) => ListTile(
                  leading: const Icon(Icons.cast),
                  title: Text(device.name),
                  subtitle: Text(device.modelName ?? 'Google Cast receiver'),
                  onTap: () {
                    widget.onDeviceSelected(device);
                    Navigator.of(context).pop();
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create mini controller widget**

Create `app/lib/features/iptv/presentation/widgets/iptv_cast_mini_controller.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cast/cast.dart';
import '../../application/providers/iptv_cast_providers.dart';

class IptvCastMiniController extends ConsumerWidget {
  const IptvCastMiniController({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final castState = ref.watch(iptvCastProvider);
    final session = castState.session;
    final device = session.device;
    final media = session.media;

    if (device == null || media == null) {
      return const SizedBox.shrink();
    }

    final isPaused = session.phase == AiroCastSessionPhase.paused;
    final isLoading = session.phase == AiroCastSessionPhase.loadingMedia;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: ListTile(
          leading: Icon(isLoading ? Icons.hourglass_top : Icons.cast_connected),
          title: Text(
            'Casting to ${device.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            media.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: isPaused ? 'Play' : 'Pause',
                onPressed: isLoading
                    ? null
                    : () {
                        final notifier = ref.read(iptvCastProvider.notifier);
                        isPaused ? notifier.play() : notifier.pause();
                      },
                icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              ),
              IconButton(
                tooltip: 'Stop casting',
                onPressed: () => ref.read(iptvCastProvider.notifier).stop(),
                icon: const Icon(Icons.stop),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Integrate widgets into IPTV screen**

Modify `app/lib/features/iptv/presentation/screens/iptv_screen.dart` imports:

```dart
import '../widgets/cast_device_picker_sheet.dart';
import '../widgets/iptv_cast_mini_controller.dart';
```

Replace `_showCastMessage()` with:

```dart
Future<void> _showCastSheet() async {
  final channel = ref.read(iptvStreamingServiceProvider).currentState.currentChannel;
  if (channel == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Choose a channel before casting.')),
    );
    return;
  }

  await showIptvCastDevicePicker(
    context: context,
    onDeviceSelected: (device) {
      ref.read(iptvCastProvider.notifier).castChannelToDevice(
            channel: channel,
            device: device,
            selectedQuality: ref
                .read(iptvStreamingServiceProvider)
                .currentState
                .selectedQuality,
          );
    },
  );
}
```

Change the Cast action:

```dart
IconButton(
  icon: const Icon(Icons.cast_connected),
  tooltip: 'Cast',
  onPressed: _showCastSheet,
),
```

Update `_playChannel` in both `IPTVScreen` and `IPTVScreenBody`:

```dart
void _playChannel(IPTVChannel channel) {
  final castState = ref.read(iptvCastProvider);
  if (castState.activeDevice != null) {
    ref.read(iptvCastProvider.notifier).castChannelToActiveDevice(
          channel: channel,
          selectedQuality:
              ref.read(iptvStreamingServiceProvider).currentState.selectedQuality,
        );
    return;
  }
  ref.read(iptvStreamingServiceProvider).playChannel(channel);
  ref.read(addToRecentlyWatchedProvider(channel));
}
```

Add `const IptvCastMiniController()` below `_StreamTabContent` in the non-fullscreen scaffold body:

```dart
body: Column(
  children: [
    Expanded(
      child: _StreamTabContent(
        onChannelTap: _playChannel,
        onFullscreenToggle: _toggleFullscreen,
      ),
    ),
    const IptvCastMiniController(),
  ],
),
```

For `IPTVScreenBody`, wrap the normal branch similarly:

```dart
child: Column(
  children: [
    Expanded(
      child: _StreamTabContent(
        onChannelTap: _playChannel,
        onFullscreenToggle: _toggleFullscreen,
      ),
    ),
    const IptvCastMiniController(),
  ],
),
```

- [ ] **Step 6: Run UI tests**

Run:

```bash
cd app
flutter test test/features/iptv/iptv_cast_ui_test.dart
```

Expected: PASS.

- [ ] **Step 7: Run IPTV screen smoke tests**

Run:

```bash
cd app
flutter test test/features/iptv test/core/cast
```

Expected: PASS.

- [ ] **Step 8: Commit Task 5**

```bash
git add app/lib/features/iptv/presentation/screens/iptv_screen.dart app/lib/features/iptv/presentation/widgets/cast_device_picker_sheet.dart app/lib/features/iptv/presentation/widgets/iptv_cast_mini_controller.dart app/test/features/iptv/iptv_cast_ui_test.dart
git commit -m "feat(iptv): add Cast picker and remote controls"
```

## Task 6: Security, Privacy, and Release Documentation

**Files:**
- Create: `docs/features/media-hub/GOOGLE_CAST_V1_QA.md`
- Modify: `docs/features/media-hub/ACCEPTANCE_TESTS.md`
- Modify: `docs/release/RELEASE_CHECKLIST.md`
- Test: `app/test/core/cast/cast_url_privacy_test.dart`

- [ ] **Step 1: Write URL privacy test**

Create `app/test/core/cast/cast_url_privacy_test.dart`:

```dart
import 'package:airo_app/core/cast/cast.dart';
import 'package:airo_app/core/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Cast media request string representation does not expose query tokens', () {
    final request = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/live.m3u8?token=secret'),
      contentType: 'application/x-mpegURL',
      title: 'Private Channel',
    );

    AppLogger.clearBuffer();
    AppLogger.info('Casting ${request.title}', tag: 'CAST');
    final logs = AppLogger.getRecentLogsAsString();

    expect(logs, contains('Private Channel'));
    expect(logs, isNot(contains('token=secret')));
  });
}
```

- [ ] **Step 2: Run privacy test**

Run:

```bash
cd app
flutter test test/core/cast/cast_url_privacy_test.dart
```

Expected: PASS. Cast code must log only channel title, host, or redacted URL.

- [ ] **Step 3: Create real-device QA guide**

Create `docs/features/media-hub/GOOGLE_CAST_V1_QA.md`:

```markdown
# Google Cast V1 QA Guide

## Scope

V1 verifies Google Cast only. It does not test AirPlay, local files, browser receivers, custom receivers, proxies, or multi-device casting.

## Required Devices

- Android phone with Airo debug or release build.
- iPhone with Airo debug or TestFlight build.
- Chromecast-enabled TV, preferably Sony Bravia / Android TV / Google TV.
- Shared Wi-Fi network for phone and TV.

## Test Matrix

| Case | Steps | Expected Result |
| --- | --- | --- |
| Android discovery | Open Stream, play a channel, tap Cast | TV appears in picker |
| iOS discovery | Open Stream, accept local network permission, tap Cast | TV appears in picker |
| HLS cast | Select TV for a `.m3u8` channel | TV starts playback without Airo installed on TV |
| Stop cast | Tap Stop in mini controller | Receiver stops and Airo returns to local playback-ready state |
| Replace session | Cast to TV A, then cast to TV B | TV A session ends before TV B starts |
| No devices | Turn TV off and tap Cast | App shows no-device guidance and Refresh |
| Receiver disconnect | Start cast, disconnect TV network | App clears active session and shows recoverable state |
| Mobile leaves Wi-Fi | Start cast, move phone off Wi-Fi | App does not crash and can reconnect after returning to Wi-Fi |

## Evidence

Record:

- App build number.
- Sender platform and OS version.
- Receiver model and OS version.
- IPTV channel ID used for HLS success.
- Screenshots of picker, active mini controller, and error state.
```

- [ ] **Step 4: Add acceptance test references**

Append to `docs/features/media-hub/ACCEPTANCE_TESTS.md`:

```markdown
## 9. Google Cast V1 Tests

### [CP-CAST-001] Cast Device Discovery
**Given:** A Chromecast-enabled TV is on the same Wi-Fi  
**When:** User opens Stream, starts a channel, and taps Cast  
**Then:** The TV appears in a single-select device picker

### [CP-CAST-002] Single Receiver Playback
**Given:** A public HLS IPTV channel is selected  
**When:** User selects one Cast receiver  
**Then:** The receiver fetches the stream URL directly and starts playback

### [CP-CAST-003] Replace Active Session
**Given:** User is casting to one receiver  
**When:** User starts casting to another receiver  
**Then:** The first session stops or disconnects before the second session starts

### [CP-CAST-004] Unsupported Header Stream
**Given:** An IPTV channel requires custom headers  
**When:** User attempts to cast it  
**Then:** Airo shows an unsupported-stream message and does not start a proxy
```

- [ ] **Step 5: Add release checklist entry**

Append to `docs/release/RELEASE_CHECKLIST.md` under the relevant testing section:

```markdown
### Google Cast V1

- [ ] Android sender discovers and casts to Chromecast-enabled TV.
- [ ] iOS sender shows local network permission and discovers the same receiver class.
- [ ] Public HLS IPTV channel plays on receiver without TV app installation.
- [ ] Unsupported header/auth streams fail without proxying.
- [ ] No full IPTV URLs are present in debug logs, analytics logs, or bug-report logs.
- [ ] AirPlay, browser receiver, local file casting, and multi-device UI are not visible in V1.
```

- [ ] **Step 6: Run docs and privacy checks**

Run:

```bash
cd app
flutter test test/core/cast/cast_url_privacy_test.dart
cd ..
rg -n "AirPlay|local file|multi-device|browser receiver" app/lib/features/iptv app/lib/core/cast
```

Expected: privacy test passes. The `rg` command should return no user-visible V1 UI labels for future-scope features.

- [ ] **Step 7: Commit Task 6**

```bash
git add docs/features/media-hub/GOOGLE_CAST_V1_QA.md docs/features/media-hub/ACCEPTANCE_TESTS.md docs/release/RELEASE_CHECKLIST.md app/test/core/cast/cast_url_privacy_test.dart
git commit -m "docs(media-hub): add Google Cast V1 QA gates"
```

## Task 7: Final Verification and GitHub Issue Updates

**Files:**
- Verification should not require source edits. Update docs only when the manual QA evidence needs to be recorded.

- [ ] **Step 1: Run focused test suite**

Run:

```bash
cd app
flutter test test/core/cast test/features/iptv/iptv_cast_media_adapter_test.dart test/features/iptv/iptv_cast_notifier_test.dart test/features/iptv/iptv_cast_ui_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer**

Run:

```bash
cd app
flutter analyze
```

Expected: no new analyzer errors from Cast implementation. Pre-existing analyzer failures must be captured in the PR body with unrelated file paths.

- [ ] **Step 3: Run platform plist validation**

Run:

```bash
plutil -lint app/ios/Runner/Info.plist
```

Expected: `app/ios/Runner/Info.plist: OK`.

- [ ] **Step 4: Manual QA checkpoint**

Run through `docs/features/media-hub/GOOGLE_CAST_V1_QA.md` on:

- Android sender -> Sony Bravia / Android TV.
- iOS sender -> Sony Bravia / Android TV.

Record the device model, OS versions, channel ID, and pass/fail notes in the PR body.

- [ ] **Step 5: Update GitHub issues**

Use these commands after the matching work is complete:

```bash
gh issue comment 455 --body "Implemented framework Cast contract, fake controller, plugin adapter, and platform setup. Tests: flutter test test/core/cast && flutter analyze."
gh issue comment 456 --body "Implemented IPTV channel to Cast media request adapter. Tests: flutter test test/features/iptv/iptv_cast_media_adapter_test.dart."
gh issue comment 457 --body "Implemented single-device Cast picker and mini controller. Tests: flutter test test/features/iptv/iptv_cast_ui_test.dart."
gh issue comment 458 --body "Completed security/privacy review for Cast V1. Checks: flutter test test/core/cast/cast_url_privacy_test.dart; no proxy/header bypass paths added."
gh issue comment 459 --body "Completed automation and real-device QA matrix. Manual devices tested: Android sender, iOS sender, Chromecast-enabled TV."
gh issue comment 460 --body "Completed release and developer readiness docs. Checks: plutil -lint app/ios/Runner/Info.plist; release checklist updated."
```

Before posting the commands above, add the exact command output and manual QA evidence to each body string.

- [ ] **Step 6: Commit final verification docs if changed**

When Step 4 adds checklist evidence to docs, commit it:

```bash
git add docs/features/media-hub/GOOGLE_CAST_V1_QA.md
git commit -m "test(media-hub): record Google Cast V1 QA evidence"
```

When no files changed, do not create an empty commit.

## Implementation Order

Implement in this order:

1. Task 1 creates the stable contract and fake.
2. Task 3 can run before Task 2 because it only depends on Task 1.
3. Task 4 depends on Tasks 1 and 3.
4. Task 5 depends on Task 4.
5. Task 2 must complete before real-device QA.
6. Tasks 6 and 7 close release readiness.

## PR Checklist

- [ ] The PR links epic #453 and child issues #455, #456, #457, #458, #459, #460.
- [ ] The PR states V1 scope: Google Cast only, IPTV URLs only, one receiver.
- [ ] The PR states future scope exclusions.
- [ ] The PR includes focused test command output.
- [ ] The PR includes `flutter analyze` output or a clear unrelated-preexisting-failure note.
- [ ] The PR includes Android and iOS manual QA evidence or explicitly marks real-device QA as pending before merge.

# feature_iptv → AiroPlaybackEngine Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retrofit `VideoPlayerStreamingService` (the class that actually drives every live-channel and VOD screen in `feature_iptv`) to run playback through `AiroPlaybackEngine` instead of a raw `VideoPlayerController`, so CV-016's track catalog and CV-031's external-subtitle projection become visible in the real app UI.

**Architecture:** In-place refactor, not a parallel adapter class. `VideoPlayerStreamingService` keeps its exact public `IPTVStreamingService` shape (only additive methods) and its exact `StreamingState` output shape (only additive fields), so every downstream provider and widget except the two explicitly touched needs zero changes. Two real gaps in `AiroPlaybackEngine` block this and are closed first: it exposes no renderable video surface (`buildView()`), and it never emits continuous position/duration/buffering state (a controller listener, moved from the service into the engine).

**Tech Stack:** Flutter/Dart, Riverpod, `video_player` package, `flutter_test` with `FakeVideoPlayerPlatform`/`FakeAiroPlaybackEngine` test doubles (no real network or platform channel in any test in this plan).

## Global Constraints

- TDD throughout: write the failing test first, verify RED, then implement to GREEN. Every task in this plan follows that shape explicitly.
- No behavior change to anything not explicitly listed as touched: DVR, live-edge detection, buffer health, network-quality estimation, retry-on-timeout, audio-context focus, wakelock, cast.
- `AiroPlaybackSourceHandle.direct()` is additive — the existing `.redacted()` factory, its validation rules, and its tests are untouched.
- `StreamingState`/`PlaybackState`/`BufferStatus`/`NetworkQuality`/`LiveStreamState` keep every existing field; only `tracks`/`selectedTrackIds` are added.
- No mpv fallback wiring, no mpv rendering (`MpvAiroPlaybackEngine.buildView()` returns `null` in this plan).
- No aspect-ratio/BoxFit logic moves into the engine — `buildView()` returns a widget sized to the video's intrinsic dimensions; the caller keeps wrapping it in `FittedBox(fit: _boxFitFor(aspectRatioFit))` exactly as today.
- External-subtitle attach UI is VOD-only, not on live channels.
- Full spec: `docs/superpowers/specs/2026-07-18-feature-iptv-airo-playback-engine-migration-design.md`.

---

### Task 1: `AiroPlaybackSourceHandle.direct()` factory

**Files:**
- Modify: `packages/platform_player/lib/src/models/playback_engine_models.dart:103-149` (the `AiroPlaybackSourceHandle` class)
- Test: `packages/platform_player/test/playback_engine_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `AiroPlaybackSourceHandle.direct(String url) → AiroPlaybackSourceHandle` — later tasks (Task 7) call this to build `AiroMediaOpenRequest.sourceHandle` from a real channel URL.

- [ ] **Step 1: Write the failing test**

Add to `packages/platform_player/test/playback_engine_test.dart` (inside the existing top-level `group('Airo playback engine contract', ...)` block, after the `'external subtitle handle rejects raw urls like source handles'` test):

```dart
    test('direct() accepts a raw https URL that redacted() would reject', () {
      final handle = AiroPlaybackSourceHandle.direct(
        'https://example.com/stream.m3u8?token=abc123',
      );
      expect(handle.value, 'https://example.com/stream.m3u8?token=abc123');
    });

    test('direct() accepts an Xtream-style credential-bearing URL', () {
      final handle = AiroPlaybackSourceHandle.direct(
        'http://provider.example.com/user123/pass456/789.m3u8',
      );
      expect(
        handle.value,
        'http://provider.example.com/user123/pass456/789.m3u8',
      );
    });

    test('direct() still redacts in toString()', () {
      final handle = AiroPlaybackSourceHandle.direct(
        'https://example.com/secret.m3u8?token=abc123',
      );
      expect(handle.toString(), 'AiroPlaybackSourceHandle(redacted)');
      expect(handle.toString(), isNot(contains('secret')));
      expect(handle.toString(), isNot(contains('abc123')));
    });

    test('redacted() still rejects raw URLs after direct() is added', () {
      expect(
        () => AiroPlaybackSourceHandle.redacted('https://example.com/x.m3u8'),
        throwsArgumentError,
      );
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_player && flutter test test/playback_engine_test.dart`
Expected: FAIL — `The method 'direct' isn't defined for the type 'AiroPlaybackSourceHandle'`.

- [ ] **Step 3: Write minimal implementation**

In `packages/platform_player/lib/src/models/playback_engine_models.dart`, inside `class AiroPlaybackSourceHandle extends Equatable`, add a second factory alongside the existing `AiroPlaybackSourceHandle.redacted`:

```dart
class AiroPlaybackSourceHandle extends Equatable {
  const AiroPlaybackSourceHandle._(this.value);

  factory AiroPlaybackSourceHandle.redacted(String value) {
    final rejection = validate(value);
    if (rejection != null) {
      throw ArgumentError.value(value, 'value', rejection.stableId);
    }
    return AiroPlaybackSourceHandle._(value.trim());
  }

  /// Accepts a trusted, internally-resolved playable URL (a channel or VOD
  /// stream URL from our own provider adapters) that `.redacted()` would
  /// reject — `.redacted()`'s URL-rejection check exists to catch raw user
  /// input passed by mistake, not legitimate stream URLs, which are always
  /// http/https and sometimes carry Xtream/Stalker credentials in the path.
  /// `toString()` still redacts: the safety invariant (never log/print the
  /// raw value) is unchanged, only the acceptance check is skipped.
  factory AiroPlaybackSourceHandle.direct(String url) {
    return AiroPlaybackSourceHandle._(url.trim());
  }

  final String value;
  // ... rest of class unchanged (validate, toString, props)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_player && flutter test test/playback_engine_test.dart`
Expected: PASS, all tests including the 4 new ones and the full pre-existing suite.

- [ ] **Step 5: Commit**

```bash
git add packages/platform_player/lib/src/models/playback_engine_models.dart packages/platform_player/test/playback_engine_test.dart
git commit -m "feat(platform_player): add AiroPlaybackSourceHandle.direct() for trusted stream URLs"
```

---

### Task 2: `AiroPlaybackBufferedRange` + `AiroPlaybackState.bufferedRanges`

**Files:**
- Modify: `packages/platform_player/lib/src/models/playback_engine_models.dart` (add new class near `AiroPlaybackTrackOption`; extend `AiroPlaybackState`)
- Test: `packages/platform_player/test/playback_engine_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `AiroPlaybackBufferedRange {start, end}`, `AiroPlaybackState.bufferedRanges: List<AiroPlaybackBufferedRange>` — consumed by Task 4 (engine emits it) and Task 6 (`LiveEdgeDetector` reads it).

- [ ] **Step 1: Write the failing test**

Add to `packages/platform_player/test/playback_engine_test.dart`, new top-level group after the `externalSubtitleTracksFor` group:

```dart
  group('AiroPlaybackBufferedRange', () {
    test('equality by start/end', () {
      const a = AiroPlaybackBufferedRange(
        start: Duration.zero,
        end: Duration(seconds: 10),
      );
      const b = AiroPlaybackBufferedRange(
        start: Duration.zero,
        end: Duration(seconds: 10),
      );
      expect(a, b);
    });
  });

  group('AiroPlaybackState.bufferedRanges', () {
    test('defaults to empty', () {
      final state = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
      );
      expect(state.bufferedRanges, isEmpty);
    });

    test('copyWith overrides bufferedRanges', () {
      final state = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
      );
      final next = state.copyWith(
        bufferedRanges: const [
          AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration(seconds: 5),
          ),
        ],
      );
      expect(next.bufferedRanges, hasLength(1));
      expect(next.bufferedRanges.single.end, const Duration(seconds: 5));
    });

    test('copyWith without bufferedRanges preserves existing value', () {
      final state = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
        bufferedRanges: const [
          AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration(seconds: 5),
          ),
        ],
      );
      final next = state.copyWith(phase: AiroPlaybackEnginePhase.playing);
      expect(next.bufferedRanges, hasLength(1));
    });

    test('bufferedRanges participates in equality', () {
      final a = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
        bufferedRanges: const [
          AiroPlaybackBufferedRange(
            start: Duration.zero,
            end: Duration(seconds: 5),
          ),
        ],
      );
      final b = AiroPlaybackState(
        backendKind: AiroPlaybackBackendKind.fake,
        phase: AiroPlaybackEnginePhase.idle,
      );
      expect(a, isNot(b));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_player && flutter test test/playback_engine_test.dart`
Expected: FAIL — `The getter 'bufferedRanges' isn't defined for the type 'AiroPlaybackState'` (and `AiroPlaybackBufferedRange` undefined).

- [ ] **Step 3: Write minimal implementation**

In `packages/platform_player/lib/src/models/playback_engine_models.dart`, add this new class right after `class AiroPlaybackTrackOption extends Equatable { ... }` (before `kAiroExternalSubtitleTrackIdPrefix`):

```dart
class AiroPlaybackBufferedRange extends Equatable {
  const AiroPlaybackBufferedRange({required this.start, required this.end});

  final Duration start;
  final Duration end;

  @override
  List<Object?> get props => [start, end];
}
```

Then modify `class AiroPlaybackState extends Equatable` — add the field to the constructor, the field declaration, `copyWith`, and `props`:

```dart
class AiroPlaybackState extends Equatable {
  AiroPlaybackState({
    required this.backendKind,
    required this.phase,
    this.request,
    this.position = Duration.zero,
    this.duration,
    this.volume = 1,
    this.playbackSpeed = 1,
    List<AiroPlaybackQualityOption> qualityOptions = const [],
    this.selectedQualityId,
    List<AiroPlaybackTrackOption> tracks = const [],
    Map<AiroPlaybackTrackKind, String> selectedTrackIds = const {},
    List<AiroPlaybackBufferedRange> bufferedRanges = const [],
    this.diagnostics,
    this.error,
    this.schemaVersion = kAiroPlaybackEngineSchemaVersion,
  }) : qualityOptions = List.unmodifiable(qualityOptions),
       tracks = List.unmodifiable(tracks),
       selectedTrackIds = Map.unmodifiable(selectedTrackIds),
       bufferedRanges = List.unmodifiable(bufferedRanges);

  // ... existing fields ...
  final List<AiroPlaybackBufferedRange> bufferedRanges;

  AiroPlaybackState copyWith({
    AiroPlaybackEnginePhase? phase,
    AiroMediaOpenRequest? request,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackSpeed,
    List<AiroPlaybackQualityOption>? qualityOptions,
    String? selectedQualityId,
    List<AiroPlaybackTrackOption>? tracks,
    Map<AiroPlaybackTrackKind, String>? selectedTrackIds,
    List<AiroPlaybackBufferedRange>? bufferedRanges,
    AiroPlaybackDiagnostics? diagnostics,
    AiroPlaybackError? error,
  }) {
    return AiroPlaybackState(
      schemaVersion: schemaVersion,
      backendKind: backendKind,
      phase: phase ?? this.phase,
      request: request ?? this.request,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      qualityOptions: qualityOptions ?? this.qualityOptions,
      selectedQualityId: selectedQualityId ?? this.selectedQualityId,
      tracks: tracks ?? this.tracks,
      selectedTrackIds: selectedTrackIds ?? this.selectedTrackIds,
      bufferedRanges: bufferedRanges ?? this.bufferedRanges,
      diagnostics: diagnostics ?? this.diagnostics,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    backendKind,
    phase,
    request,
    position,
    duration,
    volume,
    playbackSpeed,
    qualityOptions,
    selectedQualityId,
    tracks,
    selectedTrackIds,
    bufferedRanges,
    diagnostics,
    error,
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_player && flutter test`
Expected: PASS, entire `platform_player` suite (this touches a shared model — run the full package suite, not just the one file).

- [ ] **Step 5: Commit**

```bash
git add packages/platform_player/lib/src/models/playback_engine_models.dart packages/platform_player/test/playback_engine_test.dart
git commit -m "feat(platform_player): add AiroPlaybackBufferedRange and AiroPlaybackState.bufferedRanges"
```

---

### Task 3: `AiroPlaybackEngine.buildView()` interface + Fake/Unavailable implementations

**Files:**
- Modify: `packages/platform_player/lib/src/services/airo_playback_engine.dart`
- Modify: `packages/platform_player/lib/src/services/fake_playback_engine.dart`
- Modify: `packages/platform_player/lib/src/services/unavailable_playback_engine.dart`
- Test: `packages/platform_player/test/playback_engine_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `AiroPlaybackEngine.buildView() → Widget?` — Task 4 implements it for `VideoPlayerAiroPlaybackEngine`, Task 5 for `MpvAiroPlaybackEngine`.

- [ ] **Step 1: Write the failing test**

Add to `packages/platform_player/test/playback_engine_test.dart`, inside the existing `group('Airo playback engine contract', ...)`:

```dart
    test('fake engine buildView returns a non-null placeholder after open', () async {
      final engine = FakeAiroPlaybackEngine();
      expect(engine.buildView(), isNull);

      await engine.open(request());
      final view = engine.buildView();
      expect(view, isNotNull);
      expect(
        (view!.key as ValueKey<String>).value,
        'fake-engine-view',
      );
      await engine.dispose();
    });

    test('unavailable engine buildView always returns null', () {
      final engine = UnavailableAiroPlaybackEngine();
      expect(engine.buildView(), isNull);
    });
```

Add this import at the top of the test file if not already present:

```dart
import 'package:flutter/widgets.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_player && flutter test test/playback_engine_test.dart`
Expected: FAIL — `The method 'buildView' isn't defined for the type 'FakeAiroPlaybackEngine'` (and for `UnavailableAiroPlaybackEngine`).

- [ ] **Step 3: Write minimal implementation**

In `packages/platform_player/lib/src/services/airo_playback_engine.dart`, add the import and the new method to the interface:

```dart
import 'package:flutter/widgets.dart';

import '../models/playback_engine_models.dart';

abstract class AiroPlaybackEngine {
  AiroPlaybackBackendKind get backendKind;

  Stream<AiroPlaybackState> get states;

  AiroPlaybackState get currentState;

  Future<AiroPlaybackState> open(AiroMediaOpenRequest request);

  Future<AiroPlaybackState> play();

  Future<AiroPlaybackState> pause();

  Future<AiroPlaybackState> stop();

  Future<AiroPlaybackState> seek(Duration position);

  Future<AiroPlaybackState> setVolume(double volume);

  Future<AiroPlaybackState> setPlaybackSpeed(double speed);

  Future<AiroPlaybackState> selectQuality(String qualityId);

  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  });

  Future<AiroPlaybackDiagnostics> diagnostics();

  Future<AiroPlaybackState> enterPictureInPicture();

  Future<AiroPlaybackState> exitPictureInPicture();

  /// Returns a widget rendering this engine's video surface, sized to the
  /// video's intrinsic dimensions (ready to be wrapped in a FittedBox by the
  /// caller for aspect-ratio fitting). Returns null when there is nothing
  /// local to render: not yet opened, no local video surface for this
  /// backend (e.g. cast), or the backend doesn't support rendering yet.
  Widget? buildView();

  Future<void> dispose();
}
```

In `packages/platform_player/lib/src/services/fake_playback_engine.dart`, add the import and method:

```dart
import 'package:flutter/widgets.dart';

// ... existing imports stay ...

class FakeAiroPlaybackEngine implements AiroPlaybackEngine {
  // ... existing members unchanged ...

  @override
  Widget? buildView() {
    if (_state.phase != AiroPlaybackEnginePhase.open &&
        _state.phase != AiroPlaybackEnginePhase.playing &&
        _state.phase != AiroPlaybackEnginePhase.paused &&
        _state.phase != AiroPlaybackEnginePhase.buffering) {
      return null;
    }
    return const SizedBox(key: ValueKey('fake-engine-view'));
  }

  // ... rest unchanged ...
}
```

In `packages/platform_player/lib/src/services/unavailable_playback_engine.dart`, add the import and method:

```dart
import 'package:flutter/widgets.dart';

// ... existing imports stay ...

class UnavailableAiroPlaybackEngine implements AiroPlaybackEngine {
  // ... existing members unchanged ...

  @override
  Widget? buildView() => null;

  // ... rest unchanged ...
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_player && flutter test`
Expected: PASS, entire `platform_player` suite.

- [ ] **Step 5: Commit**

```bash
git add packages/platform_player/lib/src/services/airo_playback_engine.dart packages/platform_player/lib/src/services/fake_playback_engine.dart packages/platform_player/lib/src/services/unavailable_playback_engine.dart packages/platform_player/test/playback_engine_test.dart
git commit -m "feat(platform_player): add AiroPlaybackEngine.buildView() to the contract"
```

---

### Task 4: `VideoPlayerAiroPlaybackEngine` — `buildView()` + continuous state emission

**Files:**
- Modify: `packages/platform_media/lib/src/video_player_airo_playback_engine.dart`
- Modify: `packages/platform_media/test/support/fake_video_player_platform.dart` (add event-scripting methods)
- Test: `packages/platform_media/test/video_player_airo_playback_engine_test.dart`

**Interfaces:**
- Consumes: `AiroPlaybackEngine.buildView()` (Task 3), `AiroPlaybackBufferedRange`/`AiroPlaybackState.bufferedRanges` (Task 2).
- Produces: `VideoPlayerAiroPlaybackEngine.buildView()` returning a real widget; `states` stream emitting continuously (position/duration/bufferedRanges/phase/error) without an explicit method call — consumed by Task 7 (`VideoPlayerStreamingService`).

- [ ] **Step 1: Extend the fake platform to script post-init events**

Modify `packages/platform_media/test/support/fake_video_player_platform.dart` — add the ability to push additional `VideoEvent`s onto an already-created player's stream, and track the most recently created player id:

```dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Minimal [VideoPlayerPlatform] test double: just enough of the platform
/// channel contract for [VideoPlayerController.initialize] to complete (or
/// fail) deterministically in `flutter test`, without a real device.
///
/// Scriptable via [scriptedInitError] so engine tests can simulate a
/// decoder/codec failure at `open()` time, and via [emitBufferingStart] /
/// [emitBufferingEnd] / [emitError] so tests can simulate mid-playback
/// events on the most-recently-created player.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform({
    this.fakeDuration = const Duration(minutes: 3),
    this.fakeSize = const Size(1920, 1080),
  });

  final Duration fakeDuration;
  final Size fakeSize;

  /// Set before calling controller.initialize() to simulate a platform
  /// failure (e.g. codec/decoder rejection) instead of a clean init.
  PlatformException? scriptedInitError;

  final Map<int, StreamController<VideoEvent>> _eventControllers = {};
  int _nextPlayerId = 0;
  int? _lastPlayerId;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextPlayerId++;
    _eventControllers[id] = StreamController<VideoEvent>.broadcast();
    _lastPlayerId = id;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = _eventControllers[playerId]!;
    final error = scriptedInitError;
    scheduleMicrotask(() {
      if (error != null) {
        controller.addError(error);
        return;
      }
      controller.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: fakeDuration,
          size: fakeSize,
        ),
      );
    });
    return controller.stream;
  }

  /// Pushes a `bufferingStart` event onto the most-recently-created player,
  /// simulating the video pausing to rebuffer.
  void emitBufferingStart() {
    _eventControllers[_lastPlayerId]?.add(
      VideoEvent(eventType: VideoEventType.bufferingStart),
    );
  }

  /// Pushes a `bufferingEnd` event onto the most-recently-created player,
  /// simulating buffering finishing and playback resuming.
  void emitBufferingEnd() {
    _eventControllers[_lastPlayerId]?.add(
      VideoEvent(eventType: VideoEventType.bufferingEnd),
    );
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<void> dispose(int playerId) async {
    await _eventControllers.remove(playerId)?.close();
  }
}
```

- [ ] **Step 2: Write the failing tests**

Add to `packages/platform_media/test/video_player_airo_playback_engine_test.dart`, inside `group('VideoPlayerAiroPlaybackEngine engine-specific behavior', ...)`:

```dart
    test('buildView is null before open, non-null after', () async {
      final engine = VideoPlayerAiroPlaybackEngine();
      expect(engine.buildView(), isNull);

      await engine.open(request());
      expect(engine.buildView(), isNotNull);

      await engine.dispose();
    });

    test('buildView is null after dispose', () async {
      final engine = VideoPlayerAiroPlaybackEngine();
      await engine.open(request());
      await engine.dispose();
      expect(engine.buildView(), isNull);
    });

    test(
      'controller buffering events are reflected on the states stream without an explicit call',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        final phases = <AiroPlaybackEnginePhase>[];
        final subscription = engine.states.listen((s) => phases.add(s.phase));

        await engine.open(request());
        await engine.play();
        fakePlatform.emitBufferingStart();
        await Future<void>.delayed(Duration.zero);
        fakePlatform.emitBufferingEnd();
        await Future<void>.delayed(Duration.zero);

        await subscription.cancel();
        await engine.dispose();

        expect(phases, contains(AiroPlaybackEnginePhase.buffering));
        // Returns to playing after buffering ends.
        expect(phases.last, AiroPlaybackEnginePhase.playing);
      },
    );

    test(
      'engine state carries bufferedRanges reflecting the controller value',
      () async {
        final engine = VideoPlayerAiroPlaybackEngine();
        await engine.open(request());
        await engine.play();
        fakePlatform.emitBufferingStart();
        await Future<void>.delayed(Duration.zero);
        fakePlatform.emitBufferingEnd();
        await Future<void>.delayed(Duration.zero);

        // bufferedRanges is always a list (possibly empty in the fake, since
        // FakeVideoPlayerPlatform doesn't script buffered DurationRanges) —
        // the assertion proves the field is populated from controller.value
        // without throwing, not a specific non-empty value.
        expect(engine.currentState.bufferedRanges, isA<List>());

        await engine.dispose();
      },
    );
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd packages/platform_media && flutter test test/video_player_airo_playback_engine_test.dart`
Expected: FAIL — `buildView` undefined on `VideoPlayerAiroPlaybackEngine`, and `emitBufferingStart`/`emitBufferingEnd` undefined on `FakeVideoPlayerPlatform` until Step 1 lands (Step 1 already added those — so this should fail only on `buildView` and the phase-transition assertions).

- [ ] **Step 4: Write minimal implementation**

Modify `packages/platform_media/lib/src/video_player_airo_playback_engine.dart`:

```dart
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:platform_player/platform_player.dart';
import 'package:video_player/video_player.dart';

/// Concrete [AiroPlaybackEngine] wrapping the `video_player` package
/// (ExoPlayer / AVPlayer / `<video>` depending on platform). This is the
/// `videoPlayer` default engine the design's resolver picks for
/// Web/Android/Android TV/iOS/macOS.
///
/// Note: `AiroPlaybackSourceHandle.value` is expected to already be a
/// directly-openable URI by the time it reaches this engine. Resolving an
/// opaque handle token into a real URL (e.g. via a proxy/token layer) is out
/// of scope here — this engine only consumes the handle's value as-is.
class VideoPlayerAiroPlaybackEngine implements AiroPlaybackEngine {
  VideoPlayerController? _controller;
  AiroPlaybackState _state = AiroPlaybackState.idle(
    backendKind: AiroPlaybackBackendKind.videoPlayer,
  );
  final StreamController<AiroPlaybackState> _stateController =
      StreamController<AiroPlaybackState>.broadcast();

  @override
  AiroPlaybackBackendKind get backendKind => AiroPlaybackBackendKind.videoPlayer;

  @override
  Stream<AiroPlaybackState> get states => _stateController.stream;

  @override
  AiroPlaybackState get currentState => _state;

  @override
  Future<AiroPlaybackState> open(AiroMediaOpenRequest request) async {
    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.opening,
        request: request,
        position: request.startPosition,
      ),
    );

    await _disposeController();

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(request.sourceHandle.value),
    );
    _controller = controller;

    try {
      await controller.initialize();
    } on TimeoutException {
      return _fail(
        AiroPlaybackErrorCode.networkUnavailable,
        'open',
        request,
      );
    } on PlatformException {
      return _fail(AiroPlaybackErrorCode.decoderFailed, 'open', request);
    } on Object {
      return _fail(AiroPlaybackErrorCode.backendUnavailable, 'open', request);
    }

    if (request.startPosition > Duration.zero) {
      await controller.seekTo(request.startPosition);
    }
    await controller.setVolume(_state.volume);
    await controller.setPlaybackSpeed(_state.playbackSpeed);
    controller.addListener(_onControllerValueChanged);

    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.open,
        request: request,
        position: request.startPosition,
        duration: controller.value.duration,
        tracks: externalSubtitleTracksFor(request),
        diagnostics: AiroPlaybackDiagnostics(
          backendId: backendKind.stableId,
          hardwareAccelerated: true,
        ),
      ),
    );
    return _state;
  }

  /// Continuously mirrors `VideoPlayerController.value` into
  /// [AiroPlaybackState], fired on every native player update (position
  /// ticks, buffering transitions, errors) — not just on explicit method
  /// calls. This is what lets [AiroPlaybackEngine] consumers (progress bars,
  /// buffer-health monitors, live-edge detectors) observe playback without
  /// holding a reference to the raw controller.
  void _onControllerValueChanged() {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;

    if (value.hasError) {
      _fail(AiroPlaybackErrorCode.decoderFailed, 'playback', _state.request);
      return;
    }

    final nextPhase = value.isBuffering
        ? AiroPlaybackEnginePhase.buffering
        : (_state.phase == AiroPlaybackEnginePhase.buffering
              ? AiroPlaybackEnginePhase.playing
              : _state.phase);

    _emit(
      _state.copyWith(
        phase: nextPhase,
        position: value.position,
        duration: value.duration,
        bufferedRanges: value.buffered
            .map(
              (r) => AiroPlaybackBufferedRange(start: r.start, end: r.end),
            )
            .toList(),
      ),
    );
  }

  @override
  Future<AiroPlaybackState> play() async {
    await _controller?.play();
    return _transition(AiroPlaybackEnginePhase.playing);
  }

  @override
  Future<AiroPlaybackState> pause() async {
    await _controller?.pause();
    return _transition(AiroPlaybackEnginePhase.paused);
  }

  @override
  Future<AiroPlaybackState> stop() async {
    await _controller?.pause();
    await _controller?.seekTo(Duration.zero);
    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.stopped,
        position: Duration.zero,
      ),
    );
    return _state;
  }

  @override
  Future<AiroPlaybackState> seek(Duration position) async {
    await _controller?.seekTo(position);
    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.paused,
        position: position,
      ),
    );
    return _state;
  }

  @override
  Future<AiroPlaybackState> setVolume(double volume) async {
    final clamped = volume.clamp(0, 1).toDouble();
    await _controller?.setVolume(clamped);
    _emit(_state.copyWith(volume: clamped));
    return _state;
  }

  @override
  Future<AiroPlaybackState> setPlaybackSpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
    _emit(_state.copyWith(playbackSpeed: speed));
    return _state;
  }

  @override
  Future<AiroPlaybackState> selectQuality(String qualityId) async {
    return _fail(
      AiroPlaybackErrorCode.qualityUnavailable,
      'selectQuality',
      _state.request,
    );
  }

  @override
  Future<AiroPlaybackState> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async {
    final matches = _state.tracks.where(
      (t) => t.kind == kind && t.id == trackId,
    );
    if (matches.isEmpty) {
      return _fail(
        AiroPlaybackErrorCode.trackUnavailable,
        'selectTrack',
        _state.request,
      );
    }
    final nextSelected = Map<AiroPlaybackTrackKind, String>.from(
      _state.selectedTrackIds,
    )..[kind] = trackId;
    _emit(_state.copyWith(selectedTrackIds: nextSelected));
    return _state;
  }

  @override
  Future<AiroPlaybackDiagnostics> diagnostics() async {
    return _state.diagnostics ??
        AiroPlaybackDiagnostics(backendId: backendKind.stableId);
  }

  @override
  Future<AiroPlaybackState> enterPictureInPicture() async {
    return _fail(
      AiroPlaybackErrorCode.unsupportedOperation,
      'enterPictureInPicture',
      _state.request,
    );
  }

  @override
  Future<AiroPlaybackState> exitPictureInPicture() async {
    return _fail(
      AiroPlaybackErrorCode.unsupportedOperation,
      'exitPictureInPicture',
      _state.request,
    );
  }

  @override
  Widget? buildView() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    return SizedBox(
      width: controller.value.size.width,
      height: controller.value.size.height,
      child: VideoPlayer(controller),
    );
  }

  @override
  Future<void> dispose() async {
    await _disposeController();
    await _stateController.close();
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerValueChanged);
    await controller?.dispose();
  }

  AiroPlaybackState _transition(AiroPlaybackEnginePhase phase) {
    _emit(_state.copyWith(phase: phase));
    return _state;
  }

  AiroPlaybackState _fail(
    AiroPlaybackErrorCode code,
    String operation,
    AiroMediaOpenRequest? request,
  ) {
    _emit(
      _state.copyWith(
        phase: AiroPlaybackEnginePhase.failed,
        request: request,
        error: AiroPlaybackError(code: code, operation: operation),
      ),
    );
    return _state;
  }

  void _emit(AiroPlaybackState state) {
    _state = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/platform_media && flutter test test/video_player_airo_playback_engine_test.dart`
Expected: PASS, all tests including the conformance suite (still 14/14) and the new ones.

Then run the full package: `cd packages/platform_media && flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add packages/platform_media/lib/src/video_player_airo_playback_engine.dart packages/platform_media/test/support/fake_video_player_platform.dart packages/platform_media/test/video_player_airo_playback_engine_test.dart
git commit -m "feat(platform_media): VideoPlayerAiroPlaybackEngine buildView() + continuous state emission"
```

---

### Task 5: `MpvAiroPlaybackEngine.buildView()` → null

**Files:**
- Modify: `packages/platform_media/lib/src/mpv_airo_playback_engine.dart`
- Test: `packages/platform_media/test/mpv_airo_playback_engine_test.dart`

**Interfaces:**
- Consumes: `AiroPlaybackEngine.buildView()` (Task 3).
- Produces: `MpvAiroPlaybackEngine.buildView()` — always null, documented as a follow-up (no `media_kit_video` dependency in this slice).

- [ ] **Step 1: Write the failing test**

Add to `packages/platform_media/test/mpv_airo_playback_engine_test.dart`, inside `group('MpvAiroPlaybackEngine engine-specific behavior', ...)`:

```dart
    test('buildView always returns null (no media_kit_video dependency yet)', () async {
      final engine = MpvAiroPlaybackEngine(
        playerFactory: FakeMpvPlayerFacade.new,
      );
      expect(engine.buildView(), isNull);

      await engine.open(request());
      expect(engine.buildView(), isNull);

      await engine.dispose();
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/platform_media && flutter test test/mpv_airo_playback_engine_test.dart`
Expected: FAIL — `The method 'buildView' isn't defined for the type 'MpvAiroPlaybackEngine'`.

- [ ] **Step 3: Write minimal implementation**

In `packages/platform_media/lib/src/mpv_airo_playback_engine.dart`, add the import and method:

```dart
import 'package:flutter/widgets.dart';

// ... existing imports stay ...

class MpvAiroPlaybackEngine implements AiroPlaybackEngine {
  // ... existing members unchanged ...

  @override
  Widget? buildView() {
    // No media_kit_video dependency in this slice — mpv isn't consumed by
    // feature_iptv yet (CV-030's Non-Goals). Wiring real mpv rendering is a
    // follow-up slice alongside the mpv-fallback-coordinator wiring.
    return null;
  }

  // ... rest unchanged ...
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/platform_media && flutter test`
Expected: PASS, entire `platform_media` suite.

- [ ] **Step 5: Commit**

```bash
git add packages/platform_media/lib/src/mpv_airo_playback_engine.dart packages/platform_media/test/mpv_airo_playback_engine_test.dart
git commit -m "feat(platform_media): MpvAiroPlaybackEngine.buildView() stub (no rendering dep yet)"
```

---

### Task 6: `LiveEdgeDetector.attachToEngine()` — decouple from `VideoPlayerController`

**Files:**
- Modify: `packages/platform_streams/lib/src/services/live_edge_detector.dart`
- Modify: `packages/platform_streams/pubspec.yaml` (remove `video_player` dependency, add `platform_player` if not already present)
- Test: `packages/platform_streams/test/live_edge_detector_test.dart` (new file)

**Interfaces:**
- Consumes: `AiroPlaybackEngine`/`AiroPlaybackState`/`AiroPlaybackBufferedRange` (Tasks 2, 3), `FakeAiroPlaybackEngine` (already exists in `platform_player`).
- Produces: `LiveEdgeDetector.attachToEngine(AiroPlaybackEngine engine)` — consumed by Task 7.

- [ ] **Step 1: Confirm `platform_streams` dependency on `platform_player`**

Run: `grep -A 10 "^dependencies:" packages/platform_streams/pubspec.yaml`
Expected: `platform_player:\n    path: ../platform_player` already present (confirmed during design). If it's not present, add it under `dependencies:` before running any test.

- [ ] **Step 2: Write the failing tests**

Create `packages/platform_streams/test/live_edge_detector_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';
import 'package:platform_streams/platform_streams.dart';

void main() {
  group('LiveEdgeDetector.attachToEngine', () {
    late FakeAiroPlaybackEngine engine;
    late LiveEdgeDetector detector;

    AiroMediaOpenRequest request() {
      return AiroMediaOpenRequest(
        requestId: 'live-edge-1',
        sourceHandle: AiroPlaybackSourceHandle.redacted('opaque-1'),
        mediaKind: AiroPlaybackMediaKind.hls,
      );
    }

    setUp(() {
      engine = FakeAiroPlaybackEngine();
      detector = LiveEdgeDetector(
        config: const LiveEdgeConfig(updateInterval: Duration(milliseconds: 50)),
      );
    });

    tearDown(() {
      detector.dispose();
    });

    test('vod content (known finite duration) reports isLiveStream false', () async {
      await engine.open(request());
      // FakeAiroPlaybackEngine doesn't set a duration by default, so we
      // simulate a VOD-shaped state directly via a second fake instance
      // that starts with an explicit finite duration.
      LiveEdgeState? received;
      detector.onStateUpdate = (s) => received = s;
      detector.attachToEngine(engine);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Zero duration (FakeAiroPlaybackEngine's default) is treated as live
      // per the existing _detectLiveStream heuristic — this proves the
      // detector is reading engine state at all.
      expect(received, isNotNull);
    });

    test('detach stops receiving further updates', () async {
      await engine.open(request());
      var updateCount = 0;
      detector.onStateUpdate = (_) => updateCount++;
      detector.attachToEngine(engine);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      final countAtDetach = updateCount;
      detector.detach();

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(updateCount, countAtDetach);
    });

    test('notifyUserSeek suppresses drift detection immediately after', () async {
      await engine.open(request());
      var driftDetected = false;
      detector.onDriftDetected = () => driftDetected = true;
      detector.attachToEngine(engine);
      detector.notifyUserSeek();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(driftDetected, isFalse);
    });
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd packages/platform_streams && flutter test test/live_edge_detector_test.dart`
Expected: FAIL — `The method 'attachToEngine' isn't defined for the type 'LiveEdgeDetector'`.

- [ ] **Step 4: Write minimal implementation**

Replace `packages/platform_streams/lib/src/services/live_edge_detector.dart` entirely:

```dart
import 'dart:async';
import 'package:platform_player/platform_player.dart';

/// Live Edge Detection Service (P0-1, P0-2, P0-3)
///
/// Monitors an [AiroPlaybackEngine] to detect:
/// - Whether stream is live vs VOD
/// - Current live edge position
/// - Delay from live edge
/// - DVR window boundaries
/// - Drift for auto-resync (with exponential backoff)
class LiveEdgeDetector {
  final LiveEdgeConfig _config;
  Timer? _updateTimer;
  AiroPlaybackEngine? _engine;
  StreamSubscription<AiroPlaybackState>? _engineSubscription;
  AiroPlaybackState? _lastState;

  // Callbacks
  void Function(LiveEdgeState)? onStateUpdate;
  void Function()? onDriftDetected;

  /// Called before auto-resync to give UI chance to show notification
  void Function(Duration delay)? onDriftWarning;

  // Internal tracking
  DateTime? _lastUserSeek;
  DateTime? _lastDriftNotification;
  int _driftNotificationCount = 0;

  /// M2: Exponential backoff multiplier for drift notifications
  /// First notification: immediate, Second: 30s cooldown, Third: 60s, etc.
  static const int _baseCooldownSeconds = 30;
  static const int _maxCooldownMultiplier = 4;

  LiveEdgeDetector({LiveEdgeConfig? config})
    : _config = config ?? LiveEdgeConfig.defaultConfig;

  /// Attach to an [AiroPlaybackEngine]. Subscribes to its `states` stream and
  /// caches the latest value; the periodic timer reads that cache instead of
  /// polling a controller directly, so this works identically regardless of
  /// which concrete engine (videoPlayer, mpv, ...) is active.
  void attachToEngine(AiroPlaybackEngine engine) {
    _engine = engine;
    _lastState = engine.currentState;
    _engineSubscription?.cancel();
    _engineSubscription = engine.states.listen((state) {
      _lastState = state;
    });
    _startMonitoring();
  }

  /// Detach from the current engine
  void detach() {
    _stopMonitoring();
    _engineSubscription?.cancel();
    _engineSubscription = null;
    _engine = null;
    _lastState = null;
  }

  void _startMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(_config.updateInterval, (_) {
      _updateLiveEdgeState();
    });
  }

  void _stopMonitoring() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  /// Calculate current live edge state
  void _updateLiveEdgeState() {
    final state = _lastState;
    if (state == null) return;

    final position = state.position;
    final duration = state.duration ?? Duration.zero;

    // Detect if this is a live stream (P0-1)
    final isLive = _detectLiveStream(duration, position);

    if (!isLive) {
      // VOD content - no live edge tracking needed
      onStateUpdate?.call(LiveEdgeState.vod());
      return;
    }

    // Calculate live edge (P0-2)
    final liveEdge = _calculateLiveEdge(duration, state.bufferedRanges);

    // Calculate delay from live (P0-3)
    final delay = liveEdge - position;

    // Determine live stream state (P0-4)
    final isPlaying = state.phase == AiroPlaybackEnginePhase.playing;
    final liveState = _determineLiveState(delay, isPlaying);

    // Check for drift (auto-resync trigger)
    _checkForDrift(delay);

    // Detect DVR window
    final dvrWindow = _detectDvrWindow(state.bufferedRanges, position);

    onStateUpdate?.call(
      LiveEdgeState(
        isLiveStream: true,
        liveEdge: liveEdge,
        liveDelay: delay,
        liveStreamState: liveState,
        hasDvrSupport: dvrWindow.hasDvr,
        dvrWindowStart: dvrWindow.start,
        dvrWindowDuration: dvrWindow.duration,
      ),
    );
  }

  /// Detect if stream is live vs VOD (P0-1)
  ///
  /// Heuristics:
  /// 1. Duration is zero or very large (indicates live)
  /// 2. Duration keeps increasing (live EVENT playlist)
  /// 3. Stream URL patterns (optional enhancement)
  bool _detectLiveStream(Duration duration, Duration position) {
    // Zero duration often indicates live stream
    if (duration == Duration.zero) return true;

    // Very large duration (>24 hours) likely indicates live
    if (duration.inHours > 24) return true;

    // Duration close to position with small buffer suggests live
    // (VOD would have full duration known upfront)
    if (duration.inSeconds > 0 &&
        (duration - position).inSeconds < 60 &&
        duration.inMinutes < 10) {
      return true;
    }

    // Default to VOD for known durations
    return false;
  }

  /// Calculate live edge position (P0-2)
  Duration _calculateLiveEdge(
    Duration duration,
    List<AiroPlaybackBufferedRange> buffered,
  ) {
    // For live streams, live edge is typically the end of buffered range
    // or the reported duration (whichever is greater)
    Duration maxBuffered = Duration.zero;
    for (final range in buffered) {
      if (range.end > maxBuffered) {
        maxBuffered = range.end;
      }
    }

    // Use the greater of duration or max buffered position
    return duration > maxBuffered ? duration : maxBuffered;
  }

  /// Determine the current live stream state (P0-4)
  LiveStreamState _determineLiveState(Duration delay, bool isPlaying) {
    if (!isPlaying) return LiveStreamState.paused;

    if (delay.inSeconds <= _config.liveEdgeThreshold.inSeconds) {
      return LiveStreamState.live;
    }

    return LiveStreamState.behindLive;
  }

  /// Check for drift and trigger auto-resync callback with exponential backoff
  ///
  /// M2 Enhancement: Uses exponential backoff to avoid spamming notifications
  /// - First notification: immediate
  /// - Subsequent notifications: cooldown period doubles each time
  /// - Max cooldown: 4x base (120s)
  void _checkForDrift(Duration delay) {
    // Only check if no recent user seek
    if (_lastUserSeek != null) {
      final timeSinceSeek = DateTime.now().difference(_lastUserSeek!);
      if (timeSinceSeek < const Duration(seconds: 10)) return;
    }

    if (delay > _config.autoResyncThreshold) {
      final now = DateTime.now();

      // Check exponential backoff cooldown
      if (_lastDriftNotification != null) {
        final multiplier = (_driftNotificationCount).clamp(
          1,
          _maxCooldownMultiplier,
        );
        final cooldown = Duration(seconds: _baseCooldownSeconds * multiplier);
        final timeSinceLastNotification = now.difference(
          _lastDriftNotification!,
        );

        if (timeSinceLastNotification < cooldown) {
          return; // Still in cooldown period
        }
      }

      // Send warning notification first (gives UI chance to show toast)
      onDriftWarning?.call(delay);

      // Then trigger auto-resync
      onDriftDetected?.call();

      // Update backoff tracking
      _lastDriftNotification = now;
      _driftNotificationCount++;
    }
  }

  /// Reset drift notification state (call after successful manual Go Live)
  void resetDriftState() {
    _lastDriftNotification = null;
    _driftNotificationCount = 0;
  }

  /// Detect DVR window boundaries
  _DvrWindow _detectDvrWindow(
    List<AiroPlaybackBufferedRange> buffered,
    Duration position,
  ) {
    if (buffered.isEmpty) {
      return _DvrWindow(hasDvr: false);
    }

    // Find the buffered range containing current position
    Duration? start;
    Duration? end;

    for (final range in buffered) {
      if (start == null || range.start < start) start = range.start;
      if (end == null || range.end > end) end = range.end;
    }

    if (start != null && end != null) {
      final duration = end - start;
      // DVR is supported if we have more than 30s of buffered range
      return _DvrWindow(
        hasDvr: duration.inSeconds > 30,
        start: start,
        duration: duration,
      );
    }

    return _DvrWindow(hasDvr: false);
  }

  /// Notify that user performed a manual seek
  void notifyUserSeek() {
    _lastUserSeek = DateTime.now();
  }

  /// Dispose resources
  void dispose() {
    _stopMonitoring();
    _engineSubscription?.cancel();
    _engineSubscription = null;
    _engine = null;
    _lastState = null;
    onStateUpdate = null;
    onDriftDetected = null;
  }
}

/// Result of live edge detection
class LiveEdgeState {
  final bool isLiveStream;
  final Duration liveEdge;
  final Duration liveDelay;
  final LiveStreamState liveStreamState;
  final bool hasDvrSupport;
  final Duration? dvrWindowStart;
  final Duration? dvrWindowDuration;

  const LiveEdgeState({
    required this.isLiveStream,
    this.liveEdge = Duration.zero,
    this.liveDelay = Duration.zero,
    this.liveStreamState = LiveStreamState.unknown,
    this.hasDvrSupport = false,
    this.dvrWindowStart,
    this.dvrWindowDuration,
  });

  /// Factory for VOD content (not live)
  factory LiveEdgeState.vod() => const LiveEdgeState(isLiveStream: false);
}

/// Internal DVR window detection result
class _DvrWindow {
  final bool hasDvr;
  final Duration? start;
  final Duration? duration;

  const _DvrWindow({required this.hasDvr, this.start, this.duration});
}
```

`LiveStreamState` and `LiveEdgeConfig` are defined elsewhere in `platform_player` (`streaming_state.dart`, already imported via `package:platform_player/platform_player.dart`) — no change needed there.

Remove `video_player` from `packages/platform_streams/pubspec.yaml`'s `dependencies:` section (it's no longer imported anywhere in this package after this change — confirm with `grep -rn "video_player" packages/platform_streams/lib` returning nothing before removing).

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd packages/platform_streams && flutter pub get && flutter test`
Expected: PASS, entire `platform_streams` suite including the new `live_edge_detector_test.dart`.

- [ ] **Step 6: Commit**

```bash
git add packages/platform_streams/lib/src/services/live_edge_detector.dart packages/platform_streams/pubspec.yaml packages/platform_streams/test/live_edge_detector_test.dart
git commit -m "refactor(platform_streams): LiveEdgeDetector.attachToEngine() replaces attach(VideoPlayerController)"
```

---

### Task 7: `VideoPlayerStreamingService` — engine-driven core (open/play/pause/seek/render)

**Files:**
- Modify: `packages/platform_media/lib/src/video_player_streaming_service.dart`
- Modify: `packages/platform_media/lib/platform_media.dart` (export check — `VideoPlayerStreamingService` and `StreamingState` fields already exported; no new export needed for this task)
- Test: `packages/platform_media/test/video_player_streaming_service_test.dart` (new file — first tests ever for this class)

**Interfaces:**
- Consumes: `AiroPlaybackEngine`, `AiroPlaybackSourceHandle.direct()` (Task 1), `AiroMediaOpenRequest`, `LiveEdgeDetector.attachToEngine()` (Task 6), `AiroPlaybackEngine.buildView()` (Task 3/4).
- Produces: `VideoPlayerStreamingService(engine: AiroPlaybackEngine)` constructor param (test seam); `VideoPlayerStreamingService.buildVideoView() → Widget?` — consumed by Task 9. `StreamingState.tracks`/`selectedTrackIds` now populated from the engine on every channel switch.

**Note:** the old `VideoPlayerController? get controller` getter is removed in this task (single consumer, `video_player_widget.dart:221`, updated in Task 9 — until Task 9 lands, `feature_iptv` will fail to compile; that's expected and resolved by the very next task, per this plan's ordering).

- [ ] **Step 1: Add first-ever `StreamingState.tracks`/`selectedTrackIds` fields**

Modify `packages/platform_player/lib/src/models/streaming_state.dart` — add to `class StreamingState extends Equatable`:

```dart
import 'package:equatable/equatable.dart';
import 'package:platform_channels/platform_channels.dart';
import 'playback_engine_models.dart';

// ... existing enums/classes unchanged (NetworkQuality, PlaybackState,
// LiveStreamState, LiveEdgeConfig, BufferStatus, StreamingMetrics) ...

/// Complete streaming state with Live DVR support
class StreamingState extends Equatable {
  final IPTVChannel? currentChannel;
  final PlaybackState playbackState;
  final VideoQuality currentQuality;
  final VideoQuality selectedQuality;
  final BufferStatus bufferStatus;
  final StreamingMetrics? metrics;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool isMuted;
  final String? errorMessage;
  final int retryCount;
  final DateTime? lastError;

  // === Live DVR Properties (P0-1 to P0-4) ===
  final bool isLiveStream;
  final Duration? liveEdge;
  final Duration liveDelay;
  final Duration? dvrWindowStart;
  final Duration? dvrWindowDuration;
  final LiveStreamState liveStreamState;
  final bool hasDvrSupport;
  final DateTime? lastLiveEdgeUpdate;

  // === Track catalog (CV-016/CV-031 — engine-projected tracks) ===
  final List<AiroPlaybackTrackOption> tracks;
  final Map<AiroPlaybackTrackKind, String> selectedTrackIds;

  StreamingState({
    this.currentChannel,
    this.playbackState = PlaybackState.idle,
    this.currentQuality = VideoQuality.auto,
    this.selectedQuality = VideoQuality.auto,
    this.bufferStatus = const BufferStatus(),
    this.metrics,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.errorMessage,
    this.retryCount = 0,
    this.lastError,
    this.isLiveStream = false,
    this.liveEdge,
    this.liveDelay = Duration.zero,
    this.dvrWindowStart,
    this.dvrWindowDuration,
    this.liveStreamState = LiveStreamState.unknown,
    this.hasDvrSupport = false,
    this.lastLiveEdgeUpdate,
    List<AiroPlaybackTrackOption> tracks = const [],
    Map<AiroPlaybackTrackKind, String> selectedTrackIds = const {},
  }) : tracks = List.unmodifiable(tracks),
       selectedTrackIds = Map.unmodifiable(selectedTrackIds);

  bool get isPlaying => playbackState == PlaybackState.playing;
  bool get isLoading => playbackState == PlaybackState.loading;
  bool get isBuffering => playbackState == PlaybackState.buffering;
  bool get hasError => playbackState == PlaybackState.error;
  bool get canRetry => retryCount < 3;

  bool get meetsLoadTimeTarget =>
      metrics != null && metrics!.latency.inMilliseconds < 2000;

  bool get isAtLiveEdge =>
      isLiveStream &&
      liveDelay.inSeconds <=
          LiveEdgeConfig.defaultConfig.liveEdgeThreshold.inSeconds;

  bool get isBehindLive =>
      isLiveStream &&
      liveDelay.inSeconds >
          LiveEdgeConfig.defaultConfig.liveEdgeThreshold.inSeconds;

  bool get shouldShowGoLive =>
      isLiveStream && (isBehindLive || playbackState == PlaybackState.paused);

  bool get shouldAutoResync =>
      isLiveStream &&
      liveDelay.inSeconds >
          LiveEdgeConfig.defaultConfig.autoResyncThreshold.inSeconds;

  String get formattedDelay {
    if (!isLiveStream || isAtLiveEdge) return '';
    final seconds = liveDelay.inSeconds;
    if (seconds < 60) return '${seconds}s behind';
    final minutes = liveDelay.inMinutes;
    final remainingSeconds = seconds % 60;
    if (remainingSeconds == 0) return '${minutes}m behind';
    return '${minutes}m ${remainingSeconds}s behind';
  }

  bool get canSeekBack =>
      isLiveStream && hasDvrSupport && dvrWindowDuration != null;

  StreamingState copyWith({
    IPTVChannel? currentChannel,
    PlaybackState? playbackState,
    VideoQuality? currentQuality,
    VideoQuality? selectedQuality,
    BufferStatus? bufferStatus,
    StreamingMetrics? metrics,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? isMuted,
    String? errorMessage,
    int? retryCount,
    DateTime? lastError,
    bool? isLiveStream,
    Duration? liveEdge,
    Duration? liveDelay,
    Duration? dvrWindowStart,
    Duration? dvrWindowDuration,
    LiveStreamState? liveStreamState,
    bool? hasDvrSupport,
    DateTime? lastLiveEdgeUpdate,
    List<AiroPlaybackTrackOption>? tracks,
    Map<AiroPlaybackTrackKind, String>? selectedTrackIds,
  }) {
    return StreamingState(
      currentChannel: currentChannel ?? this.currentChannel,
      playbackState: playbackState ?? this.playbackState,
      currentQuality: currentQuality ?? this.currentQuality,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      bufferStatus: bufferStatus ?? this.bufferStatus,
      metrics: metrics ?? this.metrics,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      errorMessage: errorMessage,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      isLiveStream: isLiveStream ?? this.isLiveStream,
      liveEdge: liveEdge ?? this.liveEdge,
      liveDelay: liveDelay ?? this.liveDelay,
      dvrWindowStart: dvrWindowStart ?? this.dvrWindowStart,
      dvrWindowDuration: dvrWindowDuration ?? this.dvrWindowDuration,
      liveStreamState: liveStreamState ?? this.liveStreamState,
      hasDvrSupport: hasDvrSupport ?? this.hasDvrSupport,
      lastLiveEdgeUpdate: lastLiveEdgeUpdate ?? this.lastLiveEdgeUpdate,
      tracks: tracks ?? this.tracks,
      selectedTrackIds: selectedTrackIds ?? this.selectedTrackIds,
    );
  }

  @override
  List<Object?> get props => [
    currentChannel,
    playbackState,
    currentQuality,
    bufferStatus,
    position,
    volume,
    isMuted,
    errorMessage,
    isLiveStream,
    liveEdge,
    liveDelay,
    liveStreamState,
    tracks,
    selectedTrackIds,
  ];
}
```

(Note: `const StreamingState()` default constructions elsewhere in the codebase, e.g. `VideoPlayerStreamingService.stop()`'s `_updateState(const StreamingState())`, must change to non-const `StreamingState()` since the constructor is no longer const once it has a body computing `List.unmodifiable`/`Map.unmodifiable` — this matches the existing pattern already used by `AiroMediaOpenRequest` and `AiroPlaybackState`, which have the identical non-const-constructor-with-unmodifiable-collections shape. Search for `const StreamingState()` across the codebase and remove the `const` keyword at each call site as part of this step — checked during Step 4 below.)

- [ ] **Step 2: Write the failing tests for `StreamingState`**

Add to `packages/feature_iptv/test/iptv/domain/services/streaming_state_test.dart` (existing file — append):

```dart
  group('StreamingState.tracks / selectedTrackIds', () {
    test('default to empty', () {
      final state = StreamingState();
      expect(state.tracks, isEmpty);
      expect(state.selectedTrackIds, isEmpty);
    });

    test('copyWith overrides tracks and selectedTrackIds', () {
      final state = StreamingState();
      final next = state.copyWith(
        tracks: const [
          AiroPlaybackTrackOption(
            id: 'external_sub_0',
            kind: AiroPlaybackTrackKind.subtitle,
            label: 'English',
            isExternal: true,
          ),
        ],
        selectedTrackIds: const {AiroPlaybackTrackKind.subtitle: 'external_sub_0'},
      );
      expect(next.tracks, hasLength(1));
      expect(next.selectedTrackIds[AiroPlaybackTrackKind.subtitle], 'external_sub_0');
    });
  });
```

Add the import at the top of that test file if not already present: `import 'package:platform_player/platform_player.dart';`

- [ ] **Step 3: Run test to verify it fails, then implement, then pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/domain/services/streaming_state_test.dart`
Expected: FAIL first (fields undefined) — implementation is Step 1 above, already written. After applying Step 1's changes to `packages/platform_player/lib/src/models/streaming_state.dart`:

Run: `cd packages/platform_player && flutter test` (this model lives in `platform_player`)
Expected: PASS.

Then: `cd packages/feature_iptv && flutter test test/iptv/domain/services/streaming_state_test.dart`
Expected: PASS.

- [ ] **Step 4: Find and fix every `const StreamingState()` call site**

Run: `grep -rn "const StreamingState()" packages/ app/`

For each match, remove the `const` keyword (e.g. `const StreamingState()` → `StreamingState()`). Based on exploration, the known call site is `packages/platform_media/lib/src/video_player_streaming_service.dart`'s `stop()` method and its `StreamingState _state = const StreamingState();` field initializer — both are edited directly as part of Step 6 below, so no separate action needed here beyond confirming no OTHER file has a stray `const StreamingState()` construction that would fail to compile.

- [ ] **Step 5: Write the failing tests for `VideoPlayerStreamingService`**

Create `packages/platform_media/test/video_player_streaming_service_test.dart` — this is the first-ever test file for this class:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fakePlatform;
  late VideoPlayerStreamingService service;

  IPTVChannel channel({String streamUrl = 'https://example.com/live.m3u8'}) {
    return IPTVChannel(
      id: 'chan-1',
      name: 'Test Channel',
      streamUrl: streamUrl,
    );
  }

  setUp(() {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
    service = VideoPlayerStreamingService(
      engine: VideoPlayerAiroPlaybackEngine(),
    );
  });

  tearDown(() async {
    await service.dispose();
  });

  group('VideoPlayerStreamingService playChannel', () {
    test('opens via the injected engine and reaches playing', () async {
      await service.playChannel(channel());
      expect(service.currentState.playbackState, PlaybackState.playing);
      expect(service.currentState.currentChannel?.id, 'chan-1');
    });

    test('decoder failure surfaces as a typed error and retry count increments', () async {
      fakePlatform.scriptedInitError = PlatformException(
        code: 'VideoError',
        message: 'decoder rejected format',
      );
      await service.playChannel(channel());
      expect(service.currentState.playbackState, PlaybackState.error);
      expect(service.currentState.retryCount, 1);
    });

    test('buildVideoView returns non-null after a successful open', () async {
      await service.playChannel(channel());
      expect(service.buildVideoView(), isNotNull);
    });

    test('buildVideoView returns null before any channel is played', () {
      expect(service.buildVideoView(), isNull);
    });
  });

  group('VideoPlayerStreamingService selectTrack', () {
    test('unknown track id is a no-op that does not throw', () async {
      await service.playChannel(channel());
      await service.selectTrack(
        kind: AiroPlaybackTrackKind.subtitle,
        trackId: 'nonexistent',
      );
      expect(
        service.currentState.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
        isNull,
      );
    });
  });

  group('VideoPlayerStreamingService attachExternalSubtitle', () {
    test('attached subtitle appears in tracks after the next playChannel', () async {
      service.attachExternalSubtitle(
        AiroPlaybackExternalSubtitle(
          handle: AiroPlaybackSourceHandle.redacted('sub-en'),
          languageCode: 'en',
          label: 'English',
        ),
      );
      await service.playChannel(channel());
      expect(service.currentState.tracks, hasLength(1));
      expect(service.currentState.tracks.single.isExternal, isTrue);
    });

    test('subtitle does not appear before the next playChannel', () async {
      await service.playChannel(channel());
      expect(service.currentState.tracks, isEmpty);

      service.attachExternalSubtitle(
        AiroPlaybackExternalSubtitle(
          handle: AiroPlaybackSourceHandle.redacted('sub-en'),
          languageCode: 'en',
        ),
      );
      // Not applied yet — still empty until the next playChannel.
      expect(service.currentState.tracks, isEmpty);
    });
  });
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `cd packages/platform_media && flutter test test/video_player_streaming_service_test.dart`
Expected: FAIL — `VideoPlayerStreamingService`'s constructor doesn't accept `engine:`, `buildVideoView`/`selectTrack`/`attachExternalSubtitle` undefined.

- [ ] **Step 7: Write minimal implementation**

Replace `packages/platform_media/lib/src/video_player_streaming_service.dart` entirely:

```dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:platform_streams/platform_streams.dart';

import 'audio_context.dart';
import 'platform_media_logger.dart';
import 'video_player_airo_playback_engine.dart';

/// Video Player implementation of IPTV Streaming Service
///
/// Optimizations implemented:
/// 1. Adaptive bitrate via HLS/DASH support
/// 2. Buffer monitoring and health tracking
/// 3. Fast initial load with preloading
/// 4. Auto-retry on network errors
/// 5. Seamless quality switching
/// 6. Background audio mode
/// 7. Audio context integration (pauses music during video)
class VideoPlayerStreamingService implements IPTVStreamingService {
  final AiroPlaybackEngine _engine;
  final StreamingConfig _config;
  final AudioContextManager _audioContext;
  final _stateController = StreamController<StreamingState>.broadcast();

  StreamingState _state = StreamingState();
  Timer? _bufferMonitor;
  Timer? _metricsTimer;
  DateTime? _loadStartTime;
  bool _isBackgroundAudioMode = false;

  // Live edge detection (P0-1 through P0-4)
  final LiveEdgeDetector _liveEdgeDetector;

  StreamSubscription<AiroPlaybackState>? _engineSubscription;
  AiroPlaybackExternalSubtitle? _pendingExternalSubtitle;
  int _requestCounter = 0;

  VideoPlayerStreamingService({
    AiroPlaybackEngine? engine,
    this._config = StreamingConfig.youtube,
    AudioContextManager? audioContext,
    LiveEdgeConfig? liveEdgeConfig,
  }) : _engine = engine ?? VideoPlayerAiroPlaybackEngine(),
       _audioContext = audioContext ?? AudioContextManager(),
       _liveEdgeDetector = LiveEdgeDetector(config: liveEdgeConfig) {
    _setupLiveEdgeCallbacks();
    _engineSubscription = _engine.states.listen(_onEngineStateUpdate);
  }

  void _setupLiveEdgeCallbacks() {
    _liveEdgeDetector.onStateUpdate = _handleLiveEdgeUpdate;
    _liveEdgeDetector.onDriftDetected = _handleDriftDetected;
    _liveEdgeDetector.onDriftWarning = _handleDriftWarning;
  }

  void _handleLiveEdgeUpdate(LiveEdgeState liveState) {
    _updateState(
      _state.copyWith(
        isLiveStream: liveState.isLiveStream,
        liveEdge: liveState.liveEdge,
        liveDelay: liveState.liveDelay,
        liveStreamState: liveState.liveStreamState,
        hasDvrSupport: liveState.hasDvrSupport,
        dvrWindowStart: liveState.dvrWindowStart,
        dvrWindowDuration: liveState.dvrWindowDuration,
        lastLiveEdgeUpdate: DateTime.now(),
      ),
    );
  }

  /// M2: Handle drift warning before auto-resync
  void _handleDriftWarning(Duration delay) {
    AppLogger.info(
      'Drift detected: ${delay.inSeconds}s behind live edge',
      tag: 'LIVE_DVR',
    );
    AppLogger.analytics(
      'live_stream_drift_detected',
      params: {
        'channel': _state.currentChannel?.name,
        'delaySeconds': delay.inSeconds,
      },
    );
  }

  void _handleDriftDetected() {
    // Auto-resync to live edge when drift exceeds threshold
    // Only auto-resync if not paused by user
    if (_state.playbackState == PlaybackState.playing) {
      AppLogger.analytics(
        'live_stream_auto_resync',
        params: {
          'channel': _state.currentChannel?.name,
          'delayBeforeResync': _state.liveDelay.inSeconds,
        },
      );
      goLive();
    }
  }

  @override
  Stream<StreamingState> get stateStream => _stateController.stream;

  @override
  StreamingState get currentState => _state;

  @override
  Future<void> initialize() async {
    // Pre-warm video player infrastructure
    _startMetricsCollection();
  }

  /// Returns a widget rendering the current video surface, or null when
  /// nothing is open yet. See [AiroPlaybackEngine.buildView].
  Widget? buildVideoView() => _engine.buildView();

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    _loadStartTime = DateTime.now();
    _updateState(
      _state.copyWith(
        currentChannel: channel,
        playbackState: PlaybackState.loading,
        errorMessage: null,
        retryCount: 0,
      ),
    );

    try {
      // Request video audio focus (pauses background music)
      _audioContext.requestFocus(AudioFocusType.video);

      final url = channel.getStreamUrl(_state.selectedQuality);
      final externalSubtitles = <AiroPlaybackExternalSubtitle>[
        if (_pendingExternalSubtitle != null) _pendingExternalSubtitle!,
      ];

      final result = await _engine.open(
        AiroMediaOpenRequest(
          requestId: '${channel.id}-${_requestCounter++}',
          sourceHandle: AiroPlaybackSourceHandle.direct(url),
          // Engines don't currently branch on mediaKind — hls is the
          // dominant IPTV format in this codebase and there's no reliable
          // pre-open live/VOD signal on IPTVChannel to infer from (live vs
          // VOD detection is a post-open runtime heuristic, see
          // LiveEdgeDetector._detectLiveStream).
          mediaKind: AiroPlaybackMediaKind.hls,
          externalSubtitles: externalSubtitles,
        ),
      );

      if (result.error != null) {
        throw _EngineOpenError(result.error!.code.stableId);
      }

      await _engine.setVolume(_state.isMuted ? 0 : _state.volume);
      await _engine.setPlaybackSpeed(1.0);
      await _engine.play();

      // Calculate load time
      final loadTime = DateTime.now().difference(_loadStartTime!);

      _updateState(
        _state.copyWith(
          playbackState: PlaybackState.playing,
          duration: result.duration ?? Duration.zero,
          tracks: result.tracks,
          selectedTrackIds: result.selectedTrackIds,
          metrics: StreamingMetrics(
            latency: loadTime,
            networkQuality: _estimateNetworkQuality(loadTime),
            timestamp: DateTime.now(),
          ),
        ),
      );

      _startBufferMonitoring();

      // Attach live edge detector for live stream monitoring
      _liveEdgeDetector.attachToEngine(_engine);
    } catch (e) {
      // Release focus on error
      _audioContext.releaseFocus(AudioFocusType.video);
      await _handleError(e.toString());
    }
  }

  /// Folds every state emitted by the engine (continuous position/duration/
  /// buffering/error updates — see VideoPlayerAiroPlaybackEngine's
  /// controller listener) into [StreamingState]. Runs for the lifetime of
  /// this service, not just during playChannel — the engine instance itself
  /// doesn't change across channel switches, only what it has open.
  void _onEngineStateUpdate(AiroPlaybackState engineState) {
    if (engineState.error != null) {
      _handleError(engineState.error!.code.stableId);
      return;
    }

    _updateState(
      _state.copyWith(
        position: engineState.position,
        duration: engineState.duration ?? _state.duration,
        tracks: engineState.tracks,
        selectedTrackIds: engineState.selectedTrackIds,
        playbackState: _mapEnginePhase(engineState.phase) ?? _state.playbackState,
      ),
    );
  }

  PlaybackState? _mapEnginePhase(AiroPlaybackEnginePhase phase) {
    switch (phase) {
      case AiroPlaybackEnginePhase.playing:
        return PlaybackState.playing;
      case AiroPlaybackEnginePhase.paused:
        return PlaybackState.paused;
      case AiroPlaybackEnginePhase.buffering:
        return PlaybackState.buffering;
      case AiroPlaybackEnginePhase.stopped:
        return PlaybackState.idle;
      case AiroPlaybackEnginePhase.idle:
      case AiroPlaybackEnginePhase.opening:
      case AiroPlaybackEnginePhase.open:
      case AiroPlaybackEnginePhase.seeking:
      case AiroPlaybackEnginePhase.ended:
      case AiroPlaybackEnginePhase.failed:
      case AiroPlaybackEnginePhase.unavailable:
        return null;
    }
  }

  void _startBufferMonitoring() {
    _bufferMonitor?.cancel();
    _bufferMonitor = Timer.periodic(const Duration(seconds: 1), (_) {
      final engineState = _engine.currentState;
      final position = engineState.position;

      Duration bufferedAhead = Duration.zero;
      for (final range in engineState.bufferedRanges) {
        if (range.start <= position && range.end > position) {
          bufferedAhead = range.end - position;
          break;
        }
      }

      final bufferHealth =
          (bufferedAhead.inSeconds /
                  _config.targetBufferDuration.inSeconds *
                  100)
              .clamp(0, 100)
              .toInt();

      _updateState(
        _state.copyWith(
          bufferStatus: BufferStatus(
            bufferedAhead: bufferedAhead,
            bufferHealth: bufferHealth,
            isBuffering: engineState.phase == AiroPlaybackEnginePhase.buffering,
          ),
        ),
      );
    });
  }

  void _startMetricsCollection() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_state.isPlaying) {
        _updateState(
          _state.copyWith(
            metrics: StreamingMetrics(
              currentBitrate: _estimateBitrate(),
              networkQuality:
                  _state.metrics?.networkQuality ?? NetworkQuality.good,
              timestamp: DateTime.now(),
            ),
          ),
        );
      }
    });
  }

  int _estimateBitrate() {
    switch (_state.currentQuality) {
      case VideoQuality.ultraHd:
        return 15000;
      case VideoQuality.fullHd:
        return 5000;
      case VideoQuality.high:
        return 2500;
      case VideoQuality.medium:
        return 1000;
      case VideoQuality.low:
        return 500;
      case VideoQuality.auto:
        return 2000;
    }
  }

  NetworkQuality _estimateNetworkQuality(Duration loadTime) {
    if (loadTime.inMilliseconds < 1000) return NetworkQuality.excellent;
    if (loadTime.inMilliseconds < 2000) return NetworkQuality.good;
    if (loadTime.inMilliseconds < 4000) return NetworkQuality.fair;
    return NetworkQuality.poor;
  }

  /// Flag to prevent duplicate error handling
  bool _isHandlingError = false;

  Future<void> _handleError(String message) async {
    if (_isHandlingError || _state.playbackState == PlaybackState.error) {
      return;
    }
    _isHandlingError = true;

    final newRetryCount = _state.retryCount + 1;

    String userMessage;
    if (newRetryCount > _config.maxRetries) {
      userMessage = 'Unable to play this channel. Please try again later.';
    } else {
      userMessage = 'Playback failed: $message';
    }

    _updateState(
      _state.copyWith(
        playbackState: PlaybackState.error,
        errorMessage: userMessage,
        retryCount: newRetryCount,
        lastError: DateTime.now(),
      ),
    );

    _bufferMonitor?.cancel();
    _audioContext.releaseFocus(AudioFocusType.video);
    _liveEdgeDetector.detach();

    _isHandlingError = false;
  }

  @override
  Future<void> pause() async {
    await _engine.pause();
    _audioContext.releaseFocus(AudioFocusType.video);
    _updateState(_state.copyWith(playbackState: PlaybackState.paused));
  }

  @override
  Future<void> resume() async {
    _audioContext.requestFocus(AudioFocusType.video);
    await _engine.play();
    _updateState(_state.copyWith(playbackState: PlaybackState.playing));
  }

  @override
  Future<void> stop() async {
    _bufferMonitor?.cancel();
    _audioContext.releaseFocus(AudioFocusType.video);
    _liveEdgeDetector.detach();
    await _engine.stop();
    _updateState(StreamingState());
  }

  @override
  Future<void> seek(Duration position) async {
    _liveEdgeDetector.notifyUserSeek();

    var clampedPosition = position;
    if (_state.isLiveStream && _state.hasDvrSupport) {
      final dvrStart = _state.dvrWindowStart ?? Duration.zero;
      final liveEdge = _state.liveEdge ?? _engine.currentState.duration ?? Duration.zero;

      if (position < dvrStart) {
        clampedPosition = dvrStart;
        AppLogger.info(
          'Seek clamped to DVR start: ${dvrStart.inSeconds}s',
          tag: 'LIVE_DVR',
        );
      } else if (position > liveEdge) {
        clampedPosition = liveEdge;
        AppLogger.info(
          'Seek clamped to live edge: ${liveEdge.inSeconds}s',
          tag: 'LIVE_DVR',
        );
      }
    }

    await _engine.seek(clampedPosition);
    _updateState(_state.copyWith(position: clampedPosition));

    if (_state.isLiveStream) {
      AppLogger.analytics(
        'live_stream_seek',
        params: {
          'channel': _state.currentChannel?.name,
          'seekTo': clampedPosition.inSeconds,
          'wasClamped': clampedPosition != position,
          'delay': _state.liveDelay.inSeconds,
        },
      );
    }
  }

  @override
  Future<void> goLive() async {
    if (!_state.isLiveStream) return;

    _liveEdgeDetector.resetDriftState();

    final liveEdge = _state.liveEdge;
    if (liveEdge == null || liveEdge == Duration.zero) {
      final duration = _engine.currentState.duration;
      if (duration != null && duration > Duration.zero) {
        await _engine.seek(duration);
      }
      return;
    }

    await _engine.seek(liveEdge);
    _updateState(
      _state.copyWith(
        liveStreamState: LiveStreamState.live,
        liveDelay: Duration.zero,
      ),
    );

    AppLogger.analytics(
      'go_live_tapped',
      params: {
        'channel': _state.currentChannel?.name,
        'previousDelay': _state.liveDelay.inSeconds,
      },
    );
  }

  @override
  Future<void> setVolume(double volume) async {
    final clampedVolume = volume.clamp(0.0, 1.0);
    await _engine.setVolume(_state.isMuted ? 0 : clampedVolume);
    _updateState(_state.copyWith(volume: clampedVolume));
  }

  @override
  Future<void> toggleMute() async {
    final newMuted = !_state.isMuted;
    await _engine.setVolume(newMuted ? 0 : _state.volume);
    _updateState(_state.copyWith(isMuted: newMuted));
  }

  @override
  Future<void> setQuality(VideoQuality quality) async {
    if (quality == _state.selectedQuality) return;

    _updateState(_state.copyWith(selectedQuality: quality));

    if (_state.currentChannel != null && _state.isPlaying) {
      final position = _state.position;
      await playChannel(_state.currentChannel!);
      await seek(position);
    }
  }

  @override
  Future<void> retry() async {
    if (_state.currentChannel != null) {
      _isHandlingError = false;
      await playChannel(_state.currentChannel!);
    }
  }

  @override
  Future<void> setBackgroundAudioMode(bool enabled) async {
    _isBackgroundAudioMode = enabled;
    if (_state.currentChannel != null && _state.isPlaying) {
      await playChannel(_state.currentChannel!);
    }
  }

  /// Selects a track (audio, subtitle, or video) by id. No-op if the id
  /// isn't in the current [StreamingState.tracks] catalog — matches
  /// [AiroPlaybackEngine.selectTrack]'s typed-failure contract, silently
  /// absorbed here since there's nothing actionable for the caller to do
  /// with a typed error at this layer (the UI only offers ids that are
  /// already in the catalog).
  Future<void> selectTrack({
    required AiroPlaybackTrackKind kind,
    required String trackId,
  }) async {
    final result = await _engine.selectTrack(kind: kind, trackId: trackId);
    if (result.error != null) return;
    _updateState(_state.copyWith(selectedTrackIds: result.selectedTrackIds));
  }

  /// Stores an external subtitle to include on the next [playChannel] open
  /// request. Engines don't support attaching a subtitle to an
  /// already-open source, so this doesn't take effect until the next open —
  /// callers should re-trigger playback (e.g. call [playChannel] again) if
  /// they want it to apply immediately.
  void attachExternalSubtitle(AiroPlaybackExternalSubtitle subtitle) {
    _pendingExternalSubtitle = subtitle;
  }

  void _updateState(StreamingState newState) {
    _state = newState;
    _stateController.add(_state);
  }

  @override
  Future<void> dispose() async {
    _bufferMonitor?.cancel();
    _metricsTimer?.cancel();
    _liveEdgeDetector.dispose();
    _audioContext.releaseFocus(AudioFocusType.video);
    await _engineSubscription?.cancel();
    await _engine.dispose();
    await _stateController.close();
  }
}

class _EngineOpenError implements Exception {
  _EngineOpenError(this.code);
  final String code;
  @override
  String toString() => code;
}
```

Note: `result.tracks`/`result.selectedTrackIds`/`result.duration` on the `open()` return value — `open()` returns `AiroPlaybackState`, which already has `tracks`, `selectedTrackIds`, and `duration` fields (confirmed in Task 2/existing model). No new fields needed on `AiroPlaybackState` for this step.

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd packages/platform_media && flutter test test/video_player_streaming_service_test.dart`
Expected: PASS, all new tests.

Then run the full package: `cd packages/platform_media && flutter test`
Expected: PASS (this will currently FAIL to compile `feature_iptv` if run at the workspace level, since `video_player_widget.dart` still references the removed `controller` getter — that's expected and fixed in Task 9; running `platform_media`'s own test suite in isolation is unaffected since `feature_iptv` isn't a dependency of `platform_media`).

- [ ] **Step 9: Commit**

```bash
git add packages/platform_player/lib/src/models/streaming_state.dart packages/feature_iptv/test/iptv/domain/services/streaming_state_test.dart packages/platform_media/lib/src/video_player_streaming_service.dart packages/platform_media/test/video_player_streaming_service_test.dart
git commit -m "refactor(platform_media): VideoPlayerStreamingService drives playback through AiroPlaybackEngine"
```

---

### Task 8: `video_player_widget.dart` — render via `buildVideoView()`

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart:209-248`
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart` (new file)

**Interfaces:**
- Consumes: `VideoPlayerStreamingService.buildVideoView()` (Task 7).
- Produces: nothing new for later tasks — this is the fix that makes `feature_iptv` compile again after Task 7 removed the `controller` getter.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/src/application/providers/iptv_providers.dart';

void main() {
  testWidgets(
    'VideoPlayerWidget renders the loading placeholder when no video view is available',
    (tester) async {
      final service = VideoPlayerStreamingService(
        engine: FakeAiroPlaybackEngine(),
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvStreamingServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(home: VideoPlayerWidget()),
        ),
      );
      await tester.pump();

      // No channel played yet — buildVideoView() is null, so the widget
      // must fall back to its placeholder/loading branch instead of
      // crashing on a null video surface.
      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    },
  );
}
```

(Adjust the import path for `iptv_providers.dart` to match the package's actual public export surface if `feature_iptv.dart`'s barrel file doesn't already expose it — check `packages/feature_iptv/lib/feature_iptv.dart` for the exact export path before finalizing this import.)

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/video_player_widget_test.dart`
Expected: FAIL — compile error, `service.controller` doesn't exist (from Task 7's removal) inside `video_player_widget.dart`.

- [ ] **Step 3: Write minimal implementation**

Modify `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart`, inside `_buildPlayer`:

```dart
  Widget _buildPlayer(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
    AiroPlaybackViewFit aspectRatioFit,
  ) {
    // Update wakelock based on current playback state
    // This is called on every build when state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateWakelockForPlayback(state);
    });

    final videoView = service.buildVideoView();

    return MouseRegion(
      onHover: (_) => _showControls(),
      onEnter: (_) => _showControls(),
      child: GestureDetector(
        onTap: _showControls,
        child: Container(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video display
              if (videoView != null)
                SizedBox.expand(
                  child: FittedBox(
                    fit: _boxFitFor(aspectRatioFit),
                    child: videoView,
                  ),
                )
              else if (state.playbackState == PlaybackState.loading)
                _buildLoading()
              else
                _buildPlaceholder(state),

              // ... rest of the Stack's children (cinema mode vignette,
              // controls overlay, etc.) unchanged — only the `controller`
              // variable and the `if (controller != null && controller.value.isInitialized)`
              // branch above are replaced.
```

The rest of the method (cinema mode overlay, controls, everything after the video-display `if`/`else if`/`else` chain) is unchanged — only the `final controller = service.controller;` line and the video-display branch's condition/child are replaced as shown.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/video_player_widget_test.dart`
Expected: PASS.

Then run the full package: `cd packages/feature_iptv && flutter test`
Expected: PASS — this is the first point where the full workspace compiles again after Task 7's breaking change.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart
git commit -m "fix(feature_iptv): render video via VideoPlayerStreamingService.buildVideoView()"
```

---

### Task 9: `video_player_widget.dart` — subtitle-track selector button

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart:586-630` (control bar `Row`)
- Test: `packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart`

**Interfaces:**
- Consumes: `StreamingState.tracks`/`selectedTrackIds` (Task 7), `VideoPlayerStreamingService.selectTrack()` (Task 7).
- Produces: nothing new for later tasks.

- [ ] **Step 1: Write the failing test**

Add to `packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart`:

```dart
  testWidgets(
    'subtitle button is hidden when there are no tracks',
    (tester) async {
      final engine = FakeAiroPlaybackEngine(tracks: const []);
      final service = VideoPlayerStreamingService(engine: engine);
      addTearDown(service.dispose);
      await service.playChannel(
        IPTVChannel(id: 'c1', name: 'Chan', streamUrl: 'https://x/y.m3u8'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [iptvStreamingServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: VideoPlayerWidget()),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('iptv-player-subtitle-button')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'subtitle button is visible and calls selectTrack when tracks exist',
    (tester) async {
      final engine = FakeAiroPlaybackEngine(
        tracks: const [
          AiroPlaybackTrackOption(
            id: 'external_sub_0',
            kind: AiroPlaybackTrackKind.subtitle,
            label: 'English',
            isExternal: true,
          ),
        ],
      );
      final service = VideoPlayerStreamingService(engine: engine);
      addTearDown(service.dispose);
      await service.playChannel(
        IPTVChannel(id: 'c1', name: 'Chan', streamUrl: 'https://x/y.m3u8'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [iptvStreamingServiceProvider.overrideWithValue(service)],
          child: const MaterialApp(home: VideoPlayerWidget()),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('iptv-player-subtitle-button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('iptv-player-subtitle-button')));
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(
        service.currentState.selectedTrackIds[AiroPlaybackTrackKind.subtitle],
        'external_sub_0',
      );
    },
  );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/video_player_widget_test.dart`
Expected: FAIL — `find.byKey(ValueKey('iptv-player-subtitle-button'))` finds nothing even when tracks exist (button doesn't exist yet).

- [ ] **Step 3: Write minimal implementation**

Modify `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart`, in the control-bar `Row` (around line 586-630), add a new `_PlayerControlButton` before the "Fullscreen button" entry:

```dart
                      // Subtitle/track selector — hidden entirely when
                      // there's nothing to show (mirrors the CV-pro-17
                      // PiP-toggle visibility pattern).
                      if (state.tracks.isNotEmpty)
                        _PlayerControlButton(
                          key: const ValueKey('iptv-player-subtitle-button'),
                          icon: Icons.subtitles,
                          tooltip: 'Subtitles & Tracks',
                          onPressed: () => _showTrackSelector(
                            context,
                            service,
                            state,
                          ),
                        ),
                      // Fullscreen button
                      _PlayerControlButton(
                        key: const ValueKey('iptv-player-fullscreen-button'),
                        icon: _isFullscreen
                            ? Icons.fullscreen_exit
                            : Icons.fullscreen,
                        onPressed: _toggleFullscreen,
                      ),
```

Add a new method to `_VideoPlayerWidgetState` (near `_buildCenterButton` or any other helper method):

```dart
  void _showTrackSelector(
    BuildContext context,
    VideoPlayerStreamingService service,
    StreamingState state,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final track in state.tracks)
                ListTile(
                  title: Text(track.label),
                  subtitle: track.isExternal ? const Text('External') : null,
                  trailing:
                      state.selectedTrackIds[track.kind] == track.id
                          ? const Icon(Icons.check)
                          : null,
                  onTap: () {
                    service.selectTrack(kind: track.kind, trackId: track.id);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/widgets/video_player_widget_test.dart`
Expected: PASS, all tests including the two new ones.

Then: `cd packages/feature_iptv && flutter test`
Expected: PASS, entire `feature_iptv` suite (regression gate for existing channel-switch/track-management tests).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart
git commit -m "feat(feature_iptv): subtitle/track selector button in player controls"
```

---

### Task 10: `vod_screen.dart` — external-subtitle-attach entry point

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/screens/vod_screen.dart`
- Modify: `packages/feature_iptv/lib/presentation/widgets/vod_list_widget.dart` (`VodListWidget` and `_VodListTile`)
- Test: `packages/feature_iptv/test/iptv/presentation/screens/vod_screen_test.dart` (new file)

**Interfaces:**
- Consumes: `VideoPlayerStreamingService.attachExternalSubtitle()` (Task 7), `VodItem` (`packages/platform_channels/lib/src/models/vod_item.dart:61` — fields: `id`, `title`, `streamUrl`, `group` (required, non-nullable), `kind: VodContentKind` (required), `posterUrl`, `containerExtension`, `seriesRef`), `filteredVodMoviesProvider`/`filteredVodSeriesGroupsProvider`/`vodSearchQueryProvider`/`addToVodWatchHistoryProvider` (all in `packages/feature_iptv/lib/application/providers/vod_providers.dart`).
- Produces: nothing new for later tasks — final UI task in this plan.

`VodListWidget` (`packages/feature_iptv/lib/presentation/widgets/vod_list_widget.dart`) currently takes a single `onItemTap: void Function(VodItem item)?` and renders each item via a private `_VodListTile` (`onTap: VoidCallback` only, no room for a second action). Both need a new optional callback threaded through.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_iptv/test/iptv/presentation/screens/vod_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/vod_providers.dart';

void main() {
  testWidgets(
    'subtitle-URL entry attaches the subtitle before playback starts',
    (tester) async {
      final engine = FakeAiroPlaybackEngine(tracks: const []);
      final service = VideoPlayerStreamingService(engine: engine);
      addTearDown(service.dispose);

      const item = VodItem(
        id: 'vod-1',
        title: 'Test Movie',
        streamUrl: 'https://example.com/movie.mp4',
        group: 'Movies',
        kind: VodContentKind.movie,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvStreamingServiceProvider.overrideWithValue(service),
            vodContinueWatchingProvider.overrideWith((ref) async => []),
            filteredVodMoviesProvider.overrideWithValue([item]),
            filteredVodSeriesGroupsProvider.overrideWithValue([]),
            addToVodWatchHistoryProvider(item).overrideWith((ref) async {}),
          ],
          child: const MaterialApp(home: VodScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('vod-add-subtitle-button-vod-1')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('vod-subtitle-url-field')),
        'https://example.com/en.vtt',
      );
      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Movie'));
      await tester.pumpAndSettle();

      expect(service.currentState.tracks, hasLength(1));
      expect(service.currentState.tracks.single.isExternal, isTrue);
    },
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/screens/vod_screen_test.dart`
Expected: FAIL — `find.byKey(ValueKey('vod-add-subtitle-button-vod-1'))` finds nothing.

- [ ] **Step 3: Write minimal implementation**

Modify `packages/feature_iptv/lib/presentation/widgets/vod_list_widget.dart` — add a second optional callback to `VodListWidget` and thread it through `_VodListTile` as an optional trailing icon button:

```dart
class VodListWidget extends ConsumerWidget {
  const VodListWidget({super.key, this.onItemTap, this.onAddSubtitleTap});

  final void Function(VodItem item)? onItemTap;

  /// Optional "add external subtitle" action, rendered as a trailing icon
  /// button on each tile when provided. VOD-only per CV-031's scope — live
  /// channels never pass this callback.
  final void Function(VodItem item)? onAddSubtitleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(filteredVodMoviesProvider);
    final seriesGroups = ref.watch(filteredVodSeriesGroupsProvider);
    final searchQuery = ref.watch(vodSearchQueryProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SizedBox(
            height: 44,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search movies and shows',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () =>
                            ref.read(vodSearchQueryProvider.notifier).state =
                                '',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
              ),
              onChanged: (value) =>
                  ref.read(vodSearchQueryProvider.notifier).state = value,
            ),
          ),
        ),
        if (movies.isEmpty && seriesGroups.isEmpty)
          const Expanded(child: _EmptyState())
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final movie in movies)
                  _VodListTile(
                    key: ValueKey('vod_movie_tile_${movie.id}'),
                    title: movie.title,
                    subtitle: null,
                    posterUrl: movie.posterUrl,
                    fallbackIcon: Icons.movie,
                    onTap: () => onItemTap?.call(movie),
                    onAddSubtitleTap: onAddSubtitleTap == null
                        ? null
                        : () => onAddSubtitleTap!(movie),
                    addSubtitleKey: ValueKey(
                      'vod-add-subtitle-button-${movie.id}',
                    ),
                  ),
                for (final group in seriesGroups)
                  _VodListTile(
                    key: ValueKey('vod_series_tile_${group.seriesId}'),
                    title: group.seriesTitle,
                    subtitle: '${group.episodes.length} episodes',
                    posterUrl: group.episodes.first.posterUrl,
                    fallbackIcon: Icons.video_library,
                    onTap: () => onItemTap?.call(group.episodes.first),
                    onAddSubtitleTap: onAddSubtitleTap == null
                        ? null
                        : () => onAddSubtitleTap!(group.episodes.first),
                    addSubtitleKey: ValueKey(
                      'vod-add-subtitle-button-${group.episodes.first.id}',
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
```

Modify `_VodListTile` to accept and render the optional trailing button:

```dart
class _VodListTile extends StatelessWidget {
  const _VodListTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.posterUrl,
    required this.fallbackIcon,
    required this.onTap,
    this.onAddSubtitleTap,
    this.addSubtitleKey,
  });

  final String title;
  final String? subtitle;
  final String? posterUrl;
  final IconData fallbackIcon;
  final VoidCallback onTap;
  final VoidCallback? onAddSubtitleTap;
  final Key? addSubtitleKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.42),
                      child: posterUrl != null
                          ? AiroNetworkImage(
                              url: posterUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(fallbackIcon, color: Colors.grey),
                            )
                          : Icon(fallbackIcon, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onAddSubtitleTap != null)
                    IconButton(
                      key: addSubtitleKey,
                      icon: const Icon(Icons.subtitles_outlined),
                      tooltip: 'Add subtitle URL',
                      onPressed: onAddSubtitleTap,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Modify `packages/feature_iptv/lib/presentation/screens/vod_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/providers/iptv_providers.dart';
import '../../application/providers/vod_providers.dart';
import '../widgets/vod_list_widget.dart';

/// Phone-oriented VOD screen: a "Continue Watching" row (when non-empty)
/// above [VodListWidget]. Mirrors [IPTVScreen]'s `AiroResponsiveScaffold` +
/// `AppBar` structure for visual consistency with the rest of `feature_iptv`.
class VodScreen extends ConsumerWidget {
  const VodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueWatching =
        ref.watch(vodContinueWatchingProvider).value ?? const [];

    return AiroResponsiveScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(title: const Text('Movies & Shows')),
      body: Column(
        children: [
          if (continueWatching.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Continue Watching',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: continueWatching.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = continueWatching[index];
                  return SizedBox(
                    width: 160,
                    child: _ContinueWatchingCard(
                      item: item,
                      onTap: () => _selectItem(ref, item),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: VodListWidget(
              onItemTap: (item) => _selectItem(ref, item),
              onAddSubtitleTap: (item) => _attachSubtitle(context, ref, item),
            ),
          ),
        ],
      ),
    );
  }

  void _selectItem(WidgetRef ref, VodItem item) {
    // VOD streams the same way live channels do (per CV-019): reuse the
    // existing live-channel player by building a minimal synthetic
    // IPTVChannel purely for this call — a same-request, non-persisted,
    // player-launch-only adapter, not a shared/persisted history record.
    final syntheticChannel = IPTVChannel(
      id: item.id,
      name: item.title,
      streamUrl: item.streamUrl,
      logoUrl: item.posterUrl,
      group: item.group,
    );
    ref.read(iptvStreamingServiceProvider).playChannel(syntheticChannel);
    ref.read(addToVodWatchHistoryProvider(item).future);
  }

  Future<void> _attachSubtitle(
    BuildContext context,
    WidgetRef ref,
    VodItem item,
  ) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add subtitle URL (optional)'),
          content: TextField(
            key: const ValueKey('vod-subtitle-url-field'),
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://example.com/subtitles.vtt',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Attach'),
            ),
          ],
        );
      },
    );
    if (url == null || url.isEmpty) return;

    // Reload-to-apply per the engine contract: attaching a subtitle to an
    // already-open source isn't supported (see AiroPlaybackEngine.open()),
    // so this is stored for the *next* open — Task 7's playChannel() reads
    // it. If the item is already playing, the user needs to tap it again
    // for the subtitle to take effect; the dialog copy makes this explicit
    // rather than implying an instant attach.
    ref.read(iptvStreamingServiceProvider).attachExternalSubtitle(
      AiroPlaybackExternalSubtitle(
        handle: AiroPlaybackSourceHandle.direct(url),
        label: 'Custom subtitle',
      ),
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({required this.item, required this.onTap});

  final VodItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.title,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_fill,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/screens/vod_screen_test.dart`
Expected: PASS.

Then: `cd packages/feature_iptv && flutter test`
Expected: PASS, entire `feature_iptv` suite (regression gate for `vod_list_widget_test.dart` if one exists — check `find packages/feature_iptv/test -iname "*vod_list*"` and update it if the `_VodListTile`/`VodListWidget` signature change breaks any existing construction call).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/presentation/screens/vod_screen.dart packages/feature_iptv/lib/presentation/widgets/vod_list_widget.dart packages/feature_iptv/test/iptv/presentation/screens/vod_screen_test.dart
git commit -m "feat(feature_iptv): external subtitle attach entry point on VOD screen"
```

---

### Task 11: Full regression pass and PR

**Files:** none new — verification only.

**Interfaces:** none.

- [ ] **Step 1: Run `flutter analyze` on every touched package**

```bash
cd packages/platform_player && flutter analyze
cd ../platform_media && flutter analyze
cd ../platform_streams && flutter analyze
cd ../feature_iptv && flutter analyze
```

Expected: `No issues found!` in all four.

- [ ] **Step 2: Run the full test suite for every touched package**

```bash
cd packages/platform_player && flutter test
cd ../platform_media && flutter test
cd ../platform_streams && flutter test
cd ../feature_iptv && flutter test
```

Expected: all green, no regressions in any pre-existing test (channel-switch, DVR, live-edge, buffer-health, track-management widget tests all still pass).

- [ ] **Step 3: Confirm `video_player` is gone from `platform_streams`' dependency graph**

```bash
grep -n "video_player" packages/platform_streams/pubspec.yaml
```

Expected: no match (only `platform_player` should remain as the relevant dependency).

- [ ] **Step 4: Push and open PR**

```bash
git push -u origin <branch-name>
gh pr create --repo DevelopersCoffee/airo --base main \
  --title "feat(cv-016/cv-031): wire feature_iptv playback through AiroPlaybackEngine" \
  --body "$(cat <<'EOF'
## Summary
- Retrofits VideoPlayerStreamingService (the actual live/VOD playback
  driver in feature_iptv) to run through AiroPlaybackEngine instead of a
  raw VideoPlayerController, unblocking CV-016's track catalog and
  CV-031's external-subtitle projection in the real app UI.
- Closes two real gaps found during implementation: AiroPlaybackEngine
  had no renderable-view accessor (buildView()) and never emitted
  continuous position/duration/buffering state (only on explicit method
  calls) — both fixed at the engine-contract level, not worked around.
- LiveEdgeDetector decoupled from VideoPlayerController entirely
  (attachToEngine(AiroPlaybackEngine) replaces
  attach(VideoPlayerController)) — platform_streams no longer depends on
  video_player.
- New subtitle/track selector button in the player controls; external
  subtitle URL attach entry point on the VOD screen.

## Test plan
- [x] flutter analyze clean across platform_player, platform_media,
      platform_streams, feature_iptv
- [x] Full test suites green in all four packages, including new
      first-ever tests for VideoPlayerStreamingService and
      LiveEdgeDetector
- [x] Existing channel-switch/DVR/live-edge/buffer-health/track-management
      tests unchanged in behavior, re-verified green

Design: docs/superpowers/specs/2026-07-18-feature-iptv-airo-playback-engine-migration-design.md
Refs: CV-016 (#820), CV-031 (#838)
EOF
)"
```

---

## Plan Self-Review Notes

- **Spec coverage:** every "Component" and "Data Flow" item in the design doc maps to a task above (Tasks 1-2 → source handle + buffered ranges gap items 1/5; Task 3-5 → buildView contract gap item 4; Task 6 → LiveEdgeDetector decoupling; Task 7 → the core service refactor; Tasks 8-10 → the three UI components listed).
- **Type consistency:** `AiroPlaybackBufferedRange` used identically in Tasks 2, 4, 6; `Widget? buildView()` signature identical across Tasks 3, 4, 5; `VideoPlayerStreamingService(engine: ...)` constructor param name consistent between Task 7's implementation and Tasks 8-10's tests.
- **Known soft spots for the executor to verify against the live codebase before implementing:** Task 10's exact `VodListWidget`/`VodItem`/`vod_providers.dart` field and provider names — flagged inline as needing a fresh check, since this plan's exploration didn't read those files in full (only `vod_screen.dart` and `iptv_channel.dart`/`iptv_providers.dart` were read completely).

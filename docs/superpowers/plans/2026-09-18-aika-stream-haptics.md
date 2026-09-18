# Aika Stream Haptics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Aika Stream phone/tablet player chrome and the Cast remote play semantic haptics through an application mapper; TV/Fire TV stay silent.

**Architecture:** `feature_iptv` depends on `platform_haptics` (not `airo_haptics`). `AikaHaptics` maps `AikaHapticIntent` to `AiroHaptics.selection` / `navigation` / `toggleOn|Off` / `error` / `success` / `sliderStep` / `medium`. Widgets call the mapper only.

**Tech Stack:** Flutter, Riverpod, `platform_haptics` → `airo_haptics` 1.1.0, `FakeAiroHapticPlatform`.

**Spec:** `docs/superpowers/specs/2026-09-18-aika-stream-haptics-design.md`

**Base:** `origin/main` only after haptics 1.1.0 is on that line. Not `agent/anya/1991-gguf-plan-repair`.

---

## File map

| File | Responsibility |
| --- | --- |
| `packages/platform_haptics/lib/testing.dart` | Re-export engine test fakes so IPTV never imports `airo_haptics` |
| `packages/feature_iptv/pubspec.yaml` | Path dep on `platform_haptics` |
| `packages/feature_iptv/module.yaml` | `allowed_dependencies: platform_haptics` |
| `packages/feature_iptv/lib/application/aika_haptics.dart` | Intents + abstract service + `EngineAikaHaptics` |
| `packages/feature_iptv/lib/application/providers/aika_haptics_provider.dart` | `aikaHapticsProvider` |
| `packages/feature_iptv/lib/feature_iptv.dart` | Export provider |
| `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart` | Player chrome call sites |
| `packages/feature_iptv/lib/presentation/widgets/iptv_cast_mini_controller.dart` | Cast remote call sites |
| `packages/feature_iptv/test/application/aika_haptics_test.dart` | Mapper vs fake platform |
| `packages/feature_iptv/test/iptv/presentation/widgets/iptv_cast_connection_banner_test.dart` | Live vs hydrated connect |
| `packages/feature_iptv/test/presentation/widgets/video_player_widget_context_menu_test.dart` | Favorite haptic |
| `docs/release/AIKA_STREAM_FEATURE_MATRIX.md` | One row: haptic feedback |

Do not add `airo_haptics` to app pubspecs. Do not add `HapticIntent`.

---

### Task 0: Land engine, issue, worktree

**Files:** none in the consumption PR until the engine is on `main`.

- [ ] **Step 1: Confirm `airo_haptics` is on `origin/main`**

```bash
git fetch origin main
git cat-file -e origin/main:packages/airo_haptics/pubspec.yaml
```

Expected: success. If it fails, stop. Land or cherry-pick only:

- `66b0da56` `feat(airo_haptics): consolidate standalone federated haptics engine v1.0.0`
- `6516092c` `feat(airo_haptics): release v1.1.0 engine upgrades ...`

Do not base this work on the GGUF branch that currently carries those commits.

- [ ] **Step 2: Open the parent GitHub issue**

```bash
gh issue create --title "Aika Stream: phone and Cast remote haptics" --body "$(cat <<'EOF'
Spec: docs/superpowers/specs/2026-09-18-aika-stream-haptics-design.md
Plan: docs/superpowers/plans/2026-09-18-aika-stream-haptics.md
Slice: player chrome + Cast remote. TV silent.
EOF
)"
```

- [ ] **Step 3: Worktree from `origin/main`**

```bash
git fetch origin main
git worktree add ../airo-worktrees/<issue>-aika-stream-haptics \
  -b agent/tv/<issue>-aika-stream-haptics origin/main
cd ../airo-worktrees/<issue>-aika-stream-haptics
```

Then `move_agent_to_root` to that path before any edits.

---

### Task 1: Shim testing export + IPTV dependency

**Files:**
- Create: `packages/platform_haptics/lib/testing.dart`
- Modify: `packages/feature_iptv/pubspec.yaml`
- Modify: `packages/feature_iptv/module.yaml`

- [ ] **Step 1: Add the testing barrel**

```dart
library;

export 'package:airo_haptics/testing.dart';
```

- [ ] **Step 2: Add the path dependency to `feature_iptv/pubspec.yaml` under `dependencies:` (alphabetically near the other `platform_*` entries)**

```yaml
  platform_haptics:
    path: ../platform_haptics
```

Do not add `airo_haptics` here.

- [ ] **Step 3: Add `platform_haptics` to `allowed_dependencies` in `packages/feature_iptv/module.yaml` (keep the list sorted with the other `platform_*` entries).**

- [ ] **Step 4: Resolve and validate the manifest**

```bash
cd packages/feature_iptv && dart pub get
python3 scripts/check-module-manifests.py
```

Run the Python script from the repo root. Expected: `module.yaml manifest(s) valid` and no `missing real path dependencies: platform_haptics`.

- [ ] **Step 5: Commit**

```bash
git add packages/platform_haptics/lib/testing.dart \
  packages/feature_iptv/pubspec.yaml \
  packages/feature_iptv/pubspec.lock \
  packages/feature_iptv/module.yaml
git commit -m "$(cat <<'EOF'
feat(feature_iptv): allow platform_haptics for Aika Stream mapper

EOF
)"
```

---

### Task 2: `AikaHaptics` mapper (TDD)

**Files:**
- Create: `packages/feature_iptv/lib/application/aika_haptics.dart`
- Create: `packages/feature_iptv/lib/application/providers/aika_haptics_provider.dart`
- Create: `packages/feature_iptv/test/application/aika_haptics_test.dart`
- Modify: `packages/feature_iptv/lib/feature_iptv.dart`

- [ ] **Step 1: Write the failing mapper tests**

```dart
import 'package:fake_async/fake_async.dart';
import 'package:feature_iptv/application/aika_haptics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_haptics/platform_haptics.dart';
import 'package:platform_haptics/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAiroHapticPlatform fake;
  late EngineAikaHaptics haptics;

  setUp(() async {
    fake = FakeAiroHapticPlatform();
    AiroHapticsPlatform.instance = fake;
    await AiroHaptics.updateSettings(const AiroHapticSettings());
    AiroHaptics.profile = AiroHapticProfile.defaultProfile;
    fake.clearInvocations();
    haptics = EngineAikaHaptics();
  });

  tearDown(() async {
    await haptics.detachCastSession();
  });

  test('playPause maps to selection', () async {
    await haptics.play(AikaHapticIntent.playPause);
    expectHapticPlayed(fake, AiroHapticFeedbackType.selection);
  });

  test('channelStep maps to navigation', () async {
    await haptics.play(AikaHapticIntent.channelStep);
    expectHapticPlayed(fake, AiroHapticFeedbackType.navigation);
  });

  test('favoriteOn and favoriteOff map to toggles', () async {
    await haptics.play(AikaHapticIntent.favoriteOn);
    await haptics.play(AikaHapticIntent.favoriteOff);
    expectHapticPlayed(fake, AiroHapticFeedbackType.toggleOn);
    expectHapticPlayed(fake, AiroHapticFeedbackType.toggleOff);
  });

  test('error maps to error', () async {
    await haptics.play(AikaHapticIntent.error);
    expectHapticPlayed(fake, AiroHapticFeedbackType.error);
  });

  test('castConnected maps to success', () async {
    await haptics.play(AikaHapticIntent.castConnected);
    expectHapticPlayed(fake, AiroHapticFeedbackType.success);
  });

  test('mute maps to selection', () async {
    await haptics.play(AikaHapticIntent.mute);
    expectHapticPlayed(fake, AiroHapticFeedbackType.selection);
  });

  test('stop maps to medium impact', () async {
    await haptics.play(AikaHapticIntent.stop);
    expect(
      fake.invocations.any((i) => i.impact == AiroHapticImpact.medium),
      isTrue,
    );
  });

  test('volumeTick coalesces into selection', () {
    fakeAsync((async) {
      haptics.play(AikaHapticIntent.volumeTick);
      async.elapse(const Duration(milliseconds: 20));
      expectHapticPlayed(fake, AiroHapticFeedbackType.selection);
    });
  });

  test('unsupported hardware is a silent no-op', () async {
    fake.capabilities = const AiroHapticCapabilities.unsupported();
    await haptics.play(AikaHapticIntent.playPause);
    expectNoHapticPlayed(fake);
  });

  test('play swallows platform errors', () async {
    AiroHapticsPlatform.instance = _ThrowingHapticPlatform();
    await expectLater(
      haptics.play(AikaHapticIntent.playPause),
      completes,
    );
  });

  test('attachCastSession is idempotent for the same id', () async {
    await haptics.attachCastSession(id: 'tv-1');
    await haptics.attachCastSession(id: 'tv-1');
    expect(haptics.castSessionId, 'tv-1');
    expect(AiroHaptics.profile, AiroHapticProfile.media);
  });

  test('detachCastSession stops playback and is safe twice', () async {
    await haptics.attachCastSession(id: 'tv-1');
    await haptics.detachCastSession();
    await haptics.detachCastSession();
    expect(haptics.castSessionId, isNull);
    expect(fake.isStopped, isTrue);
  });
}

class _ThrowingHapticPlatform extends FakeAiroHapticPlatform {
  @override
  Future<void> performFeedback(
    AiroHapticFeedbackType type, {
    AiroHapticOptions? options,
  }) async {
    throw StateError('plugin missing');
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd packages/feature_iptv && flutter test test/application/aika_haptics_test.dart
```

Expected: FAIL compiling `EngineAikaHaptics` / `AikaHapticIntent` not found.

- [ ] **Step 3: Implement the mapper**

`packages/feature_iptv/lib/application/aika_haptics.dart`:

```dart
import 'package:platform_haptics/platform_haptics.dart';

enum AikaHapticIntent {
  playPause,
  channelStep,
  favoriteOn,
  favoriteOff,
  error,
  castConnected,
  volumeTick,
  mute,
  stop,
}

abstract class AikaHaptics {
  Future<void> play(AikaHapticIntent intent);
  Future<void> attachCastSession({required String id});
  Future<void> detachCastSession();
}

class EngineAikaHaptics implements AikaHaptics {
  AiroHapticSession? _session;
  String? _castSessionId;

  String? get castSessionId => _castSessionId;

  @override
  Future<void> play(AikaHapticIntent intent) async {
    try {
      switch (intent) {
        case AikaHapticIntent.playPause:
        case AikaHapticIntent.mute:
          await AiroHaptics.selection();
        case AikaHapticIntent.channelStep:
          await AiroHaptics.navigation();
        case AikaHapticIntent.favoriteOn:
          await AiroHaptics.toggleOn();
        case AikaHapticIntent.favoriteOff:
          await AiroHaptics.toggleOff();
        case AikaHapticIntent.error:
          await AiroHaptics.error();
        case AikaHapticIntent.castConnected:
          await AiroHaptics.success();
        case AikaHapticIntent.volumeTick:
          AiroHaptics.sliderStep();
        case AikaHapticIntent.stop:
          await AiroHaptics.medium();
      }
    } catch (_) {
      // Never block playback or Cast controls.
    }
  }

  @override
  Future<void> attachCastSession({required String id}) async {
    if (_castSessionId == id && _session != null) return;
    await detachCastSession();
    AiroHaptics.profile = AiroHapticProfile.media;
    _session = await AiroHaptics.startSession(id: 'aika_cast_$id');
    _castSessionId = id;
  }

  @override
  Future<void> detachCastSession() async {
    _session?.dispose();
    _session = null;
    _castSessionId = null;
    try {
      await AiroHaptics.stopAll();
    } catch (_) {}
  }
}
```

`packages/feature_iptv/lib/application/providers/aika_haptics_provider.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../aika_haptics.dart';

final aikaHapticsProvider = Provider<AikaHaptics>((ref) {
  final haptics = EngineAikaHaptics();
  ref.onDispose(() {
    unawaited(haptics.detachCastSession());
  });
  return haptics;
});
```

Add to `packages/feature_iptv/lib/feature_iptv.dart`:

```dart
export "application/aika_haptics.dart";
export "application/providers/aika_haptics_provider.dart";
```

- [ ] **Step 4: Run mapper tests**

```bash
cd packages/feature_iptv && flutter test test/application/aika_haptics_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/aika_haptics.dart \
  packages/feature_iptv/lib/application/providers/aika_haptics_provider.dart \
  packages/feature_iptv/lib/feature_iptv.dart \
  packages/feature_iptv/test/application/aika_haptics_test.dart
git commit -m "$(cat <<'EOF'
feat(feature_iptv): map Aika Stream intents onto airo_haptics 1.1.0

EOF
)"
```

---

### Task 3: Wire `VideoPlayerWidget`

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart`
- Modify: `packages/feature_iptv/test/presentation/widgets/video_player_widget_context_menu_test.dart`

- [ ] **Step 1: Add a recording fake to the existing player pump and a failing favorite assertion**

In `video_player_widget_context_menu_test.dart`, add:

```dart
class RecordingAikaHaptics implements AikaHaptics {
  final plays = <AikaHapticIntent>[];
  @override
  Future<void> play(AikaHapticIntent intent) async => plays.add(intent);
  @override
  Future<void> attachCastSession({required String id}) async {}
  @override
  Future<void> detachCastSession() async {}
}
```

In `pumpPlayer`, add `aikaHapticsProvider.overrideWithValue(recording)` (or `overrideWith((ref) => recording)`). Keep the recording on the test that taps **Add to favorites**. After the existing favorite assertion:

```dart
expect(haptics.plays, [AikaHapticIntent.favoriteOn]);
```

Use a `late RecordingAikaHaptics` created inside that test and passed into pump.

- [ ] **Step 2: Run the favorite test; expect FAIL** (`plays` empty).

```bash
cd packages/feature_iptv && flutter test \
  test/presentation/widgets/video_player_widget_context_menu_test.dart
```

- [ ] **Step 3: Wire the player**

Imports:

```dart
import '../../application/aika_haptics.dart';
import '../../application/providers/aika_haptics_provider.dart';
```

On `VideoPlayerWidget` state, add a rising-edge listener in `build` (once per rebuild is fine with `ref.listen`):

```dart
ref.listen(streamingStateProvider, (previous, next) {
  final wasError = previous?.valueOrNull?.hasError == true;
  final isError = next.valueOrNull?.hasError == true;
  if (isError && !wasError) {
    unawaited(ref.read(aikaHapticsProvider).play(AikaHapticIntent.error));
  }
});
```

If `streamingStateProvider` is a `StreamProvider`, use `.asData?.value` / `valueOrNull` consistently with this file (`state.hasError` already exists on `StreamingState`).

Replace the three pause/resume sites (overlay `onPlayPause` ~1214, the site ~2260, and nested `togglePlayPause` ~3091) with one method:

```dart
void _togglePlayPause(VideoPlayerStreamingService service, StreamingState state) {
  if (state.isPlaying) {
    service.pause();
  } else {
    service.resume();
  }
  unawaited(ref.read(aikaHapticsProvider).play(AikaHapticIntent.playPause));
}
```

In `_goToNextChannel` / `_goToPreviousChannel`, after `playChannel(...)`:

```dart
unawaited(ref.read(aikaHapticsProvider).play(AikaHapticIntent.channelStep));
```

Do not play if the selectable channel is null.

In `_toggleFavoriteForCurrentChannel`, after `isNowFavorite` and before the snackbar:

```dart
unawaited(
  ref.read(aikaHapticsProvider).play(
    isNowFavorite ? AikaHapticIntent.favoriteOn : AikaHapticIntent.favoriteOff,
  ),
);
```

Do not haptic-wire browse/TV favorites screens.

- [ ] **Step 4: Re-run the context-menu test. Expected: PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(feature_iptv): play Aika haptics from player chrome

EOF
)"
```

---

### Task 4: Wire Cast remote

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/iptv_cast_mini_controller.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/widgets/iptv_cast_connection_banner_test.dart`

- [ ] **Step 1: Add a recording fake to the live-connect banner test**

```dart
class RecordingAikaHaptics implements AikaHaptics {
  final plays = <AikaHapticIntent>[];
  final attached = <String>[];
  var detached = 0;

  @override
  Future<void> play(AikaHapticIntent intent) async => plays.add(intent);

  @override
  Future<void> attachCastSession({required String id}) async => attached.add(id);

  @override
  Future<void> detachCastSession() async => detached++;
}
```

Override `aikaHapticsProvider` in the existing live-connect and hydrated-session tests. After a live connect to `tv-1`:

```dart
expect(haptics.attached, ['tv-1']);
expect(haptics.plays, [AikaHapticIntent.castConnected]);
```

After a hydrated session that is already connected on first build:

```dart
expect(haptics.attached, ['tv-1']);
expect(haptics.plays, isEmpty);
```

- [ ] **Step 2: Run those tests; expect FAIL.**

```bash
cd packages/feature_iptv && flutter test \
  test/iptv/presentation/widgets/iptv_cast_connection_banner_test.dart
```

- [ ] **Step 3: Wire `IptvCastMiniController`**

Imports for `aika_haptics.dart` and `aika_haptics_provider.dart`.

Where the widget already sets `_confirmedDeviceId` for a **hydrated** session, also:

```dart
unawaited(ref.read(aikaHapticsProvider).attachCastSession(id: device.id));
```

Where it already treats a **live** connect (the banner path), attach + `play(AikaHapticIntent.castConnected)`.

When `next.isConnected` becomes false in the existing `ref.listen`, `detachCastSession()`.

On compact/landscape/sheet controls:

- play/pause and reload-from-stopped → `playPause` (same branches that call `notifier.play()` / `pause()` / `reloadActiveMedia()`)
- `notifier.stop()` → `stop`
- `notifier.setVolume(0)` mute → `mute`
- slider `onChanged` and pad ±0.1 → `volumeTick` then the existing `setVolume`
- Disconnect button: `detachCastSession()` then existing `disconnect()`

Rising-edge Cast failure in the same session listen:

```dart
if (next.phase == AiroCastSessionPhase.failed &&
    previous?.phase != AiroCastSessionPhase.failed) {
  unawaited(ref.read(aikaHapticsProvider).play(AikaHapticIntent.error));
}
```

- [ ] **Step 4: Re-run banner tests. Expected: PASS.**

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(feature_iptv): play Aika haptics from the Cast remote

EOF
)"
```

---

### Task 5: Host proof + matrix note

**Files:**
- Modify: `docs/release/AIKA_STREAM_FEATURE_MATRIX.md`

- [ ] **Step 1: Run the narrow suite**

```bash
cd packages/feature_iptv && flutter test \
  test/application/aika_haptics_test.dart \
  test/presentation/widgets/video_player_widget_context_menu_test.dart \
  test/iptv/presentation/widgets/iptv_cast_connection_banner_test.dart
```

Expected: PASS.

- [ ] **Step 2: Confirm no direct engine import in lib**

```bash
rg "package:airo_haptics/" packages/feature_iptv/lib
```

Expected: no matches.

- [ ] **Step 3: Add a feature-matrix row**

| Haptic feedback | Phone/tablet + Cast remote | Semantic play/pause, channel step, favorite, error, Cast connect/volume. TV silent. |

- [ ] **Step 4: Commit**

```bash
git commit -m "$(cat <<'EOF'
docs(aika-stream): note phone and Cast remote haptics

EOF
)"
```

Docs-only commit may use `[skip ci]` if it is the only change in that commit. Do not `[skip ci]` the Dart commits.

---

### Task 6: Device check (not optional for merge)

- Pixel 9: local play/pause, next/prev, favorite on/off, force a bad stream for error; Cast to a receiver and exercise play/pause/stop/volume/mute.
- Fire TV: same chrome must not buzz or crash.

Name the devices in the PR.

---

## Self-review

- Spec coverage: mapper, two call-site files, Cast hydrated vs live, error rising edge, worktree base, package asks, tests, matrix. No library/D-pad/AHAP tasks (correctly omitted).
- No TBD / “add error handling later”.
- Types: `AikaHapticIntent`, `AikaHaptics`, `EngineAikaHaptics`, `aikaHapticsProvider` are consistent across tasks.
- Real 1.1.0 API: `selection`, `navigation`, `toggleOn`, `toggleOff`, `error`, `success`, `sliderStep`, `medium`, `startSession`, `AiroHapticProfile.media`. No `HapticIntent`.

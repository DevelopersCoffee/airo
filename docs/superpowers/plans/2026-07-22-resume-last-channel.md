# Resume Last Channel (TV Explorer UX Phase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On IPTV surface launch, show a branded splash for ~3 s while the last-watched live channel tunes behind it, then reveal playback; any input skips the splash.

**Architecture:** A recorder provider persists the current channel id to SharedPreferences on every tune. A resume controller reads it back on launch, finds the channel in the loaded list, and calls `playChannel` once. A single `IptvResumeGate` wrapper widget hosts the splash overlay and drives the timing (min 3 s, cap 6 s, input skips) and is wrapped around both the phone and TV screen bodies.

**Tech Stack:** Flutter, Riverpod (StateNotifier + `sharedPreferencesProvider` pattern from `tv_font_mode_provider.dart`), shared_preferences, flutter_test.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-22-tv-explorer-ux-adoption-design.md` (Resume flow section).
- Live channels resume at the live edge — same channel, never a timeshift position.
- Never loop retries behind the splash; a failed tune falls back to browse state (bounded failover rule).
- Splash dismiss: `max(3 s, first ready state)` capped at 6 s; any tap/key dismisses immediately.
- No auto-play when no last channel is stored or the channel no longer exists.
- Follow existing package layout: providers in `packages/feature_iptv/lib/application/providers/`, tests mirror under `packages/feature_iptv/test/iptv/`.
- All commands run from `packages/feature_iptv/` inside the worktree (`/Users/udaychauhan/workspace/airo/.claude/worktrees/tv-explorer-ux`).
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: Resume target lookup + last-channel persistence providers

**Files:**
- Create: `packages/feature_iptv/lib/application/providers/last_channel_provider.dart`
- Test: `packages/feature_iptv/test/iptv/application/providers/last_channel_provider_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider`, `currentChannelProvider`, `iptvChannelsProvider`, `IPTVChannel` (all exported via `package:feature_iptv`'s existing `iptv_providers.dart` / `package:platform_channels`).
- Produces:
  - `const String iptvLastChannelKey = 'iptv_last_channel';`
  - `IPTVChannel? findResumeChannel({required String? lastChannelId, required List<IPTVChannel> channels})`
  - `final lastChannelRecorderProvider = Provider<void>(...)` — must be watched (kept alive) by a widget; persists id on every tune.
  - `final resumeChannelProvider = FutureProvider<IPTVChannel?>(...)` — resolves the stored id to a live channel object, or null.

- [ ] **Step 1: Write the failing tests**

Create `packages/feature_iptv/test/iptv/application/providers/last_channel_provider_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/last_channel_provider.dart';

IPTVChannel channel(String id, {String name = 'Test'}) => IPTVChannel(
  id: id,
  name: name,
  streamUrl: 'https://example.com/$id.m3u8',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('findResumeChannel', () {
    final channels = [channel('aajtak'), channel('bbc-earth')];

    test('returns the matching channel by id', () {
      final result = findResumeChannel(
        lastChannelId: 'bbc-earth',
        channels: channels,
      );
      expect(result?.id, 'bbc-earth');
    });

    test('returns null when id is null', () {
      expect(findResumeChannel(lastChannelId: null, channels: channels), isNull);
    });

    test('returns null when the channel is gone from the list', () {
      expect(
        findResumeChannel(lastChannelId: 'gone', channels: channels),
        isNull,
      );
    });

    test('returns null for an empty channel list', () {
      expect(
        findResumeChannel(lastChannelId: 'aajtak', channels: const []),
        isNull,
      );
    });
  });

  group('lastChannelRecorderProvider', () {
    test('persists channel id when streaming state emits a channel', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final states = StreamController<StreamingState>.broadcast();
      addTearDown(states.close);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          streamingStateStreamProvider.overrideWithValue(states.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(lastChannelRecorderProvider); // activate listener

      states.add(StreamingState(currentChannel: channel('aajtak')));
      await Future<void>.delayed(Duration.zero);

      expect(prefs.getString(iptvLastChannelKey), 'aajtak');
    });
  });

  group('resumeChannelProvider', () {
    test('resolves stored id against the channel list', () async {
      SharedPreferences.setMockInitialValues({
        iptvLastChannelKey: 'bbc-earth',
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith(
            (ref) async => [channel('aajtak'), channel('bbc-earth')],
          ),
        ],
      );
      addTearDown(container.dispose);

      final resumed = await container.read(resumeChannelProvider.future);
      expect(resumed?.id, 'bbc-earth');
    });

    test('yields null when nothing stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          iptvChannelsProvider.overrideWith((ref) async => [channel('aajtak')]),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(resumeChannelProvider.future), isNull);
    });
  });
}
```

Note for the implementer: check `StreamingState`'s actual constructor in
`package:platform_player` before running — if `currentChannel` is not a named
constructor parameter, build the state the way
`packages/feature_iptv/test/iptv/application/providers/iptv_providers_test.dart`
does (copy its helper).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/iptv/application/providers/last_channel_provider_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'feature_iptv/application/providers/last_channel_provider.dart'` (file does not exist yet).

- [ ] **Step 3: Write the implementation**

Create `packages/feature_iptv/lib/application/providers/last_channel_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import 'iptv_providers.dart';

/// SharedPreferences key holding the id of the last successfully tuned
/// live channel (TV Explorer UX Phase 1 — resume flow).
const String iptvLastChannelKey = 'iptv_last_channel';

/// Pure resume-target lookup: stored id -> channel in the current list.
/// Null when nothing stored or the channel no longer exists (stale
/// playlist) — callers must not auto-play in that case.
IPTVChannel? findResumeChannel({
  required String? lastChannelId,
  required List<IPTVChannel> channels,
}) {
  if (lastChannelId == null) return null;
  for (final channel in channels) {
    if (channel.id == lastChannelId) return channel;
  }
  return null;
}

/// Persists the current channel id on every tune. Something in the widget
/// tree must watch this provider for the listener to stay live — same
/// contract as [tvIptvIntegrationProvider]. `IptvResumeGate` does.
final lastChannelRecorderProvider = Provider<void>((ref) {
  ref.listen<IPTVChannel?>(currentChannelProvider, (previous, next) {
    if (next == null || next.id == previous?.id) return;
    // Fire-and-forget: a failed prefs write must never affect playback.
    ref.read(sharedPreferencesProvider).setString(iptvLastChannelKey, next.id);
  });
});

/// Resolves the persisted last-channel id against the loaded channel list.
final resumeChannelProvider = FutureProvider<IPTVChannel?>((ref) async {
  final storedId =
      ref.watch(sharedPreferencesProvider).getString(iptvLastChannelKey);
  if (storedId == null) return null;
  final channels = await ref.watch(iptvChannelsProvider.future);
  return findResumeChannel(lastChannelId: storedId, channels: channels);
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/iptv/application/providers/last_channel_provider_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/application/providers/last_channel_provider.dart test/iptv/application/providers/last_channel_provider_test.dart
git commit -m "feat(iptv): persist and resolve last-watched live channel

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Resume controller (one-shot tune orchestration)

**Files:**
- Create: `packages/feature_iptv/lib/application/resume_last_channel_controller.dart`
- Test: `packages/feature_iptv/test/iptv/application/resume_last_channel_controller_test.dart`

**Interfaces:**
- Consumes: `resumeChannelProvider` (Task 1), `iptvStreamingServiceProvider` (existing; `Future<void> playChannel(IPTVChannel channel)`).
- Produces:
  - `enum ResumeStatus { idle, noTarget, tuning, done, failed }`
  - `class ResumeLastChannelController extends StateNotifier<ResumeStatus>` with `Future<void> attemptResume()` (idempotent — second call is a no-op).
  - `final resumeLastChannelControllerProvider = StateNotifierProvider<ResumeLastChannelController, ResumeStatus>(...)`

- [ ] **Step 1: Write the failing tests**

Create `packages/feature_iptv/test/iptv/application/resume_last_channel_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/last_channel_provider.dart';
import 'package:feature_iptv/application/resume_last_channel_controller.dart';

IPTVChannel channel(String id) => IPTVChannel(
  id: id,
  name: id,
  streamUrl: 'https://example.com/$id.m3u8',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer({
    IPTVChannel? resumeTarget,
    required List<String> playedIds,
    bool playThrows = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        resumeChannelProvider.overrideWith((ref) async => resumeTarget),
        // Fake only playChannel; the controller touches nothing else on
        // the streaming service. Copy the service-fake helper style from
        // existing tests if the service class is not directly fakeable.
        iptvStreamingServiceProvider.overrideWithValue(
          FakeStreamingService(playedIds: playedIds, playThrows: playThrows),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('tunes resume target and lands in done', () async {
    final played = <String>[];
    final container = makeContainer(
      resumeTarget: channel('aajtak'),
      playedIds: played,
    );

    await container
        .read(resumeLastChannelControllerProvider.notifier)
        .attemptResume();

    expect(played, ['aajtak']);
    expect(container.read(resumeLastChannelControllerProvider),
        ResumeStatus.done);
  });

  test('no stored target -> noTarget, nothing played', () async {
    final played = <String>[];
    final container = makeContainer(resumeTarget: null, playedIds: played);

    await container
        .read(resumeLastChannelControllerProvider.notifier)
        .attemptResume();

    expect(played, isEmpty);
    expect(container.read(resumeLastChannelControllerProvider),
        ResumeStatus.noTarget);
  });

  test('second attemptResume is a no-op', () async {
    final played = <String>[];
    final container = makeContainer(
      resumeTarget: channel('aajtak'),
      playedIds: played,
    );
    final controller =
        container.read(resumeLastChannelControllerProvider.notifier);

    await controller.attemptResume();
    await controller.attemptResume();

    expect(played, ['aajtak']);
  });

  test('play failure -> failed, no retry', () async {
    final played = <String>[];
    final container = makeContainer(
      resumeTarget: channel('aajtak'),
      playedIds: played,
      playThrows: true,
    );

    await container
        .read(resumeLastChannelControllerProvider.notifier)
        .attemptResume();

    expect(container.read(resumeLastChannelControllerProvider),
        ResumeStatus.failed);
  });
}
```

`FakeStreamingService`: implement against the real service's type. Look at how
`iptv_providers_test.dart` (or `iptv_tv_screen_test.dart`) fakes/mocks
`iptvStreamingServiceProvider` and reuse that mechanism; the fake records
`channel.id` into `playedIds` and throws `StateError('boom')` from
`playChannel` when `playThrows` is true. If the service class is not
implementable directly, extract the controller's dependency as a
`Future<void> Function(IPTVChannel)` instead (see Step 3 alternative) and
override that.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/iptv/application/resume_last_channel_controller_test.dart`
Expected: FAIL — controller file does not exist.

- [ ] **Step 3: Write the implementation**

Create `packages/feature_iptv/lib/application/resume_last_channel_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'providers/iptv_providers.dart';
import 'providers/last_channel_provider.dart';

/// Lifecycle of the launch-time resume attempt (TV Explorer UX Phase 1).
enum ResumeStatus { idle, noTarget, tuning, done, failed }

/// One-shot orchestrator: resolve resume target, tune it, report status.
/// Never retries — a failed tune falls back to browse state (bounded
/// failover rule from the spec).
class ResumeLastChannelController extends StateNotifier<ResumeStatus> {
  ResumeLastChannelController(this._ref) : super(ResumeStatus.idle);

  final Ref _ref;
  bool _attempted = false;

  Future<void> attemptResume() async {
    if (_attempted) return;
    _attempted = true;
    try {
      final target = await _ref.read(resumeChannelProvider.future);
      if (target == null) {
        state = ResumeStatus.noTarget;
        return;
      }
      state = ResumeStatus.tuning;
      await _ref.read(iptvStreamingServiceProvider).playChannel(target);
      if (mounted) state = ResumeStatus.done;
    } catch (_) {
      if (mounted) state = ResumeStatus.failed;
    }
  }
}

final resumeLastChannelControllerProvider =
    StateNotifierProvider<ResumeLastChannelController, ResumeStatus>(
      (ref) => ResumeLastChannelController(ref),
    );
```

Alternative if the streaming service cannot be faked cleanly in tests: add a
`playChannelDelegateProvider = Provider<Future<void> Function(IPTVChannel)>`
defaulting to `(c) => ref.read(iptvStreamingServiceProvider).playChannel(c)`
and have the controller call the delegate; tests override the delegate.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/iptv/application/resume_last_channel_controller_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/application/resume_last_channel_controller.dart test/iptv/application/resume_last_channel_controller_test.dart
git commit -m "feat(iptv): one-shot resume controller for last live channel

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Splash widget with min/cap timing and input skip

**Files:**
- Create: `packages/feature_iptv/lib/presentation/tv_explorer/iptv_resume_splash.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/tv_explorer/iptv_resume_splash_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks (pure widget; timing + input only).
- Produces: `class IptvResumeSplash extends StatefulWidget` with constructor
  `IptvResumeSplash({super.key, required bool playbackReady, required VoidCallback onFinished, Duration minDisplay = const Duration(seconds: 3), Duration maxDisplay = const Duration(seconds: 6)})`.
  Contract: calls `onFinished` exactly once at `max(minDisplay, playbackReady)` capped at `maxDisplay`; any tap or key event finishes immediately. Autofocuses so TV remote keys land on it.

- [ ] **Step 1: Write the failing tests**

Create `packages/feature_iptv/test/iptv/presentation/tv_explorer/iptv_resume_splash_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_iptv/presentation/tv_explorer/iptv_resume_splash.dart';

void main() {
  Widget harness({required bool playbackReady, required VoidCallback onFinished}) {
    return MaterialApp(
      home: IptvResumeSplash(
        playbackReady: playbackReady,
        onFinished: onFinished,
      ),
    );
  }

  testWidgets('finishes at minDisplay when playback already ready',
      (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: true, onFinished: () => finished++),
    );

    await tester.pump(const Duration(seconds: 2));
    expect(finished, 0, reason: 'must hold for full minDisplay');

    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    expect(finished, 1);
  });

  testWidgets('waits for playbackReady after minDisplay', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: false, onFinished: () => finished++),
    );

    await tester.pump(const Duration(seconds: 4));
    expect(finished, 0, reason: 'not ready yet, before cap');

    // Rebuild with playbackReady=true (parent state change).
    await tester.pumpWidget(
      harness(playbackReady: true, onFinished: () => finished++),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(finished, 1);
  });

  testWidgets('cap fires at maxDisplay even if never ready', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: false, onFinished: () => finished++),
    );

    await tester.pump(const Duration(seconds: 6, milliseconds: 100));
    expect(finished, 1);
  });

  testWidgets('tap skips immediately', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: false, onFinished: () => finished++),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byType(IptvResumeSplash));
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('key event skips immediately', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: false, onFinished: () => finished++),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('onFinished never fires twice', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      harness(playbackReady: true, onFinished: () => finished++),
    );
    await tester.tap(find.byType(IptvResumeSplash));
    await tester.pump(const Duration(seconds: 7));
    expect(finished, 1);
  });
}
```

Add `import 'package:flutter/services.dart';` for `LogicalKeyboardKey`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/iptv/presentation/tv_explorer/iptv_resume_splash_test.dart`
Expected: FAIL — widget file does not exist.

- [ ] **Step 3: Write the implementation**

Create `packages/feature_iptv/lib/presentation/tv_explorer/iptv_resume_splash.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';

/// Branded launch splash for the resume-last-channel flow (TV Explorer UX
/// Phase 1). Timing contract:
///   dismiss at max(minDisplay, playbackReady), capped at maxDisplay;
///   any tap or key event dismisses immediately.
/// Visuals stay deliberately simple in Phase 1 — the mosaic treatment
/// arrives with the Phase 2 shell.
class IptvResumeSplash extends StatefulWidget {
  const IptvResumeSplash({
    super.key,
    required this.playbackReady,
    required this.onFinished,
    this.minDisplay = const Duration(seconds: 3),
    this.maxDisplay = const Duration(seconds: 6),
  });

  final bool playbackReady;
  final VoidCallback onFinished;
  final Duration minDisplay;
  final Duration maxDisplay;

  @override
  State<IptvResumeSplash> createState() => _IptvResumeSplashState();
}

class _IptvResumeSplashState extends State<IptvResumeSplash> {
  Timer? _minTimer;
  Timer? _capTimer;
  bool _minElapsed = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _minTimer = Timer(widget.minDisplay, () {
      _minElapsed = true;
      _maybeFinish();
    });
    _capTimer = Timer(widget.maxDisplay, _finish);
  }

  @override
  void didUpdateWidget(IptvResumeSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playbackReady && !oldWidget.playbackReady) _maybeFinish();
  }

  void _maybeFinish() {
    if (_minElapsed && widget.playbackReady) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    _minTimer?.cancel();
    _capTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _capTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _finish();
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF05060F), Color(0xFF141B33)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Airo TV',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
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

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/iptv/presentation/tv_explorer/iptv_resume_splash_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/tv_explorer/iptv_resume_splash.dart test/iptv/presentation/tv_explorer/iptv_resume_splash_test.dart
git commit -m "feat(iptv): resume splash with min/cap timing and input skip

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: IptvResumeGate — single integration wrapper

**Files:**
- Create: `packages/feature_iptv/lib/presentation/tv_explorer/iptv_resume_gate.dart`
- Test: `packages/feature_iptv/test/iptv/presentation/tv_explorer/iptv_resume_gate_test.dart`

**Interfaces:**
- Consumes: `lastChannelRecorderProvider`, `resumeLastChannelControllerProvider` + `ResumeStatus`, `IptvResumeSplash`, `streamingStateProvider` (existing).
- Produces: `class IptvResumeGate extends ConsumerStatefulWidget` with constructor `IptvResumeGate({super.key, required Widget child})`. Behavior: keeps the recorder alive, fires `attemptResume()` once post-frame, overlays `IptvResumeSplash` above `child` until finished; renders bare `child` forever after. `ResumeStatus.noTarget`/`failed` hide the splash immediately (no 3 s hold on a browse-state launch — nothing to hide).

- [ ] **Step 1: Write the failing tests**

Create `packages/feature_iptv/test/iptv/presentation/tv_explorer/iptv_resume_gate_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/last_channel_provider.dart';
import 'package:feature_iptv/application/resume_last_channel_controller.dart';
import 'package:feature_iptv/presentation/tv_explorer/iptv_resume_gate.dart';
import 'package:feature_iptv/presentation/tv_explorer/iptv_resume_splash.dart';

IPTVChannel channel(String id) => IPTVChannel(
  id: id,
  name: id,
  streamUrl: 'https://example.com/$id.m3u8',
);

void main() {
  Widget harness(List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: IptvResumeGate(child: Text('BROWSE')),
      ),
    );
  }

  // Reuse the same streaming-service faking mechanism as Task 2's tests
  // (or the playChannelDelegateProvider alternative) so attemptResume can
  // run without a real player.

  testWidgets('no resume target: splash disappears without 3s hold',
      (tester) async {
    await tester.pumpWidget(harness([
      resumeChannelProvider.overrideWith((ref) async => null),
      lastChannelRecorderProvider.overrideWithValue(null),
    ]));
    await tester.pump();            // post-frame attemptResume
    await tester.pump();            // controller state propagation

    expect(find.byType(IptvResumeSplash), findsNothing);
    expect(find.text('BROWSE'), findsOneWidget);
  });

  testWidgets('resume target: splash shown, dismissed after timing',
      (tester) async {
    final played = <String>[];
    await tester.pumpWidget(harness([
      resumeChannelProvider.overrideWith((ref) async => channel('aajtak')),
      lastChannelRecorderProvider.overrideWithValue(null),
      // + streaming service fake recording into `played`
    ]));
    await tester.pump();
    await tester.pump();

    expect(find.byType(IptvResumeSplash), findsOneWidget);

    await tester.pump(const Duration(seconds: 7)); // beyond cap
    await tester.pump();
    expect(find.byType(IptvResumeSplash), findsNothing);
  });

  testWidgets('splash never returns after dismissal', (tester) async {
    await tester.pumpWidget(harness([
      resumeChannelProvider.overrideWith((ref) async => null),
      lastChannelRecorderProvider.overrideWithValue(null),
    ]));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(IptvResumeSplash), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/iptv/presentation/tv_explorer/iptv_resume_gate_test.dart`
Expected: FAIL — gate file does not exist.

- [ ] **Step 3: Write the implementation**

Create `packages/feature_iptv/lib/presentation/tv_explorer/iptv_resume_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/iptv_providers.dart';
import '../../application/providers/last_channel_provider.dart';
import '../../application/resume_last_channel_controller.dart';
import 'iptv_resume_splash.dart';

/// Wraps an IPTV surface body. Owns the launch-time resume flow:
/// keeps the last-channel recorder alive, fires one resume attempt
/// post-frame, and overlays [IptvResumeSplash] until it finishes.
class IptvResumeGate extends ConsumerStatefulWidget {
  const IptvResumeGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IptvResumeGate> createState() => _IptvResumeGateState();
}

class _IptvResumeGateState extends ConsumerState<IptvResumeGate> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(resumeLastChannelControllerProvider.notifier).attemptResume();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(lastChannelRecorderProvider); // keep recorder listener alive

    final status = ref.watch(resumeLastChannelControllerProvider);
    // Nothing to hide behind a splash when there is no resume target or
    // the tune failed — reveal browse state immediately.
    final showSplash = !_splashDone &&
        (status == ResumeStatus.idle || status == ResumeStatus.tuning ||
         status == ResumeStatus.done);
    final playbackReady = status == ResumeStatus.done;

    if (!_splashDone &&
        (status == ResumeStatus.noTarget || status == ResumeStatus.failed)) {
      _splashDone = true;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (showSplash)
          IptvResumeSplash(
            playbackReady: playbackReady,
            onFinished: () => setState(() => _splashDone = true),
          ),
      ],
    );
  }
}
```

Implementation note: mutating `_splashDone` during build for the
noTarget/failed branch is intentional (no extra frame with a splash), but if
the analyzer or a lint objects, switch to `ref.listen` on
`resumeLastChannelControllerProvider` inside `build` and call
`setState` there.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/iptv/presentation/tv_explorer/iptv_resume_gate_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/tv_explorer/iptv_resume_gate.dart test/iptv/presentation/tv_explorer/iptv_resume_gate_test.dart
git commit -m "feat(iptv): resume gate wiring recorder, controller and splash

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Screen integration, exports, full verification

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv/iptv_tv_screen.dart` (wrap TV screen body)
- Modify: `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart` (wrap phone screen body)
- Modify: `packages/feature_iptv/lib/feature_iptv.dart` (export new files)
- Test: existing suites must stay green.

**Interfaces:**
- Consumes: `IptvResumeGate` (Task 4).
- Produces: both IPTV surfaces launch through the resume flow; public exports for `last_channel_provider.dart`, `resume_last_channel_controller.dart`, `iptv_resume_gate.dart`.

- [ ] **Step 1: Wrap both screen bodies**

In each screen, find the widget returned as the screen's main body (in
`iptv_tv_screen.dart` the root of `build`'s returned tree, typically a
`Scaffold` body; same in `iptv_screen.dart`) and wrap exactly one existing
top-level body widget:

```dart
body: IptvResumeGate(
  child: /* existing body expression, unchanged */
),
```

Add the import to both files:

```dart
import '../tv_explorer/iptv_resume_gate.dart';
```

(from `presentation/screens/` the path is `../tv_explorer/iptv_resume_gate.dart`; from `presentation/tv/` it is also `../tv_explorer/iptv_resume_gate.dart`).

Rule: one wrap per screen, no other layout changes. If a screen already
auto-plays something on launch (check `initState` for any `playChannel`
call), remove that call in favor of the gate — double-tuning is a bug.

- [ ] **Step 2: Export new public files**

In `packages/feature_iptv/lib/feature_iptv.dart` add, alphabetically among the
existing exports:

```dart
export 'application/providers/last_channel_provider.dart';
export 'application/resume_last_channel_controller.dart';
export 'presentation/tv_explorer/iptv_resume_gate.dart';
export 'presentation/tv_explorer/iptv_resume_splash.dart';
```

- [ ] **Step 3: Run the full feature_iptv test suite**

Run: `flutter test`
Expected: all tests pass, including the pre-existing `iptv_tv_screen_test.dart`. If a screen test now hangs on the splash, override `resumeChannelProvider` with `(ref) async => null` in that test's ProviderScope — browse-state launches show no splash, keeping old assertions valid.

- [ ] **Step 4: Analyzer**

Run: `flutter analyze`
Expected: no new warnings.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/tv/iptv_tv_screen.dart lib/presentation/screens/iptv_screen.dart lib/feature_iptv.dart test/
git commit -m "feat(iptv): launch both IPTV surfaces through resume gate

Last-watched live channel auto-resumes behind a ~3s branded splash
(cap 6s, any input skips). No auto-play when nothing stored or the
channel is gone. TV Explorer UX adoption Phase 1.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Manual dogfood (macOS)**

Run the app via the `run-airo-tv` skill flow (macOS target), tune any
channel, quit, relaunch. Expected: splash ~3 s, then the same channel
playing. Press any key during splash → instant reveal. Clear app data →
relaunch shows browse state with no splash hold.

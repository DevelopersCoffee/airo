# Sleep Timer on TV Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a sofa user arm a 15/30/45/60-minute session sleep timer from Playback, cancel it from Watch, and when it fires stop live playback and return to Library.

**Architecture:** New session-only `sleepTimerRemainingProvider` in `feature_iptv`. Expire calls `iptvStreamingService.stop()` and clears `isFullscreenModeProvider`. Do not reuse `app` `sleepTimerProvider` or bedtime mode. Watch chip is cancel-only and only shows with the TV transport overlay.

**Tech Stack:** Flutter, Riverpod, existing `TvFocusable` / `TvTransportBar`, widget tests in `packages/feature_iptv`.

**Design:** `docs/superpowers/specs/2026-09-23-tv-sleep-timer-design.md`

## Global Constraints

- Presets: Off, 15, 30, 45, 60. Invalid `setMinutes` → cancel.
- Session only. No SharedPreferences.
- Expire: `stop()` then `isFullscreenModeProvider = false`. Swallow `stop()` errors. App stays open.
- Cancel: remaining 0, playback continues.
- Copy: `Sleep timer` / `Stop playback and return to Library after this time.` Chip: `Sleep in N min`.
- Playback rows after Resume last channel. Autofocus stays on first aspect option.
- Watch chip only when `useTvTransportBar && remaining > 0` and controls overlay is showing. Do not add a 7th button inside the width-capped transport action row (that would fail existing layout tests). Place the chip **above** `TvTransportBar`.
- Do not edit `app/lib/core/providers/bedtime_mode_provider.dart` or `app_shell.dart`.
- TDD. Commands from `packages/feature_iptv/`. Skip commits unless the user asked.
- Base: `origin/main` after PR #2045 (resume last channel).

---

## File structure

```
packages/feature_iptv/lib/application/providers/sleep_timer_provider.dart          [new]
packages/feature_iptv/lib/feature_iptv.dart                                        [export]
packages/feature_iptv/lib/presentation/screens/settings/playback_settings_screen.dart
packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart
packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart            [_buildTvTransportBar]
packages/feature_iptv/test/iptv/application/providers/sleep_timer_provider_test.dart [new]
packages/feature_iptv/test/iptv/presentation/screens/settings/playback_settings_screen_test.dart [modify]
packages/feature_iptv/test/iptv/presentation/tv/settings/tv_playback_section_test.dart [modify]
packages/feature_iptv/test/presentation/widgets/video_player_widget_tv_transport_bar_test.dart [modify]
```

Allowed preset set in code:

```dart
const sleepTimerPresetMinutes = {15, 30, 45, 60};
```

---

### Task 1: Session timer + expire seam

**Files:**
- Create: `packages/feature_iptv/lib/application/providers/sleep_timer_provider.dart`
- Create: `packages/feature_iptv/test/iptv/application/providers/sleep_timer_provider_test.dart`
- Modify: `packages/feature_iptv/lib/feature_iptv.dart` (export next to `resume_last_channel_preference.dart`)

**Interfaces:**
- Consumes: `iptvStreamingServiceProvider`, `isFullscreenModeProvider`
- Produces:
  - `final sleepTimerTickProvider = Provider<Duration>((ref) => const Duration(minutes: 1));`
  - `final sleepTimerExpireDelegateProvider = Provider<Future<void> Function()>((ref) { ... });`
  - `class SleepTimerNotifier extends StateNotifier<int>`
  - `void setMinutes(int minutes)`
  - `void cancel()`
  - `void handleTick()` — production timer calls this; tests call it directly (do not wait a real minute)
  - `final sleepTimerRemainingProvider = StateNotifierProvider<SleepTimerNotifier, int>(...)`

- [ ] **Step 1: Write the failing tests**

Create `packages/feature_iptv/test/iptv/application/providers/sleep_timer_provider_test.dart`. Copy unused `IPTVStreamingService` stubs from `packages/feature_iptv/test/application/multiview_provider_test.dart` `_FakePrimaryService` if the abstract class has more methods than `stop`.

```dart
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/sleep_timer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to off', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(sleepTimerRemainingProvider), 0);
  });

  test('setMinutes(30) then handleTick decrements', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(sleepTimerRemainingProvider.notifier).setMinutes(30);
    expect(container.read(sleepTimerRemainingProvider), 30);
    container.read(sleepTimerRemainingProvider.notifier).handleTick();
    expect(container.read(sleepTimerRemainingProvider), 29);
  });

  test('setMinutes(15) replaces 30', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(sleepTimerRemainingProvider.notifier);
    notifier.setMinutes(30);
    notifier.setMinutes(15);
    expect(container.read(sleepTimerRemainingProvider), 15);
  });

  test('cancel zeros remaining without calling expire', () async {
    var expired = 0;
    final container = ProviderContainer(
      overrides: [
        sleepTimerExpireDelegateProvider.overrideWith(
          (ref) => () async {
            expired++;
          },
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(sleepTimerRemainingProvider.notifier);
    notifier.setMinutes(15);
    notifier.cancel();
    expect(container.read(sleepTimerRemainingProvider), 0);
    expect(expired, 0);
  });

  test('invalid minutes cancel', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(sleepTimerRemainingProvider.notifier);
    notifier.setMinutes(30);
    notifier.setMinutes(7);
    expect(container.read(sleepTimerRemainingProvider), 0);
  });

  test('tick to zero calls expire once then stays off', () async {
    var expired = 0;
    final container = ProviderContainer(
      overrides: [
        sleepTimerExpireDelegateProvider.overrideWith(
          (ref) => () async {
            expired++;
          },
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(sleepTimerRemainingProvider.notifier);
    notifier.setMinutes(15);
    for (var i = 0; i < 15; i++) {
      notifier.handleTick();
    }
    expect(container.read(sleepTimerRemainingProvider), 0);
    expect(expired, 1);
    notifier.handleTick();
    expect(expired, 1);
  });
}
```

Add a second file-local fake only for the default-delegate test: override `iptvStreamingServiceProvider` with a stub whose `stop()` increments a counter, set `isFullscreenModeProvider` true, `await container.read(sleepTimerExpireDelegateProvider)()`, expect one stop and fullscreen false.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/sleep_timer_provider_test.dart`

Expected: FAIL compiling (`sleep_timer_provider.dart` missing).

- [ ] **Step 3: Implement the provider**

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'iptv_providers.dart';

const sleepTimerPresetMinutes = {15, 30, 45, 60};

final sleepTimerTickProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 1),
);

final sleepTimerExpireDelegateProvider = Provider<Future<void> Function()>((
  ref,
) {
  return () async {
    try {
      await ref.read(iptvStreamingServiceProvider).stop();
    } catch (_) {}
    ref.read(isFullscreenModeProvider.notifier).state = false;
  };
});

class SleepTimerNotifier extends StateNotifier<int> {
  SleepTimerNotifier(this._ref) : super(0);

  final Ref _ref;
  Timer? _timer;
  var _expireArmed = false;

  void setMinutes(int minutes) {
    _timer?.cancel();
    if (!sleepTimerPresetMinutes.contains(minutes)) {
      state = 0;
      _expireArmed = false;
      return;
    }
    state = minutes;
    _expireArmed = true;
    _timer = Timer.periodic(_ref.read(sleepTimerTickProvider), (_) {
      handleTick();
    });
  }

  void cancel() {
    _timer?.cancel();
    _expireArmed = false;
    state = 0;
  }

  void handleTick() {
    if (state <= 0) return;
    final next = state - 1;
    state = next;
    if (next > 0) return;
    _timer?.cancel();
    if (!_expireArmed) return;
    _expireArmed = false;
    unawaited(_ref.read(sleepTimerExpireDelegateProvider)());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final sleepTimerRemainingProvider =
    StateNotifierProvider<SleepTimerNotifier, int>(
      (ref) => SleepTimerNotifier(ref),
    );
```

Export immediately after `resume_last_channel_preference.dart`:

```dart
export "application/providers/sleep_timer_provider.dart";
```

- [ ] **Step 4: Run tests**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/sleep_timer_provider_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit** (skip unless asked)

```bash
git add packages/feature_iptv/lib/application/providers/sleep_timer_provider.dart \
  packages/feature_iptv/test/iptv/application/providers/sleep_timer_provider_test.dart \
  packages/feature_iptv/lib/feature_iptv.dart
git commit -m "$(cat <<'EOF'
feat(iptv): add session sleep timer that stops Watch on expire

EOF
)"
```

---

### Task 2: Playback presets

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/screens/settings/playback_settings_screen.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/screens/settings/playback_settings_screen_test.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/tv/settings/tv_playback_section_test.dart`

**Interfaces:**
- Consumes: `sleepTimerRemainingProvider`, `setMinutes` / `cancel` from Task 1
- Produces: keys `ValueKey('playback-sleep-timer-0')` (Off) and `playback-sleep-timer-15` … `60`

- [ ] **Step 1: Write failing phone test**

Append to `playback_settings_screen_test.dart`:

```dart
  testWidgets('sleep timer 30 minutes writes remaining', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlaybackSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Sleep timer'), findsOneWidget);
    expect(
      find.text('Stop playback and return to Library after this time.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('playback-sleep-timer-30')));
    await tester.pump();
    expect(container.read(sleepTimerRemainingProvider), 30);

    await tester.tap(find.byKey(const ValueKey('playback-sleep-timer-0')));
    await tester.pump();
    expect(container.read(sleepTimerRemainingProvider), 0);
  });
```

- [ ] **Step 2: Run to fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/screens/settings/playback_settings_screen_test.dart`

Expected: FAIL (`Sleep timer` not found).

- [ ] **Step 3: Phone rows**

After the resume `SwitchListTile` and before PiP, insert a `Sleep timer` heading, the subtitle, and a `RadioGroup<int>` of Off/15/30/45/60 with those `ValueKey`s. Watch remaining once:

```dart
    final sleepMinutes = ref.watch(sleepTimerRemainingProvider);
    final sleepGroupValue =
        sleepMinutes == 0 || sleepTimerPresetMinutes.contains(sleepMinutes)
        ? sleepMinutes
        : 0;
```

`onChanged`: `0` → `cancel()`, else `setMinutes`.

- [ ] **Step 4: Re-run phone test** — expected PASS.

- [ ] **Step 5: Write failing TV test**

Append to `tv_playback_section_test.dart`. Tap `find.byKey(const ValueKey('playback-sleep-timer-30'))` and `playback-sleep-timer-0` — do **not** tap `find.text('Off')` (Resume last channel already shows Off).

```dart
  testWidgets('sleep timer 30 minutes writes remaining', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvPlaybackSection())),
      ),
    );
    await tester.pump();

    expect(find.text('Sleep timer'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('playback-sleep-timer-30')),
    );
    await tester.tap(find.byKey(const ValueKey('playback-sleep-timer-30')));
    await tester.pump();
    expect(container.read(sleepTimerRemainingProvider), 30);

    await tester.tap(find.byKey(const ValueKey('playback-sleep-timer-0')));
    await tester.pump();
    expect(container.read(sleepTimerRemainingProvider), 0);
  });
```

- [ ] **Step 6: Run TV tests to fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/settings/tv_playback_section_test.dart`

Expected: FAIL (`Sleep timer` not found).

- [ ] **Step 7: TV rows**

After the Resume last channel `TvFocusable`, before `extraSections`: heading, subtitle, then `for (final minutes in [0, 15, 30, 45, 60])` a `TvFocusable` with `ValueKey('playback-sleep-timer-$minutes')`, check icon when selected, labels `Off` / `$minutes minutes`. **No autofocus** on these rows.

- [ ] **Step 8: Re-run TV + phone playback tests** — expected PASS.

- [ ] **Step 9: Commit** (skip unless asked)

```bash
git add packages/feature_iptv/lib/presentation/screens/settings/playback_settings_screen.dart \
  packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart \
  packages/feature_iptv/test/iptv/presentation/screens/settings/playback_settings_screen_test.dart \
  packages/feature_iptv/test/iptv/presentation/tv/settings/tv_playback_section_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): add Sleep timer presets to Playback settings

EOF
)"
```

---

### Task 3: Watch remaining chip

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart` (`_buildTvTransportBar` ~2183)
- Modify: `packages/feature_iptv/test/presentation/widgets/video_player_widget_tv_transport_bar_test.dart`

**Interfaces:**
- Consumes: `sleepTimerRemainingProvider`
- Produces: `ValueKey('iptv-tv-sleep-timer-chip')` **above** `TvTransportBar`, never inside `actions:`

- [ ] **Step 1: Write the failing tests**

Add optional `int sleepMinutes = 0` to `pumpTransportBar`. After the container exists, if `sleepMinutes > 0` call `setMinutes`. `addTearDown(container.dispose)` if missing.

```dart
  testWidgets('sleep chip shows remaining and cancels on select', (tester) async {
    final container = await pumpTransportBar(
      tester,
      width: 1280,
      sleepMinutes: 15,
    );

    expect(find.text('Sleep in 15 min'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('iptv-tv-sleep-timer-chip')));
    await tester.pump();

    expect(container.read(sleepTimerRemainingProvider), 0);
    expect(find.text('Sleep in 15 min'), findsNothing);
  });

  testWidgets('sleep chip is absent when timer is off', (tester) async {
    await pumpTransportBar(tester, width: 1280);
    expect(find.byKey(const ValueKey('iptv-tv-sleep-timer-chip')), findsNothing);
  });
```

- [ ] **Step 2: Run transport tests to fail**

Run: `cd packages/feature_iptv && flutter test test/presentation/widgets/video_player_widget_tv_transport_bar_test.dart`

Expected: FAIL (`sleepMinutes` missing or chip not found).

- [ ] **Step 3: Implement the chip**

Wrap the existing `TvTransportBar(...)` in a `Column(mainAxisSize: min)`: if `ref.watch(sleepTimerRemainingProvider) > 0`, a centered `TvFocusable` chip `Sleep in $remaining min` that calls `cancel()`. Then the unchanged `TvTransportBar`. Relative-import `sleep_timer_provider.dart` if the widget file does not import the barrel.

- [ ] **Step 4: Re-run transport + Task 1–2 tests**

Run: `cd packages/feature_iptv && flutter test test/presentation/widgets/video_player_widget_tv_transport_bar_test.dart test/iptv/application/providers/sleep_timer_provider_test.dart test/iptv/presentation/tv/settings/tv_playback_section_test.dart test/iptv/presentation/screens/settings/playback_settings_screen_test.dart`

Expected: PASS. If the single-row layout test matches the chip `Row`, keep using the play-pause key's ancestor `Row` (existing pattern ~line 116).

- [ ] **Step 5: Analyze + format**

Run: `cd packages/feature_iptv && dart analyze lib/application/providers/sleep_timer_provider.dart lib/presentation/tv/settings/tv_playback_section.dart lib/presentation/screens/settings/playback_settings_screen.dart lib/presentation/widgets/video_player_widget.dart && dart format lib/application/providers/sleep_timer_provider.dart lib/presentation/tv/settings/tv_playback_section.dart lib/presentation/screens/settings/playback_settings_screen.dart lib/presentation/widgets/video_player_widget.dart test/iptv/application/providers/sleep_timer_provider_test.dart test/iptv/presentation/tv/settings/tv_playback_section_test.dart test/iptv/presentation/screens/settings/playback_settings_screen_test.dart test/presentation/widgets/video_player_widget_tv_transport_bar_test.dart lib/feature_iptv.dart`

- [ ] **Step 6: Commit** (skip unless asked)

```bash
git add packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart \
  packages/feature_iptv/test/presentation/widgets/video_player_widget_tv_transport_bar_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): show cancelable sleep remaining on the TV transport

EOF
)"
```

---

## Self-review (plan vs spec)

| Spec | Task |
| --- | --- |
| Session timer, presets, replace, invalid → off | 1 |
| Expire stop + leave Watch, once, swallow errors | 1 |
| Tests call `handleTick` (no 1-minute wait) | 1 |
| Playback phone + TV copy and rows | 2 |
| Watch chip with transport, cancel-only | 3 |
| Chip not in action row | 3 |
| No bedtime / app_shell edits | all |
| No persist / auto-arm | 1 (no prefs) |

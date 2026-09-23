# Resume Last Live Channel on TV Launch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On a TV cold start, hold the existing resume splash until last-channel lookup is terminal, then open fullscreen Watch; let users turn autoplay off in Playback.

**Architecture:** Keep `IptvResumeGate` / `ResumeLastChannelController` / `playChannelDelegate`. Add a local `resumeLastChannelEnabledProvider` (default true). TV gate uses `holdUntilTerminal` plus `onEnterWatch` so `IPTVScreen` sets `isFullscreenModeProvider` only as the splash dismisses with `ResumeStatus.done`. Phone splash timing stays default.

**Tech Stack:** Flutter, Riverpod (`StateNotifier` + `sharedPreferencesProvider`), existing `IptvResumeSplash`, widget tests in `packages/feature_iptv`.

**Design:** `docs/superpowers/specs/2026-09-23-tv-resume-last-channel-design.md`

## Global Constraints

- Copy: title `Resume last channel`; subtitle `Open the last live channel when Aika Stream starts.`
- Pref key: `iptv_resume_last_channel_enabled`. Default ON. Local only. Recorder still writes `iptv_last_channel`.
- `playChannelDelegateProvider` stays play-only. Do not change it to set fullscreen.
- Phone compact: AND the pref into `IptvResumeGate.enabled` only. Do not pass `holdUntilTerminal` or `onEnterWatch`.
- Deep-link: `enabled` is false when `effectiveDeepLinkChannelId != null`.
- Skip while `idle`/`tuning`: reveal Library, never call `onEnterWatch` later.
- Failures: silent Library, no toast, no Watch.
- No sleep timer, no new `iptvSettingsSections` id, no `playbackSettingsExtraSectionsProvider` injection.
- Music Audio settings "Auto Resume" is a different feature — do not touch `audio_settings_screen.dart`.
- TDD: failing test first. Commands from `packages/feature_iptv/`.
- Do not commit unless the user asked; skip commit steps when running without commit permission.
- Analyze/test only this package. No full CI matrix.

---

## File structure

```
packages/feature_iptv/lib/application/providers/resume_last_channel_preference.dart   [new]
packages/feature_iptv/lib/feature_iptv.dart                                           [modify: export]
packages/feature_iptv/lib/presentation/tv_ux/iptv_resume_splash.dart                  [modify: onSkipped]
packages/feature_iptv/lib/presentation/tv_ux/iptv_resume_gate.dart                     [modify]
packages/feature_iptv/lib/presentation/screens/iptv_screen.dart                        [modify: both gates]
packages/feature_iptv/lib/presentation/screens/settings/playback_settings_screen.dart  [modify]
packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart            [modify]
packages/feature_iptv/test/iptv/application/providers/resume_last_channel_preference_test.dart [new]
packages/feature_iptv/test/iptv/presentation/tv_ux/iptv_resume_splash_test.dart        [modify]
packages/feature_iptv/test/iptv/presentation/tv_ux/iptv_resume_gate_test.dart          [modify]
packages/feature_iptv/test/iptv/presentation/screens/settings/playback_settings_screen_test.dart [new]
packages/feature_iptv/test/iptv/presentation/tv/settings/tv_playback_section_test.dart [modify]
```

---

### Task 1: Resume-enabled preference

**Files:**
- Create: `packages/feature_iptv/lib/application/providers/resume_last_channel_preference.dart`
- Create: `packages/feature_iptv/test/iptv/application/providers/resume_last_channel_preference_test.dart`
- Modify: `packages/feature_iptv/lib/feature_iptv.dart` (add export next to `last_channel_provider.dart`)

**Interfaces:**
- Consumes: `sharedPreferencesProvider` from `iptv_providers.dart`
- Produces:
  - `const String iptvResumeLastChannelEnabledKey = 'iptv_resume_last_channel_enabled';`
  - `class ResumeLastChannelEnabledNotifier extends StateNotifier<bool>`
  - `Future<void> setEnabled(bool enabled)`
  - `final resumeLastChannelEnabledProvider = StateNotifierProvider<ResumeLastChannelEnabledNotifier, bool>(...)`

- [ ] **Step 1: Write the failing tests**

Create `packages/feature_iptv/test/iptv/application/providers/resume_last_channel_preference_test.dart`:

```dart
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/resume_last_channel_preference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to enabled when nothing is persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(resumeLastChannelEnabledProvider), isTrue);
  });

  test('loads a persisted false through the shared store', () async {
    SharedPreferences.setMockInitialValues({
      iptvResumeLastChannelEnabledKey: false,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(resumeLastChannelEnabledProvider), isFalse);
  });

  test('setEnabled persists and a new container reads it back', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container
        .read(resumeLastChannelEnabledProvider.notifier)
        .setEnabled(false);

    expect(prefs.getBool(iptvResumeLastChannelEnabledKey), isFalse);

    final restarted = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(restarted.dispose);
    expect(restarted.read(resumeLastChannelEnabledProvider), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/resume_last_channel_preference_test.dart`

Expected: FAIL compiling (`resume_last_channel_preference.dart` does not exist).

- [ ] **Step 3: Write minimal implementation**

Create `packages/feature_iptv/lib/application/providers/resume_last_channel_preference.dart` mirroring `picture_in_picture_preference_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

const iptvResumeLastChannelEnabledKey = 'iptv_resume_last_channel_enabled';

class ResumeLastChannelEnabledNotifier extends StateNotifier<bool> {
  ResumeLastChannelEnabledNotifier(this._ref) : super(true) {
    _loadFromStorage();
  }

  final Ref _ref;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      await _ref
          .read(sharedPreferencesProvider)
          .setBool(iptvResumeLastChannelEnabledKey, enabled);
    } catch (_) {
      // Settings persistence failures must not affect playback.
    }
  }

  void _loadFromStorage() {
    try {
      final stored = _ref
          .read(sharedPreferencesProvider)
          .getBool(iptvResumeLastChannelEnabledKey);
      if (stored != null) {
        state = stored;
      }
    } catch (_) {
      // Keep default ON when preferences are unavailable.
    }
  }
}

final resumeLastChannelEnabledProvider =
    StateNotifierProvider<ResumeLastChannelEnabledNotifier, bool>(
      (ref) => ResumeLastChannelEnabledNotifier(ref),
    );
```

In `packages/feature_iptv/lib/feature_iptv.dart`, immediately after the `last_channel_provider.dart` export, add:

```dart
export "application/providers/resume_last_channel_preference.dart";
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/providers/resume_last_channel_preference_test.dart`

Expected: PASS (3 tests).

- [ ] **Step 5: Commit** (skip unless the user asked)

```bash
git add packages/feature_iptv/lib/application/providers/resume_last_channel_preference.dart \
  packages/feature_iptv/test/iptv/application/providers/resume_last_channel_preference_test.dart \
  packages/feature_iptv/lib/feature_iptv.dart
git commit -m "$(cat <<'EOF'
feat(iptv): persist resume-last-channel toggle, default on

EOF
)"
```

---

### Task 2: Splash skip vs timer + TV holdUntilTerminal

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/iptv_resume_splash.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/tv_ux/iptv_resume_splash_test.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/iptv_resume_gate.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/tv_ux/iptv_resume_gate_test.dart`

**Interfaces:**
- Consumes: existing `ResumeStatus`, `resumeChannelProvider`, `playChannelDelegateProvider`, `resumeSplashCompletedProvider`
- Produces:
  - `IptvResumeSplash({..., VoidCallback? onSkipped})` — key/tap call `onSkipped` when non-null, otherwise `onFinished`. Timer / playback-ready always call `onFinished`.
  - `IptvResumeGate({required Widget child, bool enabled = true, bool holdUntilTerminal = false, VoidCallback? onEnterWatch})`
  - `onEnterWatch` at most once, only from overlay dismiss when status is already `done`. Skip-before-done suppresses it forever.

- [ ] **Step 1: Write the failing splash test**

In `iptv_resume_splash_test.dart`, extend `harness` with optional `onSkipped` and add:

```dart
  Widget harness({
    required bool playbackReady,
    required VoidCallback onFinished,
    VoidCallback? onSkipped,
  }) {
    return MaterialApp(
      home: IptvResumeSplash(
        playbackReady: playbackReady,
        onFinished: onFinished,
        onSkipped: onSkipped,
        minDisplay: minDisplay,
        maxDisplay: maxDisplay,
      ),
    );
  }

  testWidgets('onSkipped receives tap and onFinished does not', (tester) async {
    var finished = 0;
    var skipped = 0;
    await tester.pumpWidget(
      harness(
        playbackReady: false,
        onFinished: () => finished++,
        onSkipped: () => skipped++,
      ),
    );

    await tester.tap(find.byType(IptvResumeSplash));
    await tester.pump();
    expect(skipped, 1);
    expect(finished, 0);
  });

  testWidgets('maxDisplay still calls onFinished when onSkipped is set', (
    tester,
  ) async {
    var finished = 0;
    var skipped = 0;
    await tester.pumpWidget(
      harness(
        playbackReady: false,
        onFinished: () => finished++,
        onSkipped: () => skipped++,
      ),
    );

    await tester.pump(maxDisplay + const Duration(milliseconds: 100));
    expect(finished, 1);
    expect(skipped, 0);
  });
```

Keep existing tap tests (no `onSkipped`) asserting `onFinished`.

- [ ] **Step 2: Run splash tests to verify the new ones fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/iptv_resume_splash_test.dart`

Expected: FAIL (`onSkipped` isn't defined).

- [ ] **Step 3: Implement `onSkipped` on the splash**

In `iptv_resume_splash.dart`, add optional `this.onSkipped` to the constructor. Change `_finish` to:

```dart
  void _finish({bool skipped = false}) {
    if (_finished) return;
    _finished = true;
    _minTimer?.cancel();
    _capTimer?.cancel();
    if (skipped && widget.onSkipped != null) {
      widget.onSkipped!();
    } else {
      widget.onFinished();
    }
  }
```

Call `_finish(skipped: true)` from `onKeyEvent` and `onTap`. Leave `_finishIfReady` / max timer as `_finish()`.

- [ ] **Step 4: Re-run splash tests**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/iptv_resume_splash_test.dart`

Expected: PASS.

- [ ] **Step 5: Write the failing gate tests**

Replace the `harness` helper in `iptv_resume_gate_test.dart` so it can pass the new kwargs. Keep the existing `harness(List<Override>)` working by adding optional named args. Add `dart:async` for `Completer`. Append:

```dart
  Widget harness(
    List<Override> overrides, {
    bool holdUntilTerminal = false,
    VoidCallback? onEnterWatch,
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: IptvResumeGate(
          holdUntilTerminal: holdUntilTerminal,
          onEnterWatch: onEnterWatch,
          child: const Text('BROWSE'),
        ),
      ),
    );
  }

  testWidgets(
    'holdUntilTerminal keeps splash after cap while lookup is still pending',
    (tester) async {
      final completer = Completer<IPTVChannel?>();
      await tester.pumpWidget(
        harness(
          [
            resumeChannelProvider.overrideWith((ref) => completer.future),
            playChannelDelegateProvider.overrideWithValue((channel) async {}),
          ],
          holdUntilTerminal: true,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(IptvResumeSplash), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      expect(find.byType(IptvResumeSplash), findsOneWidget);

      completer.complete(null);
      await tester.pump();
      await tester.pump();
      expect(find.byType(IptvResumeSplash), findsNothing);
    },
  );

  testWidgets('onEnterWatch fires once when done splash dismisses', (
    tester,
  ) async {
    var entered = 0;
    await tester.pumpWidget(
      harness(
        [
          resumeChannelProvider.overrideWith(
            (ref) async => channel('aajtak'),
          ),
          playChannelDelegateProvider.overrideWithValue((channel) async {}),
        ],
        holdUntilTerminal: true,
        onEnterWatch: () => entered++,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));
    await tester.pump();

    expect(entered, 1);
    expect(find.byType(IptvResumeSplash), findsNothing);
  });

  testWidgets('noTarget never calls onEnterWatch', (tester) async {
    var entered = 0;
    await tester.pumpWidget(
      harness(
        [resumeChannelProvider.overrideWith((ref) async => null)],
        holdUntilTerminal: true,
        onEnterWatch: () => entered++,
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 7));

    expect(entered, 0);
    expect(find.byType(IptvResumeSplash), findsNothing);
  });

  testWidgets('skip before done never calls onEnterWatch later', (tester) async {
    final completer = Completer<IPTVChannel?>();
    var entered = 0;
    await tester.pumpWidget(
      harness(
        [
          resumeChannelProvider.overrideWith((ref) => completer.future),
          playChannelDelegateProvider.overrideWithValue((channel) async {}),
        ],
        holdUntilTerminal: true,
        onEnterWatch: () => entered++,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(IptvResumeSplash), findsOneWidget);

    await tester.tap(find.byType(IptvResumeSplash));
    await tester.pump();
    expect(find.byType(IptvResumeSplash), findsNothing);
    expect(entered, 0);

    completer.complete(channel('aajtak'));
    await tester.pump();
    await tester.pump();
    expect(entered, 0);
  });
```

Do not remove existing tests. Default `holdUntilTerminal: false` must still dismiss at cap while a target exists.

- [ ] **Step 6: Run gate tests to verify new ones fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/iptv_resume_gate_test.dart`

Expected: FAIL (`holdUntilTerminal` / `onEnterWatch` aren't defined, or splash vanishes at 7s while lookup pending).

- [ ] **Step 7: Implement gate**

Replace `IptvResumeGate` / state in `iptv_resume_gate.dart` with:

```dart
class IptvResumeGate extends ConsumerStatefulWidget {
  const IptvResumeGate({
    super.key,
    required this.child,
    this.enabled = true,
    this.holdUntilTerminal = false,
    this.onEnterWatch,
  });

  final Widget child;
  final bool enabled;
  final bool holdUntilTerminal;
  final VoidCallback? onEnterWatch;

  @override
  ConsumerState<IptvResumeGate> createState() => _IptvResumeGateState();
}

class _IptvResumeGateState extends ConsumerState<IptvResumeGate> {
  var _skippedBeforeDone = false;
  var _enterWatchOffered = false;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(resumeLastChannelControllerProvider.notifier).attemptResume(),
      );
    });
  }

  bool _isTerminal(ResumeStatus status) {
    return status == ResumeStatus.noTarget ||
        status == ResumeStatus.failed ||
        status == ResumeStatus.done;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(lastChannelRecorderProvider);
    if (!widget.enabled) return widget.child;

    final resumeStatus = ref.watch(resumeLastChannelControllerProvider);
    final splashCompleted = ref.watch(resumeSplashCompletedProvider);
    final playbackReady =
        ref.watch(playbackStateProvider) == PlaybackState.playing;
    final showSplash =
        !splashCompleted &&
        (resumeStatus == ResumeStatus.idle ||
            resumeStatus == ResumeStatus.tuning ||
            resumeStatus == ResumeStatus.done);

    if (widget.holdUntilTerminal &&
        !splashCompleted &&
        _isTerminal(resumeStatus)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _markSplashCompleted();
      });
    }

    if (!showSplash) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IptvResumeSplash(
          playbackReady: playbackReady,
          onFinished: _markSplashCompleted,
          onSkipped: widget.holdUntilTerminal ? _onSkipped : null,
        ),
      ],
    );
  }

  void _onSkipped() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _skippedBeforeDone = true;
      if (ref.read(resumeSplashCompletedProvider)) return;
      ref.read(resumeSplashCompletedProvider.notifier).state = true;
    });
  }

  void _markSplashCompleted() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(resumeLastChannelControllerProvider);
      if (widget.holdUntilTerminal &&
          (status == ResumeStatus.idle || status == ResumeStatus.tuning)) {
        return;
      }
      if (ref.read(resumeSplashCompletedProvider)) {
        _offerEnterWatchIfDone(status);
        return;
      }
      ref.read(resumeSplashCompletedProvider.notifier).state = true;
      _offerEnterWatchIfDone(status);
    });
  }

  void _offerEnterWatchIfDone(ResumeStatus status) {
    if (_skippedBeforeDone || _enterWatchOffered) return;
    if (status != ResumeStatus.done) return;
    _enterWatchOffered = true;
    widget.onEnterWatch?.call();
  }
}
```

Leave `resumeSplashCompletedProvider` as-is.

- [ ] **Step 8: Run gate + splash tests**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/iptv_resume_gate_test.dart test/iptv/presentation/tv_ux/iptv_resume_splash_test.dart`

Expected: PASS, including the old no-target / disabled / remount tests.

- [ ] **Step 9: Commit** (skip unless the user asked)

```bash
git add packages/feature_iptv/lib/presentation/tv_ux/iptv_resume_splash.dart \
  packages/feature_iptv/lib/presentation/tv_ux/iptv_resume_gate.dart \
  packages/feature_iptv/test/iptv/presentation/tv_ux/iptv_resume_splash_test.dart \
  packages/feature_iptv/test/iptv/presentation/tv_ux/iptv_resume_gate_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): hold TV resume splash until lookup is terminal

EOF
)"
```

---

### Task 3: Playback settings rows

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/screens/settings/playback_settings_screen.dart`
- Create: `packages/feature_iptv/test/iptv/presentation/screens/settings/playback_settings_screen_test.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/tv/settings/tv_playback_section_test.dart`

**Interfaces:**
- Consumes: `resumeLastChannelEnabledProvider` from Task 1
- Produces: phone `SwitchListTile` key `ValueKey('playback-resume-last-channel-toggle')`; TV `TvFocusable` `semanticLabel` `Resume last channel, on` / `Resume last channel, off`. Autofocus stays on the first aspect option.

- [ ] **Step 1: Write the failing phone test**

Create `packages/feature_iptv/test/iptv/presentation/screens/settings/playback_settings_screen_test.dart`:

```dart
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/screens/settings/playback_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('resume last channel switch defaults on and writes the pref', (
    tester,
  ) async {
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

    expect(find.text('Resume last channel'), findsOneWidget);
    expect(
      find.text('Open the last live channel when Aika Stream starts.'),
      findsOneWidget,
    );
    expect(container.read(resumeLastChannelEnabledProvider), isTrue);

    await tester.tap(find.byKey(const ValueKey('playback-resume-last-channel-toggle')));
    await tester.pump();

    expect(container.read(resumeLastChannelEnabledProvider), isFalse);
  });
}
```

- [ ] **Step 2: Run phone test to verify it fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/screens/settings/playback_settings_screen_test.dart`

Expected: FAIL (`Resume last channel` not found).

- [ ] **Step 3: Add the phone SwitchListTile**

In `playback_settings_screen.dart`, after the aspect-ratio `RadioGroup` closing parenthesis and before the PiP `SwitchListTile`, insert:

```dart
          SwitchListTile(
            key: const ValueKey('playback-resume-last-channel-toggle'),
            secondary: const Icon(Icons.history),
            title: const Text('Resume last channel'),
            subtitle: const Text(
              'Open the last live channel when Aika Stream starts.',
            ),
            value: ref.watch(resumeLastChannelEnabledProvider),
            onChanged: (enabled) => ref
                .read(resumeLastChannelEnabledProvider.notifier)
                .setEnabled(enabled),
          ),
```

`resumeLastChannelEnabledProvider` is already on the `feature_iptv.dart` barrel this file imports.

- [ ] **Step 4: Re-run phone test**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/screens/settings/playback_settings_screen_test.dart`

Expected: PASS.

- [ ] **Step 5: Write the failing TV tests**

Append to `tv_playback_section_test.dart`:

```dart
  testWidgets('resume last channel row toggles the preference', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvPlaybackSection())),
      ),
    );
    await tester.pump();

    expect(find.text('Resume last channel'), findsOneWidget);
    expect(
      find.text('Open the last live channel when Aika Stream starts.'),
      findsOneWidget,
    );
    expect(container.read(resumeLastChannelEnabledProvider), isTrue);

    await tester.tap(find.text('Resume last channel'));
    await tester.pump();

    expect(container.read(resumeLastChannelEnabledProvider), isFalse);
  });
```

- [ ] **Step 6: Run TV playback tests to verify the new one fails**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/settings/tv_playback_section_test.dart`

Expected: FAIL (`Resume last channel` not found). Existing aspect tests still pass.

- [ ] **Step 7: Add the TV row after the aspect list**

In `tv_playback_section.dart` `build`, after the aspect `for` loop and before `if (extraSections.isNotEmpty)`, insert (keep `autofocus: index == 0` on aspect):

```dart
        const SizedBox(height: 16),
        TvFocusable(
          onSelect: () => ref
              .read(resumeLastChannelEnabledProvider.notifier)
              .setEnabled(!ref.read(resumeLastChannelEnabledProvider)),
          semanticLabel: ref.watch(resumeLastChannelEnabledProvider)
              ? 'Resume last channel, on'
              : 'Resume last channel, off',
          semanticButton: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resume last channel',
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Open the last live channel when Aika Stream starts.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  ref.watch(resumeLastChannelEnabledProvider) ? 'On' : 'Off',
                  style: TextStyle(color: colorScheme.primary, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
```

`resumeLastChannelEnabledProvider` arrives via `package:feature_iptv/feature_iptv.dart`.

- [ ] **Step 8: Re-run TV playback tests**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv/settings/tv_playback_section_test.dart`

Expected: PASS.

- [ ] **Step 9: Commit** (skip unless the user asked)

```bash
git add packages/feature_iptv/lib/presentation/screens/settings/playback_settings_screen.dart \
  packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart \
  packages/feature_iptv/test/iptv/presentation/screens/settings/playback_settings_screen_test.dart \
  packages/feature_iptv/test/iptv/presentation/tv/settings/tv_playback_section_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): add Resume last channel to Playback settings

EOF
)"
```

---

### Task 4: Wire IPTVScreen

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/screens/iptv_screen.dart` (ten-foot gate ~1176 and phone gate ~1223)

**Interfaces:**
- Consumes: `resumeLastChannelEnabledProvider` (Task 1), `IptvResumeGate.holdUntilTerminal` / `onEnterWatch` (Task 2), existing `isFullscreenModeProvider`
- Produces: ten-foot `onEnterWatch` sets fullscreen once; both gates AND the pref into `enabled`

There is no IPTVScreen widget test in this package. Prove the wiring with analyzer + the Task 2 gate tests (callback contract) and a `dart analyze` on the screen file.

- [ ] **Step 1: Add the import**

With the other `../../application/providers/` imports at the top of `iptv_screen.dart`:

```dart
import '../../application/providers/resume_last_channel_preference.dart';
```

- [ ] **Step 2: Compute enablement once in `build`**

Inside `_IPTVScreenState.build`, after `final isFullscreen = ref.watch(isFullscreenModeProvider);` (~958):

```dart
    final resumeEnabled = ref.watch(resumeLastChannelEnabledProvider);
    final resumeGateEnabled =
        widget.effectiveDeepLinkChannelId == null && resumeEnabled;
```

`IPTVScreen` is the class with `tenFootMode`. Do not edit `IPTVScreenBody` (no gate there).

- [ ] **Step 3: Ten-foot gate**

Replace the ten-foot `IptvResumeGate` (~1176) with:

```dart
          body: IptvResumeGate(
            enabled: resumeGateEnabled,
            holdUntilTerminal: true,
            onEnterWatch: () {
              if (!mounted) return;
              ref.read(isFullscreenModeProvider.notifier).state = true;
            },
            child: _StreamTabContent(
              key: const ValueKey('iptv-browse-grid'),
              onChannelTap: _playChannelFullscreen,
              onFullscreenToggle: _toggleFullscreen,
              onPlaylistSourceTap: _showPlaylistSheet,
              onGuideSourceTap: _showGuideSourceSheet,
              onScanWithPhoneTap: _showQrPlaylist,
              onWaysToWatchTap: _showWaysToWatch,
              onShareVideoFrame: widget.onShareVideoFrame,
              playlistSourceInInfoBar: true,
            ),
          ),
```

Do not call `_playChannelFullscreen` from `onEnterWatch`.

- [ ] **Step 4: Phone gate**

Replace only the `enabled:` line on the phone `IptvResumeGate` (~1223):

```dart
        body: IptvResumeGate(
          enabled: resumeGateEnabled,
          child: Stack(
```

Leave `holdUntilTerminal` / `onEnterWatch` at defaults.

- [ ] **Step 5: Analyze the package**

Run: `cd packages/feature_iptv && dart analyze lib/presentation/screens/iptv_screen.dart lib/presentation/tv_ux/iptv_resume_gate.dart lib/application/providers/resume_last_channel_preference.dart`

Expected: no issues.

- [ ] **Step 6: Regression tests**

Run: `cd packages/feature_iptv && flutter test test/iptv/presentation/tv_ux/iptv_resume_gate_test.dart test/iptv/application/resume_last_channel_controller_test.dart test/iptv/application/providers/last_channel_provider_test.dart test/iptv/application/providers/resume_last_channel_preference_test.dart test/iptv/presentation/tv/settings/tv_playback_section_test.dart test/iptv/presentation/screens/settings/playback_settings_screen_test.dart`

Expected: PASS.

- [ ] **Step 7: Format**

Run: `cd packages/feature_iptv && dart format lib/application/providers/resume_last_channel_preference.dart lib/presentation/tv_ux/iptv_resume_gate.dart lib/presentation/tv_ux/iptv_resume_splash.dart lib/presentation/screens/iptv_screen.dart lib/presentation/screens/settings/playback_settings_screen.dart lib/presentation/tv/settings/tv_playback_section.dart lib/feature_iptv.dart test/iptv/application/providers/resume_last_channel_preference_test.dart test/iptv/presentation/tv_ux/iptv_resume_gate_test.dart test/iptv/presentation/tv_ux/iptv_resume_splash_test.dart test/iptv/presentation/tv/settings/tv_playback_section_test.dart test/iptv/presentation/screens/settings/playback_settings_screen_test.dart`

- [ ] **Step 8: Commit** (skip unless the user asked)

```bash
git add packages/feature_iptv/lib/presentation/screens/iptv_screen.dart
git commit -m "$(cat <<'EOF'
feat(iptv): open Watch after TV resume splash succeeds

EOF
)"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
| --- | --- |
| Pref default ON, local key, recorder unchanged | 1 |
| Playback rows, exact copy, not Privacy / not music Auto Resume | 3 |
| Gate `enabled` AND pref AND no deep-link | 4 |
| Phone splash timing unchanged | 4 (defaults) |
| TV hold until terminal, opaque splash | 2 |
| Watch via `isFullscreenModeProvider` on `done` dismiss | 2 + 4 |
| Skip-before-done never Watch | 2 |
| Silent fail Library | 2 (`noTarget` test) + existing controller |
| `playChannelDelegate` play-only | 4 (do not touch) |
| No new settings section | 3 |
| TDD tests listed | 1–3; 4 analyze + regression |

No sleep timer. No Approach B lift. No second gate.

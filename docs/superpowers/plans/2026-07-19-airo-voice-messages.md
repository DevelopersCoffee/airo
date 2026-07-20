# AiroVoice Message Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace boring user-facing status/error strings ("Loading...", "Error: $err") with a rotating catalog of modern, characterful messages (`AiroVoice`) in `core_ui`.

**Architecture:** A static `AiroVoice` catalog in `core_ui` exposes `MessagePool`s per category (loading, thinking, searching, buffering, errorGeneric, errorNetwork, empty). Pools return a random variant via `pick()`; a seedable shared `Random` makes tests deterministic. Call sites in `app/` and `feature_iptv` swap hardcoded literals for pool picks. Internal `Failure(message:)` strings are untouched.

**Tech Stack:** Flutter/Dart, melos monorepo, `flutter test`.

## Global Constraints

- Scope: user-facing UI strings only. Never modify `Failure(message:)`, log strings, or repository error plumbing.
- Technical error detail must never be dropped — `pickWith(detail:)` appends it on a new line.
- No new dependencies.
- Many call sites are inside `const` constructors — swapping to `AiroVoice` requires removing `const` from the smallest enclosing widget expression only.
- Run `dart format` on every touched file before committing (CI gate rejects unformatted code).
- Commit messages end with `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.

---

### Task 1: `MessagePool` + `AiroVoice` catalog in core_ui

**Files:**
- Create: `packages/core_ui/lib/src/voice/airo_voice.dart`
- Modify: `packages/core_ui/lib/core_ui.dart` (add export)
- Test: `packages/core_ui/test/airo_voice_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `AiroVoice.loading|thinking|searching|buffering|errorGeneric|errorNetwork|empty` (each `MessagePool`), `MessagePool.pick() → String`, `MessagePool.pickWith({String? detail}) → String`, `MessagePool.variants → List<String>`, `AiroVoice.seed(int)`.

- [ ] **Step 1: Write the failing test**

```dart
// packages/core_ui/test/airo_voice_test.dart
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagePool', () {
    test('pick returns a variant from the pool', () {
      final msg = AiroVoice.loading.pick();
      expect(AiroVoice.loading.variants, contains(msg));
    });

    test('seed makes picks deterministic', () {
      AiroVoice.seed(42);
      final first = [for (var i = 0; i < 5; i++) AiroVoice.loading.pick()];
      AiroVoice.seed(42);
      final second = [for (var i = 0; i < 5; i++) AiroVoice.loading.pick()];
      expect(first, second);
    });

    test('pickWith appends detail on a new line', () {
      AiroVoice.seed(1);
      final headline = AiroVoice.errorGeneric.pick();
      AiroVoice.seed(1);
      final msg = AiroVoice.errorGeneric.pickWith(detail: 'boom');
      expect(msg, '$headline\nboom');
    });

    test('pickWith without detail returns headline only', () {
      final msg = AiroVoice.errorGeneric.pickWith();
      expect(msg.contains('\n'), isFalse);
    });

    test('every pool is non-empty', () {
      for (final pool in [
        AiroVoice.loading,
        AiroVoice.thinking,
        AiroVoice.searching,
        AiroVoice.buffering,
        AiroVoice.errorGeneric,
        AiroVoice.errorNetwork,
        AiroVoice.empty,
      ]) {
        expect(pool.variants, isNotEmpty);
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/core_ui && flutter test test/airo_voice_test.dart`
Expected: FAIL — compile error, `AiroVoice` undefined.

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/core_ui/lib/src/voice/airo_voice.dart
import 'dart:math';

/// A pool of interchangeable message variants for one UI situation.
class MessagePool {
  const MessagePool(this.variants);

  final List<String> variants;

  String pick() => variants[AiroVoice._random.nextInt(variants.length)];

  String pickWith({String? detail}) {
    final headline = pick();
    if (detail == null || detail.isEmpty) return headline;
    return '$headline\n$detail';
  }
}

/// Rotating catalog of modern user-facing status and error messages.
///
/// Mixes three vibes per pool: AI-assistant, playful, and minimal.
/// Internal error plumbing (Failure messages, logs) must NOT use this.
abstract final class AiroVoice {
  static Random _random = Random();

  /// Deterministic picks for tests.
  static void seed(int value) => _random = Random(value);

  static const loading = MessagePool([
    'Thinking…',
    'Warming up…',
    'Summoning pixels…',
    'Reticulating splines…',
    'One sec…',
    'Almost there…',
    'Getting things ready…',
  ]);

  static const thinking = MessagePool([
    'Thinking…',
    'Pondering deeply…',
    'Consulting the neurons…',
    'Crunching thoughts…',
    'One moment of genius…',
    'Working on it…',
  ]);

  static const searching = MessagePool([
    'Scanning the airwaves…',
    'Looking around…',
    'Sniffing out devices…',
    'Casting a wide net…',
    'Searching…',
    'On the hunt…',
  ]);

  static const buffering = MessagePool([
    'Warming up the stream…',
    'Buffering brilliance…',
    'Rolling the tape…',
    'Tuning in…',
    'One sec…',
    'Loading your show…',
  ]);

  static const errorGeneric = MessagePool([
    'Hmm, that didn’t work.',
    'Well, that was unexpected.',
    'Gremlins in the machine.',
    'Something went sideways.',
    'That didn’t go as planned.',
    'Oops — hit a snag.',
  ]);

  static const errorNetwork = MessagePool([
    'The internet blinked.',
    'Lost the signal for a moment.',
    'Network’s being shy.',
    'Can’t reach the mothership.',
    'Connection hiccup.',
  ]);

  static const empty = MessagePool([
    'Nothing here yet.',
    'A blank canvas.',
    'Crickets…',
    'All quiet for now.',
    'Empty — for now.',
  ]);
}
```

Add to `packages/core_ui/lib/core_ui.dart` alongside the other exports:

```dart
export 'src/voice/airo_voice.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/core_ui && flutter test test/airo_voice_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format packages/core_ui/lib/src/voice/airo_voice.dart packages/core_ui/test/airo_voice_test.dart packages/core_ui/lib/core_ui.dart
git add packages/core_ui
git commit -m "feat(core_ui): add AiroVoice rotating message catalog

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: feature_iptv call sites (video player + cast picker)

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart` (~line 508)
- Modify: `packages/feature_iptv/lib/presentation/widgets/cast_device_picker_sheet.dart` (~line 103)
- Test: existing tests under `packages/feature_iptv/test/` that assert the old literals.

**Interfaces:**
- Consumes: `AiroVoice.buffering.pick()`, `AiroVoice.searching.pick()` from Task 1 (`package:core_ui/core_ui.dart`).
- Produces: nothing new.

- [ ] **Step 1: Find tests asserting old literals**

Run: `grep -rn "Loading\.\.\.\|Searching for TVs" packages/feature_iptv/test/`
For each hit, update the assertion to pool membership, e.g.:

```dart
final textWidget = tester.widget<Text>(find.byKey(const Key('...'))); // or find via predicate
expect(AiroVoice.buffering.variants, contains(textWidget.data));
```

Simplest robust pattern when the old test used `find.text('Loading...')`:

```dart
expect(
  find.byWidgetPredicate(
    (w) => w is Text && AiroVoice.buffering.variants.contains(w.data),
  ),
  findsOneWidget,
);
```

- [ ] **Step 2: Run updated tests to verify they fail**

Run: `cd packages/feature_iptv && flutter test test/ -r compact` (scoped to touched test files)
Expected: FAIL — widgets still render old literals.

- [ ] **Step 3: Swap literals in widgets**

`video_player_widget.dart` — the loading container. The enclosing `Column` is `const`; drop `const` down to the smallest scope:

```dart
return Container(
  color: Colors.black,
  child: Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 16),
        Text(
          AiroVoice.buffering.pick(),
          style: const TextStyle(color: Colors.white),
        ),
      ],
    ),
  ),
);
```

`cast_device_picker_sheet.dart` — the searching tile (drop `const` on the tile if present):

```dart
AiroCastDiscoveryPhase.searching => ListTile(
  leading: const SizedBox(
    height: 24,
    width: 24,
    child: CircularProgressIndicator(strokeWidth: 2),
  ),
  title: Text(AiroVoice.searching.pick()),
),
```

Add `import 'package:core_ui/core_ui.dart';` to both files if absent.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd packages/feature_iptv && flutter test`
Expected: PASS, zero regressions (baseline was 118 tests passing).

- [ ] **Step 5: Format and commit**

```bash
dart format packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart packages/feature_iptv/lib/presentation/widgets/cast_device_picker_sheet.dart
git add packages/feature_iptv
git commit -m "feat(feature_iptv): use AiroVoice messages for buffering and cast search

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: app call sites (quest, music, dictionary, offers, settings)

**Files:**
- Modify: `app/lib/features/quest/presentation/screens/quest_chat_screen.dart:290` — `loading: () => const Text('Loading...')` → `loading: () => Text(AiroVoice.loading.pick())`
- Modify: `app/lib/features/music/presentation/screens/music_screen.dart:74,662` — `Text('Error: $err')` → `Text(AiroVoice.errorGeneric.pickWith(detail: '$err'))`
- Modify: `app/lib/features/music/presentation/widgets/beats_search_results.dart:104` — `state.errorMessage ?? 'An error occurred'` → `state.errorMessage ?? AiroVoice.errorGeneric.pick()`
- Modify: `app/lib/core/dictionary/widgets/dictionary_popup.dart:129` — snackbar `Text('Failed to play audio')` → `Text(AiroVoice.errorGeneric.pick())` (drop the `const` on the SnackBar)
- Modify: `app/lib/features/offers/presentation/widgets/offer_card.dart:258` — `Text('Error: $e')` → `Text(AiroVoice.errorGeneric.pickWith(detail: '$e'))`
- Modify: `app/lib/features/settings/presentation/screens/model_detail_screen.dart:424`, `ai_models_screen.dart:378` — `Text('Failed to delete: $e')` → `Text(AiroVoice.errorGeneric.pickWith(detail: '$e'))`
- Modify: `app/lib/features/settings/presentation/screens/intelligent_model_manager_screen.dart:84` — `message: 'Failed to load models: $err'` → `message: AiroVoice.errorGeneric.pickWith(detail: '$err')`
- Test: existing widget tests under `app/test/` asserting old literals (grep-driven).

**Interfaces:**
- Consumes: `AiroVoice.loading.pick()`, `AiroVoice.errorGeneric.pick()`, `AiroVoice.errorGeneric.pickWith(detail:)` from Task 1.
- Produces: nothing new.

- [ ] **Step 1: Find affected tests**

Run: `grep -rn "Loading\.\.\.\|An error occurred\|Failed to play audio\|Error: \$" app/test/ | grep -v goldens`
Update each assertion to pool membership (same predicate pattern as Task 2, using the matching pool). If a test seeds no randomness and needs an exact string, call `AiroVoice.seed(0)` in `setUp` and compute the expected string with a second seeded pick.

- [ ] **Step 2: Run those tests to verify they fail**

Run: `cd app && flutter test <touched test files>`
Expected: FAIL — old literals still rendered.

- [ ] **Step 3: Apply the swaps listed in Files above**

Each file: add `import 'package:core_ui/core_ui.dart';` if absent, remove `const` from the smallest enclosing expression, apply the replacement exactly as listed. Detail-bearing messages keep `$e`/`$err` via `pickWith(detail:)` — never drop the detail.

- [ ] **Step 4: Run app test suite**

Run: `cd app && flutter test`
Expected: PASS except the 3 known pre-existing failures documented in CHANGELOG (do not fix; do not introduce new ones).

- [ ] **Step 5: Format and commit**

```bash
dart format <all touched files>
git add app
git commit -m "feat(app): use AiroVoice messages for user-facing status and errors

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Sweep for stragglers + full verification

**Files:**
- Modify: any remaining user-facing literals found by sweep (judgment per hit).

**Interfaces:**
- Consumes: all `AiroVoice` pools from Task 1.
- Produces: nothing new.

- [ ] **Step 1: Sweep**

Run:
```bash
grep -rn --include="*.dart" -E "Text\(\s*'(Loading|Please wait|Something went wrong|An error occurred)" app/lib packages/*/lib | grep -v _test
```
For each hit decide: user-facing widget → swap to matching pool (loading/errorGeneric); anything feeding logs or `Failure` → leave. TV surfaces (`main_tv.dart` reachable widgets) are in scope — same rules.

- [ ] **Step 2: Full monorepo test run**

Run: `melos run test` (or `flutter test` in `app`, `packages/core_ui`, `packages/feature_iptv` if melos script absent)
Expected: PASS, only the 3 known pre-existing failures.

- [ ] **Step 3: Format, commit**

```bash
dart format <touched files>
git add -A
git commit -m "feat: sweep remaining boring status strings to AiroVoice

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

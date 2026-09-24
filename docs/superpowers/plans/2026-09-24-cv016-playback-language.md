# CV-016 playback language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist in-player subtitle/audio `languageCode` choices and auto-apply them on the next stream; Settings captions On without a saved language still no-ops.

**Architecture:** New `audioPreferenceProvider`; hook `_showTrackSelectorFor` to write prefs; add `_applyAudioPreferenceIfNeeded` beside existing caption apply. No engine or Settings catalog changes.

**Tech Stack:** Riverpod, SharedPreferences, `VideoPlayerWidget`, `FakeAiroPlaybackEngine` tests.

**Design:** `docs/superpowers/specs/2026-09-24-cv016-playback-language-design.md`

## Global Constraints

- Subtitle Off → `clearTrackSelection` only; keep saved caption `languageCode`.
- Subtitle pick with code → `setCaptionPreference(enabled: true, languageCode: code)`.
- Audio pick with code → `setPreferredLanguage(code)` on audio pref.
- Null `languageCode` on track → session-only; no pref write.
- Do not add Accessibility language rows or engine track probing.
- TDD. Commands from `packages/feature_iptv/`. Skip commits unless the user asked.
- Base: `origin/main` after EPG timezone (#2048).

---

## File structure

```
packages/feature_iptv/lib/application/providers/audio_preference_provider.dart     [new]
packages/feature_iptv/test/iptv/application/providers/audio_preference_provider_test.dart [new]
packages/feature_iptv/lib/application/iptv_backup_state_store.dart                   [audio key]
packages/feature_iptv/lib/feature_iptv.dart                                        [export]
packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart            [picker + apply]
packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart [extend]
```

---

### Task 1: `audioPreferenceProvider`

**Files:**
- Create: `packages/feature_iptv/lib/application/providers/audio_preference_provider.dart`
- Create: `packages/feature_iptv/test/iptv/application/providers/audio_preference_provider_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:feature_iptv/application/providers/audio_preference_provider.dart';
import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to no preferred language', () {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(
        SharedPreferences.getInstance() as SharedPreferences, // use async getInstance in real test
      )],
    );
    // Pattern: copy caption_preference_provider_test.dart async setUp
  });
}
```

Mirror `caption_preference_provider_test.dart`: default null; `setPreferredLanguage('eng')` writes `audio_preference_language`; restart container loads value.

- [ ] **Step 2: Run to fail** — `cd packages/feature_iptv && flutter test test/iptv/application/providers/audio_preference_provider_test.dart`

- [ ] **Step 3: Implement**

```dart
const audioPreferenceLanguageStorageKey = 'audio_preference_language';

class AudioPreferenceNotifier extends StateNotifier<String?> {
  AudioPreferenceNotifier(this._ref) : super(null) {
    _loadFromStorage();
  }
  final Ref _ref;

  void setPreferredLanguage(String languageCode) {
    state = languageCode;
    _saveToStorage();
  }

  Future<void> _loadFromStorage() async { /* prefs.getString */ }
  Future<void> _saveToStorage() async { /* prefs.setString */ }
}

final audioPreferenceProvider =
    StateNotifierProvider<AudioPreferenceNotifier, String?>(
      (ref) => AudioPreferenceNotifier(ref),
    );
```

- [ ] **Step 4: Re-run tests** — PASS.

- [ ] **Step 5: Commit** (skip unless asked)

---

### Task 2: Backup + export

**Files:**
- Modify: `packages/feature_iptv/lib/application/iptv_backup_state_store.dart`
- Modify: `packages/feature_iptv/lib/feature_iptv.dart`

- [ ] **Step 1:** Add `'audio_preference_language'` next to caption keys in the backup allowlist.

- [ ] **Step 2:** Export `audio_preference_provider.dart` after `caption_preference_provider.dart`.

- [ ] **Step 3:** `cd packages/feature_iptv && dart analyze lib/application/iptv_backup_state_store.dart lib/feature_iptv.dart`

---

### Task 3: Picker persist + audio apply

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/widgets/video_player_widget_test.dart`

- [ ] **Step 1: Write failing tests**

**Audio auto-apply** (mirror caption test ~1200):

```dart
  testWidgets('auto-applies preferred audio language once tracks are available', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      audioPreferenceLanguageStorageKey: 'de',
    });
    // FakeAiroPlaybackEngine with two audio tracks en + de
    // pump VideoPlayerWidget, playChannel, pump — expect de selected
  });
```

**Picker persist caption** — after opening subtitle sheet and tapping French row, `container.read(captionPreferenceProvider).languageCode == 'fr'` and `enabled == true`.

**Subtitle Off keeps language** — with pref `fr`, tap Off, expect language still `fr`, enabled unchanged.

- [ ] **Step 2: Run widget tests to fail**

- [ ] **Step 3: Implement**

In `_showTrackSelectorFor`:

```dart
onSelect: () {
  if (track.languageCode != null) {
    if (kind == AiroPlaybackTrackKind.subtitle) {
      ref.read(captionPreferenceProvider.notifier).setCaptionPreference(
        enabled: true,
        languageCode: track.languageCode,
      );
    } else if (kind == AiroPlaybackTrackKind.audio) {
      ref.read(audioPreferenceProvider.notifier)
          .setPreferredLanguage(track.languageCode!);
    }
  }
  service.selectTrack(kind: track.kind, trackId: track.id);
},
```

Add `_applyAudioPreferenceIfNeeded` (mirror caption, no enabled gate). Call from the same post-frame callback as `_applyCaptionPreferenceIfNeeded`.

Import `audio_preference_provider.dart`.

- [ ] **Step 4: Re-run** `flutter test test/iptv/presentation/widgets/video_player_widget_test.dart` (focused new tests) + Task 1 tests.

- [ ] **Step 5: Commit** (skip unless asked)

---

### Task 4: Analyze + format

- [ ] `dart format` + `dart analyze` on touched files.
- [ ] Grep Accessibility settings — no language picker added.

---

## Self-review (plan vs spec)

| Spec | Task |
| --- | --- |
| Audio pref store | 1 |
| Backup + export | 2 |
| Picker persist + Off keeps language | 3 |
| Audio apply mirror | 3 |
| Caption apply unchanged | 3 (no gate change) |
| Null languageCode skip | 3 |
| No Settings / engine changes | all |

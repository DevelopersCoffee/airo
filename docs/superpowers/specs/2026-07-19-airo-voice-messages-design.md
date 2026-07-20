# AiroVoice — Modern Status/Error Message Catalog

**Date:** 2026-07-19
**Status:** Approved
**Scope:** User-facing UI strings only (loading states, error screens, snackbars, empty states). Internal `Failure(message:)` strings, logs, and repository error plumbing are explicitly out of scope.

## Problem

User-facing status messages across Airo are boring and inconsistent: `'Loading...'`, `'Error: $err'`, `'Something went wrong'`, `'Failed to play audio'`. Modern AI-era apps use warmer, more characterful language ("Thinking…", "One sec…").

## Goals

- Replace boring user-facing strings with modern, characterful messages.
- Mix of three vibes in one rotation pool: AI-assistant ("Thinking…"), playful ("Reticulating splines…"), minimal ("One sec…").
- Single place to tune tone later.
- Never lose technical error detail — friendly headline, detail preserved.

## Non-Goals

- No l10n/ARB migration.
- No changes to internal error messages, logs, or `Failure` payloads.
- No new dependencies.

## Design

### Component: `AiroVoice`

Location: `packages/core_ui/lib/src/voice/airo_voice.dart`, exported from `core_ui.dart`. Both `app/` and `feature_iptv` already depend on `core_ui`.

```dart
class MessagePool {
  final List<String> variants;
  String pick();                      // random variant
  String pickWith({String? detail});  // "friendly line" or "friendly line\ndetail"
}

abstract final class AiroVoice {
  static void seed(int value);        // deterministic Random for tests
  static final MessagePool loading;       // general loading/spinners
  static final MessagePool thinking;      // AI operations
  static final MessagePool searching;     // discovery (cast devices, search)
  static final MessagePool buffering;     // media buffering
  static final MessagePool errorGeneric;  // generic failure headline
  static final MessagePool errorNetwork;  // network-ish failure headline
  static final MessagePool empty;         // empty states
}
```

Each pool holds ~6–9 variants spanning the three vibes. `pick()` is uniform-random; `seed()` resets the shared `Random` so widget tests are deterministic.

### Call sites

Swap hardcoded user-facing strings to `AiroVoice.<pool>.pick()`:

- `app/lib/features/quest/presentation/screens/quest_chat_screen.dart` — `'Loading...'` → `loading`
- `app/lib/features/music/presentation/screens/music_screen.dart` — `'Error: $err'` → `errorGeneric.pickWith(detail: ...)`
- `app/lib/features/music/presentation/widgets/beats_search_results.dart` — `'An error occurred'` → `errorGeneric`
- `app/lib/core/dictionary/widgets/dictionary_popup.dart` — `'Failed to play audio'` snackbar → `errorGeneric`
- `app/lib/features/offers/presentation/widgets/offer_card.dart` — `'Error: $e'` snackbar → `errorGeneric.pickWith`
- `app/lib/features/settings/...` — user-visible `'Failed to delete: $e'` / `'Failed to load models'` snackbars → `errorGeneric.pickWith`
- `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart` — `'Loading...'` → `buffering`
- `packages/feature_iptv/lib/presentation/widgets/cast_device_picker_sheet.dart` — `'Searching for TVs...'` → `searching`
- Sweep for remaining user-facing `'Loading'` / `'Something went wrong'` strings in widgets (grep-driven, judgment per hit).

### Error handling

`pickWith(detail:)` keeps the technical detail on a second line (or callers keep showing detail separately). Debugging information is never dropped.

### Testing

TDD throughout:

1. Unit tests for `MessagePool`/`AiroVoice`: pick returns from pool, seed determinism, `pickWith` includes detail.
2. Existing widget tests asserting old literals updated — either seed `AiroVoice` and assert exact string, or assert against pool membership.

### Workflow

Feature branch in an isolated git worktree (superpowers:using-git-worktrees). Small commits: catalog first (TDD), then call-site swaps grouped by package/feature.

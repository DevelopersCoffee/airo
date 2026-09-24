# Spec: CV-016 playback language preferences

**Status:** Approved — 2026-09-24 (brainstorming)
**Date:** 2026-09-24
**Product:** Aika Stream (`feature_iptv`)
**Follows:** Slice 1 Accessibility (captions Off/On), resume/sleep/EPG timezone
**Out of this spec:** Engine HLS/container track probing, Settings language catalog, caption appearance

## Objective

When a user picks a subtitle or audio track in Watch, Aika Stream remembers the track's `languageCode` and auto-selects a matching track on the next stream. Settings captions Off/On stays honest: On without a saved language still no-ops until the user picks in-player.

## Locked decisions

| Topic | Decision |
| --- | --- |
| Caption persist | In-player subtitle pick with non-null `languageCode` → `setCaptionPreference(enabled: true, languageCode: …)` |
| Subtitle Off | `clearTrackSelection(subtitle)` only. Saved `languageCode` stays (same as Settings Off). |
| Caption apply | Unchanged: `_applyCaptionPreferenceIfNeeded` requires `enabled && languageCode != null`. Exact code match. |
| Audio persist | New `audioPreferenceProvider` with `languageCode` only (no enabled flag — audio has no Off row). |
| Audio apply | New `_applyAudioPreferenceIfNeeded`: if `languageCode != null`, select first matching `AiroPlaybackTrackKind.audio` track when not already selected. |
| Missing code | Tracks with null `languageCode` are session-only — do not persist. |
| Settings UI | No change to `AccessibilitySettingsSection` — no language picker, status readout stays. |
| Engine catalog | No change to `platform_media` engines in this slice. Audio auto-apply is a no-op on live IPTV until tracks appear. |
| Storage | `SharedPreferences` via existing `sharedPreferencesProvider`. Register audio key in backup store. |
| Layer | Providers in `feature_iptv`. Wire persist in `video_player_widget.dart` `_showTrackSelectorFor`. |

## Non-goals

- World language catalog or Accessibility language rows.
- Persist track id or display label when `languageCode` is null.
- Subtitle Off clears saved language or sets `enabled: false`.
- HLS/container audio/subtitle discovery (`video_player_airo_playback_engine`, `mpv_airo_playback_engine`).
- VOD seek/timeline (other CV-016 items).
- Caption size/color (P3 after this).

## Why this shape

Slice 1 shipped caption Off/On and apply logic, but nothing writes `languageCode` from the in-player picker — so auto-apply never runs. Wiring picker → prefs closes that gap without inventing a Settings catalog. Audio gets the same contract so when engines grow track lists, prefs already exist.

## Architecture

```text
In-player track sheet (_showTrackSelectorFor)
  subtitle pick + languageCode → captionPreferenceProvider
  subtitle Off → clearTrackSelection only
  audio pick + languageCode → audioPreferenceProvider

On stream / tracks update (post-frame):
  _applyCaptionPreferenceIfNeeded (existing)
  _applyAudioPreferenceIfNeeded (new)
        │
        ▼
  service.selectTrack when catalog has exact languageCode match
```

## Components

### `audioPreferenceProvider`

Sibling of `caption_preference_provider.dart`.

- State: `String? languageCode` (null = no preference).
- `setPreferredLanguage(String languageCode)` — persist non-null code.
- Storage key: `audio_preference_language`.
- Load on construct; save on mutate.

### Picker hooks

In `_showTrackSelectorFor`:

- Subtitle **Off** `onSelect`: `service.clearTrackSelection(kind)` only.
- Track **onSelect**: if `track.languageCode != null`, write the appropriate pref, then `service.selectTrack`.

### Apply helpers

- Caption: existing gate unchanged.
- Audio: mirror caption loop for `AiroPlaybackTrackKind.audio`; no enabled gate.

## Runtime flow

1. User enables captions in Settings, opens Watch, picks English subs → `languageCode` `eng` saved, track selected.
2. User changes channel; new stream exposes `eng` subs → auto-selected.
3. User picks subtitle Off → captions off for session; `eng` still saved; Settings still shows "Saved language: eng".
4. User picks Spanish audio with code `spa` → saved; next VOD/test stream with `spa` audio auto-selects.
5. Live IPTV with empty `state.tracks` audio list → audio apply no-ops (unchanged UX).

## Error handling

| Case | Result |
| --- | --- |
| Enabled captions, no saved language | Apply no-ops (unchanged) |
| Saved language, no matching track | No selection; no fallback language |
| Track pick with null `languageCode` | selectTrack only; no pref write |
| Prefs load/save failure | Swallow; keep in-memory default (existing caption pattern) |

## Testing

TDD in `packages/feature_iptv`:

- `audio_preference_provider_test.dart`: default null, set/load round-trip.
- Extend or add widget/unit tests: picker subtitle pick writes caption pref; Off does not clear language; audio pick writes audio pref; `_applyAudioPreferenceIfNeeded` selects matching track when injected state has audio tracks.

Use `FakeAiroPlaybackEngine` / existing player test patterns where full widget pump is heavy.

## Files (expected)

- Create: `lib/application/providers/audio_preference_provider.dart` + test
- Modify: `lib/presentation/widgets/video_player_widget.dart`
- Modify: `lib/application/iptv_backup_state_store.dart`
- Modify: `lib/feature_iptv.dart` (export)
- Optional: extend `test/caption_preference_provider_test.dart` only if new caption API added (prefer reusing `setCaptionPreference`)

## Success

A user picks English subtitles once; every later stream with an `eng` subtitle track enables them automatically when Settings captions are On. Accessibility still says "pick one in the player" until they do. Audio preference is stored and applies when the engine reports matching tracks.

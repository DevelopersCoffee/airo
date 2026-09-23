# Spec: Resume last live channel on TV launch

**Status:** Approved — 2026-09-23 (brainstorming: goal, runtime, failures)
**Date:** 2026-09-23
**Product:** Aika Stream (`feature_iptv`; TV flavor `app/pubspec_tv.yaml` / `main_tv.dart`)
**Follows:** `docs/superpowers/specs/2026-07-22-airo-tv-ux-design.md` (Resume flow Phase 1) and Slice 1 settings (`docs/designs/aika-stream-settings.md`)
**Out of this spec:** sleep timer, CV-016 caption/audio language, Library live peek

## Objective

On a Fire TV / Android TV cold start, if a last live channel is stored and resume is enabled, hold the existing branded splash until resume is terminal, then open fullscreen Watch on that channel — the same surface a Library tile tap already uses. Back from Watch returns to Library. Users can turn the behavior off in Playback settings.

## Locked decisions

| Topic | Decision |
| --- | --- |
| Slice | Resume last live channel on TV launch + a Playback toggle. Sleep timer is a later spec. |
| Existing stack | Keep `LastChannelRecorder`, `resumeChannelProvider`, `ResumeLastChannelController`, `IptvResumeGate`, `IptvResumeSplash`. Do not add a second gate. |
| Root cause | Ten-foot `IPTVScreen` already wraps `IptvResumeGate`. Tile taps call `_playChannelFullscreen`. Resume calls `playChannelDelegate` (`playChannel` only), so TV can tune while staying on Library. Splash max 2s can also reveal Library while lookup is still `idle`. Fullscreen is an early return in `IPTVScreen`, so entering Watch unmounts the gate. |
| Approach | A — defer Watch until splash dismisses. `playChannel` stays behind the splash. `isFullscreenModeProvider` is set as the splash goes away. |
| Toggle home | IPTV Playback (phone `PlaybackSettingsScreen`, TV `TvPlaybackSection`). Not Privacy. Not the music "Auto Resume" tile in `audio_settings_screen.dart`. |
| Default | ON |
| Persistence | Local `SharedPreferences` only. Key: `iptv_resume_last_channel_enabled`. No cloud sync. |
| Recorder | Always writes `iptv_last_channel` on tune, even when autoplay is off, so turning the toggle back on still has a target. |
| Pref off / deep-link | Gate `enabled: false`. No splash, no `attemptResume`. Deep-link path already passes `enabled: widget.effectiveDeepLinkChannelId == null`; AND the pref. |
| Phone compact | Same pref and same gate enablement. Splash timing on phone stays 0.5–2s. Phone does not enter ten-foot Watch as a post-splash step. |
| TV splash hold | Keep `IptvResumeSplash` mounted until resume is terminal (`noTarget` / `failed` / `done`). Do not let the 2s cap reveal Library while still `idle` or `tuning`. |
| Success landing | `ResumeStatus.done` → set `isFullscreenModeProvider` true (same Watch as `_playChannelFullscreen`). Play has already started. |
| Failure | Silent Library. No toast. No Retry. Watch is not entered. |
| Live edge | Same channel, never a timeshift position (existing Phase 1 rule). |
| Session | Controller `_attempted` stays once-per-provider-lifetime. No re-resume when leaving Settings or switching rail destinations in the same process. |
| Copy | Title: `Resume last channel`. Subtitle: `Open the last live channel when Aika Stream starts.` |
| Settings platform | No new section in `iptvSettingsSections`. Add a row inside existing Playback. |

## Non-goals

- Sleep timer UI, expiry stopping playback, or a TV cancel FAB.
- New splash art, mosaic, or copy on `IptvResumeSplash`.
- Preferred audio/caption language (CV-016).
- Cloud-synced settings, parental PIN, ads opt-out.
- Changing `playChannelDelegate` globally to go fullscreen (would alter phone compact resume).
- A dedicated `TvResumeGate` or lifting the gate above the fullscreen early-return (Approach B / C).
- Resume from timeshift / VOD watch-progress.
- Wiki unless a later plan or CI docs-completeness check requires it.

## Why this shape

Phase 1 already shipped persist + splash + one-shot tune for `IPTVScreen`. The sofa gap is not "build resume". It is "TV browse is grid-first, Watch is a separate fullscreen early-return, and resume never asks for that early-return."

Deferring fullscreen until splash dismisses keeps the gate mounted for the whole hold. Entering Watch at tune-start would unmount the splash (Approach B's problem). A TV-only duplicate helper (Approach C) would fork phone/TV splash policy for no gain.

## Approaches considered

1. **Defer Watch until splash dismisses** — chosen. Smallest change to the existing gate. TV hold-until-terminal closes the Library flash.
2. **Lift the gate above the fullscreen early-return** — splash could cover Watch itself; larger `IPTVScreen` restructure, higher chance of focus/back bugs. Rejected for this slice.
3. **New TV-only resume helper calling `_playChannelFullscreen`** — duplicates gate/splash, still has to solve the unmount-during-hold problem. Rejected.

## Architecture

```text
IPTVScreen (tenFootMode)
  browse scaffold
    IptvResumeGate(
      enabled: noDeepLink && resumeLastChannelEnabled,
      holdUntilTerminal: true,          // TV only
      onEnterWatch: () => fullscreen,   // TV only, once, on done
      child: AiroTvShell / Library
    )
  fullscreen early-return
    VideoPlayerWidget (Watch)
      Back → Library (existing _exitFullscreen)

LastChannelRecorder ──always──► iptv_last_channel
resumeLastChannelEnabledProvider ──local bool, default true──► gate.enabled
ResumeLastChannelController.attemptResume()
  playChannelDelegate → iptvStreamingService.playChannel   (unchanged)
```

`playChannelDelegateProvider` stays a play-only seam. Fullscreen is a presentation callback on the gate, wired by `IPTVScreen` on the ten-foot path only.

## Components

### `resumeLastChannelEnabledProvider`

New notifier next to `tvFontModeProvider` / `last_channel_provider.dart` (same `sharedPreferencesProvider` + `StateNotifier` pattern).

- `bool`, default `true` when the key is missing or unreadable.
- `setEnabled(bool)` writes immediately; load failures keep the default.
- Watched by `IptvResumeGate` (or by `IPTVScreen` when computing `enabled`).

Do not put this in `app/`. It is an IPTV playback preference consumed by `feature_iptv`.

### `IptvResumeGate`

Keep the widget. Add:

- `holdUntilTerminal` (default `false` — phone). When true, ignore splash `onFinished` for overlay teardown until `ResumeStatus` is `noTarget`, `failed`, or `done`. The splash visual can still skip on key/tap; skipping on TV with `done` still enters Watch.
- `onEnterWatch` (`VoidCallback?`). Invoked at most once, and only from the overlay dismiss path when `ResumeStatus` is already `done`. Never invoked for `noTarget` / `failed` / `enabled: false`. If the overlay dismissed while still `idle` or `tuning`, a later `done` must not call it.

Existing `enabled: false` behavior stays: child only, no `attemptResume`, no splash.

### `IPTVScreen` ten-foot branch

```text
IptvResumeGate(
  enabled: effectiveDeepLinkChannelId == null && resumeEnabled,
  holdUntilTerminal: true,
  onEnterWatch: () {
    if (!mounted) return;
    ref.read(isFullscreenModeProvider.notifier).state = true;
  },
  child: _StreamTabContent(onChannelTap: _playChannelFullscreen, ...),
)
```

Do not call `_playChannelFullscreen` from `onEnterWatch` — that would `playChannel` a second time. Playback already started via the delegate.

Phone compact branch: pass the pref into `enabled` only. Do not pass `holdUntilTerminal` or `onEnterWatch`.

### Playback settings rows

- Phone: `SwitchListTile` on `PlaybackSettingsScreen`, after aspect ratio / before PiP (or immediately after the aspect-ratio group). Key: `ValueKey('playback-resume-last-channel-toggle')`.
- TV: `TvFocusable` switch row at the top of `TvPlaybackSection` (before aspect-ratio options so autofocus lands on the toggle, or keep aspect autofocus and put resume after extras — **autofocus stays on the first aspect option** so existing TV playback tests do not retarget; resume is the row after the aspect list, before `playbackSettingsExtraSectionsProvider`).
- Do not inject via `playbackSettingsExtraSectionsProvider` (that slot is airo-pro).

## Runtime flow

1. TV process starts `/live` with no deep-link. Pref on. Last id stored.
2. Gate mounts, splash covers Library (Library is built underneath; splash is opaque).
3. `attemptResume` looks up the channel (10s timeout). Status `tuning` → `playChannel`.
4. Splash stays until status is terminal. Skip/key/tap can finish the visual early; if status is already `done`, Watch opens. If still `idle`/`tuning`, stay on splash until terminal unless the user skipped **and** we treat skip as "show Library now".
5. **Skip while still tuning:** reveal Library (fail-open to browse), do **not** enter Watch later when `done` arrives. Rationale: skip means "I want browse". The in-flight `playChannel` may still start audio; that is existing Phase 1 skip behavior and is acceptable. Do not add a cancel-tune in this slice.
6. Terminal `done` + overlay dismissing → `onEnterWatch` → Watch.
7. Terminal `noTarget` / `failed` → splash gone, Library, no callback.
8. Pref off or deep-link: step 2 never happens.

## Error handling

| Case | Result |
| --- | --- |
| No stored id | `noTarget`, Library, no splash hold (existing test) |
| Id not in playlist | `noTarget`, Library |
| Lookup > 10s | `failed`, Library |
| `playChannel` throws | `failed`, Library |
| Pref off | No attempt, Library |
| Deep-link channel id set | No attempt; existing deep-link play path |
| SharedPreferences read/write fails | Pref defaults ON; recorder already swallows persist errors |

No toast. No retry loop behind the splash (existing bounded-failover rule).

## Testing

TDD in `packages/feature_iptv`. Narrow `flutter test` on the files below. No full matrix.

- Provider: default true; `setEnabled(false)` persists across a new container; missing key → true.
- Gate: `enabled: false` still does not call `attemptResume` (existing).
- Gate: pref override false ⇒ no splash, child visible, delegate not called (if the gate watches the pref itself).
- Gate `holdUntilTerminal: true`: after 2s with status still `idle`/`tuning`, splash still mounted and child not the hit target.
- Gate: `onEnterWatch` called once on `done` + splash dismiss; never on `noTarget` / `failed` / skip-before-done.
- Existing splash tests stay green with default `holdUntilTerminal: false`.
- `TvPlaybackSection` and `PlaybackSettingsScreen`: row visible, toggling updates the provider.
- Do not add a Fire TV integration test in this slice; qualify on device after merge.

## Files (expected)

- Create: `packages/feature_iptv/lib/application/providers/resume_last_channel_preference.dart` (or colocate in `last_channel_provider.dart` if the extra file is noise — prefer a sibling file so last-channel lookup stays about identity, not a user toggle).
- Create: matching `*_test.dart`.
- Modify: `iptv_resume_gate.dart` + `iptv_resume_gate_test.dart`.
- Modify: `iptv_screen.dart` (ten-foot `enabled` + new kwargs; phone `enabled` AND pref).
- Modify: `playback_settings_screen.dart` + test; `tv_playback_section.dart` + `tv_playback_section_test.dart`.
- Export from `packages/feature_iptv/lib/feature_iptv.dart` only if settings screens already import the barrel for sibling prefs.

## Success

A returning Fire TV user with the toggle on lands in Watch on last night's channel without seeing Library first. Turning the toggle off opens Library immediately. A missing/dead last channel never traps the splash and never toasts.

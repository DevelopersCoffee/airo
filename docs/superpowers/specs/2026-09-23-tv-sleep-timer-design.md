# Spec: Sleep timer on TV

**Status:** Approved — 2026-09-23 (brainstorming: goal, runtime, failures)
**Date:** 2026-09-23
**Product:** Aika Stream (`feature_iptv`; TV flavor `app/pubspec_tv.yaml` / `main_tv.dart`)
**Follows:** Slice 1 settings and resume-on-TV (`docs/superpowers/specs/2026-09-23-tv-resume-last-channel-design.md`)
**Out of this spec:** CV-016, Library live peek, bedtime mode, music/reader sleep

## Objective

A sofa user can arm a session sleep timer from Playback Settings (Off / 15 / 30 / 45 / 60 minutes) and see remaining time / cancel it on Watch. When it fires, live playback stops, Watch closes, Library is showing, and the app stays open.

## Locked decisions

| Topic | Decision |
| --- | --- |
| Expire | Stop the stream (`iptvStreamingService.stop()`), set `isFullscreenModeProvider` false, remaining `0`. Land on Library. App stays open. |
| Not expire | Pause on Watch, black ended frame, background/exit the app, fade volume. |
| Set from | Playback Settings presets **and** a Watch remaining chip (cancel). |
| Presets | Off, 15, 30, 45, 60 minutes. No custom minutes picker. |
| Persistence | Session only. Process death clears the timer. Do not auto-arm on next launch (would fight resume-last-channel). |
| Layer | New provider in `feature_iptv`. Do **not** reuse `app/lib/core/providers/bedtime_mode_provider.dart` `sleepTimerProvider` (app-layer, expire TODO never stops IPTV, phone `AppShell` FAB only). |
| Phone | Same presets on `PlaybackSettingsScreen`. Do not replace or wire the existing phone FAB / bedtime mode. |
| Watch chip | Visible when remaining `> 0` **and** the TV transport bar is visible. Label `Sleep in N min`. Select/tap cancels. Hidden with the transport, not a permanent HUD. |
| Replace | Arming 30 while 15 remains replaces the timer. No stacking. |
| Copy | Title: `Sleep timer`. Subtitle: `Stop playback and return to Library after this time.` |
| Settings platform | No new `iptvSettingsSections` id. Rows inside existing Playback, after Resume last channel. Autofocus stays on the first aspect option. |
| Tick | One-minute `Timer.periodic`. Remaining is whole minutes (same as the unused app notifier). |

## Non-goals

- Custom minute entry.
- Remembering last duration or auto-arming on launch.
- Volume fade, lock screen, or process kill.
- Sleep for music, reader, or Cast-only sessions (local IPTV Watch / ten-foot player only).
- Changing `bedtimeModeProvider` (22:00–06:00 auto flag).
- Wiki unless a later plan or CI docs-completeness check requires it.

## Why this shape

The unused `sleepTimerProvider` cannot be consumed from `feature_iptv` (framework/application boundary: IPTV screens do not import `app/`). Its expire path is a TODO. Putting the timer next to playback in `feature_iptv` lets expire call `stop()` and leave Watch without an app-layer wrapper.

Session-only avoids a next-day Fire TV launch that resumes last night's channel and then dies after 30 minutes with no new consent.

## Approaches considered

1. **New `feature_iptv` session timer** — chosen.
2. **Reuse `app` `sleepTimerProvider`** — rejected: wrong layer, expire does not stop IPTV, TV shell never mounts `AppShell`.
3. **Watch menu only** — rejected: user also wanted Playback presets.

## Architecture

```text
Playback Settings (phone + TV)
        │ setMinutes(15|30|45|60) / cancel
        ▼
 sleepTimerRemainingProvider  (int minutes, 0 = off)
        │ 1-minute tick
        │ remaining hits 0
        ▼
 expire once:
   iptvStreamingService.stop()
   isFullscreenModeProvider = false

Watch (ten-foot VideoPlayerWidget, transport visible)
   chip "Sleep in N min" → cancel()
```

## Components

### `sleepTimerRemainingProvider`

Sibling of `resume_last_channel_preference.dart`.

- State: `int` remaining minutes. `0` means off.
- `setMinutes(int minutes)` — if `minutes` not in `{15,30,45,60}`, treat as cancel (`0`). Cancel existing tick first. Start a new periodic timer.
- `cancel()` — cancel tick, state `0`. No stop/leave-Watch side effect.
- Tick: injectable `sleepTimerTickProvider` (`Duration`, default 1 minute) so tests do not wait a real minute.
- On remaining reaching `0` from the tick (not from `cancel`): call a `SleepTimerExpire` callback/provider once.
- `dispose` cancels the tick.

Expire seam (testable, no widget):

```text
final sleepTimerExpireDelegateProvider =
    Provider<Future<void> Function()>((ref) {
  return () async {
    await ref.read(iptvStreamingServiceProvider).stop();
    ref.read(isFullscreenModeProvider.notifier).state = false;
  };
});
```

`stop()` when already idle is a no-op. Still clear fullscreen so Watch cannot stick.

Do not persist to `SharedPreferences`.

### Playback rows

- **TV** `TvPlaybackSection`: after the Resume last channel row, a `Sleep timer` heading plus five `TvFocusable` options (Off / 15 minutes / 30 minutes / 45 minutes / 60 minutes). Selected option matches remaining if it is an exact preset, else Off when remaining is 0. Selecting Off calls `cancel()`. Autofocus remains on the first aspect-ratio option.
- **Phone** `PlaybackSettingsScreen`: same five choices (radio or list tiles), key `ValueKey('playback-sleep-timer-<n>')` for Off=`0`. After the resume toggle.

### Watch chip

In `video_player_widget.dart` when `useTvTransportBar && remaining > 0` and the transport overlay is showing: `TvFocusable` chip `Sleep in $n min`. `onSelect` → `cancel()`. Do not show on the phone/touch transport in this slice (`useTvTransportBar` is the ten-foot signal).

## Runtime flow

1. User picks 30 in Playback (or from Watch after we only expose cancel there — arming is Settings). Timer state 30, tick starts.
2. Watch transport up: chip `Sleep in 30 min` … `Sleep in 1 min`. Arming is Playback only; Watch is remaining + cancel.
3. User selects the chip: cancel, remaining 0, playback continues, Watch stays.
4. Tick hits 0: `stop()`, fullscreen false, Library. Chip gone.
5. User picks 30 then 15: remaining becomes 15, one tick, previous tick cancelled.
6. App killed: next launch remaining 0. Resume-last-channel may still open Watch.

## Error handling

| Case | Result |
| --- | --- |
| Expire with no current channel | `stop()` anyway; leave Watch if fullscreen |
| Expire twice | Delegate runs once per arming (guard after hitting 0) |
| `stop()` throws | Swallow; still set remaining 0 and leave Watch |
| Remaining 0 and user taps Off | No-op |
| Process death | Timer gone |

No toast on expire (Library appearing is the signal). No retry.

## Testing

TDD in `packages/feature_iptv`. Narrow `flutter test`.

- Notifier: default 0; `setMinutes(30)` then fake tick → 29; `setMinutes(15)` replaces; `cancel()` → 0 without calling expire; tick to 0 calls expire delegate once; `setMinutes(7)` (invalid) → 0.
- Playback phone + TV: selecting 30 writes the provider; Off cancels.
- Watch chip: with `useTvTransportBar: true` and remaining 12, chip text present when transport visible; `cancel` clears remaining. Not present when remaining 0.

Prove expire leaves fullscreen with a unit test on the delegate (override `iptvStreamingService` + `isFullscreenModeProvider`), not a full `IPTVScreen` pump.

## Files (expected)

- Create: `packages/feature_iptv/lib/application/providers/sleep_timer_provider.dart` + test.
- Modify: `playback_settings_screen.dart` + test; `tv_playback_section.dart` + test; `video_player_widget.dart` (TV transport overlay) + existing TV transport test or a focused chip test.
- Export from `feature_iptv.dart`.
- Do not modify `app/lib/core/providers/bedtime_mode_provider.dart` or `app_shell.dart`.

## Success

A Fire TV user sets 30 minutes in Playback, watches, sees the chip when they bring up transport, and after 30 minutes is on Library with no stream running. Cancel from the chip keeps Watch playing. Next cold start does not inherit the timer.

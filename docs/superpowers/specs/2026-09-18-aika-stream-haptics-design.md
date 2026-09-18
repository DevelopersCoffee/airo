# Spec: Aika Stream haptic consumption (airo_haptics 1.1.0)

**Status:** Approved — 2026-09-18 (architecture, components, runtime)
**Date:** 2026-09-18
**Product:** Aika Stream (`feature_iptv`, flavors `app/pubspec.yaml` and `app/pubspec_tv.yaml`)
**Engine:** `airo_haptics` 1.1.0 via monorepo shim `platform_haptics`
**Base:** `origin/main` after `airo_haptics` 1.1.0 and `platform_haptics` are on that line
**Worktree:** `../airo-worktrees/<issue>-aika-stream-haptics`
**Branch:** `agent/tv/<issue>-aika-stream-haptics`

## Objective

Give Aika Stream tactile feedback on devices that have a motor: the phone/tablet player chrome, and the phone Cast remote that already controls Chromecast / Google TV. TV and Fire TV stay silent. Application code speaks product intents; it never imports the engine package or the copy-paste `HapticIntent` API.

## Locked decisions

| Topic | Decision |
| --- | --- |
| Slice | Phone/tablet player chrome + Cast remote only |
| Not in slice | Software D-pad, `core_remote_control` pairing, brightness/scrub envelopes, library/source sheets, settings UI |
| Consumption | Application mapper `AikaHaptics` in `feature_iptv` over `platform_haptics` |
| Direct engine import | Forbidden in `feature_iptv` lib (tests may use `package:platform_haptics/testing.dart`) |
| App pubspecs | No new direct dependency; plugin arrives transitively through `feature_iptv` → `platform_haptics` → `airo_haptics` |
| Profile | `AiroHapticProfile.media` while a Cast session is attached |
| Cast session fence | `AiroHapticSession` started on live Cast attach, disposed on disconnect; semantic plays still go through `AiroHaptics.*` because 1.1.0 sessions only play patterns |
| Hydrated Cast | Attach session, no `castConnected` haptic (same rule as the existing “Playing on …” banner) |
| Settings screen | None in this slice. Engine default `enabled: true`. No-op when `capabilities.supported == false` |
| Prompt API | Do not use `HapticIntent`, `AiroHaptics.play(intent)`, `createPlayer(intensity:)`, or profiles `subtle` / `accessible` / `raw`. Those are not 1.1.0 |

## Non-goals

- Calling `AiroHaptics` from widgets.
- Adding `airo_haptics` to `app/pubspec.yaml` or `app/pubspec_tv.yaml`.
- `core_ui` haptic InkWell / focus wrappers.
- AHAP files, ADSR envelopes, `playContinuous`, `dpadMove`, `scrub`.
- A user-facing haptic toggle.
- Making Fire TV or Android TV vibrate.

## Why this shape

`airo_haptics` 1.1.0 already lives in this workspace on `agent/anya/1991-gguf-plan-repair` and is **not** on `origin/main`. `platform_haptics` is the council-facing shim (re-export only). `feature_iptv` has zero haptic call sites. Aika Stream’s real phone-as-remote is `IptvCastMiniController` (play/pause/stop/volume/mute), not a D-pad protocol.

Framework owns the engine. Application owns the journey map. That is the `AikaHaptics` mapper.

## Approaches considered

1. **Application mapper over `platform_haptics`** — chosen.
2. **Call `AiroHaptics` from player and Cast widgets** — rejected: leaks engine types, duplicates profile/throttle choices.
3. **Generic haptic widgets in `core_ui`** — rejected for this slice: favorite, error, and Cast connect would all feel like `selection`.

## Architecture

```text
player chrome / Cast remote
        │
        ▼
 AikaHaptics (feature_iptv application)
   AikaHapticIntent → AiroHaptics.*
        │
        ▼
 platform_haptics → airo_haptics 1.1.0
        │
        ▼
 native no-op when hasVibrator() is false (TV / Fire TV / web)
```

Council contract: add `platform_haptics` to `packages/feature_iptv/module.yaml` `allowed_dependencies` and to `packages/feature_iptv/pubspec.yaml`. `scripts/check-module-manifests.py` fails if the pubspec path dep is missing from the manifest.

`feature_iptv` must not depend on `airo_haptics` directly. Widen `platform_haptics` with `lib/testing.dart` that re-exports `package:airo_haptics/testing.dart`.

## Components

### `AikaHapticIntent`

Closed set for this slice:

| Intent | When | Engine call |
| --- | --- | --- |
| `playPause` | Local or Cast play/pause (including Cast reload-from-stopped) | `AiroHaptics.selection()` |
| `channelStep` | Next/previous channel actually starts | `AiroHaptics.navigation()` |
| `favoriteOn` / `favoriteOff` | After `toggleFavorite` returns | `toggleOn()` / `toggleOff()` |
| `error` | Local playback `hasError` false→true; Cast `failed` false→true | `AiroHaptics.error()` |
| `castConnected` | First live Cast connect, not hydrated resume | `AiroHaptics.success()` |
| `volumeTick` | Cast volume slider `onChanged` or pad ±0.1 | `AiroHaptics.sliderStep()` |
| `mute` | Cast mute (`setVolume(0)`) | `AiroHaptics.selection()` |
| `stop` | Cast stop | `AiroHaptics.medium()` |

No other intents.

### `AikaHaptics`

Abstract service + `EngineAikaHaptics` implementation + Riverpod `aikaHapticsProvider`.

```text
play(AikaHapticIntent intent)     // fire-and-forget; never throws to UI
attachCastSession({required id})  // idempotent per id; sets media profile; startSession
detachCastSession()               // dispose session, AiroHaptics.stopAll(), idempotent
```

`play` swallows plugin/platform errors. Unsupported hardware is already a skip inside the engine resolver.

Cast attach is a lifecycle fence (`stopAll` on detach) plus `AiroHapticProfile.media`. Semantic intents still call the facade; 1.1.0 `AiroHapticSession` only plays patterns.

Provider `onDispose` calls `detachCastSession()`.

### Call sites

Only these two files:

1. `packages/feature_iptv/lib/presentation/widgets/video_player_widget.dart`
   - `togglePlayPause` → `playPause`
   - `_goToNextChannel` / `_goToPreviousChannel` after a channel is actually selected → `channelStep`
   - `_toggleFavoriteForCurrentChannel` after `isNowFavorite` → `favoriteOn` / `favoriteOff`
   - `ref.listen` on streaming state: `hasError` false→true → `error` (once per failure, not per frame)
2. `packages/feature_iptv/lib/presentation/widgets/iptv_cast_mini_controller.dart`
   - Same connect transition as the “Playing on …” banner → `attachCastSession` + `castConnected`
   - Hydrated session at mount → `attachCastSession` only
   - Disconnect / session drop → `detachCastSession`
   - Play/pause/reload, stop, mute, volume slider/steps → matching intents
   - Session phase `failed` false→true → `error`

Favorite haptic follows storage result, not the tap. Channel haptic does not fire when next/prev is null.

Do not sprinkle haptics into `browse_screen`, TV favorites, or `channelFavoriteTogglerProvider`. Those are out of this slice even though they toggle favorites.

## Data flow

**Local player.** User taps chrome → widget calls `ref.read(aikaHapticsProvider).play(...)`. Channel change only if `nextSelectableChannelProvider` / `previousSelectableChannelProvider` yields a channel.

**Cast remote.** `IptvCastMiniController` already distinguishes hydrated vs live connect. Reuse that flag: live connect attaches and plays `castConnected`; recovered session only attaches. Volume uses `sliderStep` so the engine coalesces (~16 ms). IPTV does not add a second debounce.

**Always no-op.** `capabilities.supported == false`, engine `enabled: false`, missing vibrator. `play` never blocks playback.

## Error handling

- Mapper `try/catch` around every engine call.
- Player error haptic on the rising edge of `hasError` only.
- Cast error haptic on the rising edge of `AiroCastSessionPhase.failed` only.
- `attachCastSession` twice with the same id is a no-op. Different id detaches then attaches.
- `detachCastSession` is safe if nothing is attached.
- Widget disposed while `play` is in flight: `unawaited`; no `setState`.

## Testing

| Layer | How |
| --- | --- |
| `EngineAikaHaptics` | `FakeAiroHapticPlatform` + `expectHapticPlayed` / impact assertions. `fake_async` for `volumeTick` coalesce. Unsupported capabilities → no invocations. Throwing platform → `play` does not throw |
| Cast widget | Override `aikaHapticsProvider` with a recording fake. Assert live connect vs hydrated. Assert play/stop/volume/mute intents |
| Player widget | Same recording fake on an existing `VideoPlayerWidget` pump helper. Assert play/pause, channel step, favorite on/off |

Do not hit the real plugin in widget tests.

## Verification (devices)

| Surface | What to prove |
| --- | --- |
| Pixel 9 (or any phone with a motor) | Local play/pause, channel next/prev, favorite on/off, playback error; Cast connect/play/pause/stop/volume/mute/error |
| Fire TV Stick | Silence, no crash, no unexpected 50 ms buzz |
| Host | `cd packages/feature_iptv && flutter test` (narrowed to new tests plus the two widget files’ existing suites) |

Simulators are not the rig for “does it feel right,” but host tests prove the contract.

## Worktree / landing order

`origin/main` does not contain `packages/airo_haptics`. Those commits currently sit on `agent/anya/1991-gguf-plan-repair`:

- `66b0da56` `feat(airo_haptics): consolidate standalone federated haptics engine v1.0.0`
- `6516092c` `feat(airo_haptics): release v1.1.0 engine upgrades ...`

Do **not** base the haptic-consumption worktree on that GGUF branch. Land (or cherry-pick only) the haptics commits onto `origin/main` first, then:

```bash
git fetch origin main
git worktree add ../airo-worktrees/<issue>-aika-stream-haptics \
  -b agent/tv/<issue>-aika-stream-haptics origin/main
```

Open a parent GitHub issue before implementation (`AGENT_POLICY.md`).

## Package asks for the `airo_haptics` agent

Needed for this slice to behave correctly in production; not blockers for writing the mapper against 1.1.0:

1. **`respectSystemSettings` is unused.** `AiroHapticResolver` never reads the flag. Honor OS haptic-off and Reduce Motion in the plugin/resolver, or document that the app must set `reducedMotion` / `enabled` itself.
2. **Android TV / Fire TV hard no-op.** `hasVibrator()` is the current gate. Confirm Leanback / `FEATURE_TELEVISION` never takes a stub vibrator path that buzzes or throws.
3. **Do not add the prompt aliases** (`HapticIntent`, `play(intent)`, `createPlayer(intensity:, sharpness:)`, profiles `subtle` / `accessible` / `raw`) unless the public API is deliberately dual. Aika Stream will not consume a second dialect.

Not needed for this slice: widget helpers, AHAP presets, audio-sync, Riverpod inside the engine, settings persistence, `dpadMove` upgrades.

## Ownership and review

| Role | Why |
| --- | --- |
| Media Intelligence Architect | `feature_iptv` owner |
| Platform Architect / platform_core | `platform_haptics` / `airo_haptics` |
| Chief Architect | New allowed dependency, layer rule |
| Chief QA Officer | User-visible + widget tests |
| Chief UX Officer | Cast remote + player chrome feel |
| TV Experience Architect | Confirm TV remains silent; no D-pad scope |

## Rollback

Remove the two widget call sites and `aikaHapticsProvider` overrides. Engine stays in the workspace unused. No schema, no settings key, no migration.

## Success

- Phone feels play/pause, channel step, favorite on/off, error, and Cast remote ticks.
- Hydrated Cast does not success-buzz on app start.
- Fire TV is silent and does not crash.
- `feature_iptv` lib has zero `package:airo_haptics/` imports.
- Mapper tests fail if someone wires `HapticIntent` that does not exist.

# Device-Aware Playback Engine — Design

**Date:** 2026-07-17
**Status:** Approved (brainstorm) → pending implementation plan
**Owner package:** `platform_player` (+ `platform_media` for engine impls)
**Reviewers:** playback-architect (owner), chief-performance-officer, chief-qa-officer

## Problem

Airo runs one all-in-one app across platforms with wildly different resources:
battery-operated phones, low-CPU/low-RAM Android TV boxes, GPU-capable web/Chrome,
and desktop (Windows/Linux). Playback is the single point of failure — if the player
stalls or can't decode, the whole product fails. We want lag-free, low-power,
hardware-accelerated playback on each device class, with resilience (never get stuck)
and minimal maintenance overhead (few engines, not many).

## Goals

- Native, hardware-accelerated playback as the default on every platform that has it.
- Resilient: a codec/decoder failure falls back once to a universal engine, never loops.
- Device-aware, but simply: platform decides the default engine; device capability only
  gates whether a fallback attempt is worthwhile.
- Feature-complete for VOD: subtitles (embedded + external), audio-track switch,
  aspect-ratio control, quality/bitrate, playback speed.
- Picture-in-Picture (auto-enter when app is backgrounded during playback), with a master
  on/off toggle in a new Playback settings screen. Capability-gated per platform.
- Minimal maintenance: **two** concrete engines, not four.

## Non-Goals

- No custom Rust/C++ decoder. Reuses OS-native + mpv/FFmpeg; does not reinvent DRM,
  adaptive bitrate, or hardware tunneling.
- No `libVlc` engine build (enum value stays reserved for a future isolated swap).
- No continuous runtime engine-switching / capability probing per session (rejected as
  hard-to-maintain and prone to "stuck switching").
- No mid-playback engine swap.
- No manual PiP button (auto-enter-on-background only, for now).
- No PiP on Windows/Linux (mpv has no OS PiP) or Android TV (10-ft UI; leaving the app
  mid-playback is not a TV usage pattern).

## What Already Exists (reuse, do not rebuild)

- `AiroPlaybackEngine` — full engine interface: open/play/pause/stop/seek/setVolume/
  setPlaybackSpeed/selectQuality/selectTrack/diagnostics/dispose.
- `AiroPlaybackBackendKind` — engine identity enum already includes
  `videoPlayer, cast, media3, libVlc, mpv, fake, unavailable`.
- Full state + error model (`playback_engine_models.dart`): `AiroPlaybackState`,
  `AiroPlaybackErrorCode` (`codecUnsupported, decoderFailed, sourceUnavailable,
  networkUnavailable, backendUnavailable, …`), `AiroPlaybackSourceHandle` (with
  security redaction/validation), diagnostics with `hardwareAccelerated` flag.
- Track selection already contracted: `selectTrack` + `AiroPlaybackTrackKind.{audio,
  subtitle, video}`.
- `AiroMultiSourceFailoverController` (`multi_source_failover_models.dart`) — proven
  anti-loop **source-axis** failover: ranked sources, `failedSourceIds` set,
  `exhausted` terminal state, stall detection. Tested in `multi_source_failover_test.dart`.
- Concrete engines today: `videoPlayer` (in `platform_media/video_player_streaming_service.dart`),
  plus `FakeAiroPlaybackEngine` and `UnavailableAiroPlaybackEngine`.
- `native_media_engine_spike_models.dart` — engine-candidate evaluation framework
  (research artifact; NOT a runtime resolver).

## The Gap (what this design adds)

1. A second concrete engine: **mpv** (via media_kit).
2. **`AiroPlaybackEngineResolver`** — picks the default engine per platform. Missing today.
3. **`AiroEngineFallbackCoordinator`** — one-shot **engine-axis** fallback. Mirrors the
   existing source-axis controller's anti-loop shape.
4. Feature-layer gaps: external-subtitle loading into the open request; aspect-ratio view enum.

## Architecture

### Two independent failure axes

The error taxonomy already distinguishes them, so they never fight:

| Failure | Error code | Axis | Handler |
|---|---|---|---|
| Bad URL / dead stream | `sourceUnavailable`, `networkUnavailable` | Source | existing `AiroMultiSourceFailoverController` (next URL, same engine) |
| Codec/decoder can't play | `codecUnsupported`, `decoderFailed` | Engine | NEW `AiroEngineFallbackCoordinator` (videoPlayer → mpv) |

Both use the identical anti-loop guard: a `tried`/`failed` set plus an `exhausted`/`FAILED`
terminal state → typed error to the UI. Neither can loop.

### Engine set (two only)

- **`videoPlayer`** — primary. ExoPlayer (Android/TV) / AVPlayer (iOS/macOS) / `<video>` (web).
  Hardware-accelerated, battery-efficient, official. Already implemented.
- **`mpv`** (media_kit) — (a) primary on Windows/Linux (videoPlayer has no backend there)
  and (b) the codec/decoder fallback on resource-capable platforms. FFmpeg core provides
  multi-codec breadth. New implementation.

**mpv shipping matrix (decided):** mpv is bundled on all platforms **except Android TV and
Web**. Rationale: Android TV boxes are storage-starved (often 8GB total) and cannot absorb
the ~20-30MB per-arch native libs; media_kit's web support is weak. Result:

| Platform | Primary | Engine fallback |
|---|---|---|
| Android mobile, iOS | `videoPlayer` | `mpv` |
| macOS | `videoPlayer` | `mpv` |
| Windows, Linux | `mpv` | none (sole engine) |
| Android TV | `videoPlayer` | none (mpv excluded — storage) |
| Web | `videoPlayer` | none (media_kit web support weak) |

So engine-level fallback is active on Android-mobile / iOS / macOS. Android TV and Web run
videoPlayer only; a codec failure there yields a clean typed error (source failover still
covers dead-stream cases). Windows/Linux run mpv only.

`libVlc` is intentionally not built. If mpv underperforms on some device class later,
swapping in a `libVlc` engine is an isolated future change the contract already permits.

### Resolver — picks the default (runs once, at init)

```
AiroPlaybackEngineResolver.resolve(deviceProfile) -> AiroPlaybackBackendKind
```

Pure function. **Platform is the decider:**

- Web, Android, Android TV, iOS, macOS → `videoPlayer`
- Windows, Linux → `mpv`

Device RAM/codec capability does **not** change the default pick. It is consulted only by
the fallback gate (below). This keeps the resolver deterministic, exhaustively testable, and
free of scattered device-awareness. The resolver is total — worst case returns
`unavailable` (renders error UI), never null.

### Engine fallback coordinator — one-shot, cannot loop

```
AiroEngineFallbackCoordinator
  primary       = resolver.resolve(profile)   // e.g. videoPlayer
  fallback      = mpv    // or null when gated out on a too-weak device
  triedEngines  = {}     // anti-loop set (mirrors source failover)
```

`open(request)` state machine, hard cap of ONE engine switch:

```
try primary.open(request)
  on codecUnsupported | decoderFailed:
      if fallback == null OR fallback in triedEngines: -> FAILED (typed error → UI)
      triedEngines.add(fallback); swap to fallback; retry open ONCE
  on sourceUnavailable | networkUnavailable:
      NOT this axis -> delegate to AiroMultiSourceFailoverController
  on success:
      engine locked for the session (never re-swaps mid-playback)
```

`fallback` is `mpv` on Android-mobile / iOS / macOS, and `null` on Android TV, Web, and
Windows/Linux (per the shipping matrix — TV/Web don't bundle mpv; Win/Linux already run mpv
as primary). Where `fallback == null`, the coordinator degrades cleanly to "primary only;
codec failure → typed error." No platform ever runs two engines except transiently during
the single `open()` switch on mobile/macOS.

**Fallback gate (device-awareness lives only here):** even where mpv is bundled, on a device
below a RAM/codec threshold where mpv software-decode would OOM or crawl, `fallback` is set
to `null` so a primary failure goes straight to a clean error rather than a doomed second
attempt.

### Feature layer

| Feature | Status | Work |
|---|---|---|
| Embedded subtitles | `selectTrack(subtitle)` exists | mpv engine must honor it |
| External subtitles | not in open request | small add to `AiroMediaOpenRequest` (external sub handles) |
| Audio-track switch | `selectTrack(audio)` exists | mpv engine must honor it |
| Aspect ratio | not in contract | new `AiroPlaybackViewFit` enum (contain/cover/fill/stretch) — view-layer only, no engine change |
| Quality/bitrate | `selectQuality` exists | mpv engine must honor it |
| Playback speed | `setPlaybackSpeed` exists | mpv engine must honor it |
| Picture-in-Picture | not in contract | new engine methods + capability flag + settings toggle (see below) |

## Picture-in-Picture

**Behavior (decided):** auto-enter PiP when the app is backgrounded while a video is
playing. No manual PiP button for now. Governed by a single master on/off setting.

**PiP is a `videoPlayer`-engine capability**, tied to native OS PiP — not mpv. It follows
the engine matrix:

| Platform | Primary engine | PiP |
|---|---|---|
| Android mobile | `videoPlayer` | ✓ native Android PiP (API 26+) |
| iOS | `videoPlayer` | ✓ AVKit PiP |
| macOS | `videoPlayer` | ✓ AVKit PiP |
| Web | `videoPlayer` | ✓ Picture-in-Picture API on `<video>` |
| Android TV | `videoPlayer` | ✗ disabled (not a TV pattern) |
| Windows, Linux | `mpv` | ✗ no OS PiP |

**Contract additions** (`platform_player`):
- `AiroPlaybackEngine.enterPictureInPicture()` / `exitPictureInPicture()` → return
  `AiroPlaybackState`. Engines without support throw the existing
  `AiroPlaybackErrorCode.unsupportedOperation`.
- A `supportsPictureInPicture` capability flag on `media_capability_models` (platform +
  engine derived). Single source of truth for gating both the lifecycle trigger and the
  settings UI.

**Auto-enter trigger:** an app-lifecycle observer (`WidgetsBindingObserver`,
`AppLifecycleState.inactive/paused`) calls `enterPictureInPicture()` when ALL hold:
playing, setting enabled, and `supportsPictureInPicture == true`. Never triggers otherwise
(no-op), so unsupported platforms are inert.

**Settings** (`app/lib/features/settings`): a new **Playback settings screen** (none exists
today — only Audio + AI), following the established pattern —
`PlaybackSettings` model + Riverpod `playbackSettingsProvider` + shared_preferences
persistence (mirror `audio_context_settings.dart` / `audioContextSettingsProvider`). Screen
holds one `SwitchListTile`: **"Picture-in-Picture — automatically shrink video when you
leave the app."** The tile is **hidden entirely** when `supportsPictureInPicture == false`
(Win/Linux/TV), so users never see a dead toggle. This Playback screen is also the natural
future home for the aspect-ratio default.

## Resilience Invariants (asserted as tests, not prose)

1. Max **2** `open()` attempts per session. Ever.
2. Engine is locked after the first successful frame — no mid-playback swap.
3. Every terminal path yields a typed `AiroPlaybackError` — never a hang.
4. Resolver is total — never returns null.
5. Source-axis errors never consume the engine-fallback budget, and vice versa.

## Testing Strategy

- **Resolver** — table test: every platform → expected backend. Exhaustive, pure.
- **Fallback coordinator** — critical cases:
  - primary succeeds → no fallback attempted
  - primary `codecUnsupported` → mpv tried once → success
  - primary fails + mpv fails → FAILED, no 3rd attempt (asserts anti-loop)
  - primary fails + fallback gated (weak device) → straight to FAILED
  - source error → delegated, engine-fallback budget untouched
  - mid-playback error → no engine swap
- **mpv engine** — reuse the videoPlayer contract-conformance suite, parameterized over
  `AiroPlaybackEngine`. Both engines pass identical behavior tests.
- **Fake engine** — drives coordinator tests without real decode (already exists).
- **PiP** —
  - capability flag table test: each platform → expected `supportsPictureInPicture`.
  - lifecycle trigger: backgrounded + playing + enabled + supported → `enterPictureInPicture`
    called exactly once; any condition false → not called.
  - unsupported engine (mpv/fake): `enterPictureInPicture` → `unsupportedOperation`, no crash.
  - settings: toggle persists across restart; tile hidden when capability false.

## Package Placement

- `platform_player`: `AiroPlaybackEngineResolver`, `AiroEngineFallbackCoordinator`,
  `AiroPlaybackViewFit`, external-sub additions to `AiroMediaOpenRequest`, PiP engine methods
  (`enterPictureInPicture`/`exitPictureInPicture`).
- `platform_media`: the concrete `mpv` engine implementation (alongside existing
  videoPlayer engine), new `media_kit` dependency scoped here; `supportsPictureInPicture`
  capability flag on `media_capability_models`.
- `app/lib/features/settings`: new Playback settings screen + `PlaybackSettings` model +
  `playbackSettingsProvider`; app-lifecycle PiP observer wired near the player surface.
- New dependency `media_kit` requires chief-open-source-officer + chief-performance-officer
  review (license, binary-size, per-arch native lib impact) per Engineering Council rules.
- PiP native config: Android requires `android:supportsPictureInPicture` + `PictureInPicture`
  activity flags on the mobile flavor (not TV); iOS/macOS require the AVKit PiP background
  mode / entitlement. chief-security-officer / chief-release-devops-officer touch-point.

## Open Questions for Implementation Plan

- Exact RAM/codec threshold for the fallback gate (needs a device-profile source of truth —
  check `media_capability_models` + `platform_device_qualification`).
- Confirm media_kit build config can EXCLUDE the mpv native libs from the Android TV flavor
  while INCLUDING them on the Android mobile flavor (same Android platform, different build
  flavor). If the plugin can't be flavor-gated cleanly, Android mobile may have to drop mpv
  too. **Validate this early — it's the main build-system risk.**
- Confirm macOS media_kit fallback pulls its weight (macOS already has strong AVPlayer;
  mpv fallback may be low-value there — could be dropped to shrink the macOS bundle).

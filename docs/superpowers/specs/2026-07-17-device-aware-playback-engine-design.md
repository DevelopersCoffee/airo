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
- Minimal maintenance: **two** concrete engines, not four.

## Non-Goals

- No custom Rust/C++ decoder. Reuses OS-native + mpv/FFmpeg; does not reinvent DRM,
  adaptive bitrate, or hardware tunneling.
- No `libVlc` engine build (enum value stays reserved for a future isolated swap).
- No continuous runtime engine-switching / capability probing per session (rejected as
  hard-to-maintain and prone to "stuck switching").
- No mid-playback engine swap.

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
  Hardware-accelerated, battery-efficient, official. Covers Web, Android, Android TV, iOS,
  macOS. Already implemented.
- **`mpv`** (media_kit) — (a) desktop-filler for Windows/Linux (videoPlayer has no backend
  there) and (b) the single universal fallback for codec/decoder failures on any platform.
  FFmpeg core provides multi-codec breadth. New implementation.

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

**Fallback gate (device-awareness lives only here):** on a device below a RAM/codec
threshold where mpv software-decode would OOM or crawl, `fallback` is set to `null` so a
primary failure goes straight to a clean error rather than a doomed second attempt.

### Feature layer

| Feature | Status | Work |
|---|---|---|
| Embedded subtitles | `selectTrack(subtitle)` exists | mpv engine must honor it |
| External subtitles | not in open request | small add to `AiroMediaOpenRequest` (external sub handles) |
| Audio-track switch | `selectTrack(audio)` exists | mpv engine must honor it |
| Aspect ratio | not in contract | new `AiroPlaybackViewFit` enum (contain/cover/fill/stretch) — view-layer only, no engine change |
| Quality/bitrate | `selectQuality` exists | mpv engine must honor it |
| Playback speed | `setPlaybackSpeed` exists | mpv engine must honor it |

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

## Package Placement

- `platform_player`: `AiroPlaybackEngineResolver`, `AiroEngineFallbackCoordinator`,
  `AiroPlaybackViewFit`, external-sub additions to `AiroMediaOpenRequest`.
- `platform_media`: the concrete `mpv` engine implementation (alongside existing
  videoPlayer engine), new `media_kit` dependency scoped here.
- New dependency `media_kit` requires chief-open-source-officer + chief-performance-officer
  review (license, binary-size, per-arch native lib impact) per Engineering Council rules.

## Open Questions for Implementation Plan

- Exact RAM/codec threshold for the fallback gate (needs a device-profile source of truth —
  check `media_capability_models` + `platform_device_qualification`).
- media_kit binary-size budget on Android TV (it adds native libs; may be desktop-only if
  the TV size cost is unacceptable — in which case TV has no engine fallback, only source
  failover). **This is the biggest risk to validate early.**

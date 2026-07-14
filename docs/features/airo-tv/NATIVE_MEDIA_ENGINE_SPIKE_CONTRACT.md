# Native Media Engine Spike Contract

Status: v2 platform contract for ATV-027.

## Ownership

Native media engine evaluation is platform/framework behavior. Airo TV can
consume the eventual engine decision, but backend selection, surface
requirements, diagnostics, and decoder fallback rules belong in platform
contracts.

The spike contract lives in `packages/platform_player` because that package
already owns `AiroPlaybackEngine`, backend kinds, playback state, diagnostics,
fake engines, and unavailable engines.

## Non-Goals

This issue does not implement:

- Media3
- mpv
- libVLC
- native texture rendering
- platform-view rendering
- decoder probing
- playback widgets
- app screen wiring
- route selection

The goal is a deterministic evaluation surface for a future implementation
spike.

## Contract Shape

`AiroNativeMediaEngineCandidate` describes a backend option:

- candidate id
- backend kind
- maturity
- supported media kinds
- supported surface modes
- supported features

`AiroNativeMediaEngineSpikeRequest` describes spike requirements:

- required media kinds
- required surface modes
- required features
- whether experimental backends are allowed
- whether hardware decode is required
- whether decoder fallback is required
- whether diagnostics are required

`AiroNativeMediaEngineSpikePolicy` returns stable blocker codes:

- `accepted`
- `backend_blocked`
- `experimental_backend_not_allowed`
- `unsupported_media_kind`
- `missing_surface_mode`
- `missing_required_feature`
- `missing_diagnostics`
- `missing_hardware_decode`
- `missing_decoder_fallback`

## Adapter Boundary

`AiroNativeMediaEngineCandidateRegistry` lists candidate backend descriptions.
The package includes:

- `AiroNoOpNativeMediaEngineCandidateRegistry`
- `AiroFakeNativeMediaEngineCandidateRegistry`

Neither registry imports player SDKs or probes a device.

## Spike Acceptance

A candidate is eligible for the v2 native media engine spike only when it can
support baseline HLS/live/progressive playback, the requested surface mode,
audio and subtitle tracks, adaptive streaming, hardware decode, decoder
fallback, and privacy-safe decoder/buffer diagnostics.

Experimental backends require explicit opt-in. Blocked backends are never
accepted.

## Privacy

Diagnostics expose stable backend ids, feature ids, surface ids, and blocker
codes only. The spike contract must not expose raw media URLs, local file paths,
local addresses, provider payloads, viewing history, or diagnostic dumps.

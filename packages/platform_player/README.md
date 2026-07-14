# Platform Player

Reusable playback and receiver-control contracts for Airo.

This package is platform/framework code. Airo TV, IPTV features, Cast adapters,
future native media engines, command routing, diagnostics, and certification
flows consume these contracts instead of defining app-specific playback models.

## Scope

- Backend-agnostic `AiroPlaybackEngine` contract.
- Native media engine spike candidate, surface, diagnostics, and fallback
  evaluation contracts.
- Redacted media open requests with opaque source handles.
- Typed playback states, quality options, tracks, diagnostics, and errors.
- No-op/unavailable and fake playback engines for deterministic tests.
- Cast discovery/session abstractions used by existing IPTV flows.

This package does not choose or implement a native media backend, import native
player SDKs, probe decoders, persist sessions, render playback widgets, route
commands, or expose raw media source URLs, local paths, local IP addresses,
provider credentials, viewing history, analytics payloads, or diagnostic dumps.

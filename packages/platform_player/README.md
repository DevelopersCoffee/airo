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

## Cast Proxy Security

`CastHttpProxy` is a compatibility relay for Cast playback, not a general local
file server. Generated proxy URLs carry a random access token, and relay targets
are validated with `AiroPlaylistUrlPolicy` before the proxy fetches them.

Private, link-local, localhost, credential-bearing, and non-HTTP(S) targets are
blocked by default. Tests may opt into private targets for loopback fixtures,
but product flows should only do that behind an explicit user consent path for
LAN streams.

## Cast Proxy Benchmarks

`CastProxyBenchmarkPolicy` evaluates aggregate device-run evidence before Airo
ports the proxy data plane to native code. A benchmark sample records target
bitrate, observed throughput, sender CPU, duration, dropped connections, and
optional battery drain. The policy currently requires a 10 minute run, observed
throughput at or above target, no dropped connections, and sender CPU at or
below 5% when relaying 10 Mbps or higher.

If the CPU, throughput, or connection gates fail, the evaluation returns
`investigate_native_data_plane` so the Rust/tokio relay work has concrete
evidence. If only the duration is too short, the evaluation returns
`rerun_required`.

Reports intentionally contain aggregate metrics only. Do not attach raw stream
URLs, receiver identifiers, local IPs, credentials, local file paths, or raw
diagnostic dumps to public issue evidence.

This package does not choose or implement a native media backend, import native
player SDKs, probe decoders, persist sessions, render playback widgets, route
commands, or expose raw media source URLs, local paths, local IP addresses,
provider credentials, viewing history, analytics payloads, or diagnostic dumps.

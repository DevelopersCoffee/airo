# Core Media Routing

Reusable Media Routing Engine contracts for Airo products.

This package is platform/framework code. Airo TV, companion controllers,
playback engines, local discovery, session ownership, and QA automation consume
these contracts to choose a media path without hard-coding route priority in
product screens.

## Scope

- Versioned media routing request, candidate, policy, blocker, and decision
  models.
- Deterministic route preflight and selection.
- Direct receiver playback preference before relay or phone-proxy fallback.
- Privacy-safe diagnostics that expose ids and blocker codes, not raw source
  values.

This package does not start a media server, open playback, inspect codecs from a
platform SDK, define full media-location schemas, collect route health events,
or own playback-session state.

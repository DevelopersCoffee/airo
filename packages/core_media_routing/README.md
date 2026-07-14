# Core Media Routing

Reusable Media Routing Engine contracts for Airo products.

This package is platform/framework code. Airo TV, companion controllers,
playback engines, local discovery, session ownership, and QA automation consume
these contracts to choose a media path without hard-coding route priority in
product screens.

## Scope

- Versioned media routing request, candidate, policy, blocker, and decision
  models.
- Versioned media location and route access-grant models.
- Versioned route score breakdowns and privacy-safe decision logs.
- Deterministic route preflight and selection.
- Direct receiver playback preference before relay or phone-proxy fallback.
- Redacted source and access handles for cloud, LAN, server, local file,
  phone-local, TV removable, desktop, and temporary access paths.
- Privacy-safe diagnostics that expose ids, scores, reasons, and blocker codes,
  not raw source values.

This package does not start a media server, open playback, inspect codecs from a
platform SDK, collect route health events, issue playback access grants, or own
playback-session state.

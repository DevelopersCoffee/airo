# Airo TV Media Routing Engine Contract

This contract defines the v2.0.0.1 platform boundary for media route
preflight and route selection. The goal is direct playback first and
phone-proxy playback only as an explicit last resort.

Implementation contract:

- Package: `packages/core_media_routing`
- Schema: `kAiroMediaRoutingSchemaVersion`
- Engine interface: `AiroMediaRoutingEngine`
- Default policy: `AiroDeterministicMediaRoutingEngine`
- Current release branch: `codex/next-v2.0.0.0`

## Route Priority

The deterministic route order is:

1. Receiver direct playback.
2. LAN direct playback.
3. Server direct playback.
4. Desktop relay.
5. Phone proxy.

Cloud command/state orchestration is not a media path and must not be selected
for video transport.

## Preflight Rules

A candidate is rejected before route selection when it is unavailable,
untrusted, expired, codec-incompatible, direct playback is unsupported, cloud
command-only, or a phone proxy without the required last-resort confirmation.

Phone proxy is eligible only when no non-phone media route is eligible and the
user has explicitly confirmed the fallback. This prevents phone-as-default
server behavior.

## Privacy Rule

Route candidates use redacted source handles. Decisions and diagnostics expose
candidate ids, route kind, source kind, and blocker codes only. They must not
include raw URLs, local file paths, local IP addresses, provider auth material,
playlist contents, or credential-bearing diagnostics.

## Consumer Rule

Airo TV screens, playback engines, local discovery adapters, and future route
inspectors should consume `AiroMediaRoutingEngine` decisions. Product code may
present user-facing fallback prompts, but it should not implement separate route
priority or phone-proxy eligibility logic.

## Out Of Scope

This issue does not define the complete media-location schema, route-handle
service, weighted route scoring, decision-log export, playback ownership model,
route health events, phone media server implementation, NAS adapters, cloud
orchestration service, playback engine changes, or route picker UI.

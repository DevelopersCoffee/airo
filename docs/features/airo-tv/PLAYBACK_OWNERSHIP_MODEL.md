# Airo TV Playback Ownership Model

This contract defines the v2.0.0.1 platform boundary for playback control
authority after media routing selects a path.

Implementation contract:

- Package: `packages/core_sessions`
- Schema: `kAiroSessionSchemaVersion`
- Snapshot model: `AiroPlaybackOwnershipSnapshot`
- Transfer policy: `AiroPlaybackOwnershipPolicy`
- Release-line base: `origin/v2`

## Ownership Snapshot

`AiroPlaybackOwnershipSnapshot` records:

- session id;
- owner node id;
- playback node id;
- source node id;
- route id and route kind;
- analytics owner node id;
- health reporter node id;
- active controller node id;
- controller operation grants;
- monotonic session revision;
- optional ownership lease expiry.

The snapshot is platform state. Airo TV screens should not infer ownership from
local widget state, current route, focused screen, or controller presence.

## Operation Authority

The playback owner can control pause, resume, seek, stop, volume, audio track,
subtitle track, recovery, health reporting, and analytics reporting. A separate
analytics owner and health reporter can submit their respective records. An
active controller can perform only explicitly granted operations.

Expired ownership leases reject all operation authority until refreshed or
transferred.

## Transfer Rules

Ownership transfer is deterministic:

- expired transfer requests are rejected;
- expired ownership leases are rejected;
- wrong current-owner claims are rejected;
- stale base revisions are rejected;
- unauthorized requesters are rejected;
- accepted transfers move owner, analytics owner, health reporter, controller
  grant, and increment the session revision.

## Privacy Rule

Ownership diagnostics expose node ids, route ids, route kind, scopes, revision,
and lease metadata only. They must not include media URLs, local paths, local IP
addresses, source handles, titles, analytics payloads, crash details, or
diagnostic dumps.

## Consumer Rule

Airo TV, companion controllers, playback engines, route inspectors, and
analytics adapters should consume `AiroPlaybackOwnershipSnapshot` and
`AiroPlaybackOwnershipPolicy`. Product code may present ownership state, but it
should not implement separate pause/seek/resume/health/analytics authority
rules.

## Out Of Scope

This issue does not implement playback execution, analytics providers, route
health events, cloud arbitration, persistent lease storage, UI ownership
indicators, or route inspector screens.

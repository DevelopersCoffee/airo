# Airo TV Local Sync And Handoff Contract

This contract defines the v2.0.0.1 platform boundary for local playback-session
sync, receiver-authoritative revisions, deterministic conflicts, and two-phase
handoff preflight.

Implementation contract:

- Package: `packages/core_sessions`
- Schema: `kAiroSessionSchemaVersion`
- Session snapshot: `AiroPlaybackSessionSnapshot`
- Sync delta: `AiroSessionSyncDelta`
- Handoff preflight: `AiroHandoffPreflightPolicy`
- Fake repository: `AiroFakePlaybackSessionRepository`

## Session Authority

`AiroPlaybackSessionSnapshot` separates:

- desired playback state requested by a controller;
- actual playback state reported by the receiver;
- active controller node ID;
- receiver node ID;
- monotonic revision;
- opaque media handle;
- capture and expiry timestamps.

The receiver is authoritative for actual playback state. Controllers may render
optimistic desired state only until a newer receiver revision arrives.

## Revisions And Conflicts

`AiroSessionRevision` carries a monotonic value, update timestamp, and reporter
node ID. Newer revisions win. Older revisions are ignored. Equal revisions from
different reporters are conflicts and must be surfaced through stable result
codes before UI or transport code attempts recovery.

## Local Sync Deltas

`AiroSessionSyncDelta` carries an entity kind, operation, revision, issue and
expiry timestamps, and an opaque payload handle.

Sync payload handles must not contain raw media URLs, provider credentials,
local file paths, local IP addresses, diagnostics dumps, analytics payloads, or
viewing history. Local and cloud transports may carry encrypted payloads later,
but this issue defines only the privacy-safe contract boundary.

## Handoff Preflight

Handoff uses prepare, ready, commit, and abort semantics. Source playback should
continue until the destination is ready and commit is accepted.

`AiroHandoffPreflightPolicy` checks:

- source snapshot exists, is fresh, and is active;
- destination snapshot exists and is fresh;
- destination node is available and advertises required capabilities;
- trusted-device relationship satisfies the required scope and trust level.

## Consumer Rule

Airo TV, companion apps, command routing, playback engines, local LAN adapters,
and future cloud orchestration must consume `core_sessions`. Product code may
render progress, conflicts, and recovery copy, but session authority, revision
merge behavior, sync validation, and handoff preflight belong to this platform
contract.

## Out Of Scope

This issue does not implement WebSocket transport, cloud orchestration,
encrypted persistence, playback execution, device picker UI, or Airo TV screens.

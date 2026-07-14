# Universal Playback Session State

Status: v2 platform contract for ATV-040.

## Ownership

Universal playback session state is platform/framework behavior. Airo TV,
companion controllers, command routing, cloud orchestration, backend storage
adapters, recovery flows, route health, and QA automation consume the contract
to reconcile controller intent with receiver-confirmed playback reality.

The contract lives in `packages/core_sessions`. Adjacent packages retain their
ownership: `core_commands` owns command envelopes and idempotency,
`core_media_routing` owns route/media-path decisions, `core_pairing` owns trust
and scopes, and `core_protocol` owns connected-node vocabulary.

## Non-Goals

This issue does not implement:

- backend storage
- WebSocket transport
- command execution
- playback engine adapters
- route scoring
- profile or parental policy
- app UI
- media proxying

## Contract Shape

`AiroUniversalPlaybackSessionSnapshot` is the canonical session snapshot:
session id, active receiver, active controller, revision, receiver-reported
actual playback state, optional controller-requested desired state, redacted
media handle, route identity, route kind, members, capture time, and expiry.

`AiroActualPlaybackState` is receiver-authoritative and includes phase,
position, duration, live offset, rate, volume, tracks, reporter, and timestamp.

`AiroDesiredPlaybackState` is controller intent. It may be rendered
optimistically, but it is cleared when a receiver actual-state report is at
least as fresh as that desired update.

`AiroUniversalSessionMember` defines session membership by node/device, role,
operation permissions, join time, expiry, and revocation.

`AiroUniversalPlaybackSessionPolicy` returns deterministic decisions:

- accept
- deny
- recover
- no-op

Decision codes cover expired snapshots, unsafe payload references, stale
revisions, conflicting revisions, receiver mismatch, missing members, expired or
revoked members, missing permissions, and unavailable repositories.

`AiroUniversalPlaybackSessionRepository` is the provider boundary.
`AiroNoOpUniversalPlaybackSessionRepository` never stores state.
`AiroFakeUniversalPlaybackSessionRepository` stores accepted snapshots in memory
and returns the latest non-expired receiver-authoritative snapshot for
deterministic host-side recovery tests.

## Authority Rules

- Receiver actual state wins over controller optimism for playback phase,
  position, buffering, rate, volume, live offset, and tracks.
- Controllers may publish desired state only through explicit session
  permissions.
- Receiver actual-state reports must be made by the active receiver member.
- Same-revision reports from different reporters are conflicts.
- Lower revisions are stale and cannot replace the current snapshot.
- Recovery returns only non-expired receiver-authoritative snapshots.

## Privacy Rules

Public diagnostics expose stable ids, roles, permissions, phases, positions,
route kind, revision, timestamps, and whether a media handle exists. They must
not expose raw media URLs, playlist paths, local file paths, request headers,
provider payloads, local addresses, credentials, titles, or viewing history.

## Automation

- Unit tests use fixed clocks, deterministic revisions, and explicit members.
- Policy tests cover receiver-authoritative updates, desired-state
  reconciliation, stale revisions, conflicts, invalid authority, missing
  permissions, expired snapshots, unsafe payload validation, and redacted
  diagnostics.
- Repository tests cover fake/no-op behavior and latest snapshot recovery
  without network or backend dependencies.

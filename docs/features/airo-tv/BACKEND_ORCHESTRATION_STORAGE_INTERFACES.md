# Airo TV Backend Orchestration Storage Interfaces

This contract defines the v2.0.0.1 platform boundary for backend-facing
orchestration storage interfaces.

Implementation contract:

- Package: `packages/core_orchestration_storage`
- Schema: `kAiroOrchestrationStorageSchemaVersion`
- Aggregate interface: `AiroOrchestrationStorage`
- Missing domain store: `AiroSessionControllerMembershipStore`

## Ownership Boundary

Backend orchestration storage is platform/framework behavior. Airo TV app code
must not import a backend SDK or write directly to provider collections for
device registry, presence, sessions, controller membership, command lifecycle,
or progress. App code may render product journeys and recovery copy while
backend adapters implement this provider-neutral contract.

The package composes existing platform packages:

- `core_device_identity` for device registry records;
- `core_presence` for expiring presence leases;
- `core_sessions` for receiver-authoritative session snapshots and controller
  members;
- `core_commands` for command lifecycle records;
- `core_watch_progress` for continue-watching progress records.

## Collections

The backend-facing manifest names these logical collections:

- `device_registry`
- `presence_leases`
- `playback_sessions`
- `session_controllers`
- `command_lifecycle`
- `watch_progress`

The contract does not prescribe Firebase, SQL, document storage, WebSocket
state, custom service storage, indexes, regions, billing tier, or deployment
topology. Provider adapters must preserve the logical collection boundaries.

## Local-First Rule

This storage layer supports optional cloud orchestration. It must not become a
runtime dependency for same-network playback or local paired control. No-op
storage returns unavailable health and does not write records. Fake storage is
deterministic for host-side tests.

## Privacy And Retention

Public snapshots expose collection health, counts, stable IDs, revisions,
statuses, and timestamps only. They must not include raw media URLs, playlist
payloads, local paths, local addresses, provider credentials, analytics payloads,
diagnostics dumps, or private backend documents.

Presence and controller memberships are expiring records. Snapshot helpers filter
expired leases and expired/revoked controller memberships. Progress, command,
session, device, and presence write semantics remain delegated to their owning
platform packages.

## Required Use Cases

- Backend adapters can advertise enabled collections and provider availability.
- A no-op adapter fails closed without persistence.
- A fake adapter composes fake domain stores for deterministic tests.
- Controller memberships can be upserted, listed, expired, and revoked without
  mutating playback-session snapshots directly.
- Health and snapshot outputs remain privacy-safe and provider-neutral.

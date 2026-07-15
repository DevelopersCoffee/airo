# Airo TV Continue-Watching Progress Contract

This contract defines the v2.0.0.1 platform boundary for cross-device
continue-watching progress, cloud opt-in behavior, local-only mode, retention,
revision conflicts, and soft deletion.

Implementation contract:

- Package: `packages/core_watch_progress`
- Schema: `kAiroWatchProgressSchemaVersion`
- Primary policy: `AiroWatchProgressPolicy`
- Primary record: `AiroWatchProgressRecord`
- Repository boundary: `AiroWatchProgressRepository`

## Ownership Boundary

Continue-watching progress is platform/framework state. Airo TV app code may
render rows, cards, settings, and opt-out copy, but schema, revisions,
retention, safe IDs, and sync eligibility belong to the platform contract.

The contract intentionally stores stable references only:

- profile ID;
- media ID;
- source ID;
- resolver ID;
- playback position and duration;
- completion state;
- revision and updater IDs;
- retention and deletion timestamps.

It does not store titles, raw media URLs, local paths, local addresses,
provider credentials, playlist payloads, or watch-history free text.

## Modes

`AiroWatchProgressSyncMode` controls where records may flow:

- `disabled`: no progress write is accepted.
- `localOnly`: local writes are accepted; cloud sync/export is blocked.
- `cloudOptIn`: cloud sync is allowed only for records marked cloud eligible.
- `cloudEnabled`: local and cloud writes are allowed if validation passes.

Local-only mode keeps progress local unless a separate explicit export flow is
added later.

## Conflict And Retention Rules

`AiroWatchProgressPolicy` is deterministic:

- newer revisions replace older records;
- older revisions are ignored;
- same revision with a different reporter is a conflict;
- expired retention windows are denied for sync;
- soft-delete tombstones are accepted and preserve deletion intent;
- invalid position, duration, completion, or unsafe stable IDs are rejected.

## Required Use Cases

- Receiver persists progress on pause, stop, background, transfer,
  completion, and shutdown.
- Local-only mode accepts local progress and blocks cloud sync.
- Cloud-enabled mode accepts newer revisions and ignores stale revisions.
- Conflict decisions are stable for same-revision different-reporter updates.
- Retention-expired records do not sync.
- Delete tombstones can remove continue-watching rows without leaking media
  details.
- Fake and no-op repositories are available for deterministic host-side
  automation.

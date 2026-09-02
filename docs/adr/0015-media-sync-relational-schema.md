# ADR 0015: Dedicated relational schema for media graph and sync entities

- Status: Accepted
- Date: 2026-07-27
- Owners: Edge Architect, Chief Architect, Rust Architect
- Related: #879, #882, #883

## Context

Airo's media graph and per-field sync merge contracts now have stable row
shapes. Persisting whole records as JSON blobs would make field clocks,
tombstones, profile deletion, graph traversal, and indexes opaque to SQLite.
The existing application database also contains unrelated money and meeting
schemas and is not the correct ownership boundary for Midas Stream media sync.

## Decision

Use a dedicated SQLite schema executed by the existing `airo_core` rusqlite
runtime. Migration `0001_media_sync_relational.sql` is additive, transactional,
idempotent, and records schema version 1.

The schema normalizes users, devices, profiles, playlists, channels, history,
favorites, collections, settings, sync events, media graph rows/edges/pack
ownership (including shared edge ownership), sync fields, and vector counters.
Structured records are never
stored as whole-record JSON. Only `channels.raw_provider_metadata` may retain
genuinely unstructured provider payloads.

Foreign keys cascade profile-owned data, tombstones remain explicit columns,
and indexes cover profile history, active favorites/channels, graph year/entity
queries, sync outbox ordering, and deleted entities.

## Consequences

- #879 and #882 adapters can map directly to scalar rows without inventing
  another persistence shape.
- Profile deletion has a database-enforced cascade boundary.
- Web fallback and existing unrelated app stores remain unchanged.
- Migration failure rolls back its transaction; file-level backup/restore
  remains the operational rollback before callers are switched.
- Native/Dart adapters expose async relational read/write paths. No deployed
  Midas Stream media/sync blob schema exists in this repository, so there is no
  legacy blob data to transform; unrelated application stores remain an
  explicit non-goal.

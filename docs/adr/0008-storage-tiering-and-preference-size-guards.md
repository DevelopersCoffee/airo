# ADR-0008: Storage Tiering and Preference Size Guards

## Status

Accepted

## Date

2026-07-15

## Context

Airo v2 uses multiple local persistence mechanisms. Small flags and settings
belong in `SharedPreferences`, structured queryable data belongs in SQLite or a
file-backed platform cache, and sensitive values belong in secure storage.

Historically, package-level code could write arbitrarily large JSON strings to
preferences. That made startup slower, increased memory spikes, and let bulk
playlist/cache payloads land in the weakest storage tier.

Hive is not the target storage tier for native Airo TV data. The web database
facade uses a lightweight in-memory adapter until a queryable IndexedDB/Drift
web store is selected and migrated explicitly.

## Decision

1. `SharedPreferences` is for small flags, settings, timestamps, validators,
   user choices, and compact lists.
2. The default preference value limit is 64 KiB per string or combined
   string-list payload.
3. `PreferencesStore` enforces the limit and throws
   `KeyValueStoreValueTooLargeException` before writing oversized values.
4. Bulk structured data must use a file-backed cache, SQLite/drift, or a native
   platform store depending on access pattern.
5. Hive is not approved for new native Airo TV persistence. Web storage must use
   an explicitly approved adapter instead of reintroducing Hive.

## Consequences

### Positive

- Oversized preference writes fail deterministically at the platform boundary.
- Playlist/cache code has a clear reason to use structured file or database
  storage instead of preferences.
- Future storage reviews can check one documented tiering policy.

### Negative

- Existing direct `SharedPreferences` call sites are not automatically guarded
  until they move behind `KeyValueStore`.
- The current web database facade is process-local memory only; persistent web
  storage still needs a dedicated migration/design before production web use.

### Risks

- Call sites that currently rely on large preference JSON must be migrated
  before switching to `PreferencesStore`.
- The 64 KiB limit is conservative; packages that need a larger value must
  document why preferences are still the correct tier.

## Alternatives Considered

### Restore Hive For Web Compatibility

Rejected because #776 explicitly retires Hive as an approved app storage tier.
Web persistence needs a first-class IndexedDB/Drift strategy instead.

### Add Guards To Every SharedPreferences Call Site

Rejected because it duplicates policy and misses future call sites. The first
enforcement point is the reusable `core_data` adapter; direct app call sites can
migrate incrementally.

## Related Decisions

- [ADR-0001](0001-package-structure.md) - Modular Package Structure

## References

- GitHub issue #776 - Storage consolidation: retire Hive, tier prefs vs SQLite,
  enforce size guards

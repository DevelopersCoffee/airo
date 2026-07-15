# ADR-0008: Storage Policy -- Tier Definitions and Hive Retirement

## Status

Accepted

## Date

2026-07-15

## Context

Three persistence mechanisms coexist in the Airo codebase:

1. **SharedPreferences** (`PreferencesStore`) -- used for user settings, feature flags, small config values.
2. **Hive 2.2.3** (`hive_flutter`) -- used only in `app_database_web.dart` as the web-platform fallback for structured data (IndexedDB backend). Hive 2.2.3 is unmaintained.
3. **Drift/SQLite** (`app_database_native.dart`) -- used on native platforms for structured data (transactions, budgets, accounts, groups, sync metadata).

There is no documented policy on what data belongs in which tier. Hive is an unmaintained dependency that should not receive new usage. Large values occasionally land in SharedPreferences, which is designed for small key-value pairs and has platform-specific size limits.

## Decision

### Storage tiers

| Tier | Backend | Use for | Size limit |
|------|---------|---------|------------|
| **Prefs** | `SharedPreferences` via `KeyValueStore` / `PreferencesStore` | Boolean flags, small strings, ints, locale, theme, onboarding state | Max 64 KB per value (debug-asserted) |
| **Structured** | Drift/SQLite (`AppDatabase`) | Playlists, channel data, EPG, user collections, transactions, budgets, accounts, sync metadata | No per-value limit; schema-governed |
| **Secure** | `FlutterSecureStorage` via `SecureKeyValueStoreAdapter` | Auth tokens, encryption keys, credentials | Small values only |
| **File** | `path_provider` directories | Cached images, M3U cache files, large blobs, downloaded media | Governed by cache eviction policy |

### Hive: RETIRED

- **Do not add new Hive usage anywhere in the codebase.**
- Existing usage in `app_database_web.dart` is the web-platform structured-data backend. It will be replaced with `drift`'s web support (sql.js / sqlite3 WASM) in a future migration (see #776).
- `hive` and `hive_flutter` dependencies remain until the web database migration is complete.

### Size guard

A debug assertion in `KeyValueStore.setString` rejects values exceeding 64 KB (65,536 chars). This catches accidental misuse of the prefs tier for large data during development without affecting release builds.

## Consequences

### Positive

- Clear guidance for contributors on where to store data.
- Debug-time protection against prefs tier misuse.
- Path toward removing an unmaintained dependency.

### Negative

- Web database migration is deferred (tracked separately).
- Hive dependency remains in pubspec until web migration completes.

### Risks

- Web platform users currently rely on the Hive-backed database; removing it without a replacement would break web builds.

## Alternatives Considered

### Alternative 1: Immediate Hive removal

Remove Hive entirely and switch web to sql.js/WASM now. Not chosen because the Drift WASM backend requires additional setup and testing, and web is not a primary target today.

### Alternative 2: Keep Hive, add wrapper

Wrap Hive behind the same `KeyValueStore` interface. Not chosen because Hive is unmaintained, and the existing usage is for structured data, not key-value pairs.

## References

- Issue #776: Storage consolidation
- Hive package: https://pub.dev/packages/hive (unmaintained since 2.2.3)
- Drift web support: https://drift.simonbinder.eu/web/

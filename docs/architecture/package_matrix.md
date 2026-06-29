# Platform Package Matrix

| Package | Ownership | Permitted Native APIs | Prohibited APIs |
|---|---|---|---|
| `platform_core` | Core abstractions, DI contracts, Lifecycle | None | `dart:io`, `sqlite3` |
| `platform_logging` | Log routing, sinks, structured context | None | `dart:io`, `sqlite3` |
| `platform_events` | Internal typed communication, Pub/Sub | None | `dart:io`, `sqlite3` |
| `platform_settings` | Typed configuration, remote config, overrides | None | `dart:io`, `sqlite3` |
| `platform_storage` | Relational data, Transactions, Migrations | `drift`, `sqlite3` | `path_provider`, raw file ops |
| `platform_filesystem` | Binary assets, Model caching, Directories | `dart:io`, `path_provider` | `drift`, `sqlite3` |
| `design_system` | Visual language, components, typography | Flutter framework | Any platform capability |

## Usage Rule
Feature packages must **only** interact with these packages via their exported `PlatformService` or Riverpod Provider contracts. They may not bypass these packages to talk directly to `sqlite3`, `dart:io`, or `shared_preferences`.

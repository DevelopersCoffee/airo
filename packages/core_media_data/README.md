# Core Media Data

Reusable media data contracts for Airo products.

This package owns media database benchmark boundaries that should not be
hard-coded inside Airo TV screens, playlist importers, EPG workers, or a
specific database adapter.

## Scope

- Versioned media database benchmark dataset profiles.
- Import, search, lookup, write, cleanup, and compact-window workload steps.
- Deterministic budget and metric evaluation for large IPTV/VOD/EPG datasets.
- Fake and no-op benchmark runners for automation and adapter boundaries.

This package does not choose a database engine, generate bundled provider
content, import database SDKs, run device-lab benchmarks, or expose raw media
source URLs, EPG source URLs, local paths, local IP addresses, provider
credentials, viewing history, analytics payloads, or device identifiers.

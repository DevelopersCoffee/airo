# Core Media Data

Reusable media data contracts for Airo products.

This package owns media data boundaries that should not be hard-coded inside
Airo TV screens, playlist importers, EPG workers, sync adapters, or a specific
database adapter.

## Scope

- Profile data ownership matrices for Full TV, Lite Receiver, and Embedded
  Receiver.
- Storage scope, sync mode, upgrade, downgrade, preservation, encryption, and
  cache-budget rules for media data domains.
- Versioned media database benchmark dataset profiles.
- Import, search, lookup, write, cleanup, and compact-window workload steps.
- Deterministic budget and metric evaluation for large IPTV/VOD/EPG datasets.
- Fake and no-op benchmark runners for automation and adapter boundaries.
- Versioned relational media graph rows, typed relationships, structured
  queries, and independently loadable knowledge-pack lifecycle.
- Deterministic rule-based media ranking with aggregate history feature
  extraction, auditable integer score contributions, and a replaceable executor
  boundary for native scoring.

This package does not choose a database engine, sync backend, vault provider,
generate bundled provider content, import database SDKs, run device-lab
benchmarks, perform provider enrichment, invoke an LLM, or expose raw media
source URLs, EPG source URLs, local paths, local IP addresses, provider
credentials, viewing history, analytics payloads, or device identifiers.

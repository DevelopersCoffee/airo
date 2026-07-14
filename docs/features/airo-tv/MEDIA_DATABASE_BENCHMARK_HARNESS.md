# Media Database Benchmark Harness

Status: v2 platform contract for ATV-028.

## Ownership

Media database benchmark definitions are framework/platform behavior. Airo TV
can run or display benchmark outcomes later, but dataset definitions, workload
steps, budget checks, result schemas, and adapter boundaries belong in
`packages/core_media_data`.

The package is intentionally separate from playlist import, EPG, playback, and
app UI modules so a database choice can change without forcing product code to
change.

## Non-Goals

This issue does not implement:

- SQLite, Drift, Isar, Hive, ObjectBox, or any other database adapter
- generated benchmark fixture files
- provider-specific media content
- device-lab execution
- Airo TV screens
- playlist parsing workers
- distributed EPG workers
- analytics upload

## Contract Shape

`AiroMediaBenchmarkDatasetProfile` describes representative media data scale:

- live channel count
- VOD item count
- EPG program count
- playlist source count
- metadata field count

`AiroMediaBenchmarkWorkloadStep` describes deterministic operations:

- import batch
- search text
- lookup by id
- update stream health
- write progress
- delete expired data
- snapshot compact EPG windows

`AiroMediaBenchmarkBudget` defines pass/fail budgets for:

- elapsed time
- peak memory
- storage size
- throughput

`AiroMediaDatabaseBenchmarkPolicy` evaluates fake, lab, or future adapter runs
with stable blocker codes:

- `accepted`
- `missing_metric`
- `incomplete_workload`
- `failed_workload`
- `over_time_budget`
- `over_memory_budget`
- `over_storage_budget`
- `below_throughput_floor`
- `privacy_unsafe_stable_id`

## Adapter Boundary

`AiroMediaDatabaseBenchmarkRunner` is the boundary for future benchmark
implementations. The platform package includes:

- `AiroNoOpMediaDatabaseBenchmarkRunner`
- `AiroFakeMediaDatabaseBenchmarkRunner`

Neither runner imports a database SDK or reads real provider data.

## Privacy

Benchmark profiles and results use counts, stable ids, operation ids, metric
names, and blocker codes only. They must not expose raw playlist URLs, EPG
source URLs, local paths, local addresses, provider payloads, viewing history,
analytics payloads, or device identifiers.

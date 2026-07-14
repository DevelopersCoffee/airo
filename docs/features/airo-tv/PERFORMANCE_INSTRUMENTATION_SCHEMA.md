# Performance Instrumentation Schema

Status: v2 platform contract for ATV-031.

## Ownership

Performance instrumentation is a shared platform contract. Airo TV, media
playback, playlist import, search, protocol, and UI code can emit samples
later, but metric names, units, buckets, safe dimensions, budget evaluation, and
sink boundaries belong in `packages/core_analytics`.

## Non-Goals

This issue does not implement:

- vendor analytics upload
- dashboards
- device profilers
- UI frame observers
- playback backend hooks
- app performance screens
- certified-device release thresholds

## Contract Shape

`AiroPerformanceSample` describes:

- sample id
- area
- metric
- unit
- numeric value
- bucket
- observation timestamp
- safe dimensions

`AiroPerformanceBudget` and `AiroPerformanceBudgetPolicy` provide deterministic
pass/fail checks for maximum and minimum thresholds.

`AiroPerformanceInstrumentationSink` is the adapter boundary. The package
includes:

- `AiroNoOpPerformanceInstrumentationSink`
- `AiroFakePerformanceInstrumentationSink`

## Covered Areas

- UI
- playback
- import
- search
- protocol
- command acknowledgement
- memory
- storage
- network
- pairing

## Privacy

Performance samples may expose stable ids, areas, metrics, units, buckets,
numeric values, and safe dimension ids only. They must not expose raw media
URLs, playlist URLs, EPG URLs, request headers, provider names or domains, local
paths, local addresses, credentials, titles, search text, viewing history,
device identifiers, analytics payloads, or diagnostic dumps.

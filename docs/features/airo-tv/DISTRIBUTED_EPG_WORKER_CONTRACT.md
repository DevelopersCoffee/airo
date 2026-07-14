# Distributed EPG Worker Contract

Status: v2 platform contract for ATV-034.

## Ownership

Distributed EPG work is platform/framework behavior. Airo TV, Lite Receiver,
companion nodes, desktop nodes, home nodes, future cloud orchestration, and QA
automation consume this contract instead of parsing full XMLTV datasets inside
receiver screens.

The contract lives in `packages/platform_epg` because that package already owns
compact EPG programs, slices, source refs, and repositories. `core_protocol`
owns binary protocol families. Secure transport owns connection and frame
validation. `core_media_data` owns benchmark dataset budgets. Product features
own rendering and navigation.

## Non-Goals

This issue does not implement:

- XMLTV download, decompression, or parsing
- provider SDK imports
- binary payload encoding
- device transfer
- persistent TV cache writes
- full guide UI
- app navigation
- playback

## Contract Shape

`DistributedEpgWorkerCapability` describes what a node can do: roles, supported
task kinds, payload formats, transfer modes, maximum request window, maximum
channel count, maximum entry count, snapshot size budget, and cache budget.

`DistributedEpgSyncRequest` asks a capable node for compact EPG work by stable
request id, redacted source ref, requested channel ids, window start/end, task
kind, payload format, and transfer mode.

`DistributedEpgSnapshotManifest` describes a produced compact snapshot or
incremental patch without exposing the payload: stable snapshot id, redacted
source ref, generated/expiry timestamps, covered window, channel count, entry
count, payload byte count, payload format, transfer mode, sequence, and
incremental flag.

`DistributedEpgWorkerPolicy` validates:

- schema version
- protocol version range
- required worker roles
- supported task kind
- supported payload format
- supported transfer mode
- valid and bounded request window
- channel count
- entry count
- snapshot byte size
- cache budget
- stale, expired, or future snapshots
- snapshot window coverage
- safe stable ids

`DistributedEpgWorker` is the provider boundary. `NoOpDistributedEpgWorker`
returns a deterministic unavailable event. `FakeDistributedEpgWorker` emits
queued, running, snapshot-ready, failed, or cancelled events without parsing,
network transfer, or persistence.

## Privacy

Worker capabilities, requests, manifests, events, and diagnostics expose only
stable ids, redacted source refs, counts, sizes, windows, progress, sequence
numbers, and blocker codes. They must not expose raw EPG URLs, playlist URLs,
request headers, local paths, local addresses, provider payloads, program
titles, viewing history, analytics payloads, or credential material.

## Automation

- Unit tests use fixed clocks and fake worker capabilities.
- Request policy tests cover role, task, format, transfer mode, window, channel
  count, and source-ref failures.
- Snapshot policy tests cover size, cache budget, entry count, stale, expired,
  future, and uncovered-window failures.
- Worker adapter tests cover no-op unavailable events, fake queued/running/ready
  events, and cancellation.

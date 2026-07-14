# Large Playlist Worker Pipeline

Status: v2 platform contract for ATV-029.

## Ownership

Large playlist import orchestration is platform behavior. Airo TV can display
progress or consume partial results later, but streamed parsing, normalization,
dedupe, batch writes, cancellation, and import diagnostics belong in
`packages/platform_playlist_import`.

The storage boundary is `AiroPlaylistBatchWriter`, so database engines can be
swapped without changing Airo TV product code.

## Non-Goals

This issue does not implement:

- isolate scheduling
- concrete database batch writes
- network download or resume logic
- generated large playlist fixtures
- Airo TV progress UI
- provider-specific shortcuts
- analytics upload

## Contract Shape

`AiroLargePlaylistImportPlan` describes:

- job id
- redacted source reference
- expected item count
- batch size
- max concurrency
- required worker stages
- partial availability behavior

`AiroLargePlaylistProgress` reports:

- current stage and status
- parsed, normalized, deduped, written, and failed counts
- batch index
- safe diagnostic codes
- completion ratio
- partial availability and terminal state helpers

`AiroPlaylistBatchWriter` is the persistence adapter boundary. It receives
batch counts and returns accepted/rejected counts without exposing channel
payloads in the contract.

## Required Stages

- `source_open`
- `parse`
- `normalize`
- `dedupe`
- `batch_write`
- `index`
- `finalize`

## Privacy

Worker diagnostics use stable ids, counts, stages, statuses, and blocker codes
only. They must not expose raw playlist URLs, local paths, local addresses,
request headers, provider payloads, viewing history, analytics payloads, or
device identifiers.

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

## Parser Hot-Path Contract

M3U channel normalization and deduplication remain owned by
`packages/platform_playlist_import`, not by Airo TV screens. The parser builds a
single normalized key per channel during parse using ASCII letter folding,
digit preservation, and punctuation/whitespace removal. This keeps duplicate
channel collapse reusable for Android TV, Fire TV, and future import workers.

Duplicate handling keeps the first normalized channel unless a later duplicate
has a logo and the existing channel does not. Deterministic tests cover this
logo-preference rule in both input orders so large playlists do not regress
while the Rust parser target is developed.

## Playlist URL Security

Playlist-derived stream and logo URLs are sanitized in platform code before
Airo TV UI consumes channel models. `platform_playlist_import` uses the shared
`AiroPlaylistUrlPolicy` to accept public HTTP(S) URLs and reject local files,
script/content schemes, URL credentials, localhost, link-local, and private
network hosts by default.

Unsafe stream entries are dropped from parsed channel output, and unsafe logo
values are stripped. Cast proxy relay targets use the same policy and require a
generated token on proxy requests, so malicious playlist content cannot cause
unauthenticated local relay fetches.

## Playlist Refresh Networking

The platform playlist importer owns HTTP validators for user-supplied M3U
sources. After a successful fetch, it stores `ETag` and `Last-Modified`
metadata with the user-derived cache. Forced refreshes send
`If-None-Match`/`If-Modified-Since` when validators exist, and a `304 Not
Modified` response returns the cached channel list instead of downloading a
full playlist body again.

Compression negotiation is explicit with `Accept-Encoding: gzip, deflate`.
HTTP/2 logo burst optimization remains a separate network slice; Airo TV UI
must continue to consume the platform importer rather than issuing playlist
refresh logic directly.

## Logo Image Rendering

Channel logo rendering is shared UI behavior, not screen-local image plumbing.
Airo TV logo widgets consume `AiroNetworkImage` from `packages/core_ui`, which
sets Flutter decode cache dimensions from the rendered size and device pixel
ratio. The TV entrypoint also applies `AiroImageCacheBudget.configureAndroidTv()`
so large playlists cannot leave the default process-wide `ImageCache`
unbounded.

This does not add disk LRU caching or HTTP/2 logo request coalescing. Those
remain separate platform/network slices.

## Privacy

Worker diagnostics use stable ids, counts, stages, statuses, and blocker codes
only. They must not expose raw playlist URLs, local paths, local addresses,
request headers, provider payloads, viewing history, analytics payloads, or
device identifiers.

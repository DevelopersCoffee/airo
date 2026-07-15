# Platform Playlist Import

Reusable playlist import contracts and services for Airo products.

This package owns playlist parsing and import pipeline boundaries that should
not be hard-coded inside Airo TV screens or tied to a concrete storage engine.

## Scope

- User-supplied M3U parsing and cache helpers.
- Generic import pipeline stage abstraction.
- Large playlist worker plan, progress, cancellation, partial availability,
  batch-write, and diagnostic contracts.
- Fake and no-op worker/batch-writer adapters for deterministic automation.

## M3U Deduplication Contract

The M3U parser normalizes channel names inside the platform package before
deduplication, so Airo TV screens consume already-collapsed channel lists.
Normalization is ASCII-only for stable M3U behavior: letters are folded to
lowercase, digits are preserved, and punctuation or whitespace is ignored.

When duplicate normalized names are found, the first channel is kept unless a
later duplicate has a logo and the existing channel does not. This preserves the
existing first-entry policy while making logo preference deterministic for large
user playlists.

## Playlist-Derived URL Policy

M3U stream URLs and `tvg-logo` values are validated while parsing. Unsafe stream
URLs are dropped before an `IPTVChannel` is created, and unsafe logo URLs are
stripped from otherwise valid channels. The parser uses the shared
`AiroPlaylistUrlPolicy` from `platform_channels`, which allows HTTP(S) public
network URLs and blocks credentials, local files, script/content schemes,
localhost, link-local, and private network hosts by default.

## Conditional Playlist Refresh

Playlist fetches send `Accept-Encoding: gzip, deflate` and reuse cached HTTP
validators when available. `ETag` is stored as `iptv_playlist_etag`, and
`Last-Modified` is stored as `iptv_playlist_last_modified` beside the
user-derived playlist cache.

On `304 Not Modified`, the parser returns the existing user-derived cache
without downloading or parsing a new response body. Changing or clearing the
playlist URL removes the cached body, timestamp, and validators together.

## Structured Playlist Cache

Fetched playlists are parsed once, then stored as structured `IPTVChannel` JSON
in the app support directory. Warm cache reads decode that channel cache through
the platform worker boundary instead of reparsing M3U text.

The legacy `iptv_playlist_cache` SharedPreferences M3U payload is removed on
cache reads and writes. SharedPreferences keeps only small metadata such as the
playlist timestamp and HTTP validators.

## Off-Main Parse Boundary

Async playlist fetches parse M3U through `AiroWorkerExecutor` from
`platform_worker_jobs`. Structured cache encode/decode also runs through that
worker boundary. This keeps large user-supplied M3U parsing and cache
serialization away from Airo TV screen code.

`parseM3U` remains synchronous for deterministic unit tests and small direct
inputs. Production callers should prefer `fetchPlaylist` or `parseM3UOffMain`
when content may be large.

This package does not choose a database engine, own Airo TV progress UI,
download provider-specific bundled content, expose raw playlist URLs in worker
diagnostics, or import storage SDKs directly. Concrete storage adapters should
plug in behind `AiroPlaylistBatchWriter`.

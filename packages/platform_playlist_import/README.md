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

This package does not choose a database engine, own Airo TV progress UI,
download provider-specific bundled content, expose raw playlist URLs in worker
diagnostics, or import storage SDKs directly. Concrete storage adapters should
plug in behind `AiroPlaylistBatchWriter`.

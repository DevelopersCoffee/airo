# Platform Channels

Reusable IPTV channel models, source helpers, and playlist-derived URL policy
for Airo products.

## Scope

- `IPTVChannel` and related channel metadata models.
- `ChannelDataService` for first-party channel data boundaries.
- `AiroChannelSearchIndex` for reusable channel search, filtering, sorting, and
  aggregate counts over loaded playlist data.
- `AiroPlaylistUrlPolicy` for validating stream and artwork URLs parsed from
  user-supplied playlist content.

## Playlist URL Policy

Playlist content is hostile input. `AiroPlaylistUrlPolicy` accepts only HTTP(S)
network URLs, rejects URL credentials, and blocks localhost, link-local,
private, carrier-grade NAT, multicast, and other non-public host ranges by
default.

Callers may opt into private hosts only after a product-level user consent flow
exists for LAN streams. Airo TV screens should consume the sanitized platform
models instead of revalidating stream and logo URLs in UI code.

## Channel Search Index

`AiroChannelSearchIndex` precomputes normalized channel search text and category
/ flavor counts once per loaded playlist. Airo TV providers should consume this
index instead of lowercasing channel names, rebuilding count maps, or running
separate category/flavor/search list passes on every keystroke.

The current implementation preserves the existing exact substring behavior for
channel name and group searches. Future Rust, trie, or tantivy-backed search can
replace the internals behind this platform-owned contract without moving search
logic back into product screens.

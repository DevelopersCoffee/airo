# Platform Channels

Reusable IPTV channel models, source helpers, and playlist-derived URL policy
for Airo products.

## Scope

- `IPTVChannel` and related channel metadata models.
- `ChannelDataService` for first-party channel data boundaries.
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

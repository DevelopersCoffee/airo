# Airo TV Remote View Model

ATV-064 defines the reusable platform model for compact remote views consumed by
Lite Receiver, Embedded Receiver, and other constrained Airo TV profiles.

The contract lives in `packages/core_remote_views` because compact remote views
need shared data limits, cache/expiry rules, redaction-oriented public maps, and
profile-specific render tiers. Airo TV app code should consume accepted remote
views and keep only layout, focus behavior, and product copy.

## Ownership

- Media owns compact search, EPG, favorites, compact-card, and ranked-stream
  item semantics.
- Data owns stable IDs, cache policy, expiry, and item limits.
- UI owns render tiers and profile-appropriate presentation rules.
- Security owns unsafe-reference rejection and redacted public maps.
- Airo TV app code must not fetch full datasets for constrained profiles when a
  compact remote view is available.

## Remote View Fields

`AiroRemoteView` includes:

- `schemaVersion`: remote-view schema version.
- `viewId`: stable view identifier.
- `type`: search results, current/next EPG, favorites, compact cards, or ranked
  backup streams.
- `profile`: target product profile.
- `renderTier`: rich, standard, or lightweight.
- `cachePolicy`: transient, cacheable, or pinned.
- `generatedAt` and `expiresAt`: cache window and expiry contract.
- `items`: compact `AiroRemoteViewItem` rows.

## Item Fields

`AiroRemoteViewItem` includes:

- `itemId`: stable item identifier.
- `kind`: media, channel, program, stream, or action.
- `primaryText` and optional `secondaryText`.
- optional `thumbnailRef`.
- `playable`: whether the row can initiate playback.
- `rank`: deterministic ordering for compact results and backup streams.
- optional `contentRef`, exposed publicly only as presence.

## Profile Rules

`AiroRemoteViewProfilePolicy` defines profile-specific limits:

- Full TV can consume richer and larger views.
- Standard TV can consume standard or lightweight views.
- Lite Receiver accepts lightweight views only, with search capped at 20 items,
  current/next EPG capped at 2 items, favorites/cards capped at 20 items, and
  ranked backup streams capped at 5 items.
- Embedded Receiver accepts lightweight views only with smaller limits.

## Validation

Remote view validation returns stable codes for:

- missing view ID
- expired view
- invalid cache window
- item count above profile/type limit
- unsupported render tier for the profile
- item missing display text
- unsafe references
- invalid negative rank

Accepted views return only `accepted`.

## Airo TV Consumption Rule

Airo TV should validate remote views before displaying search results, compact
guide rows, favorites, compact cards, or backup streams. Invalid or expired
views should be discarded or replaced by a local fallback/unavailable state
rather than rendered directly.

## Public Serialization

`toPublicMap()` exposes stable IDs, compact text, thumbnail refs, playable
state, rank, cache policy, expiry, item count, and redacted content-reference
presence. It does not expose local filesystem paths, provider payload markers,
store-console account data, raw credential material, or device logs.

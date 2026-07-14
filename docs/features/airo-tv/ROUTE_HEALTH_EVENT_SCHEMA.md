# Route Health Event Schema

Status: v2 platform contract for ATV-025.

## Ownership

Route health events are platform/framework session state. Playback engines,
receiver adapters, route recovery, companion controllers, and Airo TV screens
consume the same typed event stream instead of polling playback state or
inventing app-specific health payloads.

The schema lives in `packages/core_sessions` because playback ownership already
defines the session, route, owner, playback node, source node, and health
reporter authority.

## Event Shape

`AiroRouteHealthEvent` records:

- event id
- session id
- route id
- media id
- reporter node id
- playback node id
- source node id
- monotonic sequence
- event time
- event kind
- playback phase
- position and duration
- buffered-ahead duration
- volume and mute state
- audio and subtitle track ids
- playback speed
- route health level
- typed failure detail
- optional redacted diagnostic handle

Events are designed for event-driven state updates. They are not a transport,
analytics provider, playback engine, or persistence implementation.

## Stable Event Kinds

- `snapshot`
- `playback_state`
- `position`
- `buffer`
- `volume`
- `audio_track`
- `subtitle_track`
- `playback_speed`
- `route_health`
- `failure`
- `completed`

## Validation Codes

`AiroRouteHealthEventPolicy` returns stable validation codes:

- `accepted`
- `session_mismatch`
- `route_mismatch`
- `reporter_unauthorized`
- `non_positive_sequence`
- `stale_sequence`
- `invalid_position`
- `invalid_duration`
- `invalid_buffered_ahead`
- `invalid_volume`
- `invalid_playback_speed`
- `failure_missing`

The policy validates events against `AiroPlaybackOwnershipSnapshot`, so only
the current health reporter or playback owner can submit health events while
the ownership lease is valid.

## Privacy And Diagnostics

Route health diagnostics must expose stable ids, normalized health levels, and
typed failure categories. They must not expose raw stream URLs, local file
paths, network addresses, provider payloads, or access material. Optional
diagnostics use `AiroSessionPayloadHandle`, whose string representation is
redacted and whose constructor rejects unsafe raw values.

## Adapter Boundary

`AiroRouteHealthEventSink` is the publishing boundary. The package includes:

- `AiroNoOpRouteHealthEventSink` for products without a transport.
- `AiroFakeRouteHealthEventSink` for deterministic host-only tests.

No adapter in this issue collects player state, opens a socket, uploads
analytics, or updates Airo TV UI.

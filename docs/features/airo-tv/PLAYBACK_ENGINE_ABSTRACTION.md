# Airo TV Playback Engine Abstraction

This contract defines the v2.0.0.1 platform boundary for backend-agnostic
playback used by Airo TV, IPTV, Cast, future native media engines, command
routing, diagnostics, and certification.

Implementation contract:

- Package: `packages/platform_player`
- Schema: `kAiroPlaybackEngineSchemaVersion`
- Primary interface: `AiroPlaybackEngine`
- State model: `AiroPlaybackState`
- Request model: `AiroMediaOpenRequest`

## Engine Boundary

`AiroPlaybackEngine` defines:

- open;
- play;
- pause;
- stop;
- seek;
- volume;
- playback speed;
- quality selection;
- track selection;
- diagnostics;
- state stream;
- dispose.

The interface is backend-neutral. Existing IPTV/video_player and Cast code are
adapter candidates. Native Media3, LibVLC, MPV, FFmpeg-assisted, AVFoundation,
or other engines should implement the same contract later.

## Media Requests

`AiroMediaOpenRequest` carries an opaque `AiroPlaybackSourceHandle` instead of a
raw URL, file path, local network address, provider credential, playlist entry,
or viewing-history value.

Adapters may resolve the handle internally after platform authorization and
route selection. Product UI should never log or render the raw media source from
this boundary.

## State And Diagnostics

`AiroPlaybackState` reports:

- backend kind;
- phase;
- request ID;
- position and duration;
- volume;
- playback speed;
- quality options and selection;
- track options and selection;
- typed diagnostics;
- typed errors.

Diagnostics must use stable codes and backend identifiers. They must not expose
media source URLs, local paths, local IP addresses, provider credentials,
analytics payloads, raw crash details, or viewing history.

## Adapter Rule

Airo TV, IPTV features, command routing, route selection, and future
certification checks should consume `platform_player` playback engine contracts.
Product code may render controls, copy, and recovery flows, but backend
selection, state semantics, typed errors, and diagnostics belong to the platform
contract.

## Out Of Scope

This issue does not choose or implement a native backend, decoder probing,
fallback policy, playback widgets, Protobuf schemas, command transport, or
session persistence.

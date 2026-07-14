# Protobuf Protocol Schemas

Status: v2 platform contract for ATV-032.

## Ownership

Binary protocol schema governance is platform behavior. Airo TV, companion
controllers, local discovery, secure WebSocket transport, command routing,
session state, route health, and EPG sync can consume the protocol contracts,
but message-family descriptors, field numbers, schema compatibility, sequence
checks, payload-size limits, and replay blockers belong in
`packages/core_protocol`.

`core_commands` remains the source of command envelope semantics.
`core_sessions` remains the source of playback/session and route-health state.
Future EPG sync packages own compact EPG payload semantics.

## Non-Goals

This issue does not implement:

- generated Dart, native, or desktop Protobuf code
- protoc build scripts
- secure WebSocket transport
- encryption or signing
- cloud relay behavior
- EPG compression
- app command handling

## Contract Shape

`AiroProtobufSchemaRegistry` describes supported message families:

- envelope
- command
- playback state
- route health
- EPG sync
- acknowledgement

`AiroProtobufMessageDescriptor` defines stable message names, field numbers,
field types, required fields, and reserved field numbers.

`AiroProtobufCompatibilityPolicy` validates:

- schema version
- protocol version range
- replay sequence
- positive sequence numbers
- payload size
- required fields
- duplicate field numbers
- reserved field conflicts
- safe message ids

The canonical source schema lives at:

- `packages/core_protocol/proto/airo_v2_protocol.proto`

## Privacy

Protocol schema descriptors and compatibility probes expose only stable ids,
field numbers, field types, payload sizes, sequence ids, and blocker codes. They
must not expose raw media URLs, playlist URLs, EPG URLs, request headers, local
paths, local addresses, credentials, provider payloads, titles, search text,
viewing history, analytics payloads, diagnostic dumps, or credential material.

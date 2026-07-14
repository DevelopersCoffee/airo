# Secure WebSocket Transport Contract

Status: v2 platform contract for ATV-033.

## Ownership

Secure command and state transport is platform/framework behavior. Airo TV,
companion controllers, home nodes, local discovery, command routing, session
sync, route health, compact EPG sync, and future cloud coordination consume the
same contract instead of adding product-specific socket shortcuts.

The contract lives in `packages/core_protocol` because it defines versioned
transport metadata, handshake validation, frame validation, redaction, fake
adapters, and no-op adapters. `core_pairing` owns pairing and trust semantics,
`core_commands` owns command payload semantics, and `core_sessions` owns
playback/session state semantics.

## Non-Goals

This issue does not implement:

- real WebSocket clients or servers
- TLS certificate storage, pinning, or platform key generation
- cloud relay/provider selection
- push wake behavior
- command dispatch
- playback execution
- persistent device records
- app UI

## Contract Shape

`AiroSecureTransportEndpointDescriptor` describes a transport endpoint by stable
id, channel kind, secure scheme, supported auth modes, supported frame kinds,
frame-size budget, heartbeat interval, reconnect base delay, and trust
requirements.

`AiroSecureTransportHandshakeOffer` describes a redacted connection attempt from
a peer device. It carries stable peer id, trust state, auth mode, proof
presence, issue/expiry timestamps, optional credential expiry, and requested
frame families.

`AiroSecureTransportFrameProbe` describes a frame before it is sent or accepted.
It carries stable frame id, frame kind, monotonic sequence, issue timestamp,
payload byte count, proof presence, and an optional redacted diagnostic
reference.

`AiroSecureTransportPolicy` validates:

- schema version
- protocol version range
- secure scheme per channel kind
- supported auth mode
- proof presence
- handshake expiry
- credential expiry
- trusted peer state
- supported frame kinds
- positive monotonic sequence
- replayed sequence
- frame size
- stale/future frame timestamps
- safe diagnostic references

`AiroSecureTransportAdapter` is the provider boundary. `AiroNoOpSecureTransportAdapter`
rejects all work for products without transport support. `AiroFakeSecureTransportAdapter`
validates and records frame probes for deterministic host-side tests without
opening sockets.

## Privacy

Transport descriptors, offers, frame probes, and validation results expose only
stable ids, channel/scheme/auth/frame families, timing metadata, payload byte
counts, sequence numbers, proof presence, trust state, and blocker codes. They
must not expose raw URLs, local IP addresses, request headers, provider payloads,
credentials, media titles, search text, viewing history, analytics payloads, or
diagnostic dumps.

## Automation

- Unit tests use fixed clocks and fake descriptors.
- Handshake tests cover accepted, insecure scheme, missing proof, expired
  handshake/credential, untrusted peer, and unsupported frame kinds.
- Frame tests cover accepted, replayed sequence, oversized payload, stale/future
  timestamps, unsupported frame kind, missing proof, and unsafe diagnostic ref.
- Adapter tests cover no-op rejection and fake adapter recording without opening
  sockets.

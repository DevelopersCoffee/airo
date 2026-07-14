# Core Protocol

Shared connected-node protocol contracts for Airo V2.

This package is platform/framework code. Airo TV, mobile companion, desktop
companion, home node, local discovery, pairing, command routing, AI delegation,
and future cloud coordination consume these contracts to describe device nodes
without leaking private media or account data.

## Scope

- Stable node identity records.
- Node lifecycle states.
- Privacy-safe capability advertisements.
- Compatibility policies and deterministic blocker codes.
- Edge Media Node placeholder profiles, service descriptors, policy blockers,
  and fake/no-op registries for future home-node work.
- Protobuf protocol schema descriptors for envelopes, commands, playback state,
  route health, compact EPG sync, and acknowledgements.
- Compatibility policy for schema/protocol version, replay sequence, payload
  size, required fields, reserved fields, and stable ids.

This package does not discover devices, open sockets, store trust records,
render pairing UI, send commands, maintain presence leases, index media, relay
traffic, record media, transcode, run AI workers, generate Protobuf code, or
coordinate cloud state.

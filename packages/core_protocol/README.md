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

This package does not discover devices, open sockets, store trust records,
render pairing UI, send commands, maintain presence leases, or coordinate cloud
state.

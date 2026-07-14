# Platform Network Discovery

Local network discovery abstractions for Airo connected nodes.

This package is platform/framework code. Airo TV, mobile companion, desktop
companion, home node, pairing, command routing, and QA automation consume this
contract before native mDNS/DNS-SD adapters exist.

## Scope

- `_airotv._tcp` service metadata contract.
- Privacy-safe discovery TXT record generation and validation.
- Discovery snapshots with stale filtering and duplicate-node merge.
- No-op and in-memory fake adapters for host-only tests.

This package does not implement native mDNS/DNS-SD, ask local-network
permissions, open sockets, pair devices, send commands, or render UI.

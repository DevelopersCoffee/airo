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
- `UnifiedDiscoveryService` for mDNS/DNS-SD, SSDP/UPnP, existing Cast, and
  AirPlay adapter snapshots. It deduplicates logical receivers while retaining
  every compatible protocol route and isolates per-mechanism failure.

Native/SDK adapters remain host-specific and translate into
`DiscoveryMechanismAdapter`; this package does not import their SDK types, ask
local-network permissions, pair devices, send commands, or render UI.

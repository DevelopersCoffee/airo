# Airo TV Local Discovery Abstraction

This contract defines the v2.0.0.1 platform boundary for same-network Airo node
discovery. It prepares the project for mDNS/DNS-SD service `_airotv._tcp`
without committing to a native adapter in this issue.

Implementation contract:

- Package: `packages/platform_network_discovery`
- Schema: `kAiroDiscoverySchemaVersion`
- Service type: `kAiroDiscoveryServiceType == "_airotv._tcp"`
- Protocol dependency: `packages/core_protocol`

## Public Discovery Metadata

Discovery metadata is derived from `AiroNodeCapabilityAdvertisement` and may
include only:

- discovery schema;
- `_airotv._tcp` service type;
- connected-node schema and protocol version;
- stable node ID;
- node role;
- product profile;
- platform category;
- lifecycle;
- public capability IDs;
- expiry timestamp.

Discovery metadata must not include playlist names, media URLs, provider
credentials, local IP addresses, local file paths, viewing history, raw search
text, or voice transcripts.

## Adapter Boundary

`AiroLocalDiscoveryAdapter` defines:

- stream of discovery snapshots;
- start with advertise, browse, or advertise-and-browse mode;
- stop;
- current snapshot.

The package includes:

- `AiroNoOpLocalDiscoveryAdapter` for unsupported platforms and disabled local
  network permissions;
- `AiroFakeLocalDiscoveryAdapter` for deterministic host-only tests.

Real Android, iOS, desktop, and Fire TV discovery adapters should implement the
same contract later. Product UI should render adapter states and permission
states rather than branch on platform-specific discovery APIs.

## Release Rule

Airo TV, companion, pairing, command, and AI flows should consume
`platform_network_discovery` snapshots. Standalone playback must continue when
local discovery is unavailable, denied, blocked by multicast restrictions, or
not yet implemented for a platform.

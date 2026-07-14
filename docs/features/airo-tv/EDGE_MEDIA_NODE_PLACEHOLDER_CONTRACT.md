# Edge Media Node Placeholder Contract

Status: v2 platform contract for ATV-026.

## Ownership

Edge Media Node is future platform infrastructure. It may eventually index
media, enrich metadata, monitor stream health, relay trusted access, schedule
recordings, transcode, and run always-on AI tasks from a desktop or home node.

The placeholder contract lives in `packages/core_protocol` because it extends
the connected-node protocol: identity, role, lifecycle, trust state,
capability advertisements, and privacy-safe compatibility checks.

## Non-Goals

This issue does not implement:

- media indexing
- file scanning
- relay tunnels
- recording
- transcoding
- desktop services
- AI workers
- local discovery
- Airo TV UI

The contract only makes future work compatible with v2 protocol decisions.

## Contract Shape

`AiroEdgeMediaNodeProfile` combines a connected-node advertisement with
normalized service descriptors. Supported service ids are:

- `media_indexing`
- `metadata_enrichment`
- `stream_health`
- `relay`
- `recording`
- `transcoding`
- `ai_processing`
- `artwork_processing`

Each service descriptor has a state:

- `placeholder`
- `planned`
- `available`
- `disabled`
- `unavailable`

Only `available` services are executable. Placeholder and planned services keep
the protocol shape visible without claiming runtime support.

## Policy

`AiroEdgeMediaNodePolicy` evaluates a requested service against:

- connected-node role
- lifecycle state
- trust state
- advertisement freshness
- required connected-node capability
- service descriptor presence
- service executability
- local-network scope
- explicit risk opt-ins for relay, recording, and transcoding

Stable blocker codes:

- `accepted`
- `schema_mismatch`
- `stale_advertisement`
- `incompatible_role`
- `lifecycle_unavailable`
- `untrusted_node`
- `blocked_node`
- `missing_connected_node_capability`
- `service_missing`
- `service_not_executable`
- `local_network_required`
- `relay_not_allowed`
- `recording_not_allowed`
- `transcoding_not_allowed`

## Adapter Boundary

`AiroEdgeMediaNodeRegistry` lists candidate profiles. The package includes:

- `AiroNoOpEdgeMediaNodeRegistry` for products with no Edge Media Node support.
- `AiroFakeEdgeMediaNodeRegistry` for deterministic tests.

No registry in this issue discovers, connects to, or executes work on a node.

## Privacy

Profiles and diagnostics expose stable node ids, roles, service ids, service
states, and blocker codes only. They must not expose provider credentials, raw
media URLs, local file paths, recording payloads, relay addresses, or transcoder
internals.

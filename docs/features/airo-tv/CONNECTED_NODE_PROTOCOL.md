# Airo TV Connected-Node Protocol

This contract defines the v2.0.0.1 platform boundary for connected Airo nodes.
It must exist before local discovery, QR pairing, phone remote, command routing,
AI delegation, handoff, or cloud coordination can advertise device support.

Implementation contract:

- Package: `packages/core_protocol`
- Schema: `kAiroNodeProtocolSchemaVersion`
- Protocol version: `kAiroNodeProtocolVersion`
- Evaluator: `AiroNodeCompatibilityPolicy.evaluate`

## Public Advertisement Fields

Capability advertisements may expose only:

- schema and protocol version;
- stable node ID;
- node role;
- product profile;
- platform category;
- lifecycle state;
- capability IDs;
- issue and expiry timestamps.

Advertisements must not include playlist names, source URLs, account details,
credential material, viewing history, local network addresses, or user-entered
search text.

## Lifecycle States

| State | Compatibility behavior |
| --- | --- |
| `available` | Eligible for negotiation |
| `pairing` | Eligible for pairing-oriented negotiation |
| `connected` | Eligible for authenticated/private negotiation |
| `busy` | Eligible, but consumers may prefer another node |
| `sleeping` | Not eligible until refreshed |
| `offline` | Not eligible |
| `incompatible` | Not eligible |
| `update_required` | Not eligible |
| `blocked` | Not eligible |

## Compatibility Rules

Consumers evaluate a node through `AiroNodeCompatibilityPolicy` using required
capabilities, schema version, protocol version, trust requirement, and
advertisement freshness.

Stable blocker codes:

- `schema_mismatch`
- `protocol_too_old`
- `protocol_too_new`
- `stale_advertisement`
- `missing_capability`
- `lifecycle_unavailable`
- `untrusted_node`
- `blocked_node`

## Release Rule

Airo TV, companion, discovery, pairing, command, AI, and cloud layers should use
`core_protocol` for node identity and capability compatibility. Product code may
render the resulting state, but it should not invent a separate node model or
advertise private media/account data.

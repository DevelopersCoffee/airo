# Device Presence Lease Model

Status: v2 platform contract for ATV-039.

## Ownership

Device presence is platform/framework behavior. Airo TV, companion apps, cloud
orchestration, backend adapters, device pickers, command routing, and QA
automation consume the contract to evaluate whether devices are currently
available without inventing app-local freshness rules.

The contract lives in `packages/core_presence`. Adjacent packages retain their
ownership: `core_device_identity` owns registered identity and revocation/reset
state, while `core_protocol` owns node lifecycle and capability names.

## Non-Goals

This issue does not implement:

- backend storage
- WebSocket transport
- push notification delivery
- device registration
- command routing
- playback execution
- media proxying
- app UI

## Contract Shape

`AiroPresenceLease` is the canonical lease record: stable lease/account/device
ids, registration id, status, node lifecycle, visibility, visible capabilities,
sequence, issue time, last heartbeat time, expiry, and heartbeat interval.

`AiroPresenceHeartbeat` is the input request used to create or update a lease.

`AiroPresencePolicy` returns deterministic decisions:

- accept
- expire
- deny
- no-op

Decision codes cover schema/protocol mismatch, unsafe stable ids, unregistered
devices, account/device/registration mismatch, revoked or reset-required
devices, stale heartbeat sequences, expired leases, heartbeat cadence failures,
lease duration failures, visibility denial, and unavailable stores.

`AiroPresenceStore` is the provider boundary. `AiroNoOpPresenceStore` never
opens a provider connection. `AiroFakePresenceStore` evaluates heartbeats,
stores accepted leases in memory, and expires leases deterministically for
host-side tests.

## Privacy Rules

- Public presence maps expose only stable ids, status, lifecycle, visibility,
  visible capabilities, sequence, and timing metadata.
- Presence must not expose raw host names, local addresses, media URLs,
  playlist paths, backend payloads, viewing history, or account-sensitive data.
- Visibility is explicit and policy-gated. Product code can render visibility,
  but cannot widen it without passing the platform policy.

## Automation

- Unit tests use fixed clocks, deterministic leases, and registered device
  records.
- Policy tests cover accepted heartbeats, stale sequences, expired leases,
  cadence bounds, lease duration bounds, visibility denial, unregistered
  devices, revoked/reset devices, and identity mismatches.
- Adapter tests cover fake/no-op stores without network or persistence side
  effects.

# Local/Cloud Device Merge Contract

Status: v2 platform contract for ATV-043.

## Ownership

Local/cloud device merge behavior is platform/framework behavior. Airo TV,
companion apps, device pickers, cloud orchestration, presence, routing, and QA
automation consume this contract to merge LAN advertisements with cloud device
records without duplicating trust, freshness, or privacy rules in product UI.

The contract lives in `packages/core_device_merge`. Adjacent packages retain
their ownership: `core_device_identity` owns registered device records and
revocation/reset state, `core_presence` owns presence leases and visibility, and
`core_protocol` owns local connected-node advertisements and capabilities.

## Non-Goals

This issue does not implement:

- LAN browsing
- backend storage
- cloud provider selection
- playback execution
- media routing execution
- app UI
- media proxying

## Contract Shape

`AiroLocalDeviceObservation` wraps a local connected-node advertisement with a
fixed observation timestamp.

`AiroCloudDeviceObservation` wraps a registered device record with an optional
presence lease.

`AiroMergedDevice` is the privacy-safe device-picker summary: stable device id,
node id, role, product profile, platform category, reachability, primary source,
capabilities, optional presence status, lifecycle, last seen time, and merge
codes.

`AiroDeviceMergePolicy` returns deterministic merged devices and codes. It
prefers LAN when local and cloud records identify the same node, preserves cloud
reachability metadata, hides cloud-only records in local-only mode, and carries
blocker codes for revoked, reset-required, stale, incompatible, untrusted,
unavailable, and update-required devices.

`AiroDeviceMergeSource` is the provider boundary. `AiroNoOpDeviceMergeSource`
returns no devices. `AiroFakeDeviceMergeSource` returns fixed local/cloud inputs
for host-side tests.

## Privacy Rules

Merged summaries expose only stable ids, roles, product/platform categories,
reachability, capabilities, presence status, lifecycle, timestamps, and codes.
They must not expose raw hostnames, local IP addresses, media URLs, playlist
paths, provider payloads, credentials, current media titles, viewing history, or
diagnostic dumps.

## Automation

- Unit tests use fixed clocks, deterministic advertisements, registered records,
  and presence leases.
- Policy tests cover local+cloud duplicate merge, LAN preference, cloud-only
  fallback, local-only hiding, revoked/reset suppression, stale presence,
  expired advertisements, untrusted advertisements, incompatible capability
  requirements, update-required state, and redacted public maps.
- Source tests cover fake/no-op behavior without network, provider, backend, or
  app UI dependencies.

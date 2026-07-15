# Cloud Orchestration Boundary

Status: v2 platform contract for ATV-037.

## Ownership

Cloud orchestration is platform/framework behavior. Airo TV, companion apps,
home nodes, command routing, session sync, device registry, presence, playback
ticket brokering, notification wake, recovery, backend adapters, and QA
automation consume this contract to coordinate devices and state without making
cloud a playback dependency.

The contract lives in `packages/core_cloud_orchestration`. Adjacent packages
retain their ownership: `core_commands` owns command envelopes, `core_sessions`
owns receiver-authoritative state, `core_pairing` owns trust/scopes/tickets,
`core_media_routing` owns media paths, and `core_protocol` owns transport and
binary protocol contracts.

## Non-Goals

This issue does not implement:

- cloud provider selection
- persistent backend storage
- WebSocket transport
- push notifications
- device registration storage
- presence leases
- entitlement checks
- media proxying
- playback execution
- app UI

## Contract Shape

`AiroCloudOrchestrationManifest` describes which cloud services are enabled,
which mode is active, the required trust level, payload and retention limits,
provider availability, and whether media proxying is forbidden.

`AiroCloudOrchestrationRequest` describes a redacted cloud coordination attempt:
service kind, actor and target ids, trust level, granted scopes, optional
session/command ids, route kind, media-proxy flag, payload size, retention,
revision values, and issue/expiry timestamps.

`AiroCloudOrchestrationPolicy` returns a deterministic decision:

- allow
- deny
- local fallback
- no-op

Decision codes cover schema/protocol mismatch, cloud disabled, local-only mode,
unsupported services, discovery-only mode, untrusted or revoked actors, missing
scope, expired requests, unsafe stable ids, media proxy attempts, payload and
retention limits, stale revisions, duplicate commands, and provider
unavailability.

`AiroCloudOrchestrator` is the provider boundary. `AiroNoOpCloudOrchestrator`
never opens a provider connection. `AiroFakeCloudOrchestrator` evaluates and
records accepted requests for deterministic host-side tests.

## Local-First Rules

- Same-LAN control and playback must continue when cloud is disabled,
  unavailable, or local-only mode is active.
- Cloud may coordinate commands, presence, state, recovery, notifications, and
  ticket brokering.
- Cloud must not proxy receiver media by default.
- A command delivered over LAN and cloud must execute once through stable
  command ids and duplicate suppression.

## Privacy

Cloud orchestration manifests, requests, decisions, and diagnostics expose only
stable ids, service ids, mode, route kind, sizes, retention, revisions, and
blocker codes. They must not expose raw media URLs, playlist URLs, EPG URLs,
request headers, provider payloads, local paths, local addresses, credentials,
media titles, viewing history, analytics payloads, or diagnostic dumps.

## Automation

- Unit tests use fixed clocks, manifests, and requests.
- Policy tests cover allowed, denied, and local-fallback decisions.
- Adapter tests cover fake/no-op coordinators without network or persistence
  side effects.

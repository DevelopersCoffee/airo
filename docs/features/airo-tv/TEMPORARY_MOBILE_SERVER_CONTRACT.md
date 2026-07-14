# Temporary Mobile Server Contract

Status: v2 platform contract for ATV-023.

## Ownership

The secure temporary mobile server boundary is platform/framework code. Airo TV
uses it to decide whether a phone-local media item may be served to a trusted
receiver, but the app does not own the lifecycle rules.

The contract is defined in `packages/core_media_routing` so phones, TVs,
desktop relays, QA automation, and future receivers can share the same
deterministic validation model.

## Required Server Guarantees

A temporary mobile server route is eligible only when all of these guarantees
are represented in the platform snapshot:

- LAN-only exposure.
- Trusted receiver scope.
- Receiver allow-list binding.
- Expiring route access grant.
- Playback, range-read, and probe-read grant scopes.
- HTTP range support.
- HEAD/probe support.
- Entity validation for resumed reads.
- Auto shutdown on expiry.
- Idle shutdown.
- Battery and thermal host gates.

The contract intentionally stores opaque route handles only. Diagnostics must
show ids, capability names, stable blocker codes, and redacted access state, not
raw local URLs, addresses, file paths, or access material.

## Deterministic Validation

`AiroTemporaryMobileServerPolicy` returns stable blocker codes for route
preflight:

- `accepted`
- `server_unavailable`
- `expired`
- `idle_timeout_exceeded`
- `local_network_required`
- `trusted_receiver_required`
- `receiver_not_allowed`
- `grant_audience_mismatch`
- `grant_expired`
- `grant_scope_missing`
- `range_requests_required`
- `head_probe_requests_required`
- `entity_validation_required`
- `auto_shutdown_required`
- `idle_shutdown_required`
- `battery_too_low`
- `thermal_too_high`
- `concurrent_receiver_limit_exceeded`

The default policy requires at least 20 percent battery unless the host is
charging, thermal state no higher than warm, one active receiver, LAN scope,
trusted receiver scope, playback/range/probe grant scopes, range requests,
HEAD/probe handling, entity validation, and auto shutdown on expiry.
Idle shutdown is also required so abandoned phone-local routes do not keep the
host awake indefinitely.

## Adapter Boundary

`AiroTemporaryMobileServerController` is an interface for platform adapters.
The package includes:

- `AiroNoOpTemporaryMobileServerController` for products without a backend.
- `AiroFakeTemporaryMobileServerController` for deterministic tests and route
  preflight automation.

Neither adapter starts a network listener or serves media. Production mobile
server code must live behind this interface and satisfy the same policy before
the route engine can choose phone-local serving.

# Temporary Mobile Server Contract

Status: v2 platform contract for ATV-023 and ATV-055.

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

## Phone-Local Serving Requirements

ATV-055 adds deterministic serving decisions for real phone-local files without
starting a network listener in the contract package. A production adapter must
map the platform decision to actual file I/O.

Required behavior:

- `GET` requests for seekable playback require a valid single byte range.
- Valid range `GET` requests return `206 Partial Content` metadata with
  `Accept-Ranges`, `Content-Length`, `Content-Range`, and an entity validator.
- `HEAD` probe requests return headers only and never stream body bytes.
- Multi-range requests are rejected.
- Missing, malformed, unknown-length, and out-of-bounds ranges return stable
  rejection codes.
- Cancelled requests are rejected before any stream is opened.
- Expired grants, expired server snapshots, idle timeout, unauthorized receiver,
  low battery, and hot thermal state reject before serving decisions emit
  response headers.
- Public diagnostics expose stable ids, status codes, requirement codes, and
  numeric byte ranges only.

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

Serving decisions add stable codes for:

- `accepted`
- `unsupported_method`
- `range_header_required`
- `range_header_malformed`
- `multi_range_unsupported`
- `range_not_satisfiable`
- `unknown_media_length`
- `entity_validator_missing`
- `cancelled`

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
  preflight and serving automation.

Neither adapter starts a network listener or serves media. Production mobile
server code must live behind this interface and satisfy the same policy before
the route engine can choose phone-local serving.

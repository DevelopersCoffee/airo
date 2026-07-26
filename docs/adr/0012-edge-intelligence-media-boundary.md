# ADR-0012: Edge intelligence and media-engine boundary

## Status

Accepted

## Date

2026-07-27

## Context

Airo's on-device intelligence can translate natural-language requests into
media actions, while player and stream packages own media execution. Direct
imports between those layers would couple model output, player backends, and
product orchestration. It would also allow unvalidated model output to reach
playback code.

Milestone issue
[#899](https://github.com/DevelopersCoffee/airo/issues/899) requires a typed
bridge and a mechanically enforced dependency boundary. The intended upstream
schema authority is
[`DevelopersCoffee/barista-tuning#2`](https://github.com/DevelopersCoffee/barista-tuning/issues/2).
At acceptance time, schema contents must be identical across repositories.

## Decision

`packages/core_edge_intelligence` owns `IntentCommand/v1`, validation, and the
player-agnostic `IntentExecutor` interface.

- Intelligence packages may emit and validate commands but must not import
  `platform_player`, `platform_streams`, or `core_media_routing`.
- Media packages must not import `core_ai` or `core_edge_intelligence`.
- Application-owned adapters may import both sides, implement
  `IntentExecutor`, and map validated commands onto media-engine APIs.
- Model output fails closed. Unknown fields, enum values, types, and
  out-of-range confidence values are rejected before execution.
- v1 schema changes are additive only. Breaking changes use a new major schema
  path and Dart API.
- The vendored Airo schema cannot be described as an upstream mirror while its
  bytes or semantic shape differ from the upstream artifact.

The host-only `scripts/check-edge-import-boundaries.py` gate enforces the
package-import rules in pull requests.

## Consequences

### Positive

- Intelligence and player implementations can evolve independently.
- Model output has one typed, testable validation boundary.
- Import violations fail deterministically before merge.
- Player URLs, credentials, and backend exceptions do not enter the intent
  contract.

### Negative

- A small application adapter is required to connect the two layers.
- Schema changes require coordinated versioning across repositories.

### Risks

- The linked upstream schema currently differs from milestone #899's required
  command shape. The package README records the drift; issue closure requires
  upstream reconciliation and a drift check.
- A source scan does not replace architectural review of runtime reflection or
  generated code. Those mechanisms must not be used to bypass the boundary.

## Alternatives Considered

### Put intent types in player packages

Rejected because this makes intelligence depend on a playback implementation
and violates the two-layer architecture.

### Let intelligence call player services directly

Rejected because it bypasses validation, couples model vocabulary to backend
APIs, and makes deterministic testing harder.

### Reuse `core_commands`

Rejected because that package owns connected-device command envelopes,
idempotency, expiry, and transport lifecycle—not SLM media-query semantics.

## Related Decisions

- [ADR-0001](0001-package-structure.md) - Modular Package Structure

## References

- [Milestone issue #899](https://github.com/DevelopersCoffee/airo/issues/899)
- [Upstream schema issue](https://github.com/DevelopersCoffee/barista-tuning/issues/2)

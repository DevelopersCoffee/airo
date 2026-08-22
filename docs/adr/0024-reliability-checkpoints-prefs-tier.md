# ADR 0024 — Reliability checkpoint metadata uses the Prefs tier

## Status

Accepted (follow-up to [ADR-0023](0023-mind-reliability-checkpoints-in-process.md);
names an existing store)

## Date

2026-08-22

Deciders: Chief Architect (module boundaries / ADRs), Chief Security Officer
(no prompt bodies on disk).

## Context

ADR-0023 keeps reasoning reliability checkpoints in-process and forbids a new
`MindOpKind`. Disk durability was explicitly out of scope until a follow-up
named an **existing** store.

[ADR-0008](0008-storage-tiering-and-preference-size-guards.md) already defines
the Prefs tier: `SharedPreferences` via `KeyValueStore` / `PreferencesStore`,
max 64 KB per value, for small strings. A bounded ring of PM / AIRO-R ids is
well under that limit.

A new file, Drift table, EventBus topic, or operation-log kind would be a new
store. This ADR does not create one.

## Decision

1. **Store.** Persist the encoded `ExecutionLog` ring on the Prefs tier under
   the key `airo.mind.reliability_checkpoints.v1`, through `KeyValueStore`.
   Production uses `PreferencesStore`. Tests use an in-memory
   `ReliabilityCheckpointStore`.

2. **Payload.** JSON array of objects with only `executionId`, `failureMode`,
   `runtimeError`. No prompt, system prompt, completion, tool result, IR, or
   token fields. Decode reads those three keys and ignores everything else.

3. **Still not an operation.** Do not call `OperationLogPort.append`. Do not
   add `MindOpKind`.

4. **Best-effort.** Prefs I/O must not block or fail a chat turn. Hydrate
   before the first generate when a store is attached; persist after a
   classifier hit. A missing or corrupt value is an empty ring.

5. **Process death.** The Prefs value is what survives. In-process
   `ExecutionLog` remains the live ring (ADR-0023).

## Contract Impact

| Question | Answer |
|---|---|
| Which runtime contracts change? | None. C1–C7 and `MindRuntime` ports are unchanged. Prefs tier usage matches ADR-0008. |
| Which conformance tests become invalid? | None. In-process `lastReliabilityDiagnostic` remains valid. |
| Which benchmarks must be re-run? | None. |
| Which review roles must re-review? | Chief Architect (ADR), Chief Security Officer (payload has no prompt bodies). |
| Is G0 required again? | No. No crate public surface change beyond a small JSON codec on existing types. |

## Consequences

### Positive

- Empty Cloud / LiteRT failures survive app restart as PM / AIRO-R ids.
- Payload size stays inside the 64 KB prefs guard.

### Negative

- Prefs is not encrypted. That is acceptable only because the value contains
  no user content — only execution ids and taxonomy codes.
- Uninstalling the app clears the ring with other prefs.

### Risks

- A future change adding prompt text to the JSON would violate ADR-0023.
  Tests must keep asserting the encoded dump has no prompt body.

## Alternatives Considered

### Alternative 1: New file under application support

Rejected. That is a new store. ADR-0023 required naming an existing one.

### Alternative 2: `OperationLogPort.append`

Rejected. Same as ADR-0023: checkpoints are not Mind operations.

### Alternative 3: Secure storage

Rejected. There are no credentials in this payload. Secure storage is for
tokens and keys (ADR-0008).

## Related Decisions

- [ADR-0008](0008-storage-tiering-and-preference-size-guards.md) — Prefs tier
- [ADR-0023](0023-mind-reliability-checkpoints-in-process.md) — in-process ring
- [ADR-0021](0021-mind-runtime-port.md) — do not use `OperationLogPort` here

## References

- `packages/core_data/lib/src/storage/preferences_store.dart`
- `packages/core_ai/lib/src/reliability/failure_classifier.dart`

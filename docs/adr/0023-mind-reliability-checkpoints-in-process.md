# ADR 0023 — Mind reliability checkpoints stay in-process

## Status

Accepted (records [Architecture Freeze v1](../AIRO_MIND_ARCHITECTURE_FREEZE_v1.md);
no new primitive)

## Date

2026-08-22

Deciders: Chief Architect (module boundaries / ADRs), Chief Security Officer
(no prompt bodies on disk), Edge Architect (offline/caching consult).
This ADR does not add a `MindOpKind` and does not change `OperationLogPort`.

## Context

Reasoning reliability classifies empty or failed completions as PM-06 / PM-08
and AIRO-R06 / AIRO-R07. Rust already has an in-process `ExecutionLog` whose
`PersistableDiagnostic` fields are classification metadata only.

Dart chat kept a single `lastReliabilityDiagnostic` slot. That is not a
checkpoint log: a later successful turn erases the previous failure, and
nothing records that the payload must never include the prompt.

The freeze already forbids inventing a durable operation kind for this. A
second store, a new `MindOpKind`, or writing raw prompts / IR / completions
would be a new primitive.

## Decision

1. **Checkpoints are in-process.** Dart mirrors Rust `ExecutionLog`: a bounded
   ring of `PersistableDiagnostic` values on the assistant runtime (and any
   later caller that already classifies completions). Process death drops
   them. That is accepted.

2. **Metadata only.** Allowed fields are execution id, failure mode, runtime
   error, and (when added later) stage / recovery / model id. Forbidden:
   prompt text, system prompt, completions, tool results, retrieved notes,
   IR, tokens.

3. **No `MindOpKind`.** Reliability checkpoints are not operations. They must
   not call `OperationLogPort.append`. Meeting IR mapping stays ADR-0022.

4. **Disk durability is out of scope.** Rust `ExecutionLog::persistable`
   describes the *shape* of a future writer. Wiring that shape to a file,
   EventBus topic, or telemetry backend needs a follow-up ADR that names an
   existing store. This ADR does not create one.

5. **Prefix cache stays an adapter capability.** llama.cpp `n_keep` / KV reuse
   is not a Mind primitive. `llama-cpp-2` 0.1.153 does not expose `n_keep`.
   The llama generation engine reuses an **in-process** prefill snapshot
   (`copy_state_data` / `set_state_data` + `clear_kv_cache_seq`) when consecutive
   prompts share a token prefix. No session files. Process death drops the KV.

## Amendment 2026-08-22

In-process llama.cpp KV reuse is the adapter implementation of decision 5.
Host-only evals skip when no GGUF is present (`AIRO_LLAMA_MODEL` or the crate
`models/` path). CI does not download models.

## Contract Impact

**Required. Fill every row — "none" is an answer, blank is not.**

| Question | Answer |
|---|---|
| Which runtime contracts change? | None. C1–C7 and `MindRuntime` ports are unchanged. |
| Which conformance tests become invalid? | None. Existing `lastReliabilityDiagnostic` reads remain valid as “last record in the in-process log”. |
| Which benchmarks must be re-run? | None. |
| Which review roles must re-review? | Chief Architect (ADR), Chief Security Officer (no prompt persistence). |
| Is G0 required again? | No. No crate public surface and no plan code-block change. |

## Consequences

### Positive

- Chat / Cloud / LiteRT failures keep a short in-process history without
  crossing the operation log.
- Tests can assert the dump contains PM / AIRO-R ids and never the prompt.

### Negative

- A killed app loses the ring. Debugging across process restarts still needs
  a later writer ADR.
- Callers that only read `lastReliabilityDiagnostic` still see one slot; they
  must use `ExecutionLog.checkpoints` for history.

### Risks

- Someone later appends these diagnostics as `MindOpKind.inference`. This ADR
  forbids that; reject it in review.

## Alternatives Considered

### Alternative 1: New `MindOpKind.reliabilityCheckpoint`

Rejected. Freeze: do not add `MindOpKind` for this. Operations are user-visible
Mind work, not classifier hits.

### Alternative 2: Persist prompts at Debug diagnostic level

Rejected. Rust already omits raw content including at Debug. Dart must match.

### Alternative 3: Wait for llama.cpp session files / `n_keep`

Rejected as a substitute. Prefix cache is unrelated to checkpoint identity.
KV reuse can land later as an adapter flag without this ADR.

## Related Decisions

- [ADR-0021](0021-mind-runtime-port.md) — `OperationLogPort` is the only write
  primitive for Mind ops; this ADR does not use it.
- [ADR-0022](0022-meeting-ir-mind-persistence-mapping.md) — meeting IR may add
  `MindOpKind.meetingIrExtracted`; reliability must not ride that kind.
- [ADR-0024](0024-reliability-checkpoints-prefs-tier.md) — names the Prefs tier
  as the existing store for checkpoint *metadata* (ids only).

## References

- `rust/airo_mind_reliability/src/execution.rs`
- `packages/core_ai/lib/src/reliability/failure_classifier.dart`

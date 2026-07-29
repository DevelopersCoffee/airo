# Airo Edge Runtime Conformance Specification

Status: Accepted
Version: 1
Related ADR: ADR-0001

This specification is normative for Architecture Freeze v1. Amendments require
an approved ADR or an explicitly reviewed versioned update.

This document is the executable specification for Airo's runtime contracts. A
mock runtime must satisfy it before any production backend is implemented.

## Required contract surface

Every runtime exposes typed operations for:

- capability and contract-version discovery;
- initialize with an immutable Inference IR;
- health and lifecycle state;
- reusable sessions and multiple generations;
- streaming and cancellation;
- shutdown and restart;
- structured errors and diagnostics.

No backend may expose runtime-specific types across the core boundary.

## Mock runtime milestone

`MockRuntime` is deterministic and in-memory. It supports configurable success,
latency, token streams, cancellation, concurrency limits, and injected failures.
It is used to validate planner and scheduler behavior without Android, model
files, native libraries, or a real accelerator.

The mock must prove:

- identical inputs produce identical plans;
- sessions can be reused across generations;
- cancellation leaves the session recoverable;
- retry and recovery transitions are deterministic;
- structured error codes survive the Rust/Flutter boundary;
- scheduler priority is honored under concurrent requests.

## Backend conformance suites

### Lifecycle

- created → initializing → ready;
- ready → busy → ready;
- ready → shutting down → stopped;
- restart after stopped;
- health reflects every state transition;
- failures transition to `Failed` with a typed code.

### Request behavior

- single generation;
- streaming generation;
- cancellation before first token;
- cancellation during streaming;
- multiple generations in one session;
- concurrent requests obey scheduler/session limits;
- context overflow is reported as `ContextTooLarge`.

### Failure and recovery

- out-of-memory;
- runtime unavailable;
- backend unavailable;
- missing/corrupt model;
- invalid manifest;
- timeout;
- permission/storage failure;
- retry after recoverable failure;
- cleanup of failed session state.

### Planner behavior

- deterministic plan for identical inputs;
- capability matching through the capability graph;
- runtime certification/version rejection;
- memory cleanup and recheck sequence;
- backend fallback;
- context/output/batch reduction;
- installed-model scoring and selection;
- no model-name-specific branches.

### Performance and observability

- planner overhead is measured and remains below the agreed budget;
- startup and first-token timings are reported;
- sustained throughput is reported;
- peak memory and thermal state are reported;
- telemetry aggregation is non-blocking;
- debug execution traces explain each planner decision.

## Architecture fitness tests

CI must enforce these boundaries:

- planner crates cannot import platform or runtime implementation modules;
- model and manifest crates cannot import runtime implementations;
- runtime adapters cannot import planner policy;
- platform adapters cannot import runtime implementations;
- Flutter cannot depend on runtime-specific packages;
- all cross-boundary values use typed contracts and stable identifiers;
- planner output is deterministic for identical serialized inputs.

Fitness checks should fail on dependency-graph violations, not merely rely on
code-review convention.

## Success metrics

### Extensibility

- adding a runtime requires zero planner changes;
- adding a model requires only a manifest and registry entry;
- adding a platform requires only a platform adapter.

### Reliability

- no uncaught runtime exception crosses the Rust/Flutter boundary;
- every failure has a stable error code and diagnostic trace;
- recoverable failures return to a usable session state.

### Performance

- planner overhead remains within the agreed millisecond budget;
- runtime selection is deterministic;
- telemetry never blocks inference;
- conformance tests are runnable without physical devices.

## Delivery order

1. Freeze this specification and version 1 contracts.
2. Implement `MockRuntime` and planner/scheduler tests.
3. Add architecture fitness checks to CI.
4. Freeze the conformance interfaces.
5. Implement the LiteRT adapter against the frozen contracts.
6. Validate Android behavior and telemetry.
7. Add a second backend without planner or Flutter changes.

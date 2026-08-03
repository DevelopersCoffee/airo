# ADR 0021 — The MindRuntime port

Status: accepted
Date: 2026-08-02
Deciders: Chief Architect, Platform Architect, Chief Security Officer
Issue: [#1449](https://github.com/DevelopersCoffee/airo/issues/1449) · Epic [#1448](https://github.com/DevelopersCoffee/airo/issues/1448)

## Context

Milestone 22 builds fourteen Mind surfaces. Milestone 19 has not shipped a
vault, an operation log, or a projection. Either the surfaces wait for the
runtime, or they bind to something that is not the runtime.

Waiting means the design sits unbuilt for as long as the runtime takes.
Binding to per-screen fakes means fourteen screens each invent their own model
of an op, a context and a peer, and the runtime later arrives at an API no
screen can consume.

## Decision

`packages/feature_mind` exposes `MindRuntime` — eight abstract sub-ports shaped
to the v1 architecture's seven primitives, contracts C1–C7 and six-function
API. Two implementations sit behind it:

- `FixtureMindRuntime`, deterministic, seeded with the design's own numbers.
- `RustMindRuntime`, partial, reporting `MindPortUnavailable` per unimplemented
  port and naming the milestone 19 issue that fills it in.

Surfaces bind to ports only. Nothing in `lib/src/runtime/` or
`lib/src/widgets/` may import the generated bridge; a test enforces that on
those two layers rather than carrying a per-file exemption list.

Milestone 19 implements against the port. A runtime that cannot satisfy a
method here files a follow-up ADR rather than reshaping the port in place.

## Contract Impact

| Contract | Impact |
|---|---|
| C1 identity and device authorisation | `VaultPort` surfaces state and revocation only. No key material crosses the port. |
| C2 operation header and signing | `OperationLogPort.verify` returns a `SignatureState`, never a raw signature. |
| C3 content addressing | Not exposed. Surfaces address content through ops. |
| C4 revocation ordering | `VaultState.revocationEpoch` is the only ordering signal a surface sees. |
| C5 recovery package | `PortabilityPort` is the export flow. The format stays with #1305 and #1211. |
| C6 replay determinism | `OperationLogPort.replayFrom` and `ProjectionPort.rebuild` both report progress, so a surface cannot assume instantaneous replay. |
| C7 projection disposability | `ProjectionState.lastRebuildMs` is measured, so the on-screen "REBUILT 3.1S AGO" claim is checkable. |

No frozen surface changes. No new primitive.

## Consequences

Surfaces ship before the runtime, and every one of them already renders the
runtime-unavailable state, because that is the only state `RustMindRuntime`
produces today. That is a feature of the sequencing: the unhappy path gets
built first for once.

The risk is a port shaped by fixtures rather than by reality. Two mitigations:
milestone 19's issues are the port's first real consumer and each is reviewed
against this ADR, and no port method returns a plausible empty value in the
partial implementation — a surface can never render "no devices" when the truth
is "not built yet".

A second risk is drift between the fixture and the real runtime. The fixture is
deliberately not a mock: appending advances the sequence, rebuilding reports
progress over time, search filters, and unloading a resident model throws. A
double that resolved everything instantly would let a surface ship having never
rendered its own loading or error state.

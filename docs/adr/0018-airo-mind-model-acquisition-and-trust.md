# ADR-0018: Airo Mind model acquisition and trust

## Status

Accepted

## Date

2026-08-01

## Context

Milestone 2 is the first user-visible capability: audio → transcript → minutes →
content → semantic search, entirely offline. It needs a speech model and a
generation model on the device.

Everything else about the inference layer is already decided by frozen
contracts, and this ADR does not restate it. `C6` already guarantees *"every
engine requests resources; the Supervisor grants them"* and names speech, OCR,
embeddings, and local LLM inference as the motivating workloads. `C5` already
keeps a capability to six functions with *"no encryption primitives, no key
material, no storage engine named anywhere"*, so a capability cannot call an
inference engine. `I7` already requires streaming. `I2`/`I4` already make an
engine that writes files or emits operations a defect.

One question is genuinely unanswered by the frozen documents: **how a model gets
onto the device, and what the runtime is allowed to trust about it.**

It is unanswered because it collides with the product's central positioning —
*"cloud optional. Never cloud required."* A first run that cannot summarise
until it fetches several gigabytes makes the core feature cloud-required in
practice, whatever the documents say. That is a decision with a user-visible
consequence and no derivable answer, which is what an ADR is for.

## Decision

### 1. The runtime never acquires models. It queries for them.

The runtime asks for a **capability**, not a file:

```rust
ModelRequirement {
    task: Task,               // Speech | Generation | Embedding
    memory_budget_mb: u32,
    minimum_quality: Quality,
}
```

and receives either a handle or a structured **`ModelUnavailable`** result naming
what was missing. It never initiates a download, and it never distinguishes
bundled from imported from downloaded.

This inverts the dependency: availability is a **query**, not a side effect.
Acquisition becomes an installation concern rather than an inference concern,
which is what keeps *"never cloud required"* true in code rather than in
positioning.

`ModelUnavailable` is a normal result on a normal path — the caller degrades,
prompts, or declines — not an error to be logged and swallowed.

### 2. Three acquisition strategies, three trust models

They are **not** interchangeable, and conflating their verification is the
mistake this section exists to prevent.

| Strategy | Provenance | Verification | Consent |
|---|---|---|---|
| **Bundled** | ships inside the app | signed at build time; digest pinned in source | implicit — the user installed the app |
| **Imported** | user supplies a file | digest recorded on import; **no signature to check** | explicit, per model, naming the file |
| **Downloaded** | fetched from a configured source | signature **and** pinned digest, both required | explicit, per model, showing size and source |

**The imported case is the one that needs stating plainly: a user-supplied model
is untrusted input that will be executed as weights.** There is no signature to
verify because the user is the authority. So it gets explicit per-model consent,
it is recorded as `Provenance::UserSupplied`, and any surface that reports what
produced a summary must be able to say so. A single verification path across all
three would either reject legitimate imports or accept unsigned downloads.

### 3. Models are not user state

`I2` and `I4` say all durable **user state** originates from the runtime. A GGUF
file is an application asset, not user data, so the Model Manager holding
durable state outside the operation log is not a violation.

Recorded because the objection is reasonable and will be raised.

### 4. Compatibility is by logical model, never by file

A capability requests a task and a budget. The Model Manager resolves a
**logical** model to whatever physical format that platform runs — GGUF, MLX,
LiteRT, WebGPU weights. Nothing above the Manager names a file, a quantisation,
or a runtime.

Each installed model declares the engine versions it is compatible with.
Incompatible pairs are `ModelUnavailable`, not a crash at load.

### 5. Updates are replacements, never in-place mutation

A model update installs a new logical version alongside the old one and switches
the resolution. Nothing rewrites a model file in place.

**Consequence that must be recorded with the output, not inferred later:** an
operation that produced content records the model identity and version that
produced it — this is `MinutesGenerated → ContentID + digest + model + version`.
Replay reproduces the *reference*, never the inference, because a local model is
not byte-identical across versions and `C2` requires replay to be deterministic.
Regenerating minutes after a model update is a new operation, not a rebuild.

### 6. Revocation covers models

A model can be marked unusable — bad weights, a discovered vulnerability, a
withdrawn licence. A revoked model is `ModelUnavailable` from the next
resolution, and content it produced keeps its recorded provenance so a user can
see what needs regenerating.

Model revocation is **separate from the Vault's revocation ledger**. That ledger
is user-data crypto-shredding; this is asset lifecycle. Sharing the mechanism
would put application assets into the structure whose growth `ADR-0017` spent a
whole revision bounding.

### 7. Offline is the default path, not the fallback

With no network and no models installed, every resolution returns
`ModelUnavailable` and the product says so. With a bundled model, the meeting
pipeline runs. Downloading is an explicit user action that improves quality; it
is never a precondition for the feature existing.

**Milestone 2 ships bundled models.** Import and download can follow; the
sequence matters because bundling is the only strategy that proves the offline
claim.

## Contract Impact

| Question | Answer |
|---|---|
| **Which runtime contracts change?** | **None.** `C5` and `C6` already cover engines and capability isolation; this decides an acquisition policy beneath them. No version change, not a runtime major. |
| **Which conformance tests become invalid?** | **None.** No existing test measures model acquisition, because nothing acquired models. New tests are owed, not invalidated: offline resolution returns `ModelUnavailable`; an imported model records `UserSupplied` provenance; a revoked model resolves unavailable; content records the model version that produced it. |
| **Which benchmarks must be re-run?** | **None.** `V1`–`V7` measure the Vault, which this does not touch. New budgets are owed for model load time and resident size, and belong with the Supervisor work rather than here. |
| **Which review roles must re-review?** | **chief-security-officer** — the imported-model trust boundary and signature policy. **chief-open-source-officer** — Constitution §6 applies to any model-format dependency, and model licences are a distribution question the Vault never had. **chief-architect** — Model Manager as a Supervisor sub-component. **chief-performance-officer** when the load-time and residency budgets are written. |
| **Is `G0` required again?** | **No.** No change to `rust/airo_mind`, whose plan `G0` extracts. `G0` applies again when the Model Manager has code. |

## Consequences

### Positive

- *"Never cloud required"* becomes checkable: a device with no network and a
  bundled model runs the whole meeting pipeline.
- The runtime cannot acquire, so it cannot accidentally make a feature
  network-dependent.
- Three trust models stated separately means the weakest case — user import —
  cannot silently borrow the strongest case's assurances.
- Recording model identity with produced content is what makes `C2` determinism
  survive a nondeterministic engine.

### Negative

- Bundled models constrain app size, and the bundled model will be the smallest
  acceptable one rather than the best available.
- Three verification paths are more code than one, and the imported path is the
  one most likely to be reported as a bug ("why does it warn about my model?").
- Model revocation needs a distribution channel to be useful, and Milestone 2
  has none. Until then revocation is local-only.

### Risks

- **Imported models are an execution surface.** Consent and provenance recording
  reduce blast radius; they do not make an arbitrary GGUF safe. If sandboxing
  ever becomes available for inference, this decision should be revisited.
- The `Quality` axis in `ModelRequirement` is under-specified on purpose. It
  needs a real definition before a second model exists per task, and defining it
  early would be guessing.

## Alternatives Considered

### Ollama or a local model server

Rejected. A daemon with its own model registry, storage, and HTTP API is a
second runtime beside the operation log — `I2` and `I4`. Excellent for
development; the production path is in-process engines the Supervisor loads.

### Download-on-first-run

Rejected. It makes the core feature cloud-required in practice while the
documents claim otherwise, which is worse than either honest position.

### One verification path for all three strategies

Rejected. It would either reject legitimate user imports or accept unsigned
downloads. The strategies differ in *who the authority is*, so they cannot share
a verification path.

## Related Decisions

- [ADR-0017](0017-airo-mind-revocation-ledger-growth-and-package-framing.md) —
  why model revocation stays out of the Vault's ledger
- [ADR-0012](0012-edge-intelligence-media-boundary.md) — existing edge
  intelligence boundary

## References

- `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md` §5, §7
- `docs/superpowers/specs/2026-07-28-airo-mind-runtime-contracts.md` — `C5`, `C6`
- `docs/superpowers/specs/2026-07-27-meeting-intelligence-coverage.md`
- Milestone 20, #1246

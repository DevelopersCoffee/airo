# Airo Mind — Architecture Freeze v1

Status: **BINDING once this document merges.** Until then, pending.
Date: 2026-07-28
Owner: Airo Engineering Council
Scope: the Airo Mind runtime only. Does not amend `docs/PLATFORM_CONSTITUTION.md`.

---

## What this declares

The Airo Mind runtime architecture is **frozen**. From the moment this document merges:

- **No new primitives.**
- **No new invariants.**
- **No new contracts.**
- **No new architectural concepts.**

Everything else is implementation, validation, or an **ADR**. There is no
fourth category.

The remaining work is not requirements. It is **proving these decisions with
implementation, benchmarks, and tests — not redesigning them.**

---

## Frozen surfaces

### 1. Runtime primitives — frozen

`Identity` · `Operation` · `Content` · `Context` · `Capability` · `Projection` ·
`Vault`

Seven. Design spec §2. Adding an eighth requires an ADR.

### 2. Runtime invariants — frozen

| | |
|---|---|
| **I1** | Only the operation log and encrypted content store are durable; everything else is a disposable projection |
| **I2** | No capability creates durable storage outside the runtime |
| **I3** | Every claimed security property has an automated tamper test |
| **I4** | Runtime exclusivity — all durable user state originates from the runtime |
| **I5** | An invariant is not complete until a compile-time constraint or test fails when it is violated |
| **I6** | Canonicalize exactly once, at the boundary |
| **I7** | Streaming first — never "load everything, then process" |
| **I8** | Cost is part of correctness: complexity, allocation budget, benchmark, regression test |

Design spec §11a. Eight. Adding a ninth requires an ADR.

### 3. Runtime contracts — frozen at `v1`

`C1` Storage · `C2` Replay · `C3` Sync · `C4` Projection · `C5` Capability ·
`C6` Supervisor · `C7` Security

`2026-07-28-airo-mind-runtime-contracts.md`. Versioned as runtime ABI. **A
contract version change is a runtime major version** and requires an ADR.

### 4. Package format — frozen

Recovery Package `format_version: 1` — header fields, AAD binding, reserved
`passphrase_used` / `kdf_params` / `kdf_salt` slots, revocation-epoch placement
outside the ciphertext, and the framing decided in #1305.

The on-disk format is the least reversible thing in the system. Every device
that has ever exported one holds a copy we cannot reach.

### 5. Public runtime API — frozen

```rust
emit_operation()
attach_content()
query_projection()
instantiate_context()
replay()
sync()
```

Design spec §11c. Six functions. A capability needing anything else means the
runtime is missing a generic primitive — which is an ADR, not a local
workaround.

### 6. Sync model — frozen

**One model. Everything is an operation.** Single-device mode replays local
operations; multi-device replays local plus remote. No second storage model, no
second merge engine, no second code path. Design spec §11d.

### 7. Security model — frozen

Envelope encryption over a context hypergraph · crypto-shredding · revocation
covering content, contexts, and devices · revocation-aware restore · the header
disclosure rule · trust boundary is the user's own device mesh · `unsafe`
permitted only when isolated, documented, benchmarked, fuzzed, audited, and
justified.

---

## Architecture changes are ADRs

There is **no separate ACP process.** An Airo Mind architecture change is an
ADR in `docs/adr/` carrying the required architecture sections below.

`PLATFORM_CONSTITUTION.md` already establishes ADRs as the amendment mechanism.
A second process that overlaps it is a second process someone forgets.

An ADR touching any frozen surface above must contain all seven:

1. **Problem statement** — what is actually broken, in behaviour a user or an
   implementer can observe
2. **Evidence** — a benchmark, a working implementation, a council review
   finding, or a bug. Not a preference
3. **Alternatives considered** — including doing nothing, with why each was
   rejected
4. **Compatibility analysis** — what breaks, on devices already in the field
5. **Migration strategy** — for data already written under the current design
6. **Runtime contract impact** — which of C1–C7 change version, and therefore
   whether this is a runtime major
7. **Approval** — from every council role the Decision Matrix names for the
   surfaces touched

> **"No better idea" is not sufficient justification.** Neither is elegance,
> consistency, or that a newer approach exists. Evidence or nothing.

### Why this bar is set here

Four consecutive council reviews returned REJECT, and every one found defects
the previous could not have been expected to catch. That process works, and it
only works against a fixed target. An architecture that moves while it is being
validated cannot be validated.

---

## Phase transition

```
Discovery                  ✓
Requirements               ✓
Architecture               ✓  ← frozen here
Runtime Validation         ←  current
Runtime Implementation
Capability Implementation
Product Development
```

> **The architecture is no longer the bottleneck. Evidence is.**

Every remaining P0 asks for a benchmark, a test, or an implementation. **None
ask for a new abstraction.** That is the signal the phase actually changed —
not that ideas stopped, but that the backlog stopped containing them.

Every open issue in milestone 19 now belongs to exactly one phase. **None of
them redefine the architecture. They either prove it or implement it.**

| Issue | Phase | What it does |
|---|---|---|
| #1305 | Runtime Validation | Vault scalability — proves the Vault is sized by contexts, not content |
| #1306 | Runtime Validation | Replay and snapshots — proves the watermark makes cache-only affordable |
| #1307 | Runtime Validation | `unsafe` policy and mmap — proves the layering permits the memory budget |
| #1308 | Runtime Validation | Header disclosure and crypto-shredding — proves format reservations hold |
| #1302 | Runtime Implementation | Supervisor |
| #1311 | Milestone completion | The ten conditions |

---

## Triage rule — design debt vs engineering debt

**Every issue is exactly one of these.** No third category, and the
classification is the first question at triage, not the last.

| Type | Meaning | Label |
|---|---|---|
| **Design** | Changes runtime contracts, primitives, invariants, or any frozen surface | `type/design` — **requires an ADR** |
| **Engineering** | Implements or validates an existing contract | `type/engineering` — no ADR |

If an issue cannot be classified, it is a design issue that has not admitted it
yet. Write the ADR.

## Freeze decision matrix

The first question on any contradiction is **"which frozen contract does this
violate?"** If one already exists, the work is implementation — not
architecture.

| Situation | Action |
|---|---|
| Implementation contradicts frozen architecture | **Engineering fix** |
| Specification contradicts frozen architecture | **Engineering fix** |
| Documentation contradicts frozen architecture | **Documentation fix** |
| Runtime contract is internally inconsistent | **ADR** |
| Implementation proves a contract cannot be satisfied | **ADR with evidence** |
| Better idea, no implementation evidence | **Reject** |

Worked example, from the first case after the freeze activated: the Phase 1
plan declared `envelopes: BTreeMap<String, ContentEnvelope>` inside the Vault
while the frozen design said the Vault is sized by contexts and devices, never
by user content. Row 2 — **engineering fix, no ADR.** The architecture had
decided; the plan was behind.

Before the freeze, that contradiction would have invited another design
discussion. That is the change worth naming.

## Architecture drift — categories

Every violation is categorized, so the trend is visible rather than anecdotal.

| | Meaning |
|---|---|
| **A1** | Implementation or specification behind the architecture |
| **A2** | Documentation behind the architecture |
| **A3** | Tests behind the architecture |
| **A4** | Benchmarks behind the architecture |
| **A5** | Contracts behind the architecture |

**A1 occurrences should decrease over time.** If they do not, either the
architecture is wrong or the freeze is not being read — and those need
different responses, which is why the count matters.

**A5 is the serious one.** A contract behind the architecture means the thing
capabilities are written against is stale, and every capability built in the
interim inherits the staleness.

Recorded so far:

| Date | Category | What |
|---|---|---|
| 2026-07-28 | **A1** | Phase 1 plan held content envelopes in the Vault after §4.1 forbade it — #1319 |
| 2026-07-28 | **A2** | Review checklists quoted the pre-freeze runtime API and `I1–I6`. The fix was written before the freeze activated but **was not merged** — #1314 took the branch's earlier commits and closed while the reconciliation was still being pushed. It survived the freeze undetected and was found by an audit two days later. Fixed in #1322. |

## Decision hierarchy

When something looks wrong, work down this list. **Reaching step 5 requires
having done steps 1 through 4.**

1. **Runtime contract** — read it. Most apparent problems are a contract that
   was not read.
2. **Implementation** — build it against the contract as written.
3. **Benchmark** — measure it. Three of four council reviews rejected on
   findings that were measurable and unmeasured.
4. **Conformance test** — prove the contract holds, or prove it does not.
5. **ADR** — **only if the evidence from 2–4 shows the contract is
   inadequate.**

> Do not reopen an architecture discussion unless an implementation produces
> evidence that a frozen contract is incorrect.

This is what allows the platform to evolve without churning. A contract that
implementation proves wrong *should* change — that is what steps 2 through 4
are for. A contract someone would prefer differently should not.

## Runtime Validation — exit criteria

The phase completes only when **every frozen contract** has all five. This is
deliberately stronger than "tests exist".

| Requirement | Why |
|---|---|
| **Conformance tests** | Proves the contract holds |
| **Negative tests** | Proves it fails when violated — I5 |
| **Benchmarks** | Proves the cost — I8 |
| **Failure injection** | Proves behaviour under kill, corruption, and exhaustion, not only under success |
| **Architectural ownership** | A named council role answers for it |

Failure injection is the one usually skipped, and it is the one that matters on
a mobile device: Android kills processes without warning, flash corrupts, and
disks fill. A contract verified only on the happy path is verified for the
conditions under which nobody needed it.

## The review pipeline is mandatory, and ordered by cost

Cheapest check first. A defect caught by `clippy` costs minutes; the same
defect caught by a council review costs a review cycle, and four consecutive
reviews were spent partly on findings a compiler would have surfaced.

```
Developer
   ↓
cargo fmt
   ↓
cargo clippy -D warnings
   ↓
Unit tests
   ↓
Property tests
   ↓
Benchmark gates
   ↓
Architecture compliance
   ↓
Security review
   ↓
Rust review
   ↓
Performance review
   ↓
Merge
```

The three human reviews sit **last** deliberately. Reviewer attention is the
scarcest resource in this process and must be spent on what machines cannot
check — cryptographic soundness, ownership models, asymptotic behaviour — not
on missing imports.

Gates 1–6 are automated by #1287 (crypto-path hygiene) and #1294 (architecture
compliance).

## Review convergence — the maturity metric

Track the shape of findings over time, not just their count.

| Direction | Signal |
|---|---|
| Fewer **blocking** findings | The architecture is settling |
| More **localized** findings | Defects are contained rather than structural |
| More **CI** failures than human findings | Tooling is catching what reviewers used to |
| Reviews **confirming** invariants rather than discovering missing ones | The invariant set is complete |

Where the Phase 1 plan stands today, honestly:

| Revision | Outcome |
|---|---|
| 1 → 2 | Many findings, all blocking |
| 3, 4 | REJECT, structural — the plan did not compile |
| 5, 6 | Still meaningful findings, but increasingly localized |

**Revision 6 has not converged.** The remaining risk is no longer conceptual —
it is whether the implementation faithfully realizes the frozen contracts, and
that is what compilation, conformance tests, benchmarks, and targeted reviews
exist to reduce.

## Success metrics — Runtime Validation phase

Success was measured by **better architecture** during Requirements. It is
measured differently now, and the difference is that these are objective.

| Metric | Why it matters |
|---|---|
| Benchmark gates passing | I8 — cost is part of correctness |
| Invariants enforced by CI | I5 — an invariant that cannot fail is a description |
| Contracts with conformance tests | C1–C7 are otherwise prose |
| Startup latency | The watermark's whole justification |
| Replay throughput | Dominates runtime cost |
| Peak memory | I7 — streaming first |
| Sync convergence correctness | C3 |
| Recovery determinism | The product's second claim |

None of these is "the architecture got better". That question is closed.

## Repository layers

```
Governance            slow-moving
├── Constitution
├── ADRs
└── Architecture Freeze
        ↓
Runtime               slow-moving
├── Contracts
├── Invariants
├── APIs
└── Validation
        ↓
Capabilities          fast-moving
├── Notes · Brain · Meeting · TV · Health · ...
```

**Everything above Runtime changes slowly. Everything below evolves quickly.**
A change that makes a capability faster to build by making the runtime less
stable is a bad trade, every time, because the runtime underpins every
capability that does not exist yet.

## Definition of done — requirements phase

- [x] Runtime primitives frozen — seven, design spec §2
- [x] Runtime invariants frozen — eight, design spec §11a
- [x] Runtime contracts frozen — C1–C7 at v1
- [x] Sync model frozen — one model, design spec §11d
- [x] Security model frozen — design spec §4, §6, §7
- [x] Package format frozen — `format_version: 1`
- [x] Public API frozen — six functions, design spec §11c

**Complete on merge of this document.**

---

## What changes for everyone after the freeze

Airo Mind moves from **system design** to **platform engineering**.

Every future capability — Notes, Brain, Meetings, Health, Finance, TV, or
something nobody has proposed yet — is built against a **stable runtime rather
than a moving architectural target.** That is the whole value of freezing, and
it is worth more than any individual improvement that gets deferred to an ADR.

The corollary, stated plainly because it will be tested: **an exception granted
after the freeze is a permanent maintenance cost**, and it becomes the precedent
the next request cites. The answer to "can we just, for this one case" is an ADR
or no.

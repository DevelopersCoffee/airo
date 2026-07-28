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
`passphrase_used` / `kdf_params` / `kdf_salt` slots, and revocation-epoch
placement outside the ciphertext.

**Framing, frozen as a property.** Peak memory during export and restore must be
`O(1)` in revocation-ledger size, and truncation must be distinguishable from
corruption. `[len:u32][AEAD frame] × N` plus a sealed trailer satisfies this and
is the default shape, but the layout is not itself frozen — the property is.
Decided in [ADR-0017](adr/0017-airo-mind-revocation-ledger-growth-and-package-framing.md)
on measured evidence, superseding the justification in #1305.

**A frozen surface may not cite an open issue as its authority.** This section
previously read "the framing decided in #1305" while that issue was open and
unbuilt, which made a decided-but-unimplemented requirement indistinguishable
from a settled one. Seven plan revisions and three council reviews passed over
it. Everything frozen must be readable in full from this document.

**Encodings, frozen with the format.** These were decided in implementation and
are recorded here because they are as unreversible as the field list — a device
that exported a package holds a copy we cannot reach.

| Value | Encoding |
|---|---|
| `RevocationSubject` map key | Canonical string `kind:id`, where `kind` ∈ {`content`, `context`, `device`} and contains no `:`. First-colon split, so ids may contain `:`. Unknown kinds fail closed. |
| `[u8; 32]` and `[u8; 64]` fields | Lowercase hex string, never a JSON decimal array — the package stays inspectable in a text editor, which matters for a file users are told to store themselves |
| Outer `ciphertext`, `nonce`, `kdf_salt` | Base64, not hex and never a JSON decimal array. The package double-encodes — a JSON payload, then that ciphertext text-encoded again in the envelope — so hex on the outer blob costs a hard 2.0× and puts V4's `≤ 3× compact` floor at 3.30×, unmeetable. Base64 costs 1.33× and clears every measured shape. Inner fields stay hex; the ciphertext blob is opaque under any encoding, so nothing inspectable is lost. Measured in ADR-0017. |
| Subject ids | The design must state whether ids are NFC-normalized and control-character-free at the boundary (I6). Two ids differing by Unicode form are different subjects, so a destroy on one does not revoke the other — self-consistent on one device, a divergence source the moment C3 sync carries ids between devices. |

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

## Conformance tests name properties, not artifacts

**A conformance test must state the architectural property it protects, not the
implementation artifact that once measured it.** Otherwise the architecture
evolves, the artifact stops correlating with the property, and the test keeps
passing while testing nothing. Nothing fails, so nothing draws attention — this
is the only defect class in this document that gets *quieter* as it gets worse.

Found the hard way. C1 carried *"a synthetic 100k-content vault serializes
within a constant factor of a 10k-content vault."* That was a faithful proxy
when the Vault held one envelope per content object. The §4.1 redesign removed
content from the Vault, and the test began passing at a −0.8% delta — measuring
a dimension the Vault no longer has, while the dimension that had replaced it
(the revocation ledger) went unmeasured at +849%. The test did not break. It
went hollow, and stayed green for three council reviews.

Applying the rule as an audit immediately found two more:

| Test | Artifact it measures | Property it should protect |
|---|---|---|
| C1 / S1 vault sizing | content count | **the growth dimension the Vault actually has** — now contexts, devices, and revocations |
| C2 / S2 replay RSS | operation count | **peak RSS is O(1) in replayed state size** — a log of 1M no-op operations passes while unbounded state growth goes untested |
| C3 no-op sync | bytes exchanged | **a converged sync costs nothing** — the exchange is bounded while `merge` is O(N), measured at 11.52 ms per replica at 100k entries |

Two rules follow:

1. **Write the property first and the measurement second**, so a reader can see
   when the second stops serving the first. Every conformance test in this
   system is stated in that order.
2. **An ADR that changes a growth dimension, a storage class, or a data model
   must re-audit the conformance tests that measured the old one.** Changing the
   architecture without changing its tests is how a suite becomes decorative.
   ADR-0017 is the first to carry this obligation.

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

## G0 — Buildability. A revision does not exist until it builds.

**Gate zero, ahead of everything else.**

| Required evidence | |
|---|---|
| `cargo check` | green |
| `cargo test` | green |
| `cargo clippy --all-targets -- -D warnings` | green |

Only then does an artifact become **Revision N**. Anything before that is a
**working draft** and is not circulated for review.

### "Revision" redefined

A revision is **not** "the next document". A revision is:

> A buildable, lint-clean, test-passing artifact ready for architectural
> review.

Which makes four classes of defect **impossible to circulate**: missing
imports, non-compiling code, dead API references, and signature drift between
tasks.

### The sequence this replaces

```
   ✗  Revision N  →  Review  →  Compile  →  Reject
   ✓  Working draft  →  Compile  →  Revision N  →  Review
```

That one reordering removes an entire class of review waste. It is not a
theory: revisions 3, 4, and 6 of the Phase 1 Vault plan were circulated
without compiling, and each consumed a full council review producing findings
a compiler surfaces in under ten minutes. The security officer's fourth-round
verdict named five findings — S3, S5, S6, S8, S12 — that were **controls
written down and never executed**.

### Why the compiler goes first

It is the highest-ROI reviewer available. It reads every line every time, it
never tires, and its findings are unarguable. Human reviewers are the scarcest
resource and the only ones who can judge cryptographic soundness, ownership
models, and asymptotic behaviour — spending them on `E0433` is the most
expensive way to find a missing import.

## The review pipeline is mandatory, and ordered by cost

Cheapest check first. A defect caught by `clippy` costs minutes; the same
defect caught by a council review costs a review cycle, and four consecutive
reviews were spent partly on findings a compiler would have surfaced.

```
Working draft
   ↓
G0: cargo check · cargo test · cargo clippy -D warnings   ← becomes Revision N here
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

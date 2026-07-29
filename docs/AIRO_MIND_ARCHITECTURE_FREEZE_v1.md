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
| Subject ids | **NFC-normalized and rejected if they contain control characters**, at the boundary, exactly once (I6). Answered in design §11a/I6; this row previously said only that the design must state it. Two ids differing by Unicode form are different subjects, so a destroy on one does not revoke the other — self-consistent on one device, a divergence source the moment C3 sync carries ids between devices, surfacing as destroyed content reappearing elsewhere. |

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
6. **Contract Impact** — the table below, every row filled. "None" is an answer;
   blank is not
7. **Approval** — from every council role the Decision Matrix names for the
   surfaces touched

### The Contract Impact table

| Question | Required |
|---|---|
| Which runtime contracts change? | List — and whether the version changes, since that makes it a runtime major |
| Which conformance tests become invalid? | List — **including tests that still pass.** That case is the reason this row exists |
| Which benchmarks must be re-run? | List — a budget measured against the old shape is not evidence about the new one |
| Which review roles must re-review? | List — a prior approval covers what was approved, not its replacement |
| Is G0 required again? | Yes / No — yes for anything touching a plan's code blocks or a crate's public surface |

This exists because the previous wording asked only which contracts change
version, and an architecture change invalidates more than contracts. It leaves
tests, budgets, and approvals standing against a shape that no longer exists —
and unlike a broken test, a stale one is silent.

ADR-0017 is the worked example: contracts C1 and C7, conformance tests on C1, C2
and C3, benchmarks V4/V5/V7, re-review by Performance, Security, and Rust
Architect, G0 yes. None of that was derivable from "which contracts change
version" alone.

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

### Phase exit gate

Runtime Validation is complete when all ten hold:

| Criterion | Status |
|---|---|
| G0 passes | Required |
| Security approves | Required |
| Rust Architecture approves | Required |
| Performance approves | Required |
| ADR-0017 implemented | Required |
| Conformance suites updated | Required |
| Runtime contracts unchanged | Required unless superseded by an approved ADR |
| No new primitives | Required |
| No new invariants | Required |
| **No implementation evidence requiring an ADR** | Required |

The last row is phrased deliberately. **"No ADRs opened" would have been the
wrong rule** — it rewards suppressing an architectural problem to keep a
checklist clean, which is the opposite of what the freeze is for. The decision
hierarchy explicitly ends at "ADR, if the evidence from steps 2–4 shows the
contract is inadequate", and an ADR arriving through that path is the process
working.

What the row actually asks: *did implementation surface evidence that a frozen
contract is wrong, and is it still unaddressed?* An ADR opened, reviewed, and
approved satisfies this row. An ADR that should exist and does not, fails it.

## Every change cites its evidence

**From Revision 8 onward, every substantive change carries one of three
justifications:**

| Evidence class | Means |
|---|---|
| **Compiler** | G0 — it did not build, or it built and should not have |
| **Benchmark** | A measured number against a declared budget |
| **Review** | A council finding, with the probe or reasoning that produced it |

Anything with none of the three is deferred. Not rejected — deferred, because a
change worth making will acquire evidence, and a change that never does was
preference.

This exists because of a specific recurring failure: **five times a property was
recorded as applied and was absent from the code.** Header AAD, the
revocation-subject rewrite, error variants declared and never constructed, the
checklist's runtime API, and `hex_array` never applied to `RootPublicKey`. I5
was written for this and did not stop it, because I5 governs invariants and this
was drift in the record of what had been done.

Requiring each change to name its evidence attacks it from the other side. A
changelog entry that must cite the probe, the benchmark, or the compiler error
that demanded it cannot describe work that was never performed — the citation
either resolves or it does not.

### Where enforcement is mechanical, and where it is not

Worth stating plainly, because the weak row is the one that will fail quietly:

| Mechanism | Enforcement |
|---|---|
| G0 | **Mechanical** — compiler and tests |
| Contract Impact | **Mechanical** — the ADR template cannot omit it and a blank row is visible |
| Conformance audit | **Mechanical** — review checklist |
| Citation namespace | **Mechanical** — a fixed prefix set is greppable against real artifacts |
| Evidence Rule | **Human discipline** |

The Evidence Rule is the only one with no mechanical backstop: nothing stops a
plausible citation attached to work that was not done. The citation namespace
narrows it — an invented artifact id fails to resolve — but a *real* id cited
for the wrong change still passes. That residual gap is where tooling would help
and is not worth automating yet.

Recording it here rather than treating the stack as complete. A governance
mechanism whose weakness is known is a different thing from one whose weakness
is assumed absent.

**Three levels of assurance, and only the first two are process:**

| | Level | How |
|---|---|---|
| 1 | The identifier exists | Partially mechanical — the namespace is greppable |
| 2 | The identifier is relevant to this change | Review judgment |
| 3 | The change is correct | Compiler, benchmark, or reviewer |

Automating level 2 before implementation evidence exists would add complexity
without earning it. This is the stopping point.

### Governance rules are held to the Evidence Rule

**A new governance mechanism requires the same justification as a specification
change: an observed failure that demanded it.** Not that it seems generally
useful.

Every rule in this document has one. G0 exists because three revisions shipped
non-compiling code. The Evidence Rule exists because five properties were
recorded as applied and were absent. Contract Impact exists because a
conformance test stayed green for three reviews after the dimension it measured
was deleted. The namespace reservation above exists because `S2` meant two
things.

Governance that grows on plausibility rather than evidence has the same failure
mode as a specification that does: it accumulates, each addition locally
defensible, until the process costs more than the defects it prevents. From here
the bar is a concrete weakness exposed by Runtime Skeleton implementation.

### The changelog is a proof ledger, not a release note

A revision's changelog exists to answer one question per entry:

> **If this line disappeared six months from now, what evidence would prove it
> belonged?**

Four columns, all required:

| Change | Evidence class | Specific evidence | Frozen surface |
|---|---|---|---|

Column 4 traces the change to the architectural authority that demanded it, so
the ledger is checkable against the contracts and not only against the review
that happened to raise it.

**Column 4 must name a real frozen surface — C1–C7, or a numbered section of
this document — or say `none — plan-local`.** Both are valid. Inventing a
plausible-sounding contract name to fill the cell produces false traceability,
which is worse than an empty one, and is the same defect class as a conformance
test that measures an artifact instead of a property. Not every legitimate
change traces to a frozen surface: a fix to a promise the plan made about its
own file layout is real, evidenced, and governed by nothing frozen.

Worked example, Revision 8:

| Change | Evidence | Specific evidence | Frozen surface |
|---|---|---|---|
| Remove `link_content`'s `content_id` parameter | Review | Rust probe: `link_content("B", ctx, &mut envelope_of_A)` returned `Ok(())` after A was destroyed | **C7** — the revocation gate and the AAD disagreed on one identity |
| Apply `hex_array_32` to `RootPublicKey` | Review | `to_bytes()` emitted `identity_public_key` as a JSON decimal array | **§4** encoding table |
| Pre-sized `String` hex helper | Benchmark | `to_bytes()` on a 100k-context vault: 350.82 ms → 16.55 ms | **I8**, budget V4 — no contract governs it |
| Base64 on the outer ciphertext | Benchmark | Hex leaves a hard 3.30× floor against V4's ≤ 3× | **§4** |
| Re-export `RevocationSource` | Compiler | `error[E0433]` from an external probe; restore unreachable | `none — plan-local` |

### Evidence Identifier Namespace — prefixes are reserved

**Each prefix below means one thing across the whole project.** Reserved, not
merely conventional: a prefix may not be reused for a different artifact kind,
in this document, in the specs, in review reports, or in issue comments.

| Prefix | Reserved for |
|---|---|
| `C#` | Frozen runtime contracts |
| `I#` | Frozen invariants |
| `S#` | Conformance suites |
| `V#` / `H#` | Benchmark budgets and host datapoints |
| `G0.#` | Buildability gate steps |
| `SEC-#` | Chief Security Officer findings |
| `RA-#` | Rust Architect findings |
| `PERF-#` | Chief Performance Officer findings |
| `ADR-####` | Architecture Decision Records |
| `Freeze §#` | Numbered sections of this document |

A new council role takes a new prefix. A new artifact kind takes a new prefix.
Neither borrows an existing one.

This is the forward-looking half of the rule below, and it is the half that
matters in six months: the table below says what a citation may *name*, and this
one stops someone introducing `SEC` conformance tests or `RA` benchmarks and
recreating the collision that motivated both. The collision was not theoretical
— review findings were numbered `S1`, `S2`, `S5` while the conformance suites
were also `S1`–`S5`, and it survived four council reviews unnoticed because
nobody had to cite one from the other until the proof ledger required it.

### Citations resolve to real identifiers

**Every evidence citation names an artifact that exists independently of the
changelog**, drawn from this namespace and no other:

| Prefix | Artifact | Example |
|---|---|---|
| `rustc E####` | A compiler diagnostic | `rustc E0433` |
| `G0.#` | A buildability gate step | `G0.5` |
| `V#` / `H#` | A benchmark budget or host datapoint | `V4` |
| `SEC-#` | A Chief Security Officer finding | `SEC-15` |
| `RA-#` | A Rust Architect finding | `RA-1` |
| `PERF-#` | A Chief Performance Officer finding | `PERF-3` |
| `ADR-####` | An accepted ADR | `ADR-0017` |
| `Freeze §#` | A numbered section of this document | `Freeze §4` |
| `C#` | A runtime contract | `C7` |
| `I#` | A runtime invariant | `I6` |
| `S#` | **A conformance suite, and nothing else** | `S1` |

A reviewer can check that a cited artifact is real without judging whether the
change is correct. That is a weaker guarantee than proving the change justified,
and it is the guarantee actually worth having: it prevents invented citations the
same way `none — plan-local` prevents invented contracts.

**`S#` is reserved for conformance suites.** Review findings were numbered `S1`,
`S2`, `S5` … while the conformance suites are also `S1`–`S5`, so a bare `S2`
meant either "Replay conformance" or "`link_content` re-links destroyed
content". Role prefixes remove it. The Rust Architect already numbered findings
`RA*` *"to avoid colliding with the security officer's S*"* — that instinct was
right and did not go far enough, because neither numbering avoided the suites.

Renumbering applies going forward and to the Revision 8 ledger. Findings already
posted to issues keep their original numbers in those comments; the ledger cites
the prefixed form.

### Editorial change requires a demonstrated defect

**"The previous text was ambiguous" is not evidence.** It becomes evidence when
the ambiguity is demonstrated by a review finding or an implementation failure —
someone read it the wrong way, or built the wrong thing from it.

Without this, a document meant to become a stable engineering reference
accumulates rewording indefinitely, each edit locally defensible and none
demanded by anything. The clarifications that matter have a witness: I6's
canonicalization text exists because a mnemonic with a trailing newline derived
a different seed, and freeze §4's encoding table exists because three helpers
were applied at some of the sites their invariant covered.

## G0 — Buildability. A revision does not exist until it builds.

**Gate zero, ahead of everything else.**

| Step | Required evidence | Proves |
|---|---|---|
| `G0.1` | extraction fidelity | the compiler is judging the specification, not the extractor |
| `G0.3` | `cargo check --all-targets` green | it builds |
| `G0.4` | `cargo test` green | it behaves |
| `G0.5` | `cargo clippy --all-targets -- -D warnings` green | it is idiomatic |
| **`G0.7`** | **claim assertions green** | **a documented deletion or visibility reduction actually happened** |
| **`G0.8`** | **external-consumer probe green** | **the façade is real from outside the crate** |

Only then does an artifact become **Revision N**. Anything before that is a
**working draft** and is not circulated for review.

### `G0.7` and `G0.8` — why compilation is not enough

`G0.3`–`G0.5` prove the code compiles, behaves, and lints. **They cannot prove
a negative claim.** Code that never had a feature compiles perfectly, so
"deleted", "narrowed to `pub(crate)`", "made private", and "unreachable from
outside" are all unfalsifiable by a build.

Revision 8 of the Phase 1 Vault plan shipped **seven** such claims false with
`G0.3`–`G0.5` fully green — including `Seed::as_bytes` recorded as deleted while
remaining `pub`, which publishes the 64-byte master seed from which every other
key in the system derives. Five of the seven were findable by `grep` in under a
minute. Two council reviewers proposed this gate independently in the same round
and **neither proposed an architectural change**, which is the evidence that the
architecture was stable and the validation system was one executable layer
short.

- `docs/superpowers/plans/g0-claim-assertions.sh` — each assertion names the
  finding that motivated it. **A claim with no assertion here is a claim nothing
  checks.**
- `docs/superpowers/plans/g0-consumer-probe.sh` — `DENY` probes must fail to
  compile; `ALLOW` probes must compile. Revision 8 failed both directions at
  once: the master seed was reachable, and the device-trust journey was not,
  because `trust_device` is `pub` and takes a type `lib.rs` does not export.

This is the mechanical backstop for the Evidence Rule, which this document
already marks *"human discipline — no mechanical backstop."* That row has failed
in every revision it has been tested against.

### Property tests enter through the user's door

A test must reach the code the way a user or an attacker does. Revision 8's
truncation test removed `Frame` structs from an already-parsed package — a state
**no file can produce** — so `PackageTruncated` was asserted while being
unreachable from any real package. Measured on disk, every truncation returns
`SerializationFailed`, identical to corruption, which is the precise property
`ADR-0017` exists to remove.

Distinct from claim drift and needing a different remedy: nothing was
mis-stated, and no assertion or probe would have caught it. **For a format, the
door is bytes.**

### Each control has a test that only it can fail

A passing suite is not evidence that each control matters. The required property
is narrower:

> **Every security control has at least one test whose only failing cause is the
> removal of that control.**

Established by mutation: with all 85 Revision 8 tests, removing frame AAD,
trailer AAD, frame-nonce index pinning, or `frame.index == position` each left
the suite **entirely green**. Collapsing the frame nonce to a constant — one
`(key, nonce)` pair for every frame, so ChaCha20 keystream reuse and Poly1305
key recovery — was unobserved. Two tests existed for those controls and each
passed via the *other* control, so one mechanism silently masked another.

Stronger than coverage, and it is why mutation regressions are kept permanently
rather than run once.

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

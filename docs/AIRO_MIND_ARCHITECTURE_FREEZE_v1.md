# Airo Mind — Architecture Freeze v1

Status: **BINDING once PR #1312 merges.** Until then, pending.
Date: 2026-07-28
Owner: Airo Engineering Council
Scope: the Airo Mind runtime only. Does not amend `docs/PLATFORM_CONSTITUTION.md`.

---

## What this declares

The Airo Mind runtime architecture is **frozen**. From the moment #1312 merges:

- **No new primitives.**
- **No new invariants.**
- **No new contracts.**
- **No new architectural concepts.**

Everything else is implementation, validation, or an **Architecture Change
Proposal**. There is no fourth category.

The remaining work is not requirements. It is **proving these decisions with
implementation, benchmarks, and tests — not redesigning them.**

---

## Frozen surfaces

### 1. Runtime primitives — frozen

`Identity` · `Operation` · `Content` · `Context` · `Capability` · `Projection` ·
`Vault`

Seven. Design spec §2. Adding an eighth is an ACP.

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

Design spec §11a. Eight. Adding a ninth is an ACP.

### 3. Runtime contracts — frozen at `v1`

`C1` Storage · `C2` Replay · `C3` Sync · `C4` Projection · `C5` Capability ·
`C6` Supervisor · `C7` Security

`2026-07-28-airo-mind-runtime-contracts.md`. Versioned as runtime ABI. **A
contract version change is a runtime major version** and requires an ACP.

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
runtime is missing a generic primitive — which is an ACP, not a local
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

## Architecture Change Proposals

An ACP is an **ADR in `docs/adr/`**, following the mechanism
`PLATFORM_CONSTITUTION.md` already establishes for amendments. We are not
inventing a second process.

An ACP touching any frozen surface above must contain all seven:

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
Requirements Phase              ← COMPLETE at #1312
        ↓
Runtime Validation Phase        ← current
        ↓
Runtime Implementation Phase
        ↓
Capability Implementation Phase
```

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

## Definition of done — requirements phase

- [x] Runtime primitives frozen — seven, design spec §2
- [x] Runtime invariants frozen — eight, design spec §11a
- [x] Runtime contracts frozen — C1–C7 at v1
- [x] Sync model frozen — one model, design spec §11d
- [x] Security model frozen — design spec §4, §6, §7
- [x] Package format frozen — `format_version: 1`
- [x] Public API frozen — six functions, design spec §11c

**Complete on #1312 merge.**

---

## What changes for everyone after the freeze

Airo Mind moves from **system design** to **platform engineering**.

Every future capability — Notes, Brain, Meetings, Health, Finance, TV, or
something nobody has proposed yet — is built against a **stable runtime rather
than a moving architectural target.** That is the whole value of freezing, and
it is worth more than any individual improvement that gets deferred to an ACP.

The corollary, stated plainly because it will be tested: **an exception granted
after the freeze is a permanent maintenance cost**, and it becomes the precedent
the next request cites. The answer to "can we just, for this one case" is an ACP
or no.

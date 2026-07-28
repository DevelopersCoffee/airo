# Airo Mind — Runtime Contracts

Status: **Binding. Versioned as part of the runtime ABI. FROZEN at v1** —
see `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md`. A contract version change is a
runtime major version and requires an ADR in `docs/adr/`.
Date: 2026-07-28
Owner: Airo Engineering Council
Companion to `2026-07-27-airo-mind-runtime-design.md` (invariants I1–I8).

---

## Why contracts, and why now

Invariants describe **what must never happen**. Contracts describe **what every
subsystem guarantees**. The architecture is stable enough that the useful work
has shifted from the first to the second.

These are versioned alongside the runtime and are part of its ABI. A capability
written against Storage Contract v1 keeps working while the storage engine is
replaced beneath it, because the contract — not the implementation — is what it
depended on.

**Contract versions change only by ADR.** A contract change is a runtime major
version. That is the point of writing them down.

Every contract carries **conformance tests**. Per invariant I5, a contract with
no failing form is a description, not a contract.

---

## The control plane / data plane split

The runtime carries two responsibilities that must not be entangled.

```
Runtime
│
├── Control Plane          — manages EXECUTION
│     Supervisor
│     Scheduler
│     Resource Manager
│     Lifecycle
│
└── Data Plane             — manages DATA
      Operation Log
      Content Store
      Vault
      Replay
      Sync
      Projections
```

This matters most when the AI engines arrive. Speech recognition, OCR,
embeddings, and local LLM inference are **long-running workloads**. They request
CPU, memory, and I/O budgets from the control plane; they do not reach into
storage directly.

The constraint that keeps the split honest: **no user data crosses into the
control plane.** No operation payload, no projection data, no key material
passes through the Supervisor's lock. If it does, the Supervisor becomes the
single global contention point and every benefit is paid for twice.

---

## Capability execution — capabilities are passive

```
                  ✗                                    ✓

           Capability                          Supervisor
                ↓                                   ↓
           Runs itself                     Loads Capability
                                                    ↓
                                    Capability emits Operations
                                                    ↓
                                    Runtime updates Projections
```

A capability never drives its own execution. The Supervisor loads it, schedules
it, budgets it, cancels it, and retries it.

This centralizes scheduling, cancellation, retries, and resource accounting in
one place — which is the only place they can be enforced. A capability that
runs itself is a capability whose CPU use nobody can cap and whose work nobody
can cancel when the user navigates away.

---

## C1 — Storage Contract `v1`

**Guarantee:** durable state exists only as Operations, Content, and Vault
metadata.

- Every durable object is reachable from the operation log
- The Vault holds identity, key hierarchy, context keys, revocation ledger,
  device certificates, and policies — **sized by contexts and devices, never by
  user content** (design §4.1)
- The content store holds encrypted content objects and their wrapping sets
- No other durable store exists. No capability owns one (I2, I4)
- Writes are sequential and append-only; no in-place rewrite
- Small writes are group-committed with a bounded window; per-operation `fsync`
  is reserved for explicit durability points

**Conformance tests:** a module declaring `persistence: runtime` opens no
database · every durable object is reachable from a log replay · a synthetic
100k-content vault serializes within a constant factor of a 10k-content vault.

## C2 — Replay Contract `v1`

**Guarantee:** replay is deterministic, single-pass, and bounded.

- The same log produces **byte-identical** state on every device and platform
- No wall-clock, `HashMap` iteration, float formatting, or locale on any replay
  path
- Replay is a **single pass** fanning out to N projection sinks, not N replays
- **Snapshots are cache-only** and carry the verified-prefix watermark they were
  built at
- Signature verification is an **ingest-time obligation**; replay below the
  watermark does not re-verify
- Migrations are pure, total, forward-only, and transform interpretation at
  replay — the log is never rewritten
- Peak memory is O(1) in operation count (I7)

**Conformance tests:** cross-platform replay equivalence · `replay_passes == 1`
· RSS at 1M operations within 10% of RSS at 100k · snapshot deleted and rebuilt
produces identical state.

## C3 — Sync Contract `v1`

**Guarantee:** devices converge by exchanging operations only.

- Operations are the **only** synchronized unit — never state, never files
- Peers authenticate mutually against Vault device certificates before any
  exchange
- Reconciliation is **O(device count)**, not O(operation count) — per-device
  monotonic sequence numbers, not set reconciliation over operation IDs
- Conflict resolution follows the merge precedence chain: safety-class veto →
  property override → archetype rule → primitive default
- Merge is commutative, associative, and idempotent
- Revocation merge is **fail-closed**: when two ledgers disagree, the outcome
  revokes more, never less
- Transport is interchangeable; the engine does not know what carried the bytes

**Conformance tests:** property tests for merge commutativity, associativity,
idempotence · two devices converge from any operation permutation · a no-op
sync between two 1M-operation replicas exchanges a bounded constant · an
unauthenticated peer exchanges nothing.

## C4 — Projection Contract `v1`

**Guarantee:** every projection is rebuildable, cache-only, and disposable.

- A projection may be deleted at any time and rebuilt from the log with **zero
  data loss** (I1)
- **No value exists only in a projection**
- Every projection declares `rebuild: incremental | full_replay` — incremental
  by default
- Every projection declares `invalidation: targeted | full`
- `DestroyContent` invalidates every projection derived from that content,
  including embeddings, search snippets, and caches
- A `full`-invalidation rebuild is deferred to a bounded idle window; a destroy
  never blocks the UI on it, and is **never skipped because it is expensive**

**Conformance tests:** rebuild-from-scratch per projection · destroy content,
assert the derived entry is gone · a `targeted` projection proves it without a
full rebuild.

## C5 — Capability Contract `v1`

**Guarantee:** capabilities emit operations and consume projections. Nothing
else.

- The surface is exactly: `emit_operation` · `attach_content` ·
  `query_projection` · `instantiate_context` · `replay` · `sync`
- No SQL, no filesystem, no encryption primitives, no key material, no storage
  engine named anywhere
- A capability is **data, not code** — the runtime executes it; it never
  executes itself
- Capabilities are **passive**: the Supervisor loads, schedules, budgets,
  cancels, and retries them
- Capability entities extend the fixed core ontology, never an archetype
  directly
- Safety class **ratchets** — stricter is allowed, looser is rejected at
  validation
- Contexts created by a capability **outlive it**; uninstalling never deletes
  user data

**Conformance tests:** a capability with no filesystem access still passes its
suite · uninstall then assert contexts and content survive · a capability
declaring a looser safety class than its lineage fails validation.

**The governing question**, applied to every capability:

> Can it be implemented entirely by emitting operations and consuming
> projections? If no, either the runtime is missing a generic primitive that
> should be added once for everyone, or the capability is bypassing the
> runtime. There is no third branch.

## C6 — Supervisor Contract `v1`

**Guarantee:** every engine requests resources; the Supervisor grants them.

- Owns lifecycle, scheduling, cancellation, health, metrics, and backpressure
- Owns **memory, CPU, and I/O budgets**. An engine that exceeds its budget is
  throttled or cancelled, not permitted to starve the UI
- One thread pool per process. Subsystems do not each construct a runtime
- Work started from the UI is **cancellable** when the user navigates away or
  the app backgrounds
- Dependency ordering is enforced: Vault before Replay before Projection; sync
  does not start before replay reaches head
- Shutdown is graceful: the group-commit buffer flushes and the active segment
  seals
- **Control plane only.** No operation payload, no projection data, no key
  material passes through its lock

**Conformance tests:** a long replay cancelled mid-flight leaves no torn state ·
an engine exceeding its memory budget is stopped before the process OOMs · a
kill during group commit recovers cleanly on next start.

## C7 — Security Contract `v1`

**Guarantee:** destroyed content is unrecoverable; recovery is deterministic.

- Every operation is signed; unauthorized devices cannot write
- Every secret type is `Zeroize` + `ZeroizeOnDrop`; no derived `Debug`, `Clone`,
  or non-constant-time `PartialEq` on key material
- Every plaintext field influencing a security decision is AAD-bound or signed,
  with injective, length-prefixed, domain-separated construction
- **Header disclosure rule:** headers may reveal the structural metadata replay
  requires, and never anything that distinguishes identical user content after
  crypto-shredding
- Revocation covers content, contexts, **and devices**
- No path reaches key material without applying revocations
- Restore is deterministic and revocation-aware: a backup predating a
  destruction cannot resurrect it
- `unsafe` is prohibited unless isolated, documented, benchmarked, fuzzed,
  audited, and justified

**Conformance tests:** every AAD-bound field has a tamper test · a stale backup
does not resurrect destroyed content or a revoked device · destroy then assert
no reachable representation survives · fuzz targets on every parser reachable
from untrusted input.

---

## Runtime v1 — "architecture complete"

The runtime stops being an evolving architecture and becomes a stable platform
when **all ten** of these hold. Tracked on #1311.

1. The runtime boots with only the Supervisor.
2. Every capability runs through the Supervisor.
3. No capability owns durable persistence.
4. Every durable object is reachable from the operation log.
5. Every projection can be deleted and rebuilt.
6. A Recovery Package restore reproduces identical state.
7. Two devices converge by exchanging operations only.
8. `DestroyContent` removes every reachable representation of user content,
   except immutable structural metadata intentionally retained by design.
9. Every runtime contract has automated conformance tests.
10. Every performance contract has benchmark gates in CI.

Conditions 9 and 10 are what make the other eight verifiable rather than
asserted. Per I5 and I8, a condition with no failing form is not met — it is
merely claimed.

**After that point, engineering effort shifts to building capabilities rather
than changing the substrate beneath them.** Every accepted exception before then
is a permanent maintenance cost, because the runtime is intended to underpin
every future capability.

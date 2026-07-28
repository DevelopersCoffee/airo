# Airo Mind — Runtime Conformance Suite

Status: **Binding.** Companion to the frozen runtime contracts C1–C7.
Date: 2026-07-28
Owner: Airo Engineering Council
Tracked on: #1340

---

## What this is, and what it is not

Unit tests validate an implementation. **Conformance tests validate the
contract itself** — they are written against C1–C7, not against the code that
happens to satisfy them today, and they survive a reimplementation of the
subsystem beneath them.

Per invariant **I5**, a contract with no failing form is a description. This
suite is the failing form for every contract the runtime declares.

**Every capability passes these suites automatically before it is considered
runtime-compliant.** Not on request, not at review time — as a gate.

The distinction that makes them worth maintaining separately:

| | Fails when |
|---|---|
| Unit test | The implementation is wrong |
| **Conformance test** | **The contract is violated, regardless of implementation** |

A conformance test that has to change when the storage engine changes was
written against the implementation and is a unit test wearing the wrong label.

---

## S1 — Storage conformance (contract C1)

- [ ] Durable state originates **only** from the runtime — I4
- [ ] No capability-owned persistence: a module declaring `persistence: runtime`
      opens no database, writes no file, touches no preferences — I2
- [ ] Every durable object is reachable from a log replay
- [ ] **Destroy invalidates every projection** derived from that content —
      including embeddings, search snippets, and caches
- [ ] Recovery reproduces **identical** runtime state: same package + same seed
      + same ledger ⇒ byte-identical vault
- [ ] **The Vault holds authority, never inventory** — live content never enters
      it. Measured: a 100k-content vault serializes within a constant factor of a
      10k-content vault. *Retained as a regression guard on the §4.1 redesign,
      which measurement confirms holds at −0.8%. It is no longer a growth test —
      the Vault has no content dimension to grow in.*
- [ ] **Peak memory during export and restore is O(1) in the Vault's actual
      growth dimension**, which per ADR-0017 is contexts + devices + revocations.
      Measured: export peak RSS at 100k revocation entries within 20% of peak RSS
      at 10k, and the same for contexts. *This is the test the previous one
      stopped being. It currently fails at +849%, which is why ADR-0017 requires
      framing.*
- [ ] **Retention-class expiry adds no ledger entry** — running a `recoverable`
      object past its 30-day window, or an `ephemeral` object past its derived
      artifact, destroys the content and leaves `head_epoch` unchanged (ADR-0017)
- [ ] **Expiry is derived from logged time, never local wall clock** — two
      devices with clocks skewed by a week reach byte-identical state from the
      same log. *Without this, expiry is device-dependent, which makes it a
      decision, which puts it back in the ledger and undoes ADR-0017 silently.*

## S2 — Replay conformance (contract C2)

- [ ] Replay is **deterministic**: the same log produces byte-identical state on
      every device and platform
- [ ] **Replay after snapshot equals full replay** — the snapshot is a cache,
      and this is the test that proves it (I1)
- [ ] Migration produces identical state on every device running the same chain
- [ ] Replay order invariants hold: any permutation of concurrent operations
      converges
- [ ] `replay_passes == 1` — asserted, not documented
- [ ] **Peak RSS during replay is O(1) in replayed state size** (I7) — measured
      as RSS at 1M operations within 10% of RSS at 100k, where the operations
      *build state* rather than being no-ops. A log of 1M operations that creates
      1M contexts is the case this protects; a log of 1M no-ops passes while
      testing nothing
- [ ] Signature verification does not repeat below the verified-prefix
      watermark

## S3 — Capability conformance (contract C5)

- [ ] Emits operations only — no other write path exists to it
- [ ] Reads projections only
- [ ] **Cannot access storage directly** — a capability denied all filesystem
      and database access still passes its own suite
- [ ] **Cannot bypass the Supervisor** — it has no route to schedule, spawn, or
      persist on its own
- [ ] Uninstalling it leaves its contexts, entities, and content intact
- [ ] A capability declaring a safety class looser than its ontology lineage
      fails validation

> This is the suite that would have caught `DriftMeetingRepository`,
> `features/coins/`, `features/money/`, and `relational_store` — four
> capability-owned stores that exist because nothing asked these questions
> mechanically.

## S4 — Supervisor conformance (contract C6)

- [ ] **Lifecycle ordering**: Vault before Replay before Projection; sync does
      not start before replay reaches head
- [ ] **Cancellation**: work started from the UI stops when the user navigates
      away or the app backgrounds, and leaves no torn state
- [ ] **Backpressure**: a producer faster than the local apply path is pushed
      back on, not buffered without bound
- [ ] **Resource limits**: an engine exceeding its memory budget is stopped
      before the process is
- [ ] **Engine restart**: a failed engine restarts without corrupting the state
      of the engines around it
- [ ] Graceful shutdown flushes the group-commit buffer and seals the active
      segment
- [ ] The Supervisor is a **control plane only** — no payload, projection data,
      or key material passes through its lock

## S5 — Security conformance (contract C7)

Listed for completeness; the detailed form lives in the Security checklist.

- [ ] Every AAD-bound field has a tamper test that asserts failure — I3
- [ ] A backup predating a destruction cannot resurrect it, for content,
      contexts, **and** devices
- [ ] No path reaches key material without applying revocations
- [ ] Destroy leaves no reachable representation of user content beyond the
      structural metadata §3.1 intentionally retains

---

## Review maturity — the division of labour this enables

The goal is not "no findings". It is **findings arriving at the cheapest layer
that can produce them.**

| Layer | Finds |
|---|---|
| **CI** | Syntax and mechanical issues |
| **Conformance tests** | Contract violations |
| **Benchmarks** | Performance regressions |
| **Human reviewers** | Architectural judgment, and nothing else |

> When human reviewers are no longer spending time on things machines can
> prove, the engineering process has reached a mature state.

Measured against that target, Phase 1 today is immature and the documents say
so: four council reviews spent effort on missing imports, a non-compiling plan,
and a property recorded as applied that was never written. Every one of those
belongs to a lower layer.

The convergence metric in `AIRO_MIND_ARCHITECTURE_FREEZE_v1.md` tracks the
movement. This suite is what moves it.

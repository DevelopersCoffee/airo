# Airo Mind — Reusable Review Checklists

Status: **Binding for every Airo Mind change.**
Date: 2026-07-27
Owner: Airo Engineering Council

Council reviews should not produce one-off findings that have to be
rediscovered next time. Each review run adds to these lists; every future
capability is reviewed against them.

These exist because two consecutive revisions of the Phase 1 Vault plan shipped
defects of the same shape — a fix applied in one file and forgotten in another,
and a security property recorded as applied that was never written. Neither was
hard to find. Both survived review because nothing carried forward.

Where a line can be a CI check it is marked **[CI]** and belongs in #1287 or
#1294 rather than in a reviewer's head.

---

## Security checklist

Applied by chief-security-officer to any change touching keys, content,
operations, or the trust boundary.

### Authenticated metadata
- [ ] Every plaintext field that influences a security decision is bound as AAD or covered by a signature
- [ ] AAD construction is injective — length-prefixed, domain-separated, no two distinct inputs producing the same bytes
- [ ] **[CI]** Every AAD-bound field has a tamper test: modify it, assert failure (invariant I3)
- [ ] Signing payloads are hand-built, never a serializer's output

### Replay protection
- [ ] Replaying the same log produces byte-identical state on every platform
- [ ] **[CI]** No wall-clock, `HashMap` iteration, float formatting, or locale in any replay path
- [ ] Operations are idempotent under re-delivery
- [ ] Migrations are pure, total, and forward-only

### Revocation
- [ ] Revocation covers every subject type — content, context, device — not only the obvious one
- [ ] Revocation merge is fail-**closed**: when two ledgers disagree, the outcome revokes more, never less
- [ ] No path reaches usable key material without applying revocations
- [ ] A revocation source carries provenance; an empty ledger cannot silently pass as a checked one

### Recovery
- [ ] Restore is deterministic: same package + same seed + same ledger ⇒ identical state
- [ ] A backup predating a destruction cannot resurrect it
- [ ] The recovery artifact grants access without carrying data
- [ ] Restore fails closed on an unsupported format or an unknown protected mode

### Tamper detection
- [ ] Ciphertext modification is detected, not silently mis-decrypted
- [ ] Identity binding is verified before any decrypted state is trusted
- [ ] Format version is checked at parse time, not only at use time

### Key lifecycle
- [ ] Every secret type is `Zeroize` + `ZeroizeOnDrop`
- [ ] **[CI]** No `derive(Debug)`, `derive(Clone)`, or `derive(PartialEq)` on a secret; equality is constant-time
- [ ] Intermediate plaintext buffers are `Zeroizing`
- [ ] Feature flags that provide zeroization are pinned explicitly, with a compile-time guard
- [ ] Key material does not cross an FFI boundary; documented exceptions are enumerated and prohibited from logging

---

## Runtime checklist

Applied by chief-architect to every capability and every runtime change.

### The question that governs everything
- [ ] **Can this be implemented entirely by emitting operations and consuming projections?** If no: either the runtime is missing something generic that should be added once for everyone, or the feature is bypassing the runtime. There is no third branch and no "this feature is special".

### No direct persistence
- [ ] **[CI]** The module declares `persistence: runtime | projection | ephemeral` and the declaration matches reality (§11b)
- [ ] **[CI]** No SQLite, Drift, JSON file, preferences entry, or object store owned by a capability (invariants I2, I4)
- [ ] The capability uses only the runtime API — `create_operation`, `attach_content`, `query_projection`, `instantiate_context`, `emit_event` — and names no storage engine

### Replay determinism
- [ ] State is derived from the log, never accumulated in place
- [ ] Concurrent operations have a defined total order
- [ ] **[CI]** Serialized structures use `BTreeMap`, never `HashMap`

### Projection rebuilds
- [ ] **[CI]** Every `projection` module has a rebuild-from-scratch test
- [ ] Dropping the projection loses no data (invariant I1)
- [ ] `DestroyContent` invalidates every projection derived from that content — including embeddings, search snippets, and caches
- [ ] No value exists only in a projection

### Migration determinism
- [ ] Migrations transform interpretation at replay; the log is never rewritten
- [ ] Every device running the same migration chain reaches the same state
- [ ] Merge strategy does not change within a compatible version
- [ ] Schema fingerprint changes when and only when the schema changes

### Ontology discipline
- [ ] Capability entities extend the core ontology, never an archetype directly
- [ ] Domain meaning rides on labels, not new types
- [ ] Safety class ratchets — stricter is allowed, looser is rejected at validation

---

## Rust checklist

Applied by rust-architect to any change under `rust/`.

### No panic paths
- [ ] **[CI]** No `panic!`, `unwrap()`, `expect()`, `todo!()`, or `unreachable!()` outside `#[cfg(test)]`
- [ ] **[CI]** No `fill_bytes` — `try_fill_bytes` only
- [ ] **[CI]** No `AeadCore::generate_nonce`; RNG access goes through the approved helpers
- [ ] Slice indexing and arithmetic cannot panic on hostile input

### Error propagation
- [ ] Errors carry enough context to debug without carrying secrets
- [ ] No error variant is used for two unrelated failures — a mis-mapped variant misleads whoever debugs it next
- [ ] Fallible constructors return `Result` rather than defaulting

### Zeroization
- [ ] Covered by the security checklist's key-lifecycle section; the Rust reviewer confirms the derives and drop order actually do what they claim
- [ ] A `ZeroizeOnDrop` struct whose only field is `#[zeroize(skip)]` is flagged — it zeroizes nothing

### Fuzz coverage
- [ ] Every parser reachable from untrusted input has a fuzz target — recovery packages, capability manifests, operation headers, imported capsules
- [ ] Fuzz targets run in CI on a schedule, not only locally

### Property tests
- [ ] Round-trip: encode then decode is the identity, for every serialized type
- [ ] Merge is commutative, associative, and idempotent
- [ ] Replay of any operation permutation converges
- [ ] Revocation is monotonic — applying it twice equals applying it once

### `unsafe`
- [ ] The crate itself contains no `unsafe`
- [ ] Transitive `unsafe` in audited third-party crypto crates is explicitly accepted and named, not passed over in silence

---

## How these are used

1. A capability or runtime change opens with the relevant checklists in the PR body, unticked.
2. The reviewing officer ticks what they verified **against the code**, not against the PR description. A line ticked because the summary said so is the exact failure this document exists to prevent.
3. Anything a review discovers that is not on a list gets **added to the list** in the same PR. That is what makes the next review cheaper than the last.
4. **[CI]** lines migrate out of here and into #1287 and #1294 as they are automated. A line that CI enforces is deleted from the human checklist — reviewer attention is scarce and should be spent on what machines cannot check.

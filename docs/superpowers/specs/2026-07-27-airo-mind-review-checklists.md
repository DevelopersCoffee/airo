# Airo Mind — Reusable Review Checklists

Status: **Binding for every Airo Mind change.** The runtime API and invariant
list quoted here are **frozen surfaces** — see
`docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md`. If they drift from the design spec,
this file is wrong, not the spec.
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

## Reporting checklist

Applied by **whoever reports work as done** — human or agent — before saying so.
These are not hypothetical. Both occurred repeatedly during Phase 1 planning,
and both wasted reviewer time on states that did not exist.

### Claim drift — reported as implemented, absent from the code
- [ ] Every property described as applied is **read back from the file**, not from the summary that says it was applied
- [ ] A changelog entry asserting a fix is checked against the code it claims to have changed
- [ ] **[CI]** Where the property is mechanical, a check enforces it rather than a sentence claiming it (I5)

> Four times in Phase 1 a property was recorded as applied and was absent: the
> header AAD, the revocation-subject rewrite, error variants declared and never
> constructed, and the checklist's runtime API. Each was found by a later
> reviewer, at review cost, having already been marked done.

### State drift — reported complete after a push, not after a merge
- [ ] Completion is reported after **verifying the merge landed**, never after a successful push
- [ ] The verification reads the target branch, not the local branch or the PR page
- [ ] A PR that merges while commits are still being pushed leaves them orphaned — check for commits ahead of the base after any merge you did not perform

> Three times in Phase 1 a PR merged while work was still being pushed, taking
> the branch's earlier commits and closing. A successful `git push` says
> nothing about what landed. Once, this left the architecture freeze document
> unmerged while its contracts went in — the exact window the freeze existed to
> close.

---

## Security checklist

Applied by chief-security-officer to any change touching keys, content,
operations, or the trust boundary.

### Authenticated metadata
- [ ] Every plaintext field that influences a security decision is bound as AAD or covered by a signature
- [ ] AAD construction is injective — length-prefixed, domain-separated, no two distinct inputs producing the same bytes
- [ ] **[CI]** Every AAD-bound field has a tamper test: modify it, assert failure (invariant I3)
- [ ] Signing payloads are hand-built, never a serializer's output
- [ ] Length prefixes use checked conversions — an `as u32` truncation breaks injectivity on a long field
- [ ] Every domain-separation constant in use is read from the registry, not re-declared as a literal at the use site — a registry the code does not read guards nothing

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
- [ ] Epoch or counter values from two independently-maintained ledgers are never compared — per-device counters are not a clock; freshness is decided by subject-set containment
- [ ] Every enum arm a security decision switches on is reachable from a public API in the same phase, or is documented as reserved and asserted unreachable

### Recovery
- [ ] Restore is deterministic: same package + same seed + same ledger ⇒ identical state
- [ ] A backup predating a destruction cannot resurrect it
- [ ] The recovery artifact grants access without carrying data
- [ ] Restore fails closed on an unsupported format or an unknown protected mode
- [ ] A warning returned to the caller is `#[must_use]` — otherwise it is advice, not a control
- [ ] Any value used as a KDF password or a signed message is canonicalized first; user whitespace, case, and Unicode form never reach a derivation input verbatim

### Tamper detection
- [ ] Ciphertext modification is detected, not silently mis-decrypted
- [ ] Identity binding is verified before any decrypted state is trusted
- [ ] Format version is checked at parse time, not only at use time

### Vendored cryptographic fixtures
- [ ] Wordlists, test vectors, and constants are fetched from a **pinned commit**, never a branch
- [ ] The expected digest of a vendored fixture has provenance independent of the fetch — a checksum generated by the same command that downloaded the file validates nothing
- [ ] External test vectors are used with their **published parameters** (BIP-39's vectors use the passphrase `"TREZOR"`); an expected value regenerated from our own implementation is not a test
- [ ] A vector fixture asserts a minimum case count, so a truncated or empty file cannot pass silently

### Key lifecycle
- [ ] Every secret type is `Zeroize` + `ZeroizeOnDrop`
- [ ] **[CI]** No `derive(Debug)`, `derive(Clone)`, or `derive(PartialEq)` on a secret; equality is constant-time
- [ ] Intermediate plaintext buffers are `Zeroizing`
- [ ] Feature flags that provide zeroization are pinned explicitly, with a compile-time guard
- [ ] Key material does not cross an FFI boundary; documented exceptions are enumerated and prohibited from logging
- [ ] The **deserialized** structure holding key material is itself `ZeroizeOnDrop` — wrapping only the serialized byte buffer leaves the parsed copy in the clear
- [ ] Serialization writes into a pre-sized `Zeroizing` buffer; wrapping the returned `Vec` does not cover the reallocations it outgrew
- [ ] Bit- or byte-expanded intermediates of a secret (bit vectors, HMAC round outputs, hex strings) are zeroized — they are the same secret in a more scannable form
- [ ] A constant-time claim is checked against the whole path: a constant-time comparison preceded by a data-dependent table scan or an early return is not constant time, and the comment saying so is worse than no comment

---

## Runtime checklist

Applied by the **Runtime Architect** to every capability and every runtime
change. This is a distinct council role from chief-architect and
chief-security-officer, added because neither was asking its questions:
`DriftMeetingRepository` passed both and would have been caught here on the
first line.

Its six questions, in order:

1. Does this introduce a second source of truth?
2. Does this bypass the operation log?
3. Does this bypass the Vault?
4. Does this bypass projections?
5. Does this create feature-owned state?
6. Does this violate I1–I8?

### The question that governs everything
- [ ] **Can this be implemented entirely by emitting operations and consuming projections?** If no: either the runtime is missing something generic that should be added once for everyone, or the feature is bypassing the runtime. There is no third branch and no "this feature is special".

### No direct persistence
- [ ] **[CI]** The module declares `persistence: runtime | projection | ephemeral` and the declaration matches reality (§11b)
- [ ] **[CI]** No SQLite, Drift, JSON file, preferences entry, or object store owned by a capability (invariants I2, I4)
- [ ] The capability uses only the runtime API — `emit_operation`, `attach_content`, `query_projection`, `instantiate_context`, `replay`, `sync` — and names no storage engine

### Replay determinism
- [ ] State is derived from the log, never accumulated in place
- [ ] Concurrent operations have a defined total order
- [ ] **[CI]** Serialized structures use `BTreeMap`, never `HashMap`
- [ ] Replay is a single pass over the log driving all projection sinks; the pass count is asserted, not documented
- [ ] Signature verification does not repeat on every cold start — a persisted verified-prefix watermark bounds it

### Projection rebuilds
- [ ] **[CI]** Every `projection` module has a rebuild-from-scratch test
- [ ] Dropping the projection loses no data (invariant I1)
- [ ] `DestroyContent` invalidates every projection derived from that content — including embeddings, search snippets, and caches
- [ ] No value exists only in a projection
- [ ] **[CI]** The module declares `rebuild: incremental | full_replay` and `invalidation: targeted | full`, and the declaration is tested
- [ ] A projection that cannot be expressed as an `apply(&mut self, &Operation)` sink declares `full_replay` and carries its measured cost
- [ ] `DestroyContent` against a `full`-invalidation projection has a bounded, deferred rebuild path — the purge is never skipped because it is expensive

### Migration determinism
- [ ] Migrations transform interpretation at replay; the log is never rewritten
- [ ] Every device running the same migration chain reaches the same state
- [ ] Merge strategy does not change within a compatible version
- [ ] Schema fingerprint changes when and only when the schema changes

### Invariants are testable (I5)
- [ ] Every invariant this change claims has a **failing form**: a compile error or a test that fails when it is violated. Documentation alone is not evidence.
- [ ] The test was written before the claim was recorded as applied — three review cycles found properties marked done that were absent from the code

### Canonicalization (I6)
- [ ] Externally-supplied values pass through a canonicalizer before anything else sees them; nothing below that layer receives raw input
- [ ] Canonicalization happens **exactly once**, not defensively re-applied at each layer — re-canonicalizing hides the layer that forgot
- [ ] No function accepts a raw and a canonical value at the same type; the type distinguishes them or the raw form is unreachable past the boundary
- [ ] Applies to identifiers and derivation inputs, not just user text: entity, context, capability and package IDs, paths, URLs

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

### The plan's code is code
- [ ] **[CI]** Every Rust block in a plan compiled before the plan was approved — paste it into a scratch crate, run `cargo clippy --all-targets -- -D warnings`. Three consecutive revisions shipped code that could not compile; each cost a reviewer more time than the check does.
- [ ] Every "Interfaces" block matches the code in its own task, field for field — later tasks are written against the block, not the code
- [ ] Every call site in a later task is checked against the signature the earlier task actually produced
- [ ] Step-4 test counts, "Expected:" lines and commit messages match their own step; copy-pasted boilerplate is how a plan stops being an oracle

### Types over comments
- [ ] An invariant a comment asserts is expressed as a type, or the comment records why it cannot be — `RevocationSubject` existed while the API still took `&str`, so the invariant never became enforceable
- [ ] No doc comment claims a property the call does not have — `verify` documented as "strict verification" when `verify_strict` is the strict call is a false claim in the security-critical direction
- [ ] Impossible states are unrepresentable, not merely untested: no route to a guarded value via `Debug`, `Clone`, serde, a public field, or a pattern match
- [ ] A `&str` convenience method beside a tagged subject type is justified or removed — a convenience overload accepting the looser type re-opens what the newtype closed, and it trains the next call site
- [ ] APIs cannot be called in the wrong order — prefer consuming methods and typestate over documented sequencing
- [ ] A returned obligation is consumed by a parameter the caller must supply, or an enum the caller must match; `#[must_use]` is a lint, not a mechanism
- [ ] `#[must_use]` on a `-> bool` getter enforces nothing — the caller being warned is the one who never calls it
- [ ] A constructor asserting provenance takes a witness only the claimed producer can mint, or stays `pub(crate)` until that producer exists
- [ ] A typestate is only as strong as its narrowest visibility — a `pub(crate)` back door guards nothing once the crate holds more than one subsystem; gate the constructor on a witness type with a private field
- [ ] Signing and derivation entry points take a domain-tagged payload type, never `&[u8]` — a raw signing oracle over the root key cannot be domain-separated by its callers' good intentions
- [ ] A struct whose fields are covered by a signature or an AAD does not expose those fields as `pub` mutable
- [ ] A helper written to hold an invariant (checked length prefixes, canonicalization) is used at **every** site that invariant applies to — one built and unused is worse than none, because it reads as done
- [ ] Identifiers and secrets are domain types, not `String` / `Vec<u8>` / `u64` — `ContentId`, `ContextId`, `OperationId`, `RootPublicKey`, `RevocationEpoch`, `WrappedKey`, `ContentHash`
- [ ] A constructor accepting a raw primitive where a domain type exists is flagged — `Vault::new([7u8; 32])` builds a vault against a root that corresponds to no seed in existence

### Public surface
- [ ] `pub` vs `pub(crate)` is decided per item, not per module; `pub mod` on a module holding key material exports every future item added to it
- [ ] No key-minting or envelope-building primitive is reachable outside the aggregate that owns the revocation ledger — state created around the aggregate can never be shredded
- [ ] **[CI]** Every `pub(crate)` item has a non-test caller or is `#[cfg(test)]` — `cargo clippy` builds the lib without `cfg(test)` and `dead_code` fails `-D warnings`
- [ ] No public error variant is unconstructible in the phase that ships it

### Lints and manifest
- [ ] `unsafe` is prohibited unless **isolated, documented, benchmarked, fuzzed, audited, and justified** — all six, recorded per call site. Crates holding crypto, vault, merge, replay, or capability logic keep `forbid(unsafe_code)`; low-level primitives live in one small crate with an audited surface.
- [ ] A blanket lint is checked against what the crate will own later — `forbid` on the crate that will hold the operation log permanently forecloses `mmap`, and `forbid` cannot be locally overridden
- [ ] Large fixture arrays are `static`, not `const` — `clippy::large_const_arrays` fails `-D warnings` and a `const` array is materialised at every use site
- [ ] `x % n == 0` is written `x.is_multiple_of(n)` — `clippy::manual_is_multiple_of` fails `-D warnings`
- [ ] No blank line between a doc comment and its item — `clippy::empty_line_after_doc_comments` fails `-D warnings`; a doc comment orphaned by a deleted const silently attaches to the next item
- [ ] Fixed-size arrays above 32 bytes have their serde representation decided **in the design**, not left to the implementer — it is the on-disk format, and `[u8; 64]` has no serde impl
- [ ] Dependency floors use a caret (`"4.1.3"`), never an open `">=4.1.3"` — an open floor lets a future major resolve beside the transitive one and links the crate twice
- [ ] `default-features = false` on a crypto crate is diffed against that crate's default list and the loss recorded — dropping `ed25519-dalek`'s `fast` removes `curve25519-dalek/precomputed-tables`
- [ ] A workspace `[profile.release]` is measured on **every** member, not only the new one; `opt-level`/`codegen-units` belong in `[profile.release.package.<name>]`, and `panic = "abort"` is never set where `catch_unwind` carries FFI errors
- [ ] The accepted-transitive-`unsafe` note names the crates actually in `cargo tree`, verified, not the ones assumed to be there
- [ ] A returned `Vec` that the caller only iterates is an iterator; a returned `Vec` built solely to call `.first()` is a defect
- [ ] `entry(k.clone())` on a map is flagged — it allocates on the hit path; use `get_mut` then `insert` on miss
- [ ] A `&str` convenience wrapper that constructs an owned key to perform a lookup allocates on every call and belongs on the hot-path review list

### `unsafe`
- [ ] The crate itself contains no `unsafe`
- [ ] Transitive `unsafe` in audited third-party crypto crates is explicitly accepted and named, not passed over in silence

---

## Performance checklist

Applied by chief-performance-officer to every Rust change, every new
dependency, and every format decision. Performance decisions at the runtime
layer become ABI decisions — they freeze into the on-disk format and the
operation log, which are explicitly unretrofittable. A number not measured
before a format ships is a number nobody can change afterwards.

### Budgets exist before the code does
- [ ] Every new runtime path has a declared budget in `packages/benchmarks` before it merges, not after
- [ ] The budget names its device class — host, Apple Silicon, Pixel 9, mid-range Android, armv7 TV — and says which are estimated and which are measured
- [ ] A budget that cannot be met on the slowest supported device is a design finding, not a tuning task
- [ ] Constitution §4's `packages/benchmarks` requirement is satisfied in the phase that **freezes the format**, not the phase that first exercises it

### Streaming first (I7)
- [ ] **[CI]** Peak RSS is O(1) in collection size: the same operation over a 10x larger input allocates within a constant factor
- [ ] No path loads a whole log, vault, package, index, or content store into memory before processing it
- [ ] Export, restore, sync, migration, and index rebuild are resumable — a process kill mid-operation does not restart from zero
- [ ] A single-AEAD-blob format is flagged: one tag over the whole payload makes streaming decryption impossible for the life of the format
- [ ] Bulk formats are framed — length-prefixed records with per-frame nonces derived from a frame index, plus a sealed trailer so truncation is detected

### Serialization cost is format cost
- [ ] **[CI]** Byte arrays and ciphertext never serialize as JSON decimal arrays — measured 2.5x for structured payloads and 3.57x for high-entropy bytes
- [ ] The serialized size of any durable format is measured against a compact binary encoding and the ratio recorded in the design
- [ ] Serialize/deserialize wall time is measured at the largest realistic input, not a unit-test-sized one
- [ ] `to_vec` / `from_slice` over a large buffer is flagged — it doubles peak memory through reallocation and forecloses streaming

### Allocation discipline
- [ ] No per-call allocation to perform a lookup — building an owned key to query a map is a hot-path defect
- [ ] No deep clone of an aggregate purely to serialize it; use a borrowing serializer type
- [ ] Accessors return iterators or borrowed slices, not freshly allocated `Vec`s
- [ ] Merge and union operations allocate only on the miss path
- [ ] A collection materialized twice in one function is materialized once

### Replay and projections
- [ ] Signature verification is an ingest-time obligation with a persisted verified-prefix watermark; replay below the watermark does not re-verify
- [ ] Replay is a **single pass** fanning out to N projection sinks — assert the pass count, do not document it
- [ ] Every projection declares `rebuild: incremental | full_replay`, incremental by default
- [ ] Every projection declares `invalidation: targeted | full` — the cost `DestroyContent` imposes on it
- [ ] A `full` invalidation projection has its rebuild deferred to an idle window with a bounded budget; a destroy never blocks the UI on it
- [ ] Snapshot restore time and projection rebuild time are budgeted separately from replay throughput

### Storage and mobile flash
- [ ] Writes are sequential and append-only; no in-place rewrite of durable state
- [ ] Small writes are group-committed with a bounded latency window; per-operation `fsync` is reserved for explicit durability points
- [ ] The group-commit window is tuned against **measured** device fsync latency, never an estimate — it ranges 0.5 ms to 50 ms across real devices
- [ ] Write amplification is estimated for the smallest realistic record against a 4 KB page
- [ ] Where compaction is architecturally forbidden, a signed-checkpoint format slot is reserved before the format freezes
- [ ] Content deduplication is either supported or explicitly ruled out in the design, with the reason, so a later optimization pass cannot reintroduce convergent encryption

### Sync cost
- [ ] Reconciliation is O(device count), not O(operation count) — per-device monotonic sequence numbers, not set reconciliation over operation IDs
- [ ] Content is chunked so transfer is resumable and decryption is streaming; chunk size is recorded in the design
- [ ] Backpressure has a named owner; an unbounded producer cannot outrun the local apply path
- [ ] A no-op sync between two large, converged replicas exchanges a bounded constant, not a function of history

### Ownership and contention
- [ ] The concurrency model is decided before the first concurrent caller, not after
- [ ] No global `Mutex` sits on both the write path and the read path of the same aggregate
- [ ] A lifecycle owner exists for cancellation — long-running work started from the UI can be cancelled when the user navigates away or the app backgrounds
- [ ] One thread pool per process, owned centrally; subsystems do not each construct a runtime
- [ ] A supervisor or coordinator is a **control plane only** — no payload, projection data, or key material passes through its lock

### Compiler profile and dependency features
- [ ] **[CI]** A workspace `[profile.release]` is benchmarked on **every** member before it merges; `opt-level` and `codegen-units` belong in `[profile.release.package.<name>]`
- [ ] `opt-level = "z"` is never applied to a throughput crate — measured at 45–58% throughput loss on `airo_core`'s M3U parser
- [ ] `panic = "abort"` is never set where a `cdylib` FFI bridge relies on `catch_unwind` — verified in the bridge source, not assumed
- [ ] `lto` and `strip` changes record both the size win and the CI build-time cost across the full cross-compile matrix
- [ ] `default-features = false` on a crypto crate has the throughput cost of each dropped feature **measured** and recorded in the manifest comment — dropping `ed25519-dalek`'s `fast` costs 2.65x on signing for 49,952 bytes
- [ ] A profile or feature change affecting a crate on a shipping path is re-measured on that path's real target — `aarch64-linux-android` and `armv7-linux-androideabi`, not only the developer's host
- [ ] `#![forbid(unsafe_code)]` on a crate that will own storage I/O is flagged — it permanently forecloses `mmap`, and the layering must be decided before the log format freezes

### Numbers, not adjectives
- [ ] Every performance claim in a plan or design cites a measurement, its hardware, and its method
- [ ] "Negligible", "fast enough", and "free" are rejected without a number — three review cycles found properties recorded as applied that were absent from the code, and the same failure mode applies to performance claims
- [ ] A measured figure is re-measured when the configuration it was measured under changes

### Cost is part of correctness (I8)
- [ ] The feature declares its **asymptotic complexity** in the dimension that grows — operations, contexts, devices, content
- [ ] The feature declares an **allocation budget**, and the budget is independent of collection size wherever I7 applies
- [ ] A **benchmark** exists in `packages/benchmarks` before merge, not after
- [ ] A **regression threshold** is enforced in CI, so the budget fails loudly rather than eroding
- [ ] A structure's size class is stated and checked: the Vault is sized by contexts and devices, **never** by user content

---

## How these are used

1. A capability or runtime change opens with the relevant checklists in the PR body, unticked.
2. The reviewing officer ticks what they verified **against the code**, not against the PR description. A line ticked because the summary said so is the exact failure this document exists to prevent.
3. Anything a review discovers that is not on a list gets **added to the list** in the same PR. That is what makes the next review cheaper than the last.
4. **[CI]** lines migrate out of here and into #1287 and #1294 as they are automated. A line that CI enforces is deleted from the human checklist — reviewer attention is scarce and should be spent on what machines cannot check.

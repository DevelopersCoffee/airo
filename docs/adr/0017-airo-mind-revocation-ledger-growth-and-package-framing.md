# ADR-0017: Airo Mind revocation ledger growth, retention-class expiry, and Recovery Package framing

## Status

Accepted

## Date

2026-07-28

## Context

The Airo Mind architecture was frozen at v1 in `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md`.
Freeze §4 declares the Recovery Package `format_version: 1` frozen, including
"the framing decided in #1305".

Three things were true at once, and none of them was visible from any single document:

1. **#1305 was open and unimplemented.** Its framing requirement — `[len:u32][AEAD frame] × N`
   plus a sealed trailer — was never built. The freeze document's sentence made a decided-but-unbuilt
   requirement read as a settled fact, and seven revisions of the Phase 1 Vault plan were written
   against neither the issue nor the format it specifies.

2. **#1305's stated premise had been invalidated by a later change.** Its measurement —
   26 MB logical vault → 225 MiB on disk, ~600 MiB peak RSS — was driven by the Vault holding one
   `ContentEnvelope` per content object. #1305 says so directly: *"The Vault is O(all user content),
   not O(keys)."* The design §4.1 redesign ("authority, not inventory") subsequently removed content
   envelopes from the Vault entirely. The driver was deleted rather than framed around.

3. **The Vault retained a second unbounded collection that nobody had measured.** The revocation
   ledger records every destroyed content, context, and device permanently. This is deliberate:
   crypto-shredding leaves a tombstone forever, and R4's blind-restore protection depends on the
   ledger being complete. But it means the Vault is not O(contexts + devices).

The chief-performance-officer re-measured against the redesigned Vault. The §4.1 redesign is
confirmed to have worked exactly as intended — a Vault is byte-identical at 10k and 100k contents
(compact 2,540 B at both, export 0.07 ms at both, peak RSS delta −0.8%). #1305's original argument
is genuinely retired.

The ledger measurements are the reason this ADR exists:

| Measurement | Value |
|---|---|
| Ledger entry, resident | 137.6 B (stable across 100k–5M entries) |
| Ledger exceeds contexts + devices at | **224 destroyed subjects** |
| V5 peak RSS during export, budget 4× | **10.7×–21.6×**, flat across all sizes |
| V7 peak RSS, 10k → 100k revocations, budget +20% | **+849%** |
| Converged-replica `merge`, 100k entries | 11.52 ms — O(N), not O(1) |

V5 and V7 fail against the current single-blob format at every size and in every dimension, and the
ratio is flat rather than growing — so it is structural, not a scale effect a larger budget absorbs.
Byte-oriented serialization does not fix it (measured 11.2× after the fix, marginally worse), because
that win is on disk, not in the live set.

The size of the problem turns on one unanswered design question. Design §4.2 defines four retention
classes, two of which destroy automatically: `recoverable` (unlinked to a recycle context, destroyed
after 30 days) and `ephemeral` (destroyed once its derived artifact exists). Whether those automatic
destructions mint a revocation entry moves the five-year ledger between 91k and 1.8M entries, and the
export peak between ~57 MB and ~2.7 GB.

## Decision

### 1. Retention-class expiry does not mint a revocation entry

**The ledger records what a replica cannot derive.** That is its purpose and now its stated rule.

An explicit `DestroyContent` is a user decision. No replica can compute it from anything else it
holds, so it must be recorded, replicated, and retained forever — otherwise a stale replica
resurrects destroyed content, which is the attack the ledger exists to stop.

Retention-class expiry is not a decision. It is a function of information already in the log:

- `recoverable` — expiry is the logged `UnlinkContent` operation's timestamp plus the class's
  30-day window. Both inputs are already replicated.
- `ephemeral` — expiry is the creation of the derived artifact, which is itself a logged operation.

Every device replaying the same log with the same policy computes the same expiry at the same
logical point and destroys the content key locally, independently, without coordination. A tombstone
would record a conclusion every replica can reach on its own, at 137.6 B each, forever.

**Binding constraint this creates:** expiry must be computed from timestamps carried in logged
operations, never from each device's local wall clock. Wall-clock evaluation makes expiry
device-dependent, which makes it a decision again, which puts it back in the ledger. Phase 2's
retention implementation (#1214) must derive expiry from logged time or this ADR does not hold.

Consequence: the five-year ledger is bounded by user-initiated destroys — the ~91k-entry row, not
the ~1.8M-entry row. That is a 20× reduction in the dominant term, and it comes from deriving rather
than recording.

### 2. C1's size class is amended

C1 currently states the Vault is *"sized by contexts and devices, never by user content"* while
three lines earlier listing the revocation ledger among its contents. Those two statements
contradict each other, and the measurements settle it against the first.

C1 is amended to:

> **O(contexts + devices + revocations)**, where revocations are user-initiated destructions only
> and are retained permanently by design.

"Authority, not inventory" survives as the rule for *live* content and is confirmed by measurement.
It never applied to tombstones, and the contract should never have implied it did.

### 3. Recovery Package framing is required, for the ledger

Framing is upheld — and #1305's justification for it is formally retired and replaced. The measured
case is no longer content envelopes; it is that the Vault still contains an unbounded, monotonic,
never-compacted collection, with an export path that serializes the whole payload, seals it under one
AEAD tag, and parses the whole file back on restore.

The binding requirement is stated as a property, not a layout:

> **Peak memory during export and restore must be O(1) in ledger size, and truncation must be
> distinguishable from corruption.**

`[len:u32][AEAD frame] × N` plus a sealed trailer satisfies this and remains the default shape, but
it was drawn for content envelopes and the implementation is not bound to it. Two properties follow
that nothing in the current design provides: a partial restore that recovers every complete frame,
and a truncated package that reports truncation instead of failing identically to a corrupt one — on
the one artifact whose absence is unrecoverable.

### 4. Byte-oriented serialization is confirmed binding, and is not sufficient alone

#1305's second required change stands and is independent of everything above. Additionally, measured:

- V4's `≤ 3× compact` clause is **not** met by hex alone (3.57×/3.31× after the fix). The format
  double-encodes — a JSON payload, then that ciphertext text-encoded again in the outer JSON. Hex on
  the outer blob costs a hard 2.0×, putting the floor at 3.30×. **Base64 on the outer `ciphertext`,
  `nonce`, and `kdf_salt`** costs 1.33× and clears every measured shape. Inner fields stay hex,
  preserving the stated rationale that the package remain inspectable in a text editor; the
  ciphertext blob is opaque under any encoding.
- The existing `format!("{b:02x}")`-per-byte helper allocates one `String` per byte. Rolling it out
  across the remaining byte fields measures a **4.0× regression** on `to_bytes` (86.66 → 350.82 ms);
  the same output written into one pre-sized `String` measures **16.55 ms**, 5.2× faster and 2.8×
  smaller than what it replaces. The fix must land in the same commit as the rollout.

## Consequences

### Positive

- The dominant growth term is reduced ~20× by deriving expiry instead of recording it, with no loss
  of any security property — a replica that can compute a destruction does not need to be told.
- C1 states a size class that matches the implementation, so future work is measured against a
  contract that is true.
- Framing is decided on current evidence rather than on a superseded measurement, in the direction
  that measurement actually supports.
- Framing is specified as a property, so the implementation can choose a layout without reopening
  this ADR.
- Truncation becomes detectable and partial restore becomes possible on the Recovery Package.
- Revision 8 ships the encoding fix as a 5.2× improvement rather than a 4× regression.

### Negative

- Framing changes the on-disk format, so every AAD binding, identity binding, and tamper test needs
  re-verification against the new shape — chief-security-officer and rust-architect both signed off
  on the current one.
- Phase 1 gains scope it did not have when Revision 7 was written.
- The retention decision binds Phase 2: #1214 must derive expiry from logged timestamps, and a
  wall-clock implementation would silently invalidate this ADR rather than fail loudly. A conformance
  test must enforce it.
- The ledger still grows without bound for user-initiated destroys. This ADR bounds the growth rate,
  not the growth. A compaction story — if one is ever possible without weakening resurrection
  protection — is deferred and not attempted here.
- `RevocationLedger::merge` remains O(N) on converged replicas, which C3's "no-op sync exchanges a
  bounded constant" conformance test does not survive. That is an engineering fix, tracked
  separately, and requires edge-architect and chief-cloud-officer review.

## Governance change — the defect that hid this

Freeze §4 froze a format by reference to an open, unimplemented issue. That single sentence made a
decided-but-unbuilt requirement indistinguishable from a settled one, and it is why seven plan
revisions and three council reviews passed over it.

**A frozen surface may not cite an open issue as its authority.** Freeze §4 is amended to record the
framing requirement as pending under this ADR, with the property stated inline rather than by
reference. Anything frozen must be readable in full from the freeze document itself.

## References

- Issue #1305 — Recovery Package byte-oriented encoding (binding) + framing (this ADR)
- Issue #1193 — Airo Mind Phase 1 Vault
- `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md` §4
- `docs/superpowers/specs/2026-07-28-airo-mind-runtime-contracts.md` — C1, C3
- `docs/superpowers/specs/2026-07-27-airo-mind-runtime-design.md` §4.1, §4.2, §4.3
- `docs/superpowers/plans/2026-07-27-airo-mind-phase-1-vault.md` — Revision 7, benchmark budgets V1–V7

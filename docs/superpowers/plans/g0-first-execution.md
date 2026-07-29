# G0.7 / G0.8 — first-execution record

Status: **NOT YET EXECUTED.** No gate in this document has been run. Every
"Actual" below is deliberately empty; nothing here is a prediction rendered as
an observation.

Purpose: Revision 9A introduced four validation layers against an
implementation that Rust Architecture and Chief Security Officer had already
**rejected**. The gates are therefore expected to fail. Their first failure is
the evidence that they detect the defects they were designed to detect.

## Why the first output is preserved verbatim

A gate is only trustworthy if it was **not calibrated to the fixed state.**

After Revision 9B repairs the implementation, these gates will pass. At that
point the only thing distinguishing "the gate works and the code was fixed" from
"the gate was quietly adjusted until it agreed with the code" is a record of the
gate failing, in its original wording, against code independently verified to
violate it.

So: the first execution's output is pasted here unedited, including noise,
ordering, and any wording I would rather improve. **It is not replaced by a
cleaner rerun.** Later runs are appended, never substituted.

This is the same reasoning that made `git` history recording the BIP-39 wordlist
digest *before* the fixture was fetched a provenance-independent cross-check.

## 9A's scope is frozen

**Complete except for execution.** Until the 9A commit lands:

- no new assertions
- no new probes
- no new mutation tests
- no changes to the evidence format

The only permissible change is one required to make a gate *execute at all* —
a typo in a script surfaced by the first run. Anything else makes the validation
system a moving target, which is the defect 9A exists to remove, one level up.

A gate discovered to be *wrong* during the first run is a finding, recorded as
such, not silently corrected. The distinction: a script that cannot run is
broken; a script that runs and reports something I dislike is working.

## Completion criterion

Revision 9A is design work until the right-hand column is filled from observed
output.

| Component | Written | Executed |
|---|:-:|:-:|
| `G0.7` claim assertions | ✓ | |
| `G0.8` external-consumer probe | ✓ | |
| Mutation regressions (`mut_*` ×4) | ✓ | |
| Path-correct truncation test | ✓ | |

---

## `G0.7` — claim assertions

**Expected:** FAIL. Independently verified violations exist for `A01`
(`seed.rs:29` is `pub fn as_bytes(&self) -> &[u8; 64]`), `A02`
(`identity.rs:77` is `pub fn sign`), `A03` (`device.rs:45`), `A04` (no NFC
handling anywhere in the crate), `A05`–`A09`, `A10` (four surviving per-byte
`format!` sites), `A11` (`device.rs:80`), `A17` (`header_aad` omits `nonce`).

If `G0.7` reports **green**, the gate is broken and that is the finding.

### First execution

```
NOT YET RUN
```

### Subsequent executions

*(appended, never substituted)*

---

## `G0.8` — external-consumer probe

**Expected:** FAIL in both directions — `DENY` breaches and `ALLOW` gaps. The
two-directional design matters here: Revision 8 exposed the 64-byte master seed
(`DENY` breach) *and* made the device-trust journey uncallable (`ALLOW` gap) at
the same time.

### First execution

```
NOT YET RUN
```

---

## Mutation regressions

**Expected:** all four pass against the real crate, and each fails against the
mutant that removes its own control. The second half is the point; the first
half alone would be satisfied by tests that assert nothing.

| Test | Control it must be the sole detector of |
|---|---|
| `mut_each_frame_is_bound_to_the_header_aad` | header AAD on every frame |
| `mut_every_frame_uses_a_distinct_nonce` | frame-nonce index pinning |
| `mut_frame_index_must_equal_its_position` | position equality |
| `mut_swapping_frames_and_their_indices_still_fails` | nonce pinning under matched indices |

### First execution — real crate

```
NOT YET RUN
```

### First execution — per-mutant

```
NOT YET RUN
```

---

## Path-correct truncation test

**Expected:** fails when un-ignored. It asserts `PackageTruncated` on the
byte-stream path; measured behaviour is `SerializationFailed` at every cut
offset, indistinguishable from corruption. It stays `#[ignore]`d with `PERF-2`
as the reason until the authenticated frame count moves into the header.

### First execution

```
NOT YET RUN
```

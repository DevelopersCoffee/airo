# `G0.7` assertion-vs-invariant review

Date: 2026-07-30. Performed after the first execution (`66291ff7`) and before
Revision 9B.

**One question per assertion, and it is not "did the gate catch the defect?":**

> Does this assertion enforce the architectural **invariant**, or only the
> **finding** that motivated it?

Findings disappear once fixed; invariants persist. An assertion anchored only to
a finding loses its justification the moment the finding closes, and nobody can
then say what would have to change for it to be wrong.

`A04` failed this review before it ever executed, which is why the review exists
as a separate pass rather than a step inside the first run.

## Verdicts

`OK` — enforces an invariant, correctly located.
`WEAK` — enforces the right obligation at the wrong strength or place.
`FINDING-ONLY` — checks the finding, not the invariant. Must be repointed.

| Id | Invariant | Verdict | Note |
|---|---|---|---|
| `A01` | `C7` / `C5` — no key material leaves the crate | **WEAK** | Greps one exact signature in one file. A `fn seed_bytes()`, a `Deref<Target=[u8;64]>`, or an `as_ref` would all satisfy it. The invariant is *no route to seed bytes*; `G0.8`'s `DENY` probe expresses that and `A01` should be understood as its cheap precondition, not the check |
| `A02` | `C7` — signing is domain-tagged, never raw bytes | **WEAK** | Same shape. Also does not catch a `pub fn sign_raw`. `RA-17`'s real remedy is the `SigningPayload` newtype, which no grep expresses |
| `A03` | — | **FINDING-ONLY** | "`DeviceKey::sign` has zero callers" is a fact about Revision 8, not an invariant. Delete when the method goes; keeping it asserts that a legitimate future API must not exist |
| `A04` | `I6` — canonicalize exactly once, at the boundary | **FINDING-ONLY** | Ruled on before execution. Greps `aggregate.rs` for `is_control` where `I6` demands a type boundary; satisfying it would *violate* `I6` by canonicalizing twice. Repoint to `ContextId` existence + no `&str` identifier in the public API |
| `A05`–`A08` | `C7` / `I3` — AAD-covered fields are not externally mutable | **OK** | A `pub` field on a signature-covered struct is precisely the violation. Location is right |
| `A09` | `I3` — every AAD-bound field has a tamper test | **WEAK** | Asserts `with_*_tampered` *exists*, not that each covered field has one. Passed on first run while `A05`–`A08` failed, so it is currently green against fields that are still `pub` |
| `A10` | `I8` — cost is part of correctness | **OK** | Correctly located, and its own doc line is one of the hits, which is noise worth accepting: excluding comments would let a real site hide in a doc example |
| `A11` | `C7` — injective signing payloads | **WEAK** | Greps `len() as u32`. `as u16`, `as usize`, or a hand-rolled prefix all pass. The invariant is *every variable-length field in a signing payload is length-prefixed by the checked helper* |
| `A12` | `C7` — nonce uniqueness | **OK** | Any unchecked increment on the nonce path is the violation |
| `A13`–`A15` | `C7` — one RNG choke point | **OK** | The strongest assertions here. `RA-3` is the only finding of its class that genuinely stayed fixed, and this is why |
| `A16` | `C7` — one trust admission boundary (`SEC-15`) | **OK** | `verify_against` outside `admit_device` is the violation, wherever it appears |
| `A17` | `C7` — the header is authenticated in full | **WEAK** | Asserts one exact call. Would pass if `nonce` were folded into the AAD differently, and would fail if a future field were added and left uncovered. The invariant is *every header field appears in `header_aad`*, which wants a test, not a grep |
| `A18` | `C1` — the format round-trips the state it claims to carry | **WEAK** | Greps for a token. A round-trip property test is the real form: export a vault with `head_epoch > max(entry)`, restore, compare |
| `A19` | `I5` — suppressions do not outlive their reason | **OK** | Stale-suppression check, correctly scoped |
| `A20` | `C7` — key material is package-scoped | **WEAK** | Asserts the *absence of a specific spelling*. `SEC-37`'s point was that `pub(super)` in `vault::package` **means** `pub(in crate::vault)` — so the fix is `pub(in crate::vault::package)`, and this assertion would then pass while an equivalent `pub(crate)` elsewhere would not be caught |
| `A21` | `C7` — fail closed on caller-supplied data | **WEAK** | Greps one call site. Invariant is *every externally supplied ledger is validated before merge* |
| `A22` | `C7` | **OK** | Complements `A01` against the obvious workaround |

## Tally

| Verdict | Count |
|---|---|
| `OK` | 11 (`A05`–`A08`, `A10`, `A12`, `A13`–`A15`, `A16`, `A19`, `A22`) |
| `WEAK` | 8 (`A01`, `A02`, `A09`, `A11`, `A17`, `A18`, `A20`, `A21`) |
| `FINDING-ONLY` | 2 (`A03`, `A04`) |

**Half the assertions are weaker than the invariant they guard, and two do not
guard an invariant at all.** All 22 executed; 11 are architecturally sound.

## The pattern

Every `WEAK` verdict has the same cause: **a grep can express a forbidden
spelling, and most of these invariants are about a forbidden *shape*.**

- `A01`/`A02` want "no route to key material" — a reachability property, which
  `G0.8` expresses and `grep` cannot
- `A11`/`A17`/`A21` want "at every site the invariant covers" — universal
  quantification over sites, where a grep enumerates known ones
- `A18` wants a round-trip property
- `A20` wants a scope, and asserts a spelling

So the layering is now explicit and is the durable output of this review:

| Obligation shape | Right layer |
|---|---|
| a forbidden spelling exists nowhere | `G0.7` grep |
| an item is unreachable from outside | `G0.8` `DENY` probe |
| a journey is reachable from outside | `G0.8` `ALLOW` probe |
| a property holds over inputs | test, entering the user's door |
| a control matters | mutation regression |
| a shape is unrepresentable | **the type system** — `ContextId`, `SigningPayload` |

The last row is where four of these belong, and it is the strongest: an
assertion checks that a mistake was not made, a type makes the mistake
unrepresentable. `I6`'s own text says so — *"the type must distinguish them, or
the raw form must be unreachable past the boundary."*

## Consequences for Revision 9B

Not "strengthen every `WEAK` assertion". A grep is a cheap precondition and worth
keeping as one. The change is that **no `WEAK` assertion may be the only
enforcement of its invariant**:

1. `A03` — delete with the method it names.
2. `A04` — repoint to `ContextId`; add an assertion that no public identifier
   parameter is `&str`.
3. `A01`/`A02` — keep as preconditions; the enforcement is `G0.8`'s `DENY`
   probes, already present and already failing.
4. `A09` — restate per AAD-covered field, not existence.
5. `A11`/`A17`/`A21` — pair each with a test that quantifies over sites.
6. `A18` — replace with the `head_epoch` round-trip property test.
7. `A20` — assert the scope, `pub(in crate::vault::package)`, not the absence of
   `pub(super)`.
8. Add the fifth mutation regression for trailer AAD, still undetected at 89/89.

## Status columns

Executed and invariant-reviewed are independent. Both are now recorded, and
`executed` alone is never sufficient to call an assertion sound.

| Assertion | Executed | Invariant reviewed |
|---|:-:|:-:|
| `A05`–`A08`, `A10`, `A12`–`A16`, `A19`, `A22` | ✓ | ✓ |
| `A01`, `A02`, `A09`, `A11`, `A17`, `A18`, `A20`, `A21` | ✓ | ✗ WEAK |
| `A03`, `A04` | ✓ | ✗ FINDING-ONLY |

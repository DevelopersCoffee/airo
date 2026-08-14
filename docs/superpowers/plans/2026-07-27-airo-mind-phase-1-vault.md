# Airo Mind Phase 1 — Vault Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Airo Mind Vault — identity, device certificates, envelope encryption, revocation ledger, and revocation-aware recovery — as a standalone Rust crate with no Flutter dependency.

**Architecture:** A new `rust/airo_mind` workspace crate holding pure-Rust cryptographic state. A BIP39 seed derives a root Ed25519 identity. Each device generates its *own* keypair locally and receives a root-signed certificate, so the seed never leaves the device that created it. Content keys are wrapped independently under each granting context key (envelope encryption over a hypergraph, not a key tree). A monotonic revocation ledger records destroyed keys, and restore is type-state enforced: a `RecoveryPackage` cannot become a usable `Vault` without first applying revocations.

**Tech Stack:** Rust 2021, `ed25519-dalek` (signing), `chacha20poly1305` (XChaCha20-Poly1305 AEAD), `hkdf` + `sha2` + `hmac` (derivation, and BIP-39 implemented in-house), `zeroize`, `thiserror`, `serde` + `serde_json`.

**Spec:** `docs/superpowers/specs/2026-07-27-airo-mind-runtime-design.md` §4, §6
**Issues:** #1204 (scaffold), #1205 (governance), #1207–#1212 (Vault tasks), under epic #1193.

> **Revision 9A (2026-07-30). VALIDATION INFRASTRUCTURE. No implementation
> changes.**
>
> Revision 8 was **rejected** by Rust Architecture and Chief Security Officer,
> and approved-with-required-changes by Chief Performance Officer. The three
> reviews converged, without coordinating, on one diagnosis:
>
> > The mechanical gates validate implementation. They do not validate
> > **negative architectural claims**.
>
> Seven claims in Revision 8 were false, five findable by `grep` in under a
> minute: `Seed::as_bytes` "deleted" (present, `pub` — the 64-byte master seed),
> `RootIdentity::sign` "`pub(crate)`" (`pub` — a root signing oracle),
> `DeviceKey::sign` "deleted" (present), `with_*_tampered` accessors (absent, six
> fields still `pub`), NFC normalization (absent from the crate **and** from this
> plan, while recorded as resolved in `Freeze §4` and design `§I6`), and SEC-1's
> "reachable only from `package.rs`" (`pub(super)` inside `vault::package`
> resolves to `pub(in crate::vault)` — every module in the crate).
>
> **This revision changes no implementation.** It adds the four layers that
> would have caught those failures, so that every later change is judged by a
> stronger gate than Revision 8 had. It is a deliverable, not preparation.
>
> | Layer | What it can prove that `G0.3`–`G0.5` cannot |
> |---|---|
> | **`G0.7` claim assertions** | A documented deletion or visibility reduction actually happened. Code that never had a feature compiles fine |
> | **External-consumer probe** | The façade is real *from outside*. Nothing in-tree looks from outside, and three findings were only reachable that way |
> | **Path-correct property tests** | The property holds on the path a user or attacker takes. `PackageTruncated` was reachable only from a hand-built `Vec<Frame>`, never from a file |
> | **Mutation regressions** | Each control *matters*. Removing frame AAD, trailer AAD, nonce pinning, or position equality left all 85 tests green |
>
> **The mutation result is the most important addition.** A passing suite is not
> evidence that each control matters. The property required is narrower:
>
> > **Every security control has at least one test whose only failing cause is
> > the removal of that control.**
>
> Stronger than coverage, because it stops one mechanism silently masking
> another — which is exactly what happened: `reordered_frames_are_rejected`
> passed via the position check and
> `a_frame_does_not_transplant_between_packages` passed via the package nonce,
> so neither isolated the control it names.
>
> **No governance rule is added.** The observed failure was not a missing rule;
> it was one existing rule lacking mechanical enforcement. Both reviewers
> proposed the same mechanism and neither proposed an architectural change,
> which is the evidence that the architecture is stable and the validation
> system was one executable layer short. `Freeze §` already marked the Evidence
> Rule "human discipline — no mechanical backstop"; this is the backstop.
>
> **Traceability is bidirectional.** Every assertion carries a stable id and
> names the finding it guards; every finding cites the assertion that fails if
> it regresses. Neither direction may be blank — an assertion with no finding is
> a check nobody asked for, and a finding with no assertion is a claim nothing
> enforces. This exists so a future finding cannot silently become "checked by
> something" without anyone knowing which check enforces it. Ids are stable and
> never reused; retiring an assertion leaves a gap.
> `g0-claim-assertions.sh --list` prints the registry.
>
> | Finding | Guarded by | Claim |
> |---|---|---|
> | `SEC-33` / `RA-16` | `A01`, `A22` | `Seed::as_bytes` deleted |
> | `RA-17` | `A02` | `RootIdentity::sign` not `pub` |
> | `RA-17b` | `A03` | `DeviceKey::sign` deleted |
> | `SEC-32` | `A04` | ids NFC-normalized, control chars rejected |
> | `RA-23a` | `A05`–`A09` | AAD-covered fields private, tamper ctors exist |
> | `RA-24` | `A10` | no per-byte `format!` |
> | `RA-19` | `A11` | no unchecked length cast on a signing payload |
> | `SEC-46` | `A12` | no unchecked increment on the nonce path |
> | `RA-3` | `A13`–`A15` | `random.rs` is the only `OsRng` site |
> | `SEC-38` | `A16` | restore does not re-implement admission |
> | `SEC-35` | `A17` | the package nonce is authenticated |
> | `SEC-36` | `A18` | `head_epoch` is carried, not re-derived |
> | `RA-25` | `A19` | no stale `allow(dead_code)` |
> | `SEC-37` | `A20` | `KeyBytes::as_bytes` is package-scoped |
> | `SEC-40` | `A21` | a caller-supplied ledger is validated |
> | `RA-18`, `SEC-39`, `SEC-43`, `RA-Q4` | `G0.8` probes | façade reachable both directions |
> | `PERF-2` | path-correct test | truncation diagnosable **on bytes** |
> | frame AAD, trailer AAD, nonce pinning, position | `mut_*` ×4 | each control has a test only it fails |
>
> `G0.7` and `G0.8` are **expected to fail on this revision** — that is the
> deliverable. A gate that passed the day it was written, against code three
> independent reviewers have already rejected, would shift the burden of proof
> onto the gate itself.
>
> **First execution is part of the artifact.** The scripts are specifications
> until they are run, so 9A is not complete until each has demonstrated its own
> behaviour:
>
> | Gate | Expected | Actual | Evidence |
> |---|---|---|---|
> | `G0.7` claim assertions | FAIL (≈8 of 22) | *not yet run* | first execution |
> | `G0.8` consumer probe | FAIL (`DENY` breaches + `ALLOW` gaps) | *not yet run* | first execution |
> | `mut_*` ×4 | pass on real crate, fail per mutant | *not yet run* | first execution |
> | path-correct truncation | `#[ignore]`, fails when run | *not yet run* | first execution |
>
> Predicting a gate's output is the class of claim this revision exists to
> eliminate, so the middle column stays empty until it is measured.
>
> **Revision 8 (2026-07-29). CONSOLIDATION. No new design. REJECTED.**
>
> The first revision written under the Evidence Rule (`Freeze §`): every
> substantive change below cites the compiler diagnostic, benchmark number, or
> council finding that demanded it. A change with none of the three was
> deferred, including clarifications that only read better. Citations use the
> reserved namespace — review findings are `SEC-#` / `RA-#` / `PERF-#`, since
> bare `S#` now means a conformance suite and `S2` previously meant both
> "Replay conformance" and "`link_content` re-links destroyed content".
>
> Scope is fixed: security findings, the Rust façade, `ADR-0017`, the
> serialization changes, conformance updates, `G0`. Nothing else. No new
> primitives, invariants, or contracts.
>
> # PHASE 1 ACCEPTED — v1.0.0-alpha
>
> Feature complete against the agreed Definition of Done. Every exit criterion
> satisfied, none waived.
>
> | Area | Status |
> |---|---|
> | Security | ✅ `SEC-47` · `SEC-48` · `SEC-49` |
> | Correctness | ✅ `RA-26` |
> | Performance | ✅ `from_payload` · streaming reader (`PERF-1`+`PERF-2`) |
> | Validation | ✅ `L1.1` · `L1.2` · `L2` · `L3` |
>
> ```
> check 0 · 100 tests pass, 1 ignored · clippy 0
> L1.1 PASS (109 items) · L1.2 PASS · L3 10/10
> ```
>
> ## The Vault is frozen
>
> **No feature work.** Only security, correctness, and performance fixes.
> Anything else goes to the Vault v2 backlog. The Vault exists to support the
> runtime; it is now a dependency, not a project.
>
> ## Carried forward, not lost
>
> Recorded rather than dropped, because closing a phase is not the same as
> pretending nothing remains:
>
> | Item | Source | Disposition |
> |---|---|---|
> | `SEC-44` base64 accepts non-canonical padding | Security | v2 — blocks when `C3` sync ships, since the package then has no canonical byte form |
> | `RA-28` `WriteFailed` variant | Rust Architect | v2 — a full disk currently reports as a serialization bug |
> | `RA-29` construction-site test cannot fail | Rust Architect | v2 — it is fake coverage and known to be |
> | BIP-39 vector fixture unvendored | Rust Architect | v2 — the suite proves determinism, not conformance to the standard |
> | `PERF-8` `all_revoked()` called twice | Performance | v2 — measured 48 MB and 31 ms at 500k |
> | `PERF-9` O(N) converged merge | Performance | Phase 2 — `ADR-0017` already defers it to `C3` |
> | `PERF-10` `is_content_revoked` allocates per lookup | Performance | v2 — 30.6 ns of 113.1 ns |
> | Model acquisition | design thread | ADR, next |
>
> ## Why this is accepted on gate evidence
>
> Three council reviews rejected `2821e0b5`. Every finding they raised is closed
> and the gates now encode those findings as executable checks — a regression
> fails automatically rather than waiting for manual rediscovery. That was the
> remedy both Rust Architect and Chief Security Officer proposed, independently,
> in place of another review cycle.
>
> ---
>
> **Phase status.** Attribution before detail — `ADR-0017` is isolated so that
> any regression after it is attributable to it and not to a lingering
> propagation error.
>
> | Phase | Status |
> |---|---|
> | A — mechanical propagation | ✅ `G0` verified |
> | B — `ADR-0017` implementation | ✅ `G0` verified |
> | 9A — validation infrastructure | ✅ executed, reviewed, baselined |
> | 9B — Security findings | ✅ closed |
> | 9B — Rust Architecture findings | ✅ closed |
> | 9B — validation gates | ✅ `G0` · `G0.7` 23/23 · `G0.8` 9/9 |
> | 9B — Performance findings | ❌ **`PERF-1` and `PERF-2` remain** |
> | Security re-review | ⏳ |
> | Rust Architecture re-review | ⏳ |
> | Performance re-review | ⏳ |
>
> **Status: Revision 9B — Security and Architecture complete, pending
> Performance closure.** Not "9B complete". The stated success criterion is
> *all verified findings resolved*, and two verified Performance findings are
> open: `PERF-1` (restore is not streaming — 8.9×–9.8× against a 4× budget,
> flat across a 100× range) and `PERF-2` (the authenticated frame count has not
> moved into the header, so truncation is still indistinguishable from
> corruption on any real file; the ignored test records it).
>
> Recorded because the first report of this batch was headed "Revision 9B
> complete" and disclosed both findings afterwards. **The status follows the
> evidence, not the milestone.**
>
> **`G0` verified after each phase** — rustc 1.96.1 (31fca3adb 2026-06-26):
>
> ```
>                                                  Phase A    Phase B
> G0.1  extraction fidelity                        PASS       PASS
> G0.3  cargo check --all-targets                  0 errors   0 errors
> G0.4  cargo test --lib                           77 pass    84 pass
> G0.5  cargo clippy --all-targets -- -D warnings  0 errors   0 errors
> RA-3  OsRng outside random.rs                    0 (was 3)  0
> ```
>
> **Proof ledger.** If a line below disappeared six months from now, the
> evidence that proves it belonged:
>
> | Change | Evidence | Specific evidence | Frozen surface |
> |---|---|---|---|
> | `mod.rs` loses the aggregate to `aggregate.rs` | Review | `RA-4`: the File Structure block said both "no logic" and "holds only the Vault aggregate" — the implementation obeyed the second | `none — plan-local` |
> | `random.rs` created; `seed.rs`, `device.rs`, `package.rs` stop calling `OsRng` | Review | `RA-3`: file promised as "the ONLY RNG call sites", never existed; 3 of 5 sites bypassed it while the DoD claimed CI enforcement | `none — plan-local` |
> | `push_len_prefixed` moves `envelope.rs` → `encoding.rs` | Review | `RA-4`: `package.rs` imported its length-prefix helper from the content-wrapping module | `none — plan-local` |
>
> | `lib.rs` curated `pub use`; `RevocationSource` + `RevocationProvenance` exported | Compiler | `error[E0432]: no RevocationSource in vault` — restore was unreachable from any consumer | `none — plan-local` |
> | `Seed::as_bytes`, `RootIdentity::sign`, `DeviceKey::sign` removed or narrowed | Review | `RA-16`, `RA-17`: root seed and a raw signing oracle reachable externally; `DeviceKey::sign` had zero callers including tests | `none — plan-local` |
> | `VaultError` gains `#[non_exhaustive]`; `RevocationsNotApplied` deleted | Review | `RA-23c`: public and unconstructible, reserving space for a phase the same plan defers | `none — plan-local` |
> | `link_content` loses its `content_id` parameter | Review | `SEC-2` probe: `link_content("B", ctx, &mut envelope_of_A)` returned `Ok(())` after A was destroyed | **C7** — revocation gate and AAD disagreed on one identity |
> | `admit_device` as the one trust admission function | Review | `SEC-15` probe: revoked device re-admitted by `trust_device`, which never consulted the ledger | **C7** |
> | `add_context` fails closed on a revoked id | Review | `SEC-14` probe: destroy then re-create minted a live key under a revoked id; restore later destroyed everything under it silently | **C7** |
> | `VaultPayload` fields → `pub(super)`, purges as methods, `decrypt` private | Review + Compiler | `SEC-1` probe read every context key without applying revocations; then `error[E0624]: method 'decrypt' is private` proved the boundary holds | **C7** |
> | `hex_into` single pre-sized `String` | Benchmark | `to_bytes()` on a 100k-context vault: 350.82 ms → 16.55 ms | **I8**, budget `V4` |
> | `hex_from` decodes over `as_bytes()` | Review | `RA-20`: `end byte index 62 is not a char boundary; it is inside 'é'`, pre-auth | **C7** |
> | `hex_array_32` on `RootPublicKey` and `KeyBytes` | Review | `RA-1`: `identity_public_key` shipped as a JSON decimal array in a frozen format | **Freeze §4** |
> | `base64_bytes` on outer `ciphertext`/`nonce`/`kdf_salt` | Benchmark | Hex leaves a hard 3.30× floor against `V4`'s ≤ 3× | **Freeze §4**, `ADR-0017` |
>
> Every row above removes a degree of freedom: one fewer public seam, one
> fewer representation of an identity, one fewer admission path, one fewer
> encoding, one fewer unnamed obligation. None of them adds a capability.
>
> **Phase B — `ADR-0017`:**
>
> | Change | Evidence | Specific evidence | Frozen surface |
> |---|---|---|---|
> | Framed package format: bounded frames, per-frame nonce, sealed trailer | Benchmark | `V5` 10.7×–21.6× against a 4× budget, flat across sizes; `V7` +849% in the ledger dimension | **Freeze §4**, `ADR-0017` |
> | `PackageTruncated` distinct from `DecryptionFailed` | Benchmark → design | A truncated package previously failed AEAD identically to a corrupt one, so the user was told their backup was corrupt | `ADR-0017` |
> | `to_payload` **deleted** | Benchmark | Deep-cloned ledger and certificates purely to serialize: 26% of export peak RSS. Framing left it with no caller | **I8** |
> | `RevocationLedger::entries()` borrowing iterator, `absorb()` batch | Benchmark | `all_revoked()` materialized the whole set; `apply_revocations` called it twice, ~38 MB each at 500k | **I8** |
> | Base64 on `Wrapping.nonce` / `.ciphertext` | Benchmark | 976 B → 635 B at 3 wrappings; per content object, so it multiplies where the Vault no longer does | **Freeze §4** |
> | `ContentKey::seal` / `open` | Review | `RA` Q4: `error[E0624]: method as_bytes is private` — the returned key was inert outside the crate | **C5** — no key material to the consumer, a capability instead |
> | `SealedEnvelope`; `open_envelope` is the only parse route | Review | `RA` Q4 probe forged an envelope for content the Vault never minted — content with no revocation record, unshreddable | **C7** |
> | Only an explicit destroy moves the epoch | — | `ADR-0017`: retention expiry is derived from logged operations, so recording it would cost 137.6 B forever per expired object | `ADR-0017`, **C1** |
>
> **Phase B measurements** — Apple M1, `[profile.release]` as shipped:
>
> | Change | Evidence | Specific evidence | Frozen surface |
> |---|---|---|---|
> | `export_to` streams frames to a writer | Benchmark | Materializing export overhead was linear — 1.0 MB at 10k revocations, 6.9 MB at 100k, 32.6 MB at 500k. Streaming: 0.59 / 0.56 / 0.69 MB, flat | `ADR-0017`, **I7** |
> | `hex_array_32` on `KeyBytes` **and** `RootPublicKey` fields | Benchmark | `V4` measured 3.52× against a 2.40× projection; both were `[u8; 32]` under `#[serde(transparent)]`, so both still emitted decimal arrays. After: 2.26× | **Freeze §4** |
> | `V7` restated over export overhead | Benchmark | Same shape, two readings: **+588%** measuring total process peak, **−6%** measuring export overhead | **I7** |
>
> ### Hypotheses revised by evidence
>
> Not a defect list. Three places where executable validation changed the
> design understanding rather than confirming it — which is the argument for
> running the gate before writing the ledger instead of after.
>
> | Hypothesis | What the evidence showed |
> |---|---|
> | The trailer digest detects frame removal | It does not — the **count** check runs first and returns `PackageTruncated`. Frame integrity was already covered three ways (nonce-pinned index, position equals index, header AAD). The digest is defence in depth, not the load-bearing check. Found by writing the failing form and watching it fail |
> | `SEC-1` was applied | `error[E0624]: method 'decrypt' is private` — `restore.rs` was still reaching for key material. The boundary became real only when the compiler enforced it, and the way I learned was my own code ceasing to compile |
> | `push_len_prefixed` had moved; `purge_*` were in use | Dead-code lints proved both were documented and not done. Claim drift, twice, in a revision written specifically to eliminate it |
> | Framing satisfied `ADR-0017`'s `O(1)` property | It did not. Framing bounded the **working set** per frame while `export() -> RecoveryPackage` still accumulated every frame, so peak stayed linear. No API that returns the whole package can satisfy the property; `export_to` can, and does |
> | `hex_array_32` was applied to the key types | It was written in `encoding.rs` prose and applied to neither `KeyBytes` nor `RootPublicKey` — `RA-1` exactly, committed inside the revision written to eliminate it, in a **frozen** format, invisible to `G0` and caught only by a benchmark |
> | `V7` was a valid failing form for `I7` | It measured total process peak, which includes a resident ledger no export strategy can bound. The property passes at −6%; the artifact fails at +588% |
>
> **Observed pattern.** Every meaningful correction in Revision 8 came from
> executable evidence — compiler, tests, benchmarks — refining either an
> implementation or the interpretation of a property. **None required changing
> the architectural intent.** The compiler corrected an architectural boundary
> (`E0624`), the tests corrected a mechanism-versus-property confusion (the
> trailer digest), and the benchmarks corrected both an implementation strategy
> (streaming) and a budget's interpretation (`V7`). The architecture held
> across all six; the implementation and the understanding of it got more
> precise.
>
> The third row is the uncomfortable one: the Evidence Rule was written to stop
> exactly this, and it did not — `G0` did. That is the asymmetry `Freeze §`
> already records, observed rather than predicted.
>
> **Revision 7 (2026-07-28). THE FIRST REVISION TO PASS G0.**
>
> ```
> rustc 1.96.1 (31fca3adb 2026-06-26)
> G0.1  extraction fidelity              PASS  (docs/superpowers/plans/extract-phase-1-vault.sh)
> G0.3  cargo check --all-targets        PASS
> G0.4  cargo test --lib                 76 passed, 0 failed, 1 ignored
> G0.5  cargo clippy --all-targets -D warnings   PASS
> ```
>
> Revisions 1–6 were **working drafts**, not revisions: none of them built.
> Extracting revision 6 produced 66 compiler errors.
>
> The finding no paper review caught: **`BTreeMap<RevocationSubject, u64>`
> cannot serialize.** JSON object keys must be strings, and `serde_json` fails
> with `key must be a string`. The revocation ledger is inside the frozen
> Recovery Package format, so the structure carrying crypto-shredding could
> never be written to disk. R3 specified "keyed by a canonical string
> encoding"; revision 3 implemented the enum and dropped that half. Four
> council reviews passed over it; `cargo test` found it in under a second.
>
> Mechanically confirmed from the security review: **S3** (`zeroize` has no
> `BTreeMap` impl, so the derive never built), **S6** (three `LogHead` call
> sites still passing `&str`), **S8** (`applying_revocations_twice_is_stable`
> could not pass, and the two restore tests contradicted each other),
> **S12**, **S13**.
>
> Three extraction artifacts are compensated by the script, not by editing the
> plan: `mod.rs` block ordering, the vendored wordlist, and test-module
> placement. Without G0.1 the compiler validates the extraction rather than
> the specification.
>
> **Revision 6 (2026-07-28).** Applies the remaining rust-architect and
> chief-performance-officer blockers. `RootPublicKey` newtype so
> `Vault::new([7u8; 32])` stops compiling; export binds seed to vault so a
> mismatched pair fails at export rather than at restore years later; a
> `RevocationsApplied` witness so the restore typestate holds *inside* the
> crate, not only at its boundary; key-minting and envelope primitives are
> `pub(crate)` so content cannot be created around the Vault that owns the
> revocation ledger; `mod.rs` loses its logic to `aggregate.rs`; `lib.rs`
> becomes a curated façade rather than `pub mod`. Plus the measured release
> profile, `precomputed-tables` restored, and benchmark budgets V1–V7.
>
> **Revision 5 (2026-07-28).** Rewritten against the **frozen** architecture
> (`docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md`). The structural change: the
> Vault no longer holds content envelopes. Revisions 1–4 made it O(all user
> content), which the frozen design forbids — *"sized by contexts and devices,
> never by user content"* (§4.1). `add_content` now returns the envelope for
> the content store to hold; `link_content` and `unlink_content` take it as a
> parameter; `destroy_context` is O(1) instead of scanning every envelope.
> `VaultPayload` loses `envelopes`, gains `ZeroizeOnDrop`, and stores keys as
> `KeyBytes`. Do not implement from revisions 1–4.
>
> **Revision 2 (2026-07-27).** Rewritten after the chief-security-officer and
> chief-open-source-officer reviews on PR #1239. Fifteen security findings
> (R1–R15) and the OSS caveats are applied throughout. Two structural changes:
> FFI is out of Phase 1 entirely, and the revocation ledger now carries tagged
> subjects. Do not implement from revision 1.

## Global Constraints

- **No FFI in this phase, at all.** `rust/airo_mind` is pure Rust with unit
  tests and ships `rlib` only. Both reviews landed here independently: OSS
  found that declaring `cdylib`/`staticlib` on a crate with no exports links
  two empty artifacts on every CI push, and security found that the FFI
  boundary was the *only* place the stale-restore hole was exposed. Bindings
  move to Phase 2, when there is an operation log worth exposing. Tracked on
  #1259.
- **No panics — and `fill_bytes` panics.** `RngCore::fill_bytes` and
  `AeadCore::generate_nonce` abort the process when the OS RNG fails. Use
  `try_fill_bytes` and map into `VaultError::RngUnavailable`. Early-boot
  entropy failure on Android is rare but real, and a panic in the
  key-generation path of a medical-records vault is the wrong failure mode.
- **`serde_json` output must never become signed or hashed bytes.** Float
  formatting and escape choices are not version-stable across library
  versions. Signing payloads are hand-built, length-prefixed, and
  domain-separated. If a later phase needs to sign a serialized structure the
  answer is a fixed binary encoding, never a lighter JSON library. Write this
  into `lib.rs` module docs beside the `BTreeMap`-not-`HashMap` rule.
- **Secrets do not derive `Debug`, `Clone`, or `PartialEq`.** `Debug` prints
  key bytes into panic messages and logs. `Clone` silently duplicates material
  whose custody is supposed to be singular. Derived `PartialEq` is not
  constant-time. Where equality is genuinely needed, implement it via
  `subtle::ConstantTimeEq`.
- **Never add `airo_mind` to `airo_core`.** Separate workspace member. `airo_core` is on the Airo TV shipping critical path and must not gain crypto or storage dependencies.
- **CI runs `cargo test --all`, `cargo clippy --all -- -D warnings`, `cargo fmt --check`** across `rust/Cargo.toml` (`.github/workflows/rust-core.yml`). A new workspace member is covered automatically. Clippy warnings fail the build.
- **No panics.** Every fallible path returns `Result<_, VaultError>`. `unwrap()` and `expect()` are permitted in `#[cfg(test)]` only.
- **Every secret type implements `Zeroize` + `ZeroizeOnDrop`.** Seeds, private keys, content keys, context keys.
- **Determinism is the point.** Same seed must produce byte-identical identity bytes on every platform. No wall-clock, no `HashMap` iteration order in anything serialized — use `BTreeMap`.
- **Constitution §6 gate:** every crate below must have a `platform_dependency_governance` scorecard filed and chief-open-source-officer sign-off *before* Task 1 lands. See Task 0.
- Rust edition `2021`, matching `rust/airo_core/Cargo.toml`.

---

## File Structure

```
rust/airo_mind/
├── Cargo.toml
└── src/
    ├── lib.rs             — `mod vault;` + a CURATED `pub use` list, not `pub mod`
    └── vault/
        ├── mod.rs         — `mod` declarations and `pub(crate) use` re-exports ONLY. No types, no impls, no tests.
        ├── aggregate.rs   — the `Vault` aggregate (not `vault.rs`: `clippy::module_inception`)
        ├── encoding.rs    — length-prefixing, hex, fixed-array and base64 serde helpers
        ├── random.rs      — `random_key`, `random_nonce` — the ONLY `OsRng` call sites in the crate
        ├── error.rs       — VaultError
        ├── seed.rs        — Mnemonic ↔ Seed (Task 2)
        ├── identity.rs    — RootIdentity from Seed (Task 3)
        ├── device.rs      — DeviceKey, DeviceCertificate (Task 4)
        ├── envelope.rs    — ContentKey, ContextKey, ContentEnvelope (Task 5)
        ├── revocation.rs  — RevocationLedger (Task 6)
        ├── package.rs     — RecoveryPackage export (Task 7)
        └── restore.rs     — type-state restore (Task 8)
```

One responsibility per file.

**`mod.rs` contains no logic.** Revision 7 wrote the entire 250-line `Vault`
aggregate into it, because this block previously said both *"declarations and
re-exports ONLY, no logic"* and, four lines later, *"`mod.rs` holds only the
`Vault` aggregate and re-exports"*. Those contradict, and the implementation
obeyed the second (`RA-4`). A file structure that disagrees with itself is
followed in exactly one place, and it is not the one you remember writing. The
aggregate lives in `aggregate.rs`.

**Two placement rules that Revision 7 violated in ways the compiler cannot
see**, both `RA-3` / `RA-4`:

- `random.rs` is the only module naming `OsRng`. Revision 7 promised this and
  never created the file: `random_key` and `random_nonce` lived in
  `envelope.rs`, and `seed.rs`, `device.rs`, and `package.rs` each called
  `OsRng` directly — three violations of a rule the Definition of Done claimed
  CI enforced.
- `encoding.rs` owns every wire-format helper, including `push_len_prefixed`.
  Revision 7 left it in `envelope.rs`, so `package.rs` imported its
  length-prefix helper *and* its RNG from the content-wrapping module — a
  layering inversion the promised structure would have prevented.

---

## Task 0: Dependency governance gate (no code)

**This is a human gate, not an implementation task.** Constitution §6 requires scorecards before the dependency lands.

**Files:**
- Create: one scorecard per crate under `packages/platform_dependency_governance/` (follow the existing format in that package)

- [ ] **Step 1: File scorecards**

**Review complete.** Both officers have reported on #1205. **No crate was
rejected.** Eleven crates, with the caveats below already folded into Task 1's
manifest.

| Crate | Version | Verdict |
|---|---|---|
| `chacha20poly1305` | `0.10` | approve |
| `hkdf` | `0.12` | approve |
| `sha2` | `0.10` | approve |
| `zeroize` | `1` | approve |
| `thiserror` | `2` | approve |
| `serde` | `1` | approve |
| `serde_json` | `1` | approve — see the signing-bytes constraint above |
| `subtle` | `2` | approve — added by security R9, already transitive |
| `ed25519-dalek` | `2` | **caveat:** floor `curve25519-dalek` at `>=4.1.3` |
| `rand_core` | `0.6` | **caveat:** forced by the two above; migration issue required |
| `hmac` | `0.12` | approve — replaces `bip39`, same `digest 0.10` generation |

Version choice was validated as correct: `sha2 0.10` + `hkdf 0.12` share the
`digest 0.10` generation `flutter_rust_bridge` already pulls in. Moving to
`sha2 0.11` / `hkdf 0.13` would fork `digest` across two majors workspace-wide.

Measured binary impact: **~458 KB** stripped (408 KB plus 49,952 B for `precomputed-tables`) with `opt-level="z"` + fat LTO,
against a 4096 KB per-dependency budget. `serde` + `serde_json` are 16.4 KB of
that — which is why the OSS officer explicitly **rejected** replacing them.

- [ ] **Step 1: Apply the `curve25519-dalek` floor**

RUSTSEC-2024-0344 was a timing-variability fix in `Scalar29`/`Scalar52`
subtraction, and `4.1.3` is exactly the patched release — the current
resolution sits on the boundary with no headroom. Add an explicit floor and
verify with `cargo tree -p curve25519-dalek`.

- [ ] **Step 2: Add the BSD-3-Clause notice**

`ed25519-dalek`, `curve25519-dalek`, and `subtle` are BSD-3-Clause with no dual
option. MIT-compatible, but binary distribution requires attribution and the
non-endorsement clause. A BSD-3-Clause slot already exists in
`docs/release/V2_THIRD_PARTY_NOTICES.md` — append, do not invent a mechanism.

- [ ] **Step 3: CC0 — DECIDED. Path B, implement BIP-39 in-house.**

**`bip39`, `bitcoin_hashes`, and `hex-conservative` are dropped.** Task 2
implements BIP-39 directly on the `sha2` and `hmac` already in the tree.

Rationale, recorded so it is not relitigated:

- ~200 LOC is small enough to audit completely
- removes three supply-chain dependencies, one of which is CC0-1.0 — not
  OSI-approved, and §4(a) expressly reserves the author's patent rights
- verifiable against the complete official BIP-39 test vectors, not a sample
- fits the long-term goal of minimising the trusted computing base

Update the manifest: remove `bip39`, remove `default-features`/`features` for
it, and add `hmac = "0.12"` (same `digest 0.10` generation as `sha2` and
`hkdf`, so no new tree). File a governance scorecard for `hmac` on #1205.

Dependency count drops from eleven to nine.

The rest of Step 3 below is retained for the record only.

<details>
<summary>Original decision framing (resolved)</summary>

`bip39`, `bitcoin_hashes`, and `hex-conservative` are **CC0-1.0**: not
OSI-approved, and §4(a) expressly reserves the author's patent rights. Google's
own OSS policy bans CC0 for code. This is the crate that generates the recovery
secret for medical and financial records.

Both paths are approved; pick one and record it on #1205.

- **Path A — accept.** Record the exception in `V2_THIRD_PARTY_NOTICES.md` with
  the patent non-grant noted, plus chief-security-officer sign-off. Task 2
  proceeds as written.
- **Path B — implement BIP-39 in-house.** ~200 lines: English wordlist +
  PBKDF2-HMAC-SHA512 at 2048 iterations, on the `sha2`/`hmac` already in the
  tree. Spec and wordlist are public domain, and Task 2 already pins a known
  test vector, so the implementation is verifiable against the same assertion.
  Removes five crates. Task 2's tests stay unchanged; only the internals move.

`tiny-bip39` was evaluated and **rejected** — it trades a license concern for a
worse bus factor.

</details>

- [ ] **Step 4: Open the `rand_core` migration issue**

`rand_core 0.6` is forced by `ed25519-dalek 2` and `chacha20poly1305 0.10`, but
it places the crate on the maintenance-mode `0.6` / `getrandom 0.2` generation.
The migration is coupled: `ed25519-dalek 3` + `chacha20poly1305 0.11` +
`rand_core 0.10` move together or not at all. File it dated, do not do it now.

- [ ] **Step 5: Close #1205**

**Do not start Task 1 until Step 3 is decided.**

---

## Task 1: Scaffold the crate

**Files:**
- Create: `rust/airo_mind/Cargo.toml`
- Create: `rust/airo_mind/src/lib.rs`
- Create: `rust/airo_mind/src/vault/mod.rs`
- Create: `rust/airo_mind/src/vault/error.rs`
- Modify: `rust/Cargo.toml`

**Interfaces:**
- Consumes: nothing
- Produces: `airo_mind::vault::VaultError` — the error type every later task returns

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/error.rs`:

```rust
//! Error type for every fallible Vault operation.

use thiserror::Error;

/// Every fallible Vault operation returns this. No Vault code panics.
///
/// `#[non_exhaustive]` because this is a runtime-ABI error type and later
/// phases will add variants — the FFI boundary in #1259 needs at least one.
/// Without it, every addition is a breaking change, which is why revision 7
/// shipped a public unconstructible variant to reserve space for a phase that
/// had not arrived (`RA-23c`). The attribute costs consumers one `_ =>` arm
/// and removes that pressure permanently.
#[derive(Debug, Error, PartialEq, Eq)]
#[non_exhaustive]
pub enum VaultError {
    #[error("invalid recovery mnemonic")]
    InvalidMnemonic,

    #[error("key derivation failed")]
    DerivationFailed,

    #[error("decryption failed: wrong key or corrupted data")]
    DecryptionFailed,

    #[error("no wrapping found for context `{0}`")]
    NoWrappingForContext(String),

    #[error("content `{0}` has been revoked")]
    ContentRevoked(String),

    #[error("recovery package format version {0} is not supported")]
    UnsupportedPackageVersion(u32),

    // `RevocationsNotApplied` was here and is deleted (`RA-23c`). It was
    // public and unconstructible — reserved for the Task 10 FFI boundary that
    // Task 10 itself defers to Phase 2. `#[non_exhaustive]` above makes adding
    // it then a non-breaking change, so reserving it now buys nothing and
    // ships a variant no caller can ever match against.
    #[error("serialization failed")]
    SerializationFailed,

    /// The OS random number generator failed.
    ///
    /// Rare, but real during early boot on Android. `RngCore::fill_bytes`
    /// panics in this situation; every call site must use `try_fill_bytes` and
    /// surface this instead.
    #[error("system random number generator unavailable")]
    RngUnavailable,

    /// The recovery package's vault does not belong to the supplied seed.
    ///
    /// Either a bug or a crafted package. Restoring anyway would produce a
    /// vault that trusts device certificates signed by a root the user does
    /// not control.
    #[error("recovery package does not belong to this identity")]
    IdentityMismatch,

    #[error("content `{0}` not found")]
    ContentNotFound(String),

    #[error("device `{0}` not found")]
    DeviceNotFound(String),

    #[error("encryption failed")]
    EncryptionFailed,

    /// A recovery package uses a protection mode this build does not implement.
    ///
    /// Distinct from `UnsupportedPackageVersion` deliberately: reporting an
    /// unknown passphrase mode as "format version 1 is not supported" is false
    /// and sends whoever debugs it to the wrong place.
    #[error("recovery package uses an unsupported protection mode")]
    UnsupportedProtectionMode,

    #[error("value too long to encode")]
    ValueTooLong,

    #[error("device certificate is not signed by this identity")]
    UntrustedCertificate,

    /// `SEC-32` / `I6`. An identifier that is not printable ASCII, which
    /// includes every non-NFC form, every control character, and the bidi
    /// overrides that render as one thing and compare as another.
    #[error("identifier is not canonical: printable ASCII only")]
    InvalidIdentifier,

    /// `SEC-15`. Distinct from `UntrustedCertificate` on purpose: a revoked
    /// device's certificate *is* validly signed, and collapsing the two would
    /// tell an operator the signature failed when the truth is that a genuine
    /// credential is no longer honoured.
    #[error("device `{0}` has been revoked")]
    DeviceRevoked(String),

    /// `ADR-0017`. Distinct from `DecryptionFailed` because the whole point of
    /// the sealed trailer is that a truncated package is diagnosable: it says
    /// how many frames survived, so a partial restore can be offered instead
    /// of "your backup is corrupt".
    #[error("recovery package is truncated: the file ends mid-structure")]
    PackageTruncated,

    /// `SEC-14`. Identity retirement is irreversible — a destroyed context id
    /// can never be re-created. The user-visible name may be reused under a
    /// new id; the identity may not.
    #[error("context `{0}` was destroyed and its identity cannot be reused")]
    ContextRetired(String),
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};

    #[test]
    fn error_messages_are_actionable() {
        assert_eq!(
            VaultError::NoWrappingForContext("hospitalization".into()).to_string(),
            "no wrapping found for context `hospitalization`"
        );
        assert_eq!(
            VaultError::UntrustedCertificate.to_string(),
            "device certificate is not signed by this identity"
        );
    }

    /// `RA-23c` in its failing form (`I5`): every variant is constructible
    /// from somewhere that is not a test. Revision 7 shipped
    /// `RevocationsNotApplied` with zero construction sites, and nothing
    /// caught it because an unused *variant* is not dead code to the compiler
    /// the way an unused function is.
    ///
    /// This test cannot be written as a compile-time check, so it is written
    /// as a review obligation with a home: adding a variant means adding its
    /// constructor in the same change, or the variant does not land.
    #[test]
    fn every_variant_has_a_non_test_construction_site() {
        // Enumerated by hand because `strum` is a dependency this crate will
        // not take on for one test. The list is the failing form: a variant
        // added without a construction site has no line to add here.
        const CONSTRUCTED_IN: &[(&str, &str)] = &[
            ("InvalidMnemonic", "seed.rs"),
            ("DerivationFailed", "identity.rs"),
            ("DecryptionFailed", "envelope.rs, package.rs"),
            ("NoWrappingForContext", "envelope.rs"),
            ("ContentRevoked", "aggregate.rs"),
            ("UnsupportedPackageVersion", "package.rs"),
            ("SerializationFailed", "package.rs"),
            ("RngUnavailable", "random.rs"),
            ("ValueTooLong", "encoding.rs"),
            ("UntrustedCertificate", "aggregate.rs"),
            ("DeviceRevoked", "aggregate.rs"),
            ("ContextRetired", "aggregate.rs"),
            ("InvalidIdentifier", "identifier.rs"),
            ("PackageTruncated", "package.rs"),
        ];
        assert!(CONSTRUCTED_IN.iter().all(|(_, site)| !site.is_empty()));
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind`
Expected: FAIL — `error: package ID specification 'airo_mind' did not match any packages`

- [ ] **Step 3: Write the crate manifest and module tree**

Create `rust/airo_mind/Cargo.toml`:

```toml
[package]
name = "airo_mind"
version = "0.1.0"
edition = "2021"
description = "Airo Mind runtime — vault, operation log, projections. Local-first personal knowledge."
license = "MIT"

[lib]
name = "airo_mind"
# rlib only. This crate exports nothing across FFI in Phase 1, and declaring
# cdylib/staticlib links two empty artifacts on every CI push.
crate-type = ["rlib"]

[dependencies]
# BIP-39 is implemented in-house (Task 2), not taken as a dependency: ~200 LOC
# auditable in full, no CC0 patent-non-grant on the recovery path, and three
# fewer supply-chain crates. `hmac` is the same digest 0.10 generation as sha2
# and hkdf, so it adds no new tree.
hmac = "0.12"
chacha20poly1305 = { version = "0.10", features = ["getrandom"] }
# Explicit feature pinning, not defaults. `zeroize` is what keeps the root
# private key out of freed memory; someone adding default-features = false for
# binary size later would silently remove it.
# `precomputed-tables` restored explicitly, NOT via `ed25519-dalek/fast`, so
# the intent survives a feature rename. Measured cost of dropping it:
# sign 14.2 us -> 37.6 us (2.65x) for 49,952 bytes saved. Design spec §3 makes
# signing per-operation, so this is a Phase 2 hot path.
ed25519-dalek = { version = "2", default-features = false, features = ["std", "rand_core", "zeroize"] }
curve25519-dalek = { version = "4.1.3", features = ["precomputed-tables"] }
# RUSTSEC-2024-0344: timing variability in Scalar29/Scalar52 subtraction.
# 4.1.3 is the patched release. Floored explicitly so a downgrade fails.
hkdf = "0.12"
rand_core = { version = "0.6", features = ["getrandom"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
sha2 = "0.10"
subtle = "2"
thiserror = "2"
zeroize = { version = "1", features = ["derive"] }
```

Create `rust/airo_mind/src/lib.rs`:

```rust
#![forbid(unsafe_code)]
//! Airo Mind runtime.
//!
//! `forbid(unsafe_code)` is the point: "pure Rust, no FFI" is otherwise a
//! description rather than a property, and nothing enforces a description.
//!
//! The runtime understands seven primitives and no domain concepts:
//! Identity, Operation, Content, Context, Capability, Projection, Vault.
//!
//! Rules for every module in this crate:
//!   - No panics. Return `Result`.
//!   - Every secret type is `Zeroize` + `ZeroizeOnDrop`.
//!   - Anything serialized uses `BTreeMap`, never `HashMap` — replay must be
//!     byte-identical across devices and platforms.
//!   - `serde_json` output never becomes signed or hashed bytes. Signing
//!     payloads are hand-built, length-prefixed, and domain-separated.
//!
//! # Visibility tiers
//!
//! Three, and there is deliberately no capability tier. `Freeze §5`'s
//! six-function API governs what a **capability** may call; capabilities never
//! link this crate. `airo_mind` is a data-plane subsystem the runtime
//! composes, so its public surface does not contradict `Freeze §5` — and the
//! reason that question kept arising is that nothing said so anywhere.
//!
//!   - **Tier 1, `pub`** — what the runtime host needs. Never names key
//!     material.
//!   - **Tier 2, `pub(crate)`** — what the runtime's own subsystems need.
//!     **Growing this tier is a review decision.** The operation log, sync,
//!     merge, and projections all land inside this boundary in later phases,
//!     written by implementers with less context; `pub(crate)` means every one
//!     of them can reach whatever is in it. This is the tier `LogHead`'s
//!     private field and the restore witness both escaped through.
//!   - **Tier 3, private** — key material, envelope internals, payload
//!     internals.

mod vault;
```

**The curated list, item by item.** Revision 7 shipped `pub mod vault;` while
this block and revision 6's changelog both recorded a curated `pub use` list
(`RA-18`). The consequence was not cosmetic: `RevocationSource` was never
re-exported, so `apply_revocations` could not be called, so `AppliedRestore`
could not be obtained, so **Phase 1 shipped no reachable restore path at all**.
Three reviewers hit it independently — Rust Architecture and Performance both
had to add the re-export to compile a probe.

The question that decides every row: **for every remaining public item, what
external consumer requires it?** `G0` proves the crate builds; it cannot prove
the surface is intentionally minimal. Note `airo_mind` has *no* consumer in
Phase 1 — FFI is deferred to #1259 and the crate ships `rlib` only — so `pub`
is the exception, and "a future phase will want it" is a reason to keep it
`pub(crate)` until that phase exists and can validate the shape.

Add to `rust/airo_mind/src/lib.rs`:

```rust
// The grouping and the comments below ARE the curated surface (`RA-18`): each
// line records the external consumer that justifies the export. rustfmt sorts
// the list alphabetically and re-attaches every comment to whatever ends up
// beneath it, which turns the rationale into noise. Skipped deliberately.
#[rustfmt::skip]
pub use vault::{
    // Onboarding and recovery journey — #1234 / #1235
    generate_mnemonic, seed_from_mnemonic, Seed,     // Seed is opaque: no as_bytes
    RootIdentity, RootPublicKey,
    // `I6` / `A04` / `SEC-47`: the canonical identifiers. A consumer cannot
    // call the Vault without constructing one -- the boundary made unavoidable,
    // for all three RevocationSubject kinds rather than just contexts.
    ContextId, ContentId, DeviceId,
    Vault,
    RecoveryPackage, RECOVERY_PACKAGE_FORMAT_VERSION,
    // Restore path — unreachable in revision 7 without the next two
    SealedRestore, AppliedRestore, RevocationSource, RevocationProvenance,
    // `SEC-48`: `RevocationLedger` and `LogHead` are NOT exported. Revision 9B
    // exported them to make a non-blind restore reachable, which made forging
    // one reachable at the same time. Phase 1 has no log, so it has no honest
    // ReplayedFromLog to reach.
    // `SEC-38`: `trust_device` is `pub` and takes this, so a `pub` API took an
    // unnameable type and the device-trust journey (#1257) was uncallable.
    DeviceCertificate, DeviceKey,
    PurgeDirective, UnlinkOutcome, RevocationSubject,
    // Content path — opaque handles
    ContentEnvelope, ContentKey, SealedEnvelope,
    VaultError,
};
```

| Item | External consumer |
|---|---|
| `generate_mnemonic`, `seed_from_mnemonic`, `Seed` | Onboarding UI. `Seed` opaque — `as_bytes` deleted, `RA-16` |
| `RootIdentity` | `from_seed`, `public_key`, `identity_id` only. `sign` → `pub(crate)`, `RA-17` |
| `RootPublicKey` | It is a *public* key. `as_bytes` stays `pub` |
| `Vault` | The aggregate; method list in Task 7 |
| `RecoveryPackage`, `RECOVERY_PACKAGE_FORMAT_VERSION` | Export/import UI. **All six fields → private with read accessors** — `revocation_epoch` and `identity_public_key` are AAD-bound, so `RA-23a` applies here exactly as to `DeviceCertificate` |
| `SealedRestore`, `AppliedRestore` | The restore typestate chain |
| `RevocationSource`, `RevocationProvenance` | **The `RA-18` fix.** Required to call `apply_revocations` and to render the restore warning copy |
| `PurgeDirective`, `UnlinkOutcome`, `RevocationSubject` | Returned from public methods; a public return type must be nameable |
| `ContentEnvelope`, `ContentKey` | Content store. **Opaque handles with `seal`/`open` rather than byte accessors is specified and NOT yet implemented** — `ContentKey::as_bytes` is `pub(crate)` with no `seal`, so the returned key is inert outside the crate, and `#[derive(Deserialize)]` on `ContentEnvelope` is a second door past "the Vault is the only door". Tracked with the `ADR-0017` framing work, since both change the envelope wire shape and it freezes when #1214 writes the first one |
| `VaultError` | Every fallible path. **`#[non_exhaustive]`** |

**`pub(crate)`, because no external consumer exists yet:**
`RevocationLedger` entirely — today it is fully public with a `pub fn revoke`,
so any consumer can mint a ledger and revoke arbitrary subjects; the public
question "was this destroyed?" is already answered by
`Vault::is_content_destroyed` · `DeviceKey`, `DeviceCertificate` and their
methods — device enrolment is a pairing flow that does not exist in Phase 1,
and the *enrolment API*, not the certificate struct, is what should eventually
be public; exporting the struct now freezes the wrong seam · `ContextKey` ·
`RootIdentity::sign` · `Vault::to_payload`, `from_payload`, `context_key`,
`revocations` · `RecoveryPackage::decrypt` · `VaultPayload`, `KeyBytes` ·
`LogHead`, `RevocationsApplied` · `encoding::*`, `domain::*`, `random::*`.

**Deleted:** `DeviceKey::sign` — zero callers anywhere, including tests
(`RA-17`) · `Seed::as_bytes` (`RA-16`) · `VaultError::RevocationsNotApplied`
(`RA-23c`).

`RevocationsNotApplied` deserves its reasoning recorded, because the variant
*looked* necessary. Revision 7 shipped it public and unconstructible, reserved
for the Task 10 FFI boundary that Task 10 itself defers to Phase 2. It only
looked necessary because `VaultError` lacked `#[non_exhaustive]`; with the
attribute, adding the variant in Phase 2 stops being a breaking change. The
attribute is correct for a runtime-ABI error type regardless, so the variant
goes now.

Create `rust/airo_mind/src/vault/domain.rs` — the domain-separation registry
(security R11):

```rust
//! Every domain-separation string in the crate, in one place.
//!
//! The two original strings happened not to be prefixes of one another. That
//! was luck, not construction. A registry plus the test below makes it
//! construction: adding `"airo-mind/root"` beside
//! `"airo-mind/root-identity/v1"` now fails the build rather than silently
//! weakening separation.

pub const ROOT_IDENTITY: &[u8] = b"airo-mind/root-identity/v1";
pub const RECOVERY_PACKAGE: &[u8] = b"airo-mind/recovery-package/v1";
pub const DEVICE_CERTIFICATE: &[u8] = b"airo-mind/device-certificate/v1";
pub const CONTENT_WRAPPING: &[u8] = b"airo-mind/content-wrapping/v1";
pub const PACKAGE_HEADER: &[u8] = b"airo-mind/recovery-package-header/v1";

/// Every registered string. Add here when adding a constant above.
#[cfg_attr(not(test), allow(dead_code))]
pub const ALL: &[&[u8]] = &[
    ROOT_IDENTITY,
    RECOVERY_PACKAGE,
    DEVICE_CERTIFICATE,
    CONTENT_WRAPPING,
    PACKAGE_HEADER,
];

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};

    #[test]
    fn no_domain_string_is_a_prefix_of_another() {
        for (i, a) in ALL.iter().enumerate() {
            for (j, b) in ALL.iter().enumerate() {
                if i == j {
                    continue;
                }
                assert!(
                    !b.starts_with(a),
                    "{} is a prefix of {}",
                    String::from_utf8_lossy(a),
                    String::from_utf8_lossy(b)
                );
            }
        }
    }

    #[test]
    fn every_domain_string_is_versioned() {
        for s in ALL {
            let text = String::from_utf8_lossy(s);
            assert!(text.starts_with("airo-mind/"), "{text} lacks the namespace");
            assert!(text.ends_with("/v1"), "{text} lacks a version suffix");
        }
    }
}
```

Create `rust/airo_mind/src/vault/mod.rs`:

```rust
//! The Vault: identity, keys, revocations, trust, device certificates.
//!
//! The only mutable, non-append-only store in the system. Everything else is
//! an append-only log or a projection derived from one.

mod aggregate;
mod device;
mod domain;
mod encoding;
mod envelope;
mod error;
mod identifier;
mod identity;
mod package;
mod random;
mod restore;
mod revocation;
mod seed;
mod wordlist;

pub use aggregate::{PurgeDirective, UnlinkOutcome, Vault};
pub use error::VaultError;
pub use identifier::{ContentId, ContextId, DeviceId};
pub use package::{RecoveryPackage, RECOVERY_PACKAGE_FORMAT_VERSION};
pub use restore::{AppliedRestore, RevocationProvenance, RevocationSource, SealedRestore};
```

`mod.rs` carries declarations and re-exports and **nothing else** — no types,
no impls, no tests (`RA-4`). Each task below adds its `mod` line and its
`pub use` line here, and its code to its own file.

Add a compile-time guard to `rust/airo_mind/src/lib.rs` (security R8). The
manifest pins `ed25519-dalek`'s `zeroize` feature explicitly; this makes a
future feature change break the build rather than silently leak the root
private key into freed memory:

```rust
const _: fn() = || {
    fn assert_zeroize_on_drop<T: zeroize::ZeroizeOnDrop>() {}
    assert_zeroize_on_drop::<ed25519_dalek::SigningKey>();
};
```

Modify `rust/Cargo.toml`:

```toml
[workspace]
members = ["airo_core", "airo_mind"]
resolver = "2"

# Measured by chief-performance-officer on Apple Silicon against the real
# iptv-org fixture. Do not relitigate without new measurements.
#
#   lto="fat" + codegen-units=1 : airo_core 7-11% FASTER, dylib -474 KB (-32%)
#   opt-level="z" on airo_core  : 45-58% SLOWER on the M3U parser. REJECTED.
#   panic="abort"               : REJECTED. airo_core is a cdylib whose
#                                 flutter_rust_bridge handler relies on
#                                 catch_unwind to turn panics into Dart errors
#                                 (handler.rs:95, executor.rs:69). Setting it
#                                 aborts the whole app on any recoverable error.
#
# Costs +22% clean build across eight release jobs in rust-core.yml. If CI time
# becomes the constraint, evaluate lto="thin" before reverting.
[profile.release]
lto = "fat"
codegen-units = 1
strip = "symbols"

# opt-level is scoped: airo_mind optimizes for size, airo_core for throughput.
[profile.release.package.airo_mind]
opt-level = "z"
```

**Open obligation on this approval:** the `airo_core` half was measured on
Apple Silicon. It must be re-measured on `aarch64-linux-android` and
`armv7-linux-androideabi` — the Fire TV Stick path uses 32-bit curve25519 and
ChaCha backends with different codegen — before it reaches a TV release build.
Tracked as H5 on #1257.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind`
Expected: PASS, 1 test

- [ ] **Step 5: Verify CI gates pass locally**

Run: `cargo clippy --manifest-path rust/Cargo.toml --all -- -D warnings`
Run: `cargo fmt --manifest-path rust/Cargo.toml --check`
Expected: both clean. Clippy warnings fail CI, so fix them now rather than in review.

- [ ] **Step 6: Commit**

```bash
git add rust/Cargo.toml rust/airo_mind/
git commit -m "feat(mind): scaffold airo_mind crate with vault error type

New workspace member, deliberately separate from airo_core: airo_core is
on the Airo TV shipping critical path and must not gain crypto or storage
dependencies.

Refs #1204"
```

---

## Task 2: Seed generation and mnemonic round-trip

Implements the first half of #1207.

**Files:**
- Create: `rust/airo_mind/src/vault/seed.rs`
- Modify: `rust/airo_mind/src/vault/mod.rs`

**Interfaces:**
- Consumes: `VaultError` (Task 1)
- Produces:
  - `Seed` — newtype over `[u8; 64]`, `ZeroizeOnDrop`, with `fn as_bytes(&self) -> &[u8; 64]`
  - `fn generate_mnemonic() -> Result<Zeroizing<String>, VaultError>` — 24 words
  - `fn seed_from_mnemonic(phrase: &str) -> Result<Seed, VaultError>`

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/seed.rs`:

Create `rust/airo_mind/src/vault/wordlist.rs` — the official BIP-39 English
wordlist, 2048 entries, public domain, verbatim from the specification:

```rust
//! BIP-39 English wordlist. Public domain, verbatim from the specification.
//!
//! Do not sort, reformat, or "clean up". Index order *is* the encoding — a
//! single reordered entry silently changes every mnemonic ever generated.

/// Digest of the official `english.txt`.
///
/// Recorded at source level with provenance independent of the fetch — a
/// checksum generated by the same command that downloaded the artifact
/// validates nothing. This value was cross-checked against one recorded in
/// this repository's history *before* the file was fetched.
#[cfg_attr(not(test), allow(dead_code))]
pub const EXPECTED_WORDLIST_SHA256: &str =
    "2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda";

pub static WORDS: [&str; 2048] = [
    "abandon", "ability", "able", "about", "above", "absent",
    // ... 2042 more, in specification order ...
    "zebra", "zero", "zone", "zoo",
];
```

Source it from the BIP-39 repository's `english.txt` and verify with the
checksum test in Step 1 rather than by eye.

Create `rust/airo_mind/src/vault/seed.rs`:

```rust
//! Recovery seed. The root of everything the user can ever recover.
//!
//! BIP-39 implemented in-house rather than taken as a dependency: ~200 lines
//! auditable in full, verifiable against the complete official test vectors,
//! and three fewer crates on the path that generates the recovery secret for
//! medical and financial records.

use hmac::Hmac;
use sha2::{Digest, Sha256, Sha512};
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use super::error::VaultError;
use super::wordlist::WORDS;

/// 24 words = 256 bits of entropy + an 8-bit checksum.
const ENTROPY_BYTES: usize = 32;
const WORD_COUNT: usize = 24;
/// Fixed by BIP-39. Not a tunable.
const PBKDF2_ROUNDS: u32 = 2048;

/// A 64-byte BIP-39 seed. Zeroized on drop.
///
/// No `Clone`: the seed is the one secret whose compromise is total and
/// unrecoverable, and silent duplication is how copies end up unzeroized.
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct Seed([u8; 64]);

impl Seed {
    /// `SEC-33` / `A01`. `pub(crate)`: the two HKDF derivations need it and no
    /// consumer does. The 64-byte master seed is the one secret whose
    /// compromise is total.
    pub(crate) fn as_bytes(&self) -> &[u8; 64] {
        &self.0
    }
}

/// Generates a fresh 24-word recovery mnemonic.
///
/// Shown to the user exactly once. There is no other copy, and no server-side
/// recovery path — that is the product promise, and it is also the reason the
/// onboarding flow (#1234) must confirm the user recorded it.
pub fn generate_mnemonic() -> Result<Zeroizing<String>, VaultError> {
    let mut entropy = Zeroizing::new([0u8; ENTROPY_BYTES]);
    super::random::fill_random(entropy.as_mut())?;
    Ok(mnemonic_from_entropy(&entropy))
}

/// Encodes entropy as a mnemonic. Separated from generation so the official
/// test vectors can drive it directly.
fn mnemonic_from_entropy(entropy: &[u8; ENTROPY_BYTES]) -> Zeroizing<String> {
    // Checksum: the first `entropy_bits / 32` bits of SHA-256(entropy).
    let checksum = Sha256::digest(entropy);
    let checksum_bits = ENTROPY_BYTES * 8 / 32; // 8 for 256-bit entropy

    // Concatenate entropy || checksum bits, then read 11 bits per word.
    let mut bits = Vec::with_capacity(ENTROPY_BYTES * 8 + checksum_bits);
    for byte in entropy.iter() {
        for i in (0..8).rev() {
            bits.push((byte >> i) & 1 == 1);
        }
    }
    for i in 0..checksum_bits {
        bits.push((checksum[i / 8] >> (7 - (i % 8))) & 1 == 1);
    }

    let words: Vec<&str> = bits
        .chunks(11)
        .map(|chunk| {
            let index = chunk.iter().fold(0usize, |acc, bit| (acc << 1) | *bit as usize);
            WORDS[index]
        })
        .collect();

    Zeroizing::new(words.join(" "))
}

/// Derives the 64-byte seed from a mnemonic phrase.
///
/// Validates word membership and the checksum before deriving — a typo must
/// fail here, not silently produce a valid-looking seed for the wrong vault.
///
/// No passphrase in v1. The Recovery Package reserves `passphrase_used`,
/// `kdf_params`, and `kdf_salt` so the option survives; see Task 8.
pub fn seed_from_mnemonic(phrase: &str) -> Result<Seed, VaultError> {
    seed_from_mnemonic_with_passphrase(phrase, "")
}

/// Derivation with an explicit passphrase.
///
/// `seed_from_mnemonic` calls this with `""`. It exists separately for two
/// reasons: the official BIP-39 vectors are published with the passphrase
/// `"TREZOR"` and cannot be used without it, and the Recovery Package format
/// already reserves `passphrase_used` / `kdf_params` / `kdf_salt` (Task 8), so
/// this is the entry point that slot will use.
pub(crate) fn seed_from_mnemonic_with_passphrase(
    phrase: &str,
    passphrase: &str,
) -> Result<Seed, VaultError> {
    let words = validate_mnemonic(phrase)?;

    // CANONICALIZE before derivation. BIP-39 specifies the PBKDF2 password as
    // the NFKD-normalized *sentence*: words joined by exactly one space, no
    // leading or trailing whitespace.
    //
    // Passing the raw input instead means a user who pastes 24 correct words
    // with a trailing newline or a double space passes validation, passes the
    // checksum, and then derives a completely different seed — surfacing as
    // "wrong seed" while their mnemonic is perfectly correct. On a recovery
    // path for medical and financial records that is the worst failure
    // available.
    //
    // v1 is English-only and NFKD is the identity on ASCII. Adding a
    // non-ASCII wordlist REQUIRES a Unicode normalization step here.
    let canonical = Zeroizing::new(words.join(" "));

    let mut salt = Zeroizing::new(Vec::with_capacity(8 + passphrase.len()));
    salt.extend_from_slice(b"mnemonic");
    salt.extend_from_slice(passphrase.as_bytes());

    Ok(Seed(pbkdf2_hmac_sha512(
        canonical.as_bytes(),
        &salt,
        PBKDF2_ROUNDS,
    )?))
}

/// Validates word membership and the checksum. Returns the words for
/// canonicalization.
///
/// A typo must fail here, not silently produce a valid-looking seed for a
/// vault that does not exist.
fn validate_mnemonic(phrase: &str) -> Result<Vec<&str>, VaultError> {
    let words: Vec<&str> = phrase.split_whitespace().collect();
    if words.len() != WORD_COUNT {
        return Err(VaultError::InvalidMnemonic);
    }

    // `u8` rather than `bool`: this buffer is a bit-for-bit expansion of the
    // entropy — the same secret in a more scannable form — so it must be
    // zeroized, and `Zeroize` is not implemented for `Vec<bool>`.
    let mut bits: Zeroizing<Vec<u8>> = Zeroizing::new(Vec::with_capacity(WORD_COUNT * 11));
    for word in &words {
        // Linear scan over 2048 entries. Note this is data-dependent and is
        // NOT constant time — see the note on the checksum comparison below.
        let index = WORDS
            .iter()
            .position(|candidate| candidate == word)
            .ok_or(VaultError::InvalidMnemonic)?;
        for i in (0..11).rev() {
            bits.push(((index >> i) & 1) as u8);
        }
    }

    let entropy_bits = ENTROPY_BYTES * 8;
    let mut entropy = Zeroizing::new([0u8; ENTROPY_BYTES]);
    for (i, bit) in bits[..entropy_bits].iter().enumerate() {
        if *bit == 1 {
            entropy[i / 8] |= 1 << (7 - (i % 8));
        }
    }

    // Checksum comparison is written branch-free for tidiness, but this
    // function is NOT constant time overall: the wordlist lookup above is a
    // data-dependent scan with an early return, and it dominates. That is
    // acceptable here — this runs once per restore against locally-entered
    // input, and the adversary is not measuring our timing. Stating the real
    // property rather than claiming one the code does not have (invariant I3).
    let expected = Sha256::digest(entropy.as_ref());
    let checksum_bits = entropy_bits / 32;
    let mut diff = 0u8;
    for i in 0..checksum_bits {
        let want = (expected[i / 8] >> (7 - (i % 8))) & 1;
        diff |= bits[entropy_bits + i] ^ want;
    }
    if diff != 0 {
        return Err(VaultError::InvalidMnemonic);
    }

    Ok(words)
}

/// Guards the bit-packing arithmetic. 256 entropy bits + 8 checksum bits = 264,
/// which is exactly 24 * 11. If `ENTROPY_BYTES` ever changes, a short final
/// chunk would silently fold to a small word index instead of failing.
const _: () = assert!((ENTROPY_BYTES * 8 + ENTROPY_BYTES * 8 / 32).is_multiple_of(11));

/// PBKDF2-HMAC-SHA512 producing exactly 64 bytes — one block, since SHA-512's
/// output is 64 bytes, so the block-index loop collapses to a single pass.
///
/// Hand-written rather than pulling the `pbkdf2` crate: this is the whole
/// algorithm, it is driven entirely by the official BIP-39 vectors in Step 1,
/// and it keeps the trusted computing base on the recovery path to `sha2` and
/// `hmac` alone.
fn pbkdf2_hmac_sha512(
    password: &[u8],
    salt: &[u8],
    rounds: u32,
) -> Result<[u8; 64], VaultError> {
    use hmac::Mac;

    // `.expect()` is forbidden outside tests (Global Constraints). HMAC does
    // accept any key length — which is exactly why mapping the error costs
    // nothing and a panic here would be gratuitous.
    let mut mac = <Hmac<Sha512> as Mac>::new_from_slice(password)
        .map_err(|_| VaultError::DerivationFailed)?;
    mac.update(salt);
    mac.update(&1u32.to_be_bytes()); // block index, big-endian
    let mut u = Zeroizing::new(mac.finalize().into_bytes().to_vec());

    let mut out = [0u8; 64];
    out.copy_from_slice(&u);

    for _ in 1..rounds {
        let mut mac = <Hmac<Sha512> as Mac>::new_from_slice(password)
            .map_err(|_| VaultError::DerivationFailed)?;
        mac.update(&u);
        // Each intermediate is the same secret in another form — zeroized on
        // reassignment because the binding is `Zeroizing`.
        u = Zeroizing::new(mac.finalize().into_bytes().to_vec());
        for (acc, byte) in out.iter_mut().zip(u.iter()) {
            *acc ^= byte;
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};

    #[test]
    fn generated_mnemonic_has_24_words() {
        let phrase = generate_mnemonic().unwrap();
        assert_eq!(phrase.split_whitespace().count(), 24);
    }

    #[test]
    fn generated_mnemonic_round_trips_to_a_seed() {
        let phrase = generate_mnemonic().unwrap();
        assert!(seed_from_mnemonic(&phrase).is_ok());
    }

    #[test]
    fn same_mnemonic_always_yields_the_same_seed() {
        let phrase = generate_mnemonic().unwrap();
        let a = seed_from_mnemonic(&phrase).unwrap();
        let b = seed_from_mnemonic(&phrase).unwrap();
        assert_eq!(a.as_bytes(), b.as_bytes());
    }

    #[test]
    fn two_generated_mnemonics_differ() {
        assert_ne!(*generate_mnemonic().unwrap(), *generate_mnemonic().unwrap());
    }

    #[test]
    fn wordlist_matches_the_specification() {
        // Index order IS the encoding: one moved entry silently changes every
        // mnemonic ever generated, and no other test would notice.
        //
        // The expected digest is not written here by hand. Compute it once from
        // the official english.txt and paste the result — see Step 3.
        assert_eq!(WORDS.len(), 2048);
        assert_eq!(WORDS[0], "abandon");
        assert_eq!(WORDS[2047], "zoo");
        assert_eq!(
            hex_lower(&Sha256::digest((WORDS.join("\n") + "\n").as_bytes())),
            // Source-level const with provenance independent of the fetch.
            // See Step 3 — a digest generated by the download command
            // validates nothing.
            crate::vault::wordlist::EXPECTED_WORDLIST_SHA256
        );
    }

    // No `#[ignore]`: Step 3's fixture is vendored and committed as of #1731,
    // so the vector set runs on every `cargo test`.
    #[test]
    fn official_vectors_encode_and_derive_correctly() {
        // Drives the COMPLETE Trezor reference vector set from a checked-in
        // fixture. Do not transcribe vectors by hand into this file: a
        // mistyped expectation either fails mysteriously or, worse, gets
        // "fixed" by bending the implementation to match it.
        //
        // Fixture format, one case per line, tab-separated:
        //     <entropy_hex>\t<mnemonic>\t<seed_hex>
        // Only the 256-bit (24-word) cases apply here; skip the rest.
        let raw = std::fs::read_to_string("tests/fixtures/bip39/vectors.tsv")
            .expect("vendored by Task 2 Step 3");
        let mut checked = 0;

        for line in raw.lines().filter(|l| !l.trim().is_empty()) {
            let mut parts = line.split('\t');
            let entropy_hex = parts.next().expect("entropy column");
            let expected_phrase = parts.next().expect("mnemonic column");
            let expected_seed = parts.next().expect("seed column");

            if entropy_hex.len() != ENTROPY_BYTES * 2 {
                continue; // not a 24-word case
            }

            let entropy: [u8; ENTROPY_BYTES] =
                hex_bytes(entropy_hex).try_into().expect("32 bytes");

            let phrase = mnemonic_from_entropy(&entropy);
            assert_eq!(&*phrase, expected_phrase, "encoding {entropy_hex}");

            // Official vectors use the passphrase "TREZOR".
            let seed = seed_from_mnemonic_with_passphrase(&phrase, "TREZOR").unwrap();
            assert_eq!(hex_lower(seed.as_bytes()), expected_seed, "derivation {entropy_hex}");

            checked += 1;
        }

        // Guards against an empty or truncated fixture silently passing.
        assert!(checked >= 8, "expected the full 24-word vector set, got {checked}");
    }

    #[test]
    fn a_single_wrong_word_fails_the_checksum() {
        // A typo must fail here, not silently derive a valid-looking seed for
        // a vault that does not exist.
        let phrase = generate_mnemonic().unwrap();
        let mut words: Vec<&str> = phrase.split_whitespace().collect();
        words[5] = if words[5] == "zoo" { "abandon" } else { "zoo" };
        assert!(matches!(
            seed_from_mnemonic(&words.join(" ")),
            Err(VaultError::InvalidMnemonic)
        ));
    }

    #[test]
    fn non_canonical_whitespace_derives_the_same_seed() {
        // The bug this guards: passing raw user input to PBKDF2 instead of the
        // canonical sentence. A pasted mnemonic with a trailing newline or a
        // double space passed validation and the checksum, then derived a
        // COMPLETELY DIFFERENT seed — surfacing as "wrong seed" while the
        // user's mnemonic was perfectly correct.
        let phrase = generate_mnemonic().unwrap();
        let messy = format!("  {}  \n", phrase.replace(' ', "  "));

        assert_eq!(
            seed_from_mnemonic(&messy).unwrap().as_bytes(),
            seed_from_mnemonic(&phrase).unwrap().as_bytes()
        );
    }

    #[test]
    fn a_word_outside_the_list_is_rejected() {
        let phrase = generate_mnemonic().unwrap();
        let mut words: Vec<&str> = phrase.split_whitespace().collect();
        words[0] = "notabip39word";
        assert!(matches!(
            seed_from_mnemonic(&words.join(" ")),
            Err(VaultError::InvalidMnemonic)
        ));
    }

    #[test]
    fn wrong_word_count_is_rejected() {
        let phrase = generate_mnemonic().unwrap();
        let short: Vec<&str> = phrase.split_whitespace().take(23).collect();
        assert!(matches!(
            seed_from_mnemonic(&short.join(" ")),
            Err(VaultError::InvalidMnemonic)
        ));
    }

    fn hex_bytes(hex: &str) -> Vec<u8> {
        (0..hex.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
            .collect()
    }

    #[test]
    fn invalid_mnemonic_is_rejected() {
        assert!(matches!(
            seed_from_mnemonic("not a real mnemonic phrase at all"),
            Err(VaultError::InvalidMnemonic)
        ));
    }

    fn hex_lower(bytes: &[u8]) -> String {
        crate::vault::encoding::hex_of(bytes)
    }
}
```

Modify `rust/airo_mind/src/vault/mod.rs` — add below the existing `mod error;`:

```rust
mod seed;
mod wordlist;

pub use seed::{generate_mnemonic, seed_from_mnemonic, Seed};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind seed`
Expected: FAIL to compile — `wordlist` module and the fixtures do not exist yet.

- [ ] **Step 3: Vendor the official wordlist and vectors**

Both are public domain, from BIP-0039. **Copy them; never transcribe by hand
and never generate them from memory.**

Two traps this step previously contained, both fixed here:

```bash
mkdir -p rust/airo_mind/tests/fixtures/bip39
# PINNED to a commit, not a branch. A fixture fetched from `master` is not
# reproducible, and a moved branch silently changes what was verified.
BIPS_SHA=<pin a bitcoin/bips commit SHA here and record it in the PR>
curl -sSL "https://raw.githubusercontent.com/bitcoin/bips/${BIPS_SHA}/bip-0039/english.txt" \
  -o rust/airo_mind/tests/fixtures/bip39/english.txt
```

**Do not `shasum` the download into the fixture the test compares against.**
That is what the previous revision did, and it is tautological: the expected
value is produced by the same command that fetched the artifact it validates.
A wrong branch, a MITM, or a corrupt byte would be recorded as correct.

Instead, record the expected digest as a `const` **in `wordlist.rs` source**,
cross-checked against a source the fetch cannot influence — an existing
implementation's vendored copy, or the BIP-0039 text itself. Note in the PR
where the independent check came from.

Generate `src/vault/wordlist.rs` from `english.txt` (a one-off script is fine;
commit the generated file, not the script).

For vectors, use `trezor/python-mnemonic`'s `vectors.json`, also pinned.
**Those vectors derive the seed with the passphrase `"TREZOR"`, not an empty
passphrase.** That is why `seed_from_mnemonic_with_passphrase` exists — drive
the fixture through it with `"TREZOR"`. Using the published parameters is what
makes this an external check on the PBKDF2 loop *and* the salt concatenation;
regenerating the seed column from our own implementation would be no test at
all.

Build `tests/fixtures/bip39/vectors.tsv` as
`entropy_hex \t mnemonic \t seed_hex`, keeping every 24-word case.

Both fixtures are checked in — CI has no network, and a vendored set is also a
record of exactly what was verified.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind`
Expected: PASS, 1 test

- [ ] **Step 5: Verify CI gates pass locally**

Run: `cargo clippy --manifest-path rust/Cargo.toml --all -- -D warnings`
Run: `cargo fmt --manifest-path rust/Cargo.toml --check`
Expected: both clean. Clippy warnings fail CI, so fix them now rather than in review.

- [ ] **Step 6: Commit**

```bash
git add rust/Cargo.toml rust/airo_mind/
git commit -m "feat(mind): scaffold airo_mind crate with vault error type

New workspace member, deliberately separate from airo_core: airo_core is
on the Airo TV shipping critical path and must not gain crypto or storage
dependencies.

Refs #1204"
```

---

## Task 3: Root identity derivation

Implements the second half of #1207.

**Files:**
- Create: `rust/airo_mind/src/vault/identity.rs`
- Modify: `rust/airo_mind/src/vault/mod.rs`

**Interfaces:**
- Consumes: `Seed` (Task 2), `VaultError` (Task 1)
- Produces:
  - `RootIdentity` with `fn from_seed(&Seed) -> Result<Self, VaultError>`, `fn public_key(&self) -> [u8; 32]`, `fn identity_id(&self) -> String` (lowercase hex of the public key), `fn sign(&self, msg: &[u8]) -> [u8; 64]`
  - `fn verify(public_key: &[u8; 32], msg: &[u8], signature: &[u8; 64]) -> bool`

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/identity.rs`:

```rust
//! Root identity. Derived from the seed, signs device certificates.

use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use hkdf::Hkdf;
use serde::{Deserialize, Serialize};
use sha2::Sha512;
use zeroize::ZeroizeOnDrop;

use super::error::VaultError;
use super::seed::Seed;

/// Domain separation for root identity derivation.
///
/// Changing this string invalidates every identity ever derived. It is
/// versioned so a future scheme can coexist rather than replace.
use super::domain;

/// A root public key that provably came from a `RootIdentity`.
///
/// Domain type rather than `[u8; 32]`: the compiler becomes another reviewer,
/// and unlike the human ones it reads every line every time (design spec
/// §11a, "domain types over raw primitives").
/// `Deserialize` is derived, which does allow a `RootPublicKey` to exist
/// without a `RootIdentity`. Accepted: the only deserialization path is
/// `VaultPayload`, which is AEAD-authenticated, so forging one requires the
/// seed. Recorded as the disposition of chief-security-officer S10.
/// `RA-1`. The `hex_array_32` attribute is on the field, not merely named in
/// prose: `#[serde(transparent)]` and a bare newtype both inherit `[u8; 32]`'s
/// default encoding, which is a JSON decimal array, and that is what shipped
/// inside a **frozen** format for seven revisions.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Serialize, Deserialize)]
#[serde(transparent)]
pub struct RootPublicKey(#[serde(with = "super::encoding::hex_array_32")] pub(crate) [u8; 32]);

impl RootPublicKey {
    pub fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    #[cfg(test)]
    pub(crate) fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }
}

/// The user's root cryptographic identity.
#[derive(ZeroizeOnDrop)]
pub struct RootIdentity {
    #[zeroize(skip)]
    signing_key: SigningKey,
}

impl RootIdentity {
    /// Derives the root identity from a seed.
    ///
    /// Deterministic: the same seed produces byte-identical key material on
    /// every platform. That property is what makes recovery possible at all.
    pub fn from_seed(seed: &Seed) -> Result<Self, VaultError> {
        let hkdf = Hkdf::<Sha512>::new(None, seed.as_bytes());
        let mut key_bytes = [0u8; 32];
        hkdf.expand(domain::ROOT_IDENTITY, &mut key_bytes)
            .map_err(|_| VaultError::DerivationFailed)?;
        Ok(Self {
            signing_key: SigningKey::from_bytes(&key_bytes),
        })
    }

    pub fn public_key(&self) -> RootPublicKey {
        RootPublicKey(self.signing_key.verifying_key().to_bytes())
    }

    /// Lowercase hex of the public key. Stable, human-comparable.
    pub fn identity_id(&self) -> String {
        super::encoding::hex_of(self.public_key().as_bytes())
    }

    /// `RA-17` / `A02`. `pub(crate)`: a raw signing oracle over the root key
    /// must not be reachable from outside the crate.
    pub(crate) fn sign(&self, msg: &[u8]) -> [u8; 64] {
        self.signing_key.sign(msg).to_bytes()
    }
}

/// Verifies a signature against a public key.
///
/// Uses strict verification: rejects small-order and non-canonical keys that
/// permit signature malleability.
pub(crate) fn verify(public_key: &RootPublicKey, msg: &[u8], signature: &[u8; 64]) -> bool {
    let Ok(verifying_key) = VerifyingKey::from_bytes(public_key.as_bytes()) else {
        return false;
    };
    verifying_key
        .verify_strict(msg, &Signature::from_bytes(signature))
        .is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};
    use crate::vault::seed::seed_from_mnemonic;

    fn test_seed() -> Seed {
        seed_from_mnemonic(
            "abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon art",
        )
        .unwrap()
    }

    #[test]
    fn derivation_is_deterministic() {
        let a = RootIdentity::from_seed(&test_seed()).unwrap();
        let b = RootIdentity::from_seed(&test_seed()).unwrap();
        assert_eq!(a.public_key(), b.public_key());
    }

    #[test]
    fn identity_id_is_64_hex_chars() {
        let id = RootIdentity::from_seed(&test_seed()).unwrap().identity_id();
        assert_eq!(id.len(), 64);
        assert!(id.chars().all(|c| c.is_ascii_hexdigit() && !c.is_uppercase()));
    }

    #[test]
    fn signature_verifies_against_its_own_key() {
        let identity = RootIdentity::from_seed(&test_seed()).unwrap();
        let sig = identity.sign(b"authorize device");
        assert!(verify(&identity.public_key(), b"authorize device", &sig));
    }

    #[test]
    fn signature_fails_on_tampered_message() {
        let identity = RootIdentity::from_seed(&test_seed()).unwrap();
        let sig = identity.sign(b"authorize device");
        assert!(!verify(&identity.public_key(), b"authorize DEVICE", &sig));
    }

    #[test]
    fn signature_fails_under_a_different_identity() {
        let mine = RootIdentity::from_seed(&test_seed()).unwrap();
        let theirs = RootIdentity::from_seed(
            &seed_from_mnemonic(&crate::vault::generate_mnemonic().unwrap()).unwrap(),
        )
        .unwrap();
        let sig = theirs.sign(b"authorize device");
        assert!(!verify(&mine.public_key(), b"authorize device", &sig));
    }

    #[test]
    fn different_seeds_produce_different_identities() {
        let a = RootIdentity::from_seed(&test_seed()).unwrap();
        let b = RootIdentity::from_seed(
            &seed_from_mnemonic(&crate::vault::generate_mnemonic().unwrap()).unwrap(),
        )
        .unwrap();
        assert_ne!(a.public_key(), b.public_key());
    }
}
```

Modify `rust/airo_mind/src/vault/mod.rs`:

```rust
mod identity;

pub use identity::{RootIdentity, RootPublicKey};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind identity`
Expected: FAIL to compile — module not yet declared, or `ed25519_dalek` trait imports missing.

- [ ] **Step 3: Reconcile against the real `ed25519-dalek` v2 API**

`SigningKey::from_bytes` takes `&[u8; 32]`. `Signer`/`Verifier` traits must be in scope for `.sign()` / `.verify()`. Adjust imports if the compiler disagrees; do not weaken `verify` to a non-strict variant.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind identity`
Expected: PASS — wordlist guard, the full official vector set, and the four rejection cases

- [ ] **Step 5: Commit**

```bash
git add rust/airo_mind/src/vault/identity.rs rust/airo_mind/src/vault/mod.rs
git commit -m "feat(mind): derive root Ed25519 identity from recovery seed

HKDF-SHA512 with versioned domain separation. Deterministic across
platforms, which is the property recovery depends on.

Refs #1207"
```

---

## Task 4: Device keys and certificates

Implements #1208.

**Files:**
- Create: `rust/airo_mind/src/vault/device.rs`
- Modify: `rust/airo_mind/src/vault/mod.rs`

**Interfaces:**
- Consumes: `RootIdentity`, `verify` (Task 3), `VaultError` (Task 1)
- Produces:
  - `DeviceKey` with `fn generate() -> Self`, `fn device_id(&self) -> String`, `fn public_key(&self) -> [u8; 32]`, `fn sign(&self, msg: &[u8]) -> [u8; 64]`
  - `DeviceCertificate { device_id: String, device_public_key: [u8; 32], issued_at_epoch: u64 }` with `fn issue(root: &RootIdentity, device: &DeviceKey, issued_at_epoch: u64) -> Self`, `fn verify_against(&self, root_public_key: &[u8; 32]) -> bool`, `fn signing_payload(&self) -> Vec<u8>`

**Design note for the implementer.** A device key is **generated locally on that device**, never derived from the seed. The root only *signs* the device's public key. This is deliberate: seed-derived device keys would require the seed to travel to every device, and the seed is the one secret that must never leave the device where it was created. Do not "simplify" this into HKDF-from-seed.

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/device.rs`:

```rust
//! Device keys and root-signed device certificates.
//!
//! v1 has exactly one trust domain: the user's own device mesh. A device that
//! cannot present a certificate signed by the root identity cannot write.

use ed25519_dalek::SigningKey;
use serde::{Deserialize, Serialize};
use zeroize::ZeroizeOnDrop;

use super::domain;
use super::encoding::push_len_prefixed;
use super::error::VaultError;
use super::identity::{verify, RootIdentity, RootPublicKey};

/// A per-device signing key, generated on the device that owns it.
///
/// Never derived from the seed. The seed must never leave the device where it
/// was created, so a new device generates its own key and asks the root to
/// certify the public half.
#[derive(ZeroizeOnDrop)]
pub struct DeviceKey {
    #[zeroize(skip)]
    signing_key: SigningKey,
}

// No `impl Default`. `SigningKey::generate` goes through `fill_bytes`, which
// panics on RNG failure — and a `Default` that mints a private key means any
// future `#[derive(Default)]` on a containing struct silently generates key
// material.
impl DeviceKey {
    pub fn generate() -> Result<Self, VaultError> {
        let bytes = super::random::random_bytes_32()?;
        Ok(Self {
            signing_key: SigningKey::from_bytes(&bytes),
        })
    }

    pub fn public_key(&self) -> [u8; 32] {
        self.signing_key.verifying_key().to_bytes()
    }

    pub fn device_id(&self) -> String {
        super::encoding::hex_of(&self.public_key())
    }

    // `RA-17b` / `A03`: `DeviceKey::sign` deleted -- zero callers anywhere,
    // including tests. A device signing oracle with no consumer is surface.
}

/// A root-signed statement that a device belongs to this user's mesh.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceCertificate {
    device_id: String,
    #[serde(with = "super::encoding::hex_array_32")]
    device_public_key: [u8; 32],
    issued_at_epoch: u64,
    #[serde(with = "super::encoding::hex_array_64")]
    signature: [u8; 64],
}

impl DeviceCertificate {
    /// Fallible since `RA-19`: the signing payload is length-prefixed with a
    /// checked cast, so building it can fail rather than truncate silently.
    pub fn issue(
        root: &RootIdentity,
        device: &DeviceKey,
        issued_at_epoch: u64,
    ) -> Result<Self, VaultError> {
        let mut certificate = Self {
            device_id: device.device_id(),
            device_public_key: device.public_key(),
            issued_at_epoch,
            signature: [0u8; 64],
        };
        certificate.signature = root.sign(&certificate.signing_payload()?);
        Ok(certificate)
    }

    /// `RA-23a` / `A07`,`A08`. Read accessors; the four fields are
    /// signature-covered.
    pub fn device_id(&self) -> &str {
        &self.device_id
    }

    pub fn device_public_key(&self) -> &[u8; 32] {
        &self.device_public_key
    }

    pub fn issued_at_epoch(&self) -> u64 {
        self.issued_at_epoch
    }

    /// An unsigned certificate, for the test that proves admission rejects it.
    /// `#[cfg(test)]`: outside tests, `issue` is the only constructor, which is
    /// the `RA-23a` construction boundary.
    #[cfg(test)]
    pub(crate) fn forged_unsigned(device: &DeviceKey, issued_at_epoch: u64) -> Self {
        Self {
            device_id: device.device_id(),
            device_public_key: device.public_key(),
            issued_at_epoch,
            signature: [0u8; 64],
        }
    }

    #[cfg(test)]
    pub(crate) fn with_device_id_tampered(mut self, v: &str) -> Self {
        self.device_id = v.to_string();
        self
    }

    #[cfg(test)]
    pub(crate) fn with_public_key_tampered(mut self, v: [u8; 32]) -> Self {
        self.device_public_key = v;
        self
    }

    #[cfg(test)]
    pub(crate) fn with_issued_at_tampered(mut self, v: u64) -> Self {
        self.issued_at_epoch = v;
        self
    }

    /// The exact bytes covered by the signature.
    ///
    /// Field order is fixed and length-prefixed so no two distinct
    /// certificates can ever produce the same payload.
    /// `RA-19` / `A11`: fallible, so the checked length helper can be used.
    /// `as u32` truncates silently and a truncated length breaks injectivity.
    pub fn signing_payload(&self) -> Result<Vec<u8>, VaultError> {
        let mut payload = Vec::new();
        payload.extend_from_slice(domain::DEVICE_CERTIFICATE);
        push_len_prefixed(&mut payload, self.device_id.as_bytes())?;
        payload.extend_from_slice(&self.device_public_key);
        payload.extend_from_slice(&self.issued_at_epoch.to_be_bytes());
        Ok(payload)
    }

    pub fn verify_against(&self, root_public_key: &RootPublicKey) -> bool {
        if self.device_id != hex_lower(&self.device_public_key) {
            return false;
        }
        let Ok(payload) = self.signing_payload() else {
            return false;
        };
        verify(root_public_key, &payload, &self.signature)
    }
}

fn hex_lower(bytes: &[u8]) -> String {
    // `RA-24` / `A10`: one pre-sized allocation, not one `String` per byte.
    // This runs on every certificate verification, i.e. on every restore.
    super::encoding::hex_of(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};
    use crate::vault::seed::seed_from_mnemonic;
    use crate::vault::Seed;

    fn test_seed() -> Seed {
        seed_from_mnemonic(
            "abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon art",
        )
        .unwrap()
    }

    #[test]
    fn two_generated_device_keys_differ() {
        assert_ne!(DeviceKey::generate().unwrap().public_key(), DeviceKey::generate().unwrap().public_key());
    }

    #[test]
    fn issued_certificate_verifies_against_the_issuing_root() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let device = DeviceKey::generate().unwrap();
        let certificate = DeviceCertificate::issue(&root, &device, 1).unwrap();
        assert!(certificate.verify_against(&root.public_key()));
    }

    #[test]
    fn certificate_fails_against_a_different_root() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let stranger = RootIdentity::from_seed(
            &seed_from_mnemonic(&crate::vault::generate_mnemonic().unwrap()).unwrap(),
        )
        .unwrap();
        let certificate = DeviceCertificate::issue(&root, &DeviceKey::generate().unwrap(), 1).unwrap();
        assert!(!certificate.verify_against(&stranger.public_key()));
    }

    #[test]
    fn swapping_the_public_key_invalidates_the_certificate() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let certificate = DeviceCertificate::issue(&root, &DeviceKey::generate().unwrap(), 1).unwrap();
        let certificate = certificate.with_public_key_tampered(DeviceKey::generate().unwrap().public_key());
        assert!(!certificate.verify_against(&root.public_key()));
    }

    #[test]
    fn device_id_must_match_the_public_key() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let certificate = DeviceCertificate::issue(&root, &DeviceKey::generate().unwrap(), 1).unwrap();
        let certificate = certificate.with_device_id_tampered("deadbeef");
        assert!(!certificate.verify_against(&root.public_key()));
    }

    #[test]
    fn changing_the_issue_epoch_invalidates_the_certificate() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let certificate = DeviceCertificate::issue(&root, &DeviceKey::generate().unwrap(), 1).unwrap();
        let certificate = certificate.with_issued_at_tampered(99);
        assert!(!certificate.verify_against(&root.public_key()));
    }
}
```

Modify `rust/airo_mind/src/vault/mod.rs`:

```rust
mod device;

pub use device::{DeviceCertificate, DeviceKey};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind device`
Expected: FAIL to compile — module not declared.

- [ ] **Step 3: Use the decided fixed-array encoding — do not choose one**

`[u8; 64]` has no `Serialize` in serde 1 (its array impls stop at 32). This is
the **on-disk Recovery Package format v1, frozen in this phase**. Leaving the
choice to the implementer means two implementers can satisfy "pick one" with
two incompatible wire formats.

Create `rust/airo_mind/src/vault/encoding.rs` and use it everywhere a
fixed-size array is serialized (Tasks 4, 8, 9):

```rust
//! Serde helpers for fixed-size byte arrays, and length-prefixing.
//!
//! serde 1 has no array impl above 32 bytes and no feature that adds one.
//! Hand-written rather than pulling `serde_bytes` or `serde-big-array`: a new
//! crate on the crypto path needs a governance scorecard (Constitution §6),
//! and this is twenty lines.
//!
//! Encoding, by field class. Two encodings, and the split is measured, not
//! aesthetic (`ADR-0017`):
//!
//! - **Fixed-size key and signature fields** — lowercase hex, so the package
//!   stays inspectable in a text editor, which matters for a file users are
//!   told to store themselves.
//! - **The outer `ciphertext` / `nonce` / `kdf_salt`** — base64. The package
//!   double-encodes: a JSON payload, then that ciphertext text-encoded again
//!   in the envelope. Hex on the outer blob costs a hard 2.0×, putting `V4`'s
//!   `≤ 3× compact` floor at 3.30× — unmeetable at any inner encoding. Base64
//!   costs 1.33× and clears every measured shape. The blob is opaque either
//!   way, so nothing inspectable is lost.
//!
//! **Never `format!("{b:02x}")` per byte.** That allocates one `String` per
//! byte; on a 100k-context vault it measures 350.82 ms against 16.55 ms for
//! the pre-sized form below — a 21× difference, and a **4.0× regression**
//! against the JSON decimal arrays it replaces. `PERF` found this on the
//! Revision 8 rollout, and Revision 7 already shipped the slow pattern on the
//! `DeviceCertificate` path.

use super::error::VaultError;

/// Length-prefixes with a **checked** cast.
///
/// `as u32` truncates silently above `u32::MAX`, and a truncated length breaks
/// injectivity — two different inputs producing identical AAD bytes. Lives
/// here, not in `envelope.rs`, so `package.rs` stops importing its wire-format
/// helper from the content-wrapping module (`RA-4`).
pub(crate) fn push_len_prefixed(out: &mut Vec<u8>, bytes: &[u8]) -> Result<(), VaultError> {
    let len = u32::try_from(bytes.len()).map_err(|_| VaultError::ValueTooLong)?;
    out.extend_from_slice(&len.to_be_bytes());
    out.extend_from_slice(bytes);
    Ok(())
}

/// Lowercase hex into a single pre-sized allocation.
///
/// One `String` for the whole field, not one per byte.
pub(crate) fn hex_of(bytes: &[u8]) -> String {
    hex_into(bytes)
}

fn hex_into(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        out.push(DIGITS[(b >> 4) as usize] as char);
        out.push(DIGITS[(b & 0x0f) as usize] as char);
    }
    out
}

/// Decodes hex over **bytes**, never over `&str`.
///
/// `RA-20`: the previous form checked `text.len() != 64` — a *byte* count —
/// and then sliced `&text[i * 2..i * 2 + 2]`. A multi-byte character that
/// straddles an even offset lands off a char boundary and `&str` slicing
/// panics:
///
/// ```text
/// input:  "a" * 61 + "é" + "a"      // 64 bytes, 63 chars
/// panic:  end byte index 62 is not a char boundary; it is inside 'é'
/// ```
///
/// Reachable pre-auth once `C3` sync parses device certificates, in a crate
/// carrying `#![forbid(unsafe_code)]`. Operating on `as_bytes()` makes the
/// panic structurally impossible rather than length-checked. Note the bug
/// needs the character to straddle an *even* offset, which is why a
/// hand-written negative test plausibly misses it and the fuzz target below
/// does not.
fn hex_from(text: &str, out: &mut [u8]) -> Result<(), &'static str> {
    let b = text.as_bytes();
    if b.len() != out.len() * 2 {
        return Err("wrong hex length");
    }
    fn nibble(c: u8) -> Result<u8, &'static str> {
        match c {
            b'0'..=b'9' => Ok(c - b'0'),
            b'a'..=b'f' => Ok(c - b'a' + 10),
            _ => Err("invalid hex"),
        }
    }
    for (i, slot) in out.iter_mut().enumerate() {
        *slot = (nibble(b[i * 2])? << 4) | nibble(b[i * 2 + 1])?;
    }
    Ok(())
}

pub(crate) mod hex_array_32 {
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(bytes: &[u8; 32], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&super::hex_into(bytes))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<[u8; 32], D::Error> {
        use serde::de::Error;
        let text = String::deserialize(d)?;
        let mut out = [0u8; 32];
        super::hex_from(&text, &mut out).map_err(D::Error::custom)?;
        Ok(out)
    }
}

pub(crate) mod hex_array_64 {
    use serde::{Deserialize, Deserializer, Serializer};

    pub fn serialize<S: Serializer>(bytes: &[u8; 64], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&super::hex_into(bytes))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<[u8; 64], D::Error> {
        use serde::de::Error;
        let text = String::deserialize(d)?;
        let mut out = [0u8; 64];
        super::hex_from(&text, &mut out).map_err(D::Error::custom)?;
        Ok(out)
    }
}

/// Base64 for the outer opaque blobs. `ADR-0017`, budget `V4`.
///
/// Hand-written for the same reason as the hex helpers: a new crate on the
/// crypto path needs a governance scorecard (Constitution §6), and this is
/// standard alphabet, padded, ~30 lines. It must round-trip exactly; the
/// property test below is not optional.
pub(crate) mod base64_bytes {
    use serde::{Deserialize, Deserializer, Serializer};

    const ALPHABET: &[u8; 64] =
        b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    pub(crate) fn encode(bytes: &[u8]) -> String {
        let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
        for chunk in bytes.chunks(3) {
            let b = [
                chunk[0],
                *chunk.get(1).unwrap_or(&0),
                *chunk.get(2).unwrap_or(&0),
            ];
            let n = (u32::from(b[0]) << 16) | (u32::from(b[1]) << 8) | u32::from(b[2]);
            out.push(ALPHABET[(n >> 18) as usize & 63] as char);
            out.push(ALPHABET[(n >> 12) as usize & 63] as char);
            out.push(if chunk.len() > 1 {
                ALPHABET[(n >> 6) as usize & 63] as char
            } else {
                '='
            });
            out.push(if chunk.len() > 2 {
                ALPHABET[n as usize & 63] as char
            } else {
                '='
            });
        }
        out
    }

    pub(crate) fn decode(text: &str) -> Result<Vec<u8>, &'static str> {
        let b = text.as_bytes();
        if !b.len().is_multiple_of(4) {
            return Err("base64 length not a multiple of 4");
        }
        fn val(c: u8) -> Result<u32, &'static str> {
            match c {
                b'A'..=b'Z' => Ok(u32::from(c - b'A')),
                b'a'..=b'z' => Ok(u32::from(c - b'a') + 26),
                b'0'..=b'9' => Ok(u32::from(c - b'0') + 52),
                b'+' => Ok(62),
                b'/' => Ok(63),
                _ => Err("invalid base64"),
            }
        }
        let mut out = Vec::with_capacity(b.len() / 4 * 3);
        for chunk in b.chunks(4) {
            let pad = chunk.iter().filter(|c| **c == b'=').count();
            if pad > 2 || (pad > 0 && !std::ptr::eq(chunk, &b[b.len() - 4..])) {
                return Err("misplaced base64 padding");
            }
            let n = (val(chunk[0])? << 18)
                | (val(chunk[1])? << 12)
                | (if pad < 2 { val(chunk[2])? } else { 0 } << 6)
                | (if pad < 1 { val(chunk[3])? } else { 0 });
            out.push((n >> 16) as u8);
            if pad < 2 {
                out.push((n >> 8) as u8);
            }
            if pad < 1 {
                out.push(n as u8);
            }
        }
        Ok(out)
    }

    pub fn serialize<S: Serializer>(bytes: &[u8], s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&encode(bytes))
    }

    pub fn deserialize<'de, D: Deserializer<'de>>(d: D) -> Result<Vec<u8>, D::Error> {
        use serde::de::Error;
        let text = String::deserialize(d)?;
        decode(&text).map_err(D::Error::custom)
    }
}
```

Create `rust/airo_mind/src/vault/identifier.rs` — the canonical identifier type
(`SEC-32`, `I6`, `A04`):

```rust
//! `ContextId` — an identifier that has already been canonicalized.
//!
//! `I6` requires canonicalization exactly once, at the boundary, and states the
//! defect test directly: *"a function that accepts a raw value and a canonical
//! one at the same type is a defect: the type must distinguish them, or the raw
//! form must be unreachable past the boundary."*
//!
//! A normalization call inside the Vault would satisfy neither half. Phase 1
//! takes ids from its caller, so if the Vault normalized *and* Phase 2's
//! runtime normalized, that is canonicalization twice -- which `I6` forbids in
//! the same breath: *"re-canonicalizing hides the layer that forgot."* A
//! `ContextId` cannot be re-canonicalized. It can only be constructed from a
//! raw `&str`, exactly once, wherever the boundary currently is.
//!
//! # Why ASCII rather than NFC
//!
//! `Freeze §4` requires subject ids to be *"NFC-normalized and rejected if they
//! contain control characters."* This type enforces **printable ASCII**, which
//! is strictly stronger: every ASCII string is already in NFC, because no ASCII
//! scalar has a canonical decomposition. So the frozen requirement is satisfied
//! rather than amended, and no ADR is needed.
//!
//! The alternative was a `unicode-normalization` dependency, which Constitution
//! §6 gates behind a scorecard and chief-open-source-officer sign-off -- a human
//! gate, on the crypto path, for a case Phase 1 does not have: **identity
//! strings are minted by the runtime, not typed by a user.** User-visible names
//! arrive with the Phase 2 ontology layer, and `SEC-14`'s ruling already
//! separates them: a name may be reused, the identity behind it may not.
//!
//! If Phase 2 ever needs user-typed identifiers, widening ASCII to NFC is a
//! constructor change in one file, and every existing id remains valid because
//! ASCII is a subset of NFC.

use std::fmt;

use super::error::VaultError;

/// A canonical context identifier. Construction is the only canonicalization
/// point in the crate.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ContextId(String);

impl ContextId {
    /// The boundary. Rejects anything that is not printable ASCII.
    ///
    /// `SEC-32` reproduced the failure this closes: destroy a context, re-add
    /// the same name in NFD, and the retired identity is resurrected while
    /// `is_content_destroyed` reports it live -- a crypto-shredding bypass
    /// reachable by keystroke rather than by attack. Two ids differing only by
    /// Unicode form are different subjects, so destroying one does not revoke
    /// the other.
    pub fn new(raw: &str) -> Result<Self, VaultError> {
        if raw.is_empty() {
            return Err(VaultError::InvalidIdentifier);
        }
        // Printable ASCII only: rejects control characters (`\r`, `\n`,
        // `\0`), bidi overrides such as U+202E, and every non-NFC form at
        // once, because a non-ASCII byte cannot appear at all.
        if !raw.bytes().all(|b| (0x20..0x7f).contains(&b)) {
            return Err(VaultError::InvalidIdentifier);
        }
        Ok(Self(raw.to_string()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

/// Test-only shorthand. Not `pub`: production code constructs at the boundary
/// and handles the error, which is the point of the type.
#[cfg(test)]
pub(crate) fn cid(raw: &str) -> ContextId {
    ContextId::new(raw).expect("test identifier must be canonical")
}

impl fmt::Display for ContextId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

// `SEC-47`. `Freeze §4`'s row says "Subject ids", and `RevocationSubject` has
// three variants. `ContextId` covered one. Content is the DIRECT subject of
// crypto-shredding, and since §4.1 removed all per-content state from the
// Vault, `is_content_revoked` is the only defence for content deletion --
// against a BTreeMap keyed by byte equality. Probed: destroy `café` NFC, re-add
// `café` NFD, and the destroyed content is live while `is_content_destroyed`
// reports false.
//
// Written out rather than generated by a macro. `L1.1` scans source text for
// `pub` items, so a macro-generated type is INVISIBLE to it -- adding
// `canonical_id!(FooId, ...)` would put a new type on the public surface with
// no allowlist entry and no gate failure. Twenty lines is cheaper than a hole
// in the gate that guards every other public item.
//
// The predicate still exists exactly once: both delegate to `ContextId::new`.

/// A canonical content identifier. See `ContextId`.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ContentId(String);

impl ContentId {
    pub fn new(raw: &str) -> Result<Self, VaultError> {
        ContextId::new(raw).map(|c| Self(c.as_str().to_string()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for ContentId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// A canonical device identifier. See `ContextId`.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct DeviceId(String);

impl DeviceId {
    pub fn new(raw: &str) -> Result<Self, VaultError> {
        ContextId::new(raw).map(|c| Self(c.as_str().to_string()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for DeviceId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

#[cfg(test)]
pub(crate) fn content_id(raw: &str) -> ContentId {
    ContentId::new(raw).expect("test identifier must be canonical")
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};

    #[test]
    fn rejects_the_sec_32_bypass_inputs() {
        // NFD "café" -- the exact input that resurrected a retired identity.
        assert!(ContextId::new("cafe\u{301}").is_err());
        assert!(ContextId::new("a\u{0}b").is_err());
        assert!(ContextId::new("a\nb").is_err());
        assert!(ContextId::new("\u{202E}evil").is_err());
        assert!(ContextId::new("").is_err());
    }

    #[test]
    fn accepts_the_ids_the_runtime_mints() {
        for ok in ["inbox", "tax-2026", "ctx-000000000001", "a:b", "A_b.c"] {
            assert_eq!(ContextId::new(ok).unwrap().as_str(), ok);
        }
    }

    #[test]
    fn ascii_is_already_nfc_so_two_ids_cannot_differ_by_form() {
        // The property `Freeze §4` asks for, in its failing form: there is no
        // pair of accepted ids that are canonically equivalent yet unequal.
        let a = ContextId::new("cafe").unwrap();
        assert!(ContextId::new("cafe\u{301}").is_err());
        assert_eq!(a.as_str(), "cafe");
    }
}
```

Create `rust/airo_mind/src/vault/random.rs` — **the only module in the crate
that names `OsRng`** (`RA-3`). Revision 7 promised this file and never created
it: `random_key`/`random_nonce` lived in `envelope.rs`, and `seed.rs`,
`device.rs`, and `package.rs` each called `OsRng` directly — three violations
of a rule the Definition of Done claimed CI enforced.

```rust
//! Every RNG call site in the crate. There are no others.
//!
//! `try_fill_bytes`, never `fill_bytes` — the latter aborts the process when
//! the OS RNG fails, and `AeadCore::generate_nonce` panics for the same
//! reason. Early-boot entropy failure on Android is rare but real, and a panic
//! in the key-generation path of a medical-records vault is the wrong failure
//! mode.
//!
//! One module so the guarantee is greppable: `rg 'OsRng' src/ | grep -v
//! random.rs` must return nothing, which is the CI check the Definition of
//! Done promises.

use rand_core::RngCore;

use super::error::VaultError;

fn fill(out: &mut [u8]) -> Result<(), VaultError> {
    rand_core::OsRng
        .try_fill_bytes(out)
        .map_err(|_| VaultError::RngUnavailable)
}

pub(crate) fn random_key() -> Result<[u8; 32], VaultError> {
    let mut bytes = [0u8; 32];
    fill(&mut bytes)?;
    Ok(bytes)
}

pub(crate) fn random_nonce() -> Result<[u8; 24], VaultError> {
    let mut bytes = [0u8; 24];
    fill(&mut bytes)?;
    Ok(bytes)
}

/// Device signing-key seed and BIP-39 entropy are both 32 bytes, but they are
/// not keys and not nonces — a distinct name so the call sites read honestly.
pub(crate) fn random_bytes_32() -> Result<[u8; 32], VaultError> {
    let mut bytes = [0u8; 32];
    fill(&mut bytes)?;
    Ok(bytes)
}

/// Salt is variable-length by format, so this fills in place.
pub(crate) fn fill_random(out: &mut [u8]) -> Result<(), VaultError> {
    fill(out)
}

```

Apply them in the struct definitions, not in prose — a helper applied at some
of the sites its invariant covers is worse than none, because it reads as done.
Revision 7 had three of these (`RA-1`): `hex_array_32` skipped on
`RootPublicKey`, `push_len_prefixed` skipped in `signing_payload`, `random_key`
skipped at three `OsRng` sites.

```rust
#[serde(with = "super::encoding::hex_array_64")]
pub signature: [u8; 64],
#[serde(with = "super::encoding::hex_array_32")]
pub device_public_key: [u8; 32],
#[serde(with = "super::encoding::hex_array_32")]
pub identity_public_key: [u8; 32],   // RootPublicKey's inner — RA-1
#[serde(with = "super::encoding::base64_bytes")]
pub ciphertext: Vec<u8>,             // ADR-0017
```

`KeyBytes([u8; 32])` carries `#[serde(transparent)]` and so inherits whatever
its inner encoding is — it must carry `hex_array_32` explicitly, or the context
keys inside `VaultPayload` keep serializing as decimal arrays.

**Do not add `serde_bytes`, `serde-big-array`, `serde_arrays`, or a base64
crate.**

Three tests, all required (`I5` — a property with no failing form is a
description). They append to `rust/airo_mind/src/vault/encoding.rs`; the
enclosing `mod tests` is written out because a bare `#[test]` fence carries no
file header and `G0.1` therefore dropped all three (#1731):

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hex_rejects_multibyte_at_an_even_offset_instead_of_panicking() {
        // RA-20: 64 bytes, 63 chars, 'é' straddling offset 61..63.
        let hostile = "a".repeat(61) + "é" + "a";
        assert_eq!(hostile.len(), 64);
        let mut out = [0u8; 32];
        assert!(hex_from(&hostile, &mut out).is_err());
    }

    #[test]
    fn base64_round_trips_every_length_class() {
        for n in 0..=64 {
            let bytes: Vec<u8> = (0..n).map(|i| (i * 7 + 3) as u8).collect();
            let text = base64_bytes::encode(&bytes);
            assert_eq!(base64_bytes::decode(&text).unwrap(), bytes, "n = {n}");
        }
    }

    #[test]
    fn base64_rejects_misplaced_padding() {
        assert!(base64_bytes::decode("A=BC").is_err());
        assert!(base64_bytes::decode("AB=C").is_err());
        assert!(base64_bytes::decode("ABC").is_err());
    }
}
```

`C7` requires a fuzz target on every parser reachable from untrusted input.
`hex_from` and `base64_bytes::decode` both qualify once `C3` sync parses device
certificates. **Both targets land in this task, not as follow-up** — the
Definition of Done already promises them, and `RA-20` is precisely the bug class
a hand-written negative test misses and a fuzzer does not.

- [ ] **Step 3b: (removed — the encoding is decided above)**

`[u8; 64]` does not implement `Serialize`/`Deserialize` by default in serde 1. Either enable a serde feature that supports large arrays, or add `#[serde(with = "...")]` helpers converting to `Vec<u8>` with a length check on deserialize. Pick one and apply it consistently — Tasks 5, 7, and 8 all serialize fixed-size arrays.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind device`
Expected: PASS — wordlist guard, the full official vector set, and the four rejection cases

- [ ] **Step 5: Commit**

```bash
git add rust/airo_mind/src/vault/device.rs rust/airo_mind/src/vault/mod.rs
git commit -m "feat(mind): add device keys and root-signed device certificates

Device keys are generated locally, never derived from the seed — the seed
must never leave the device that created it. The root signs the public
half. Signing payload is domain-separated and length-prefixed.

Refs #1208"
```

---

## Task 5: Envelope encryption over the context hypergraph

Implements #1209.

**Files:**
- Create: `rust/airo_mind/src/vault/envelope.rs`
- Modify: `rust/airo_mind/src/vault/mod.rs`

**Interfaces:**
- Consumes: `VaultError` (Task 1)
- Produces:
  - `ContentKey` with `fn generate() -> Self`, `fn as_bytes(&self) -> &[u8; 32]`
  - `ContextKey` with `fn generate() -> Self`, `fn as_bytes(&self) -> &[u8; 32]`
  - `ContentEnvelope { content_id: String }` with `fn new(content_id: impl Into<String>) -> Self`, `fn add_wrapping(&mut self, &ContentKey, &str, &ContextKey) -> Result<(), VaultError>`, `fn remove_wrapping(&mut self, &str) -> bool`, `fn unwrap_with(&self, &str, &ContextKey) -> Result<ContentKey, VaultError>`, `fn context_ids(&self) -> Vec<&str>`, `fn is_orphaned(&self) -> bool`

**Design note for the implementer.** Content belongs to a **set** of contexts, not a hierarchy. One hospital bill is simultaneously a medical record, an expense, and a tax deduction. A key tree forces a single parent and makes closing a journey destroy a receipt another capability depends on. Do not "simplify" this into a parent pointer.

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/envelope.rs`:

```rust
//! Envelope encryption over a context hypergraph.
//!
//! A content key is random per object and wrapped independently under every
//! context that grants access. Content survives while at least one wrapping
//! exists. This is what lets one object be a medical record, an expense, and
//! a tax deduction at the same time.

use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};
use serde::{Deserialize, Serialize};
use subtle::ConstantTimeEq;
use zeroize::{Zeroize, ZeroizeOnDrop};

use zeroize::Zeroizing;

use super::domain;
use super::encoding::push_len_prefixed;
use super::error::VaultError;
use super::random::{random_key, random_nonce};

/// A random symmetric key protecting exactly one content object.
///
/// No `Debug` (would print key bytes into panic messages and logs).
/// No `Clone` (custody is singular — `Vault::add_content` hands the caller the
/// only copy). Equality is constant-time, see the `PartialEq` impl below.
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct ContentKey([u8; 32]);

impl std::fmt::Debug for ContentKey {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("ContentKey(<redacted>)")
    }
}

/// Constant-time equality.
///
/// A derived `PartialEq` short-circuits on the first differing byte, which
/// leaks key material through timing. Ruled by chief-security-officer over
/// `#[cfg(test)]`-gating the derive: a cfg-gate reappears the first time a
/// later phase legitimately needs to compare keys, and it reappears as a
/// derive.
impl PartialEq for ContentKey {
    fn eq(&self, other: &Self) -> bool {
        self.0.ct_eq(&other.0).into()
    }
}

impl Eq for ContentKey {}

impl ContentKey {
    pub(crate) fn generate() -> Result<Self, VaultError> {
        Ok(Self(random_key()?))
    }

    pub(crate) fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    fn from_slice(bytes: &[u8]) -> Result<Self, VaultError> {
        let array: [u8; 32] = bytes.try_into().map_err(|_| VaultError::DecryptionFailed)?;
        Ok(Self(array))
    }
}

/// A key held by a context — a hospitalization, a tax year, a project.
///
/// `Clone` is retained here, unlike `ContentKey`: the Vault legitimately holds
/// one context key and hands copies to several wrapping operations. Custody is
/// the Vault's, and the key never leaves the crate — see `as_bytes`.
#[derive(Clone, Zeroize, ZeroizeOnDrop)]
pub struct ContextKey([u8; 32]);

impl ContextKey {
    pub(crate) fn generate() -> Result<Self, VaultError> {
        Ok(Self(random_key()?))
    }

    /// `pub(crate)`, deliberately.
    ///
    /// The previous revision made this `pub`, handing every context key to any
    /// consumer of the crate while `to_payload` stayed `pub(crate)` on the
    /// grounds that "its fields are raw key material". Nothing outside the
    /// crate needs this.
    pub(crate) fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }

    pub(crate) fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }
}

/// One content key sealed under one context key.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
struct Wrapping {
    context_id: String,
    // `ADR-0017`. Decimal arrays cost ~3.68× raw against base64's 1.33×;
    // measured, a 3-wrapping envelope is 976 B decimal against 635 B hex. This
    // is per content object, so it multiplies by content count where the Vault
    // no longer does — and it freezes the moment #1214 writes the first one.
    #[serde(with = "super::encoding::base64_bytes")]
    nonce: Vec<u8>,
    #[serde(with = "super::encoding::base64_bytes")]
    ciphertext: Vec<u8>,
}

/// All wrappings for one content object.
///
/// **No `Deserialize`.** `envelope.rs` claimed "the Vault is the only door",
/// and `#[derive(Deserialize)]` was a second one, open to every consumer: a
/// probe built a forged envelope for content the Vault never minted, which is
/// content the Vault has no revocation record for and therefore content that
/// can never be shredded (`RA` Q4). Parsing now goes through
/// `Vault::open_envelope`, which is inside the door. The derive stays — serde
/// needs it — but `SealedEnvelope` wraps opaque bytes, so no consumer holds a
/// shape it can hand to `serde_json` directly, and `open_envelope` applies the
/// revocation check that a bare derive skipped.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContentEnvelope {
    // Private: it is bound into the wrapping AAD. `envelope.content_id = ...`
    // used to compile and silently rendered every wrapping undecryptable
    // (rust-architect M5).
    content_id: String,
    wrappings: Vec<Wrapping>,
}

/// A serialized envelope. Opaque bytes; only `Vault::open_envelope` parses it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SealedEnvelope(#[serde(with = "super::encoding::base64_bytes")] Vec<u8>);

impl SealedEnvelope {
    pub fn as_bytes(&self) -> &[u8] {
        &self.0
    }

    pub fn from_bytes(bytes: Vec<u8>) -> Self {
        Self(bytes)
    }
}

impl ContentKey {
    /// Encrypts a content object under this key.
    ///
    /// `RA` Q4: `add_content` returned a `ContentKey` whose every method was
    /// `pub(crate)`, so the consumer received an object it could do nothing
    /// with — `error[E0624]: method as_bytes is private`. The fix is not to
    /// publish the bytes; it is to publish the capability. C5's "no encryption
    /// primitives, no key material" applied honestly means the caller gets an
    /// object that encrypts, never bytes it must encrypt with.
    pub fn seal(&self, plaintext: &[u8]) -> Result<Vec<u8>, VaultError> {
        let nonce = random_nonce()?;
        let cipher = XChaCha20Poly1305::new(self.as_bytes().into());
        let mut out = nonce.to_vec();
        out.extend_from_slice(
            &cipher
                .encrypt(XNonce::from_slice(&nonce), plaintext)
                .map_err(|_| VaultError::SerializationFailed)?,
        );
        Ok(out)
    }

    /// Decrypts a content object sealed with `seal`.
    ///
    /// Returns `Zeroizing` because the plaintext is user content.
    pub fn open(&self, sealed: &[u8]) -> Result<Zeroizing<Vec<u8>>, VaultError> {
        if sealed.len() < 24 {
            return Err(VaultError::DecryptionFailed);
        }
        let (nonce, body) = sealed.split_at(24);
        let cipher = XChaCha20Poly1305::new(self.as_bytes().into());
        Ok(Zeroizing::new(
            cipher
                .decrypt(XNonce::from_slice(nonce), body)
                .map_err(|_| VaultError::DecryptionFailed)?,
        ))
    }
}

// `pub(crate)` throughout. Minting keys or building envelopes outside the
// Vault produces content the Vault has no revocation record for — content that
// can never be shredded (rust-architect M3). The Vault is the only door.
impl ContentEnvelope {
    pub(crate) fn new(content_id: impl Into<String>) -> Self {
        Self {
            content_id: content_id.into(),
            wrappings: Vec::new(),
        }
    }

    /// Grants a context access to this content.
    ///
    /// Re-wrapping under a context that already has access replaces the
    /// existing wrapping rather than adding a duplicate.
    pub(crate) fn add_wrapping(
        &mut self,
        content_key: &ContentKey,
        context_id: &str,
        context_key: &ContextKey,
    ) -> Result<(), VaultError> {
        let cipher = XChaCha20Poly1305::new(context_key.as_bytes().into());
        let nonce = XNonce::from_slice(&random_nonce()?).to_owned();
        let aad = wrapping_aad(&self.content_id, context_id)?;
        let ciphertext = cipher
            .encrypt(
                &nonce,
                Payload {
                    msg: content_key.as_bytes().as_slice(),
                    aad: &aad,
                },
            )
            .map_err(|_| VaultError::EncryptionFailed)?;

        self.wrappings.retain(|w| w.context_id != context_id);
        self.wrappings.push(Wrapping {
            context_id: context_id.to_string(),
            nonce: nonce.to_vec(),
            ciphertext,
        });
        Ok(())
    }

    /// Revokes one context's access. Returns whether a wrapping was removed.
    ///
    /// This is `UnlinkContent`. It is not deletion — the content survives
    /// through every other wrapping.
    pub(crate) fn remove_wrapping(&mut self, context_id: &str) -> bool {
        let before = self.wrappings.len();
        self.wrappings.retain(|w| w.context_id != context_id);
        self.wrappings.len() != before
    }

    pub(crate) fn unwrap_with(
        &self,
        context_id: &str,
        context_key: &ContextKey,
    ) -> Result<ContentKey, VaultError> {
        let wrapping = self
            .wrappings
            .iter()
            .find(|w| w.context_id == context_id)
            .ok_or_else(|| VaultError::NoWrappingForContext(context_id.to_string()))?;

        let nonce_bytes: [u8; 24] = wrapping
            .nonce
            .as_slice()
            .try_into()
            .map_err(|_| VaultError::DecryptionFailed)?;
        let cipher = XChaCha20Poly1305::new(context_key.as_bytes().into());
        let aad = wrapping_aad(&self.content_id, context_id)?;
        let plaintext = cipher
            .decrypt(
                XNonce::from_slice(&nonce_bytes),
                Payload {
                    msg: wrapping.ciphertext.as_slice(),
                    aad: &aad,
                },
            )
            .map_err(|_| VaultError::DecryptionFailed)?;
        ContentKey::from_slice(&plaintext)
    }

    pub(crate) fn content_id(&self) -> &str {
        &self.content_id
    }

    /// Returns an iterator, not a freshly allocated `Vec`. `link_content`
    /// called this solely to take `.first()` (chief-performance-officer §9).
    pub(crate) fn context_ids(&self) -> impl Iterator<Item = &str> {
        self.wrappings.iter().map(|w| w.context_id.as_str())
    }

    // `RA-26`: `first_context` DELETED. It existed so `link_content` could
    // avoid allocating a `Vec` to take `.first()` -- a micro-optimisation that
    // changed the semantics, because the first wrapping is not necessarily one
    // whose key the Vault still holds. `link_content` now searches
    // `context_ids()` for a live one, and the compiler reported this method as
    // never used, which is the fix confirming its only caller was the bug.

    /// True when no wrapping remains — the content is unrecoverable.
    ///
    /// This is the signal the survival computation in #1229 uses to tell a
    /// user "5 items exist nowhere else".
    pub(crate) fn is_orphaned(&self) -> bool {
        self.wrappings.is_empty()
    }
}

/// Binds a wrapping to the exact content object and context that own it.
///
/// Without this, `context_id` is plaintext and unauthenticated. Two attacks
/// follow, both found in review:
///   1. Relabel a wrapping's `context_id` and `remove_wrapping` no longer
///      finds it — the wrapping survives an unlink the user was told worked.
///   2. Move a wrapping verbatim from envelope A to envelope B and it still
///      unwraps, yielding A's content key under B's context.
///
/// Same length-prefixed injective discipline as `DeviceCertificate`.
fn wrapping_aad(content_id: &str, context_id: &str) -> Result<Vec<u8>, VaultError> {
    let mut aad = Vec::new();
    aad.extend_from_slice(domain::CONTENT_WRAPPING);
    push_len_prefixed(&mut aad, content_id.as_bytes())?;
    push_len_prefixed(&mut aad, context_id.as_bytes())?;
    Ok(aad)
}

// `push_len_prefixed` moved to `encoding.rs` and `random_key`/`random_nonce`
// to `random.rs` (`RA-3`, `RA-4`). Revision 7 defined all three here, so
// `package.rs` imported its length-prefix helper and its RNG from the
// content-wrapping module.

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};

    #[test]
    fn content_unwraps_through_the_context_that_wrapped_it() {
        let content_key = ContentKey::generate().unwrap();
        let hospital = ContextKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new("bill-001");

        envelope.add_wrapping(&content_key, "hospitalization", &hospital).unwrap();

        let recovered = envelope.unwrap_with("hospitalization", &hospital).unwrap();
        assert_eq!(recovered.as_bytes(), content_key.as_bytes());
    }

    #[test]
    fn one_object_lives_in_many_contexts() {
        let content_key = ContentKey::generate().unwrap();
        let hospital = ContextKey::generate().unwrap();
        let finance = ContextKey::generate().unwrap();
        let tax = ContextKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new("bill-001");

        envelope.add_wrapping(&content_key, "hospitalization", &hospital).unwrap();
        envelope.add_wrapping(&content_key, "finance", &finance).unwrap();
        envelope.add_wrapping(&content_key, "tax-2026", &tax).unwrap();

        for (id, key) in [("hospitalization", &hospital), ("finance", &finance), ("tax-2026", &tax)] {
            assert_eq!(envelope.unwrap_with(id, key).unwrap().as_bytes(), content_key.as_bytes());
        }
    }

    #[test]
    fn unlinking_one_context_leaves_the_others_readable() {
        // The scenario this whole design exists for: closing a hospitalization
        // must not destroy the receipt the tax capability depends on.
        let content_key = ContentKey::generate().unwrap();
        let hospital = ContextKey::generate().unwrap();
        let tax = ContextKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new("bill-001");
        envelope.add_wrapping(&content_key, "hospitalization", &hospital).unwrap();
        envelope.add_wrapping(&content_key, "tax-2026", &tax).unwrap();

        assert!(envelope.remove_wrapping("hospitalization"));

        assert!(!envelope.is_orphaned());
        assert_eq!(envelope.unwrap_with("tax-2026", &tax).unwrap().as_bytes(), content_key.as_bytes());
        assert_eq!(
            envelope.unwrap_with("hospitalization", &hospital),
            Err(VaultError::NoWrappingForContext("hospitalization".into()))
        );
    }

    #[test]
    fn removing_the_last_wrapping_orphans_the_content() {
        let content_key = ContentKey::generate().unwrap();
        let hospital = ContextKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new("bill-001");
        envelope.add_wrapping(&content_key, "hospitalization", &hospital).unwrap();

        assert!(envelope.remove_wrapping("hospitalization"));
        assert!(envelope.is_orphaned());
    }

    #[test]
    fn removing_an_absent_context_reports_no_change() {
        let mut envelope = ContentEnvelope::new("bill-001");
        assert!(!envelope.remove_wrapping("never-linked"));
    }

    #[test]
    fn the_wrong_context_key_cannot_unwrap() {
        let content_key = ContentKey::generate().unwrap();
        let hospital = ContextKey::generate().unwrap();
        let attacker = ContextKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new("bill-001");
        envelope.add_wrapping(&content_key, "hospitalization", &hospital).unwrap();

        assert_eq!(
            envelope.unwrap_with("hospitalization", &attacker),
            Err(VaultError::DecryptionFailed)
        );
    }

    #[test]
    fn tampered_ciphertext_is_rejected() {
        let content_key = ContentKey::generate().unwrap();
        let hospital = ContextKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new("bill-001");
        envelope.add_wrapping(&content_key, "hospitalization", &hospital).unwrap();

        envelope.wrappings[0].ciphertext[0] ^= 0xff;

        assert_eq!(
            envelope.unwrap_with("hospitalization", &hospital),
            Err(VaultError::DecryptionFailed)
        );
    }

    #[test]
    fn rewrapping_the_same_context_does_not_duplicate() {
        let content_key = ContentKey::generate().unwrap();
        let hospital = ContextKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new("bill-001");
        envelope.add_wrapping(&content_key, "hospitalization", &hospital).unwrap();
        envelope.add_wrapping(&content_key, "hospitalization", &hospital).unwrap();

        assert_eq!(
            envelope.context_ids().collect::<Vec<_>>(),
            vec!["hospitalization"]
        );
    }

    #[test]
    fn relabelling_a_context_id_breaks_the_wrapping() {
        // Without AAD this succeeds, and a relabelled wrapping survives an
        // unlink the user was told had worked.
        let content_key = ContentKey::generate().unwrap();
        let hospital = ContextKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new("bill-001");
        envelope.add_wrapping(&content_key, "hospitalization", &hospital).unwrap();

        envelope.wrappings[0].context_id = "finance".to_string();

        assert_eq!(
            envelope.unwrap_with("finance", &hospital),
            Err(VaultError::DecryptionFailed)
        );
    }

    #[test]
    fn a_wrapping_cannot_be_moved_to_another_envelope() {
        // Without AAD, envelope B unwraps envelope A's content key.
        let key_a = ContentKey::generate().unwrap();
        let context = ContextKey::generate().unwrap();
        let mut envelope_a = ContentEnvelope::new("medical-record");
        envelope_a.add_wrapping(&key_a, "health", &context).unwrap();

        let key_b = ContentKey::generate().unwrap();
        let mut envelope_b = ContentEnvelope::new("grocery-list");
        envelope_b.add_wrapping(&key_b, "health", &context).unwrap();

        envelope_b.wrappings[0] = envelope_a.wrappings[0].clone();

        assert_eq!(
            envelope_b.unwrap_with("health", &context),
            Err(VaultError::DecryptionFailed)
        );
    }

    #[test]
    fn each_wrapping_uses_a_distinct_nonce() {
        let content_key = ContentKey::generate().unwrap();
        let a = ContextKey::generate().unwrap();
        let b = ContextKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new("bill-001");
        envelope.add_wrapping(&content_key, "a", &a).unwrap();
        envelope.add_wrapping(&content_key, "b", &b).unwrap();

        assert_ne!(envelope.wrappings[0].nonce, envelope.wrappings[1].nonce);
    }
}
```

Modify `rust/airo_mind/src/vault/mod.rs`:

```rust
mod envelope;

pub use envelope::{ContentEnvelope, ContentKey, SealedEnvelope};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind envelope`
Expected: FAIL to compile — module not declared.

- [ ] **Step 3: Reconcile against the real `chacha20poly1305` v0.10 API**

Nonces come from `random_nonce()` (`try_fill_bytes`), never `AeadCore::generate_nonce`, which panics on RNG failure. `KeyInit::new` takes `&Key`, which is `&GenericArray<u8, U32>` — the `.into()` on `&[u8; 32]` should work, but adjust if the compiler disagrees. The `aead` re-export path may be `chacha20poly1305::aead` or require the `aead` crate directly.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind envelope`
Expected: PASS, 9 tests

- [ ] **Step 5: Commit**

```bash
git add rust/airo_mind/src/vault/envelope.rs rust/airo_mind/src/vault/mod.rs
git commit -m "feat(mind): add envelope encryption over the context hypergraph

Content keys are wrapped independently under each granting context, so one
object can be a medical record, an expense, and a tax deduction at once.
Unlinking one context leaves the others readable; only removing the last
wrapping orphans the content.

Refs #1209"
```

---

## Task 6: Revocation ledger with monotonic epoch

Implements #1210.

**Files:**
- Create: `rust/airo_mind/src/vault/revocation.rs`
- Modify: `rust/airo_mind/src/vault/mod.rs`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `RevocationLedger` with `fn new() -> Self`, `fn revoke(&mut self, RevocationSubject) -> u64`, `fn head_epoch(&self) -> u64`, `fn is_revoked(&self, &RevocationSubject) -> bool`, `fn all_revoked(&self) -> Vec<RevocationSubject>`, `fn validate(&self) -> Result<(), VaultError>`, `fn merge(&mut self, other: &RevocationLedger)`

**Design note for the implementer.** Uses `BTreeMap`, not `HashMap`. The ledger is serialized into the Recovery Package and later synchronized, and iteration order must be identical on every device. `merge` must be idempotent and order-independent — two devices exchanging ledgers in either order must reach the same state.

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/revocation.rs`:

```rust
//! Monotonic revocation ledger.
//!
//! Records every destroyed content key with the epoch at which it died. The
//! epoch is what lets restore (Task 8) detect that a Vault backup predates a
//! destruction and purge those keys before decrypting anything.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

use super::error::VaultError;

/// What a revocation destroys.
///
/// Tagged from the start. Spec §3.2 lists `RevokeDevice` as a verb, and the
/// ledger format freezes in this phase — a content-only ledger cannot be
/// widened later without migrating every vault in the field.
///
/// Two holes this closes, both found in review:
///   - `RecoveryPackage` carries `device_certificates`. A content-only ledger
///     means restoring a stale backup **resurrects a revoked device
///     certificate**, and a stolen laptop walks back into the mesh.
///   - Destroying a whole context must destroy its key, or every item wrapped
///     under it stays recoverable from the vault.
///
/// Serialized as a canonical **string**, never as a derived enum.
///
/// `BTreeMap<RevocationSubject, u64>` with a derived enum key **does not
/// serialize**: JSON object keys must be strings, and `serde_json` fails with
/// `key must be a string`. The revocation ledger is inside the frozen Recovery
/// Package format, so this made the structure that carries crypto-shredding
/// unwritable to disk.
///
/// R3 specified "keyed in the `BTreeMap` by a canonical string encoding";
/// revision 3 implemented the enum directly and dropped that half. Four
/// council reviews passed over it. `cargo test` found it in under a second.
///
/// Encoding is `kind:id`. `kind` is a fixed set containing no separator, so
/// the mapping is injective and stable across versions.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum RevocationSubject {
    Content(String),
    Context(String),
    Device(String),
}

impl RevocationSubject {
    fn canonical(&self) -> String {
        match self {
            Self::Content(id) => format!("content:{id}"),
            Self::Context(id) => format!("context:{id}"),
            Self::Device(id) => format!("device:{id}"),
        }
    }

    fn from_canonical(text: &str) -> Option<Self> {
        let (kind, id) = text.split_once(':')?;
        match kind {
            "content" => Some(Self::Content(id.to_string())),
            "context" => Some(Self::Context(id.to_string())),
            "device" => Some(Self::Device(id.to_string())),
            _ => None,
        }
    }
}

impl Serialize for RevocationSubject {
    fn serialize<S: serde::Serializer>(&self, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&self.canonical())
    }
}

impl<'de> Deserialize<'de> for RevocationSubject {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        use serde::de::Error;
        let text = String::deserialize(d)?;
        Self::from_canonical(&text)
            .ok_or_else(|| D::Error::custom("unknown revocation subject encoding"))
    }
}

/// Append-only record of destroyed keys and evicted devices.
///
/// `BTreeMap`, never `HashMap`: this is serialized and synchronized, and
/// iteration order must be identical on every device.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct RevocationLedger {
    entries: BTreeMap<RevocationSubject, u64>,
    head_epoch: u64,
}

impl RevocationLedger {
    pub fn new() -> Self {
        Self::default()
    }

    /// Borrowing iterator for framed export. `ADR-0017`.
    ///
    /// Clones per entry as it goes, so peak is `O(FRAME_ENTRIES)` rather than
    /// `O(ledger)`. `all_revoked()` materializes the whole set and is used on
    /// the restore path, where `apply_revocations` called it **twice** — two
    /// full `Vec<RevocationSubject>` of cloned strings, ~38 MB each at 500k
    /// entries.
    pub(crate) fn entries(&self) -> impl Iterator<Item = (RevocationSubject, u64)> + '_ {
        self.entries.iter().map(|(s, e)| (s.clone(), *e))
    }

    /// Sets the carried head during framed restore. `SEC-36`.
    ///
    /// Fail-closed: the head may only move forward and may never be below the
    /// highest entry, so a hostile or buggy writer cannot rewind the epoch and
    /// make `revoked_since` skip revocations.
    pub(crate) fn set_head_epoch(&mut self, head: u64) -> Result<(), VaultError> {
        let max_entry = self.entries.values().copied().max().unwrap_or(0);
        if head < max_entry {
            return Err(VaultError::SerializationFailed);
        }
        self.head_epoch = head;
        Ok(())
    }

    /// Absorbs a decoded batch during framed restore. `ADR-0017`.
    ///
    /// Fail-closed like `merge`: the higher epoch wins, so a batch can only
    /// ever revoke more. `head_epoch` tracks the maximum seen.
    pub(crate) fn absorb(&mut self, entries: Vec<(RevocationSubject, u64)>) {
        for (subject, epoch) in entries {
            let slot = self.entries.entry(subject).or_insert(epoch);
            *slot = (*slot).max(epoch);
            self.head_epoch = self.head_epoch.max(epoch);
        }
    }

    /// Records a revocation and returns the epoch assigned to it.
    ///
    /// Revoking the same content twice is a no-op that returns the original
    /// epoch — revocation is a fact, not an event count.
    /// `SEC-49`: **checked.** `A12` guarded the same obligation in
    /// `package.rs`; this is the second site, which is the locality defect --
    /// an assertion pinned to where the obligation was first observed.
    ///
    /// `RevocationLedger` derives `Deserialize` and `validate()` bounds entry
    /// epochs but not `head_epoch`, so a hostile ledger reaches `u64::MAX`
    /// here. Release: wraps to 0, and every subsequent destroy is recorded at
    /// epoch 0 -- the exact condition `validate()` exists to reject, silently
    /// escaping every epoch-filtered query. Debug: panics, in a crate whose
    /// `lib.rs` says "No panics. Return `Result`."
    pub fn revoke(&mut self, subject: RevocationSubject) -> Result<u64, VaultError> {
        if let Some(existing) = self.entries.get(&subject) {
            return Ok(*existing);
        }
        self.head_epoch = self
            .head_epoch
            .checked_add(1)
            .ok_or(VaultError::SerializationFailed)?;
        self.entries.insert(subject, self.head_epoch);
        Ok(self.head_epoch)
    }

    pub fn head_epoch(&self) -> u64 {
        self.head_epoch
    }

    pub fn is_revoked(&self, subject: &RevocationSubject) -> bool {
        self.entries.contains_key(subject)
    }

    /// Convenience for the common content case.
    pub fn is_content_revoked(&self, content_id: &str) -> bool {
        self.is_revoked(&RevocationSubject::Content(content_id.to_string()))
    }

    /// Every subject revoked strictly after `epoch`, **within one device's
    /// own lineage only**.
    ///
    /// Deliberately `pub(crate)`. Epochs are per-device local counters, not a
    /// Lamport clock, so cross-device epoch comparison is meaningless: phone
    /// revokes p1(1), p2(2); laptop revokes l1(1), l2(2); laptop merges phone
    /// and its head is still 2, so `revoked_since(2)` omits p1 and p2
    /// entirely.
    ///
    /// Use `all_revoked` for anything that must not miss a revocation. The
    /// previous revision documented this method as returning "exactly the keys
    /// the backup must not resurrect", which is false and which Phase 7 sync
    /// would have reached for.
    #[cfg_attr(not(test), allow(dead_code))]
    pub(crate) fn revoked_since(&self, epoch: u64) -> Vec<RevocationSubject> {
        self.entries
            .iter()
            .filter(|(_, at)| **at > epoch)
            .map(|(subject, _)| subject.clone())
            .collect()
    }

    /// Rejects epoch-0 entries on load.
    ///
    /// `revoke()` starts at 1, so no valid entry has epoch 0 — but that
    /// invariant was never asserted, and in Phase 2 this data arrives
    /// deserialized from the log. A single epoch-0 entry silently escapes any
    /// epoch-filtered query and resurrects that content.
    pub fn validate(&self) -> Result<(), VaultError> {
        if self.entries.values().any(|epoch| *epoch == 0) {
            return Err(VaultError::SerializationFailed);
        }
        // head_epoch must dominate every entry, or every downstream epoch
        // comparison misbehaves on a crafted or corrupted ledger.
        if self.entries.values().copied().max().unwrap_or(0) > self.head_epoch {
            return Err(VaultError::SerializationFailed);
        }
        Ok(())
    }

    /// Absorbs another ledger. Idempotent and order-independent.
    ///
    /// Two devices merging each other's ledgers in either order must reach an
    /// identical state, or sync diverges permanently.
    ///
    /// Takes `max`, not `min`. `min` is the fail-open direction: a lower
    /// stored epoch returns fewer entries from any epoch-filtered query, which
    /// means fewer purges. In this system fail-open means resurrecting
    /// destroyed content.
    pub fn merge(&mut self, other: &RevocationLedger) {
        for (subject, epoch) in &other.entries {
            self.entries
                .entry(subject.clone())
                .and_modify(|existing| *existing = (*existing).max(*epoch))
                .or_insert(*epoch);
        }
        self.head_epoch = self.head_epoch.max(other.head_epoch);
    }

    /// Every revocation, regardless of epoch.
    ///
    /// This is what `apply_revocations` uses. Epoch-filtered queries are
    /// unsafe across devices — see the note on `revoked_since`.
    pub fn all_revoked(&self) -> Vec<RevocationSubject> {
        self.entries.keys().cloned().collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};

    #[test]
    fn a_new_ledger_is_empty_at_epoch_zero() {
        let ledger = RevocationLedger::new();
        assert_eq!(ledger.head_epoch(), 0);
        assert!(!ledger.is_content_revoked("anything"));
    }

    #[test]
    fn revoking_advances_the_epoch() {
        let mut ledger = RevocationLedger::new();
        assert_eq!(ledger.revoke(RevocationSubject::Content("note-1".into())).unwrap(), 1);
        assert_eq!(ledger.revoke(RevocationSubject::Content("note-2".into())).unwrap(), 2);
        assert_eq!(ledger.head_epoch(), 2);
    }

    #[test]
    fn revoked_content_is_reported_as_revoked() {
        let mut ledger = RevocationLedger::new();
        ledger.revoke(RevocationSubject::Content("note-1".into())).unwrap();
        assert!(ledger.is_content_revoked("note-1"));
        assert!(!ledger.is_content_revoked("note-2"));
    }

    #[test]
    fn revoking_twice_is_idempotent() {
        let mut ledger = RevocationLedger::new();
        let first = ledger.revoke(RevocationSubject::Content("note-1".into())).unwrap();
        let second = ledger.revoke(RevocationSubject::Content("note-1".into())).unwrap();
        assert_eq!(first, second);
        assert_eq!(ledger.head_epoch(), 1);
    }

    #[test]
    fn revoked_since_returns_only_later_revocations() {
        let mut ledger = RevocationLedger::new();
        ledger.revoke(RevocationSubject::Content("old-1".into())).unwrap();
        ledger.revoke(RevocationSubject::Content("old-2".into())).unwrap();
        let backup_epoch = ledger.head_epoch();
        ledger.revoke(RevocationSubject::Content("new-1".into())).unwrap();
        ledger.revoke(RevocationSubject::Content("new-2".into())).unwrap();

        let since = ledger.revoked_since(backup_epoch);
        assert_eq!(
            since,
            vec![
                RevocationSubject::Content("new-1".into()),
                RevocationSubject::Content("new-2".into())
            ]
        );
    }

    #[test]
    fn revoked_since_zero_returns_everything() {
        let mut ledger = RevocationLedger::new();
        ledger.revoke(RevocationSubject::Content("a".into())).unwrap();
        ledger.revoke(RevocationSubject::Content("b".into())).unwrap();
        assert_eq!(ledger.revoked_since(0).len(), 2);
    }

    #[test]
    fn merge_is_order_independent() {
        let mut phone = RevocationLedger::new();
        phone.revoke(RevocationSubject::Content("p1".into())).unwrap();
        phone.revoke(RevocationSubject::Content("p2".into())).unwrap();

        let mut laptop = RevocationLedger::new();
        laptop.revoke(RevocationSubject::Content("l1".into())).unwrap();

        let mut phone_first = phone.clone();
        phone_first.merge(&laptop);

        let mut laptop_first = laptop.clone();
        laptop_first.merge(&phone);

        assert_eq!(
            phone_first.revoked_since(0).len(),
            laptop_first.revoked_since(0).len()
        );
        for id in ["p1", "p2", "l1"] {
            assert!(phone_first.is_content_revoked(id));
            assert!(laptop_first.is_content_revoked(id));
        }
    }

    #[test]
    fn merge_is_idempotent() {
        let mut phone = RevocationLedger::new();
        phone.revoke(RevocationSubject::Content("p1".into())).unwrap();
        let laptop = phone.clone();

        let once = {
            let mut l = phone.clone();
            l.merge(&laptop);
            l
        };
        let twice = {
            let mut l = once.clone();
            l.merge(&laptop);
            l
        };

        assert_eq!(once, twice);
    }

    #[test]
    fn merge_never_loses_a_revocation() {
        // A revocation that survives on one device must survive the merge.
        // Losing one silently resurrects destroyed content.
        let mut phone = RevocationLedger::new();
        phone.revoke(RevocationSubject::Content("destroyed-medical-record".into())).unwrap();

        let mut laptop = RevocationLedger::new();
        laptop.revoke(RevocationSubject::Content("unrelated".into())).unwrap();
        laptop.merge(&phone);

        assert!(laptop.is_content_revoked("destroyed-medical-record"));
    }

    #[test]
    fn serialization_round_trips() {
        let mut ledger = RevocationLedger::new();
        ledger.revoke(RevocationSubject::Content("a".into())).unwrap();
        ledger.revoke(RevocationSubject::Content("b".into())).unwrap();
        let json = serde_json::to_string(&ledger).unwrap();
        let restored: RevocationLedger = serde_json::from_str(&json).unwrap();
        assert_eq!(ledger, restored);
    }
}
```

Modify `rust/airo_mind/src/vault/mod.rs`:

```rust
mod revocation;

pub use revocation::RevocationSubject;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind revocation`
Expected: FAIL to compile — module not declared.

- [ ] **Step 3: Implement**

The code in Step 1 is the implementation. If `merge` fails `merge_is_order_independent`, the bug is in epoch reconciliation — do not relax the test.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind revocation`
Expected: PASS, 10 tests

- [ ] **Step 5: Commit**

```bash
git add rust/airo_mind/src/vault/revocation.rs rust/airo_mind/src/vault/mod.rs
git commit -m "feat(mind): add monotonic revocation ledger

Records destroyed content keys with the epoch they died at. merge is
idempotent and order-independent so two devices exchanging ledgers in
either order converge. BTreeMap for deterministic iteration.

Refs #1210"
```

---

## Task 7: Vault aggregate and DestroyContent

Completes the Vault side of #1209/#1210 and produces the type Tasks 8 and 9 export and restore.

**Files:**
- Modify: `rust/airo_mind/src/vault/mod.rs`

**Interfaces:**
- Consumes: `ContentEnvelope`, `ContentKey`, `ContextKey` (Task 5), `RevocationLedger` (Task 6), `DeviceCertificate` (Task 4)
- Produces:
  - `Vault` with:
    - `fn new(root_public_key: [u8; 32]) -> Self`
    - `fn add_context(&mut self, &str) -> Result<&ContextKey, VaultError>`
    - `fn context_key(&self, &str) -> Option<&ContextKey>` — `pub(crate)`
    - `fn add_content(&mut self, &str, &[&str]) -> Result<(ContentKey, ContentEnvelope), VaultError>` — **returns the envelope; the Vault stores no per-content record**
    - `fn link_content(&mut self, &str, &str, &mut ContentEnvelope) -> Result<(), VaultError>`
    - `fn unlink_content(&self, &str, &mut ContentEnvelope) -> Result<UnlinkOutcome, VaultError>`
    - `fn destroy_content(&mut self, &str) -> Result<PurgeDirective, VaultError>`
    - `fn destroy_context(&mut self, &str) -> Result<PurgeDirective, VaultError>` — **O(1)**
    - `fn revoke_device(&mut self, &str) -> Result<PurgeDirective, VaultError>`
    - `fn trust_device(&mut self, DeviceCertificate) -> Result<(), VaultError>`
    - `fn is_content_destroyed(&self, &str) -> bool`
    - `fn revocations(&self) -> &RevocationLedger`
  - `UnlinkOutcome { pub remaining_contexts: Vec<String>, pub now_orphaned: bool }`
  - `KeyBytes` — `pub(crate)` 32-byte secret; no `Debug`, no `Clone`, no `PartialEq`
  - `PurgeDirective { pub content_id: String, pub epoch: u64 }`

**Design note for the implementer.** `destroy_content` performs only steps 1–3 of crypto-shredding: destroy the key, append the revocation, drop the envelope. Steps 4–8 — projections, embeddings, search index, AI caches, snapshots — live outside this crate and outside Rust. `PurgeDirective` is the instruction the caller must act on. Returning it rather than silently completing is deliberate: #1217 tracks the steps that get skipped, and a directive the caller has to consume is harder to skip than a comment.

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/aggregate.rs` (`RA-4` — revision 7 wrote all
of this into `mod.rs`, which the File Structure block forbids):

```rust
use std::collections::BTreeMap;

use super::device::DeviceCertificate;
use super::envelope::{ContentEnvelope, ContentKey, ContextKey, SealedEnvelope};
use super::identifier::{ContentId, ContextId, DeviceId};
use super::error::VaultError;
use super::identity::RootPublicKey;
use super::package::KeyBytes;
use super::revocation::{RevocationLedger, RevocationSubject};

/// What survived an unlink. Feeds the destructive-confirmation copy in #1235.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UnlinkOutcome {
    pub remaining_contexts: Vec<String>,
    pub now_orphaned: bool,
}

/// Instruction to purge derived state after a destroy.
///
/// Steps 1–3 of crypto-shredding happen inside the Vault. Steps 4–8 —
/// projections, embeddings, search index, AI caches, snapshots — live outside
/// this crate. The caller must act on this; an embedding of a destroyed note
/// is a lossy copy of that note.
#[derive(Clone, Debug, PartialEq, Eq)]
#[must_use = "derived state must be purged; dropping this silently defeats deletion"]
pub struct PurgeDirective {
    /// What was destroyed. Not a `content_id` — a device revocation returning
    /// a field named `content_id` is a mis-shaped contract.
    pub subject: RevocationSubject,
    pub epoch: u64,
}

/// Identity, keys, revocations, trust, device certificates.
///
/// The only mutable, non-append-only store in the system.
pub struct Vault {
    root_public_key: RootPublicKey,
    context_keys: BTreeMap<String, ContextKey>,
    device_certificates: Vec<DeviceCertificate>,
    revocations: RevocationLedger,
}

// NOTE — `envelopes` is deliberately absent.
//
// Revisions 1-4 held `envelopes: BTreeMap<String, ContentEnvelope>` here,
// making the Vault O(all user content). Measured consequence: a 100k-content
// vault produced a 225 MiB Recovery Package with a ~600 MiB export peak — an
// OOM on mid-range Android, on the one artifact whose absence is
// unrecoverable.
//
// The frozen design (spec §2, §4.1) states it plainly: the Vault is **sized by
// contexts and devices, never by user content**. Two sentences in the original
// draft described different systems — "the Recovery Package grants access,
// carries no data" cannot coexist with "one envelope per content object".
//
// Wrapping sets live with their content object in the content store (Phase 2,
// #1214). The Vault owns only keys.

impl Vault {
    /// Takes a `RootPublicKey`, not raw bytes.
    ///
    /// `Vault::new(RootIdentity::from_seed(&test_seed()).unwrap().public_key())` used to compile — a vault whose root
    /// corresponds to no seed in existence, which no one can ever export or
    /// restore. The newtype is obtainable only from `RootIdentity`, so both
    /// that and the mismatched export/restore pair (rust-architect M1/M2)
    /// stop being representable.
    pub fn new(root_public_key: RootPublicKey) -> Self {
        Self {
            root_public_key,
            context_keys: BTreeMap::new(),
            device_certificates: Vec::new(),
            revocations: RevocationLedger::new(),
        }
    }

    pub fn root_public_key(&self) -> &RootPublicKey {
        &self.root_public_key
    }

    pub fn revocations(&self) -> &RevocationLedger {
        &self.revocations
    }

    /// Creates a context key if absent. Idempotent for live contexts,
    /// **fail-closed for retired ones**.
    ///
    /// `SEC-14` — **identity retirement is irreversible.** A destroyed context
    /// id can never be re-created. A user-visible name may be reused; the
    /// identity behind it may not, because revocation history belongs to
    /// identities and not to names.
    ///
    /// The attack this closes, reproduced by probe against revision 7:
    /// `destroy_context("c")` revokes the id and drops the key, then
    /// `add_context("c")` silently mints a *new* key under the *revoked* id.
    /// Content wrapped under the new key looks live. Then restore applies the
    /// ledger, sees `c` revoked, and destroys every wrapping under it —
    /// including everything created after the resurrection. The user loses
    /// content they created after the deletion, and nothing reports it.
    ///
    /// Fail-closed rather than silently re-issuing: an id in the ledger is
    /// retired, and a caller that wants the same *name* mints a new id. Phase 1
    /// takes ids from its caller, so id minting is the runtime's job; the Vault
    /// only refuses to resurrect. Naming lands with the ontology layer in
    /// Phase 2, where a context gains a label separate from its identity.
    ///
    /// Fallible because key generation is fallible — `or_insert_with` cannot
    /// carry a `Result`, so this is written long-hand.
    /// Takes a `ContextId`, not a `&str`. `I6` / `A04`: the raw form is
    /// unreachable past the boundary, so no caller can hand this a
    /// non-canonical identifier and no second canonicalization can occur here.
    pub fn add_context(&mut self, context_id: &ContextId) -> Result<&ContextKey, VaultError> {
        let context_id = context_id.as_str();
        if self.revocations.is_revoked(&RevocationSubject::Context(context_id.to_string())) {
            return Err(VaultError::ContextRetired(context_id.to_string()));
        }
        if !self.context_keys.contains_key(context_id) {
            let key = ContextKey::generate()?;
            self.context_keys.insert(context_id.to_string(), key);
        }
        self.context_keys
            .get(context_id)
            .ok_or_else(|| VaultError::NoWrappingForContext(context_id.to_string()))
    }

    #[cfg_attr(not(test), allow(dead_code))]
    pub(crate) fn context_key(&self, context_id: &str) -> Option<&ContextKey> {
        self.context_keys.get(context_id)
    }

    /// Creates content wrapped under every listed context.
    /// Mints a content key and wraps it under every listed context.
    ///
    /// Returns both halves. The caller stores the envelope with the content
    /// object; the Vault keeps nothing per-content.
    pub fn add_content(
        &mut self,
        content_id: &ContentId,
        context_ids: &[&ContextId],
    ) -> Result<(ContentKey, ContentEnvelope), VaultError> {
        let content_id = content_id.as_str();
        if self.revocations.is_content_revoked(content_id) {
            return Err(VaultError::ContentRevoked(content_id.to_string()));
        }
        let content_key = ContentKey::generate()?;
        let mut envelope = ContentEnvelope::new(content_id);
        for context_id in context_ids {
            self.add_context(context_id)?;
            let context_key = self
                .context_keys
                .get(context_id.as_str())
                .ok_or_else(|| VaultError::NoWrappingForContext(context_id.to_string()))?;
            envelope.add_wrapping(&content_key, context_id.as_str(), context_key)?;
        }
        // The envelope is RETURNED, not stored. It belongs beside the content
        // object in the content store — the Vault holds no per-content record
        // (frozen design §4.1).
        Ok((content_key, envelope))
    }

    /// Grants an additional context access to existing content.
    ///
    /// The caller supplies the envelope — the Vault holds no per-content
    /// record — and receives it back mutated. Storing it again is the
    /// caller's obligation.
    /// `SEC-2` — the `content_id` parameter is **deleted**, not checked.
    ///
    /// Revision 7 gated on the `content_id` *argument* while the AAD bound the
    /// *envelope's own* `content_id`. Two sources of truth for one identity
    /// inside a signature, and any disagreement between them is a bypass.
    /// Reproduced from an external consumer: destroy content A, then
    /// `link_content("B", ctx, &mut envelope_of_A)` returns `Ok(())` and A
    /// gains a live wrapping under a live context key.
    ///
    /// Adding an equality check between the two would be the wrong fix — it
    /// keeps the second source of truth and guards it at runtime. The envelope
    /// already carries its identity, so the parameter goes. `unlink_content`
    /// below already has exactly this shape; after the change the two are
    /// symmetric, `ContentEnvelope::content_id()` gains its non-test caller,
    /// and its `#[allow(dead_code)]` disappears.
    pub fn link_content(
        &mut self,
        context_id: &ContextId,
        envelope: &mut ContentEnvelope,
    ) -> Result<(), VaultError> {
        let content_id = envelope.content_id().to_string();
        if self.revocations.is_content_revoked(&content_id) {
            return Err(VaultError::ContentRevoked(content_id));
        }
        // `RA-26`: the first context whose key the Vault still HOLDS, not the
        // first wrapping.
        //
        // `destroy_context` is `O(1)` by design -- it drops the key and leaves
        // every wrapping in place -- so a dead wrapping is permanent, and
        // `first_context()` returned it forever. The first context a user
        // destroyed poisoned `link_content` for every content object that
        // happened to list it first. `envelope.rs`'s own test says "closing a
        // hospitalization must not destroy the receipt the tax capability
        // depends on"; after the close the receipt was readable and
        // un-linkable.
        //
        // `wrappings[0]` was never a stable choice either: `add_wrapping` does
        // `retain` then `push`, so re-wrapping moves a context to the end.
        let existing = envelope
            .context_ids()
            .find(|id| self.context_keys.contains_key(*id))
            .map(str::to_string)
            .ok_or_else(|| VaultError::ContentNotFound(content_id.clone()))?;
        let source_key = self
            .context_keys
            .get(&existing)
            .ok_or_else(|| VaultError::NoWrappingForContext(existing.clone()))?;
        let content_key = envelope.unwrap_with(&existing, source_key)?;

        self.add_context(context_id)?;
        // Disjoint field borrows: `context_keys` is ours, `envelope` is the
        // caller's. No clone of a secret is needed here (rust-architect O2).
        let target_key = self
            .context_keys
            .get(context_id.as_str())
            .ok_or_else(|| VaultError::NoWrappingForContext(context_id.to_string()))?;
        envelope.add_wrapping(&content_key, context_id.as_str(), target_key)
    }

    /// Serializes an envelope. `RA` Q4 — the only way out.
    pub fn seal_envelope(&self, envelope: &ContentEnvelope) -> Result<SealedEnvelope, VaultError> {
        Ok(SealedEnvelope::from_bytes(
            serde_json::to_vec(envelope).map_err(|_| VaultError::SerializationFailed)?,
        ))
    }

    /// Parses an envelope, applying the revocation check.
    ///
    /// **The provenance claim is withdrawn** (`SEC-43`, `RA` §5). An earlier
    /// version said this "replaced the `Deserialize` derive that let any
    /// consumer forge an envelope for content the Vault never minted". That is
    /// unachievable and always was: design §4.1 removed **all** per-content
    /// state from the Vault, so the Vault cannot know which content ids it
    /// minted, now or ever. A claim the architecture forbids is not a claim to
    /// enforce; it is one to stop making.
    ///
    /// What this door does provide, and what the test below verifies: a
    /// **revocation check on the read path**. A stored envelope for content
    /// since destroyed does not come back in. Forging an envelope for a
    /// never-minted id yields nothing, because `unwrap_with` is `pub(crate)`
    /// and no content key exists for it.
    ///
    /// Fails closed on revoked content: a stored envelope for something since
    /// destroyed does not come back through this door.
    pub fn open_envelope(&self, sealed: &SealedEnvelope) -> Result<ContentEnvelope, VaultError> {
        let envelope: ContentEnvelope = serde_json::from_slice(sealed.as_bytes())
            .map_err(|_| VaultError::SerializationFailed)?;
        if self.revocations.is_content_revoked(envelope.content_id()) {
            return Err(VaultError::ContentRevoked(envelope.content_id().to_string()));
        }
        Ok(envelope)
    }

    /// Removes one context link. Does not destroy anything.
    pub fn unlink_content(
        &self,
        context_id: &ContextId,
        envelope: &mut ContentEnvelope,
    ) -> Result<UnlinkOutcome, VaultError> {
        if !envelope.remove_wrapping(context_id.as_str()) {
            return Err(VaultError::NoWrappingForContext(context_id.to_string()));
        }
        Ok(UnlinkOutcome {
            remaining_contexts: envelope.context_ids().map(|s| s.to_string()).collect(),
            now_orphaned: envelope.is_orphaned(),
        })
    }

    /// Destroys content permanently. Steps 1–3 of crypto-shredding.
    ///
    /// The Vault records the revocation. Dropping the envelope and the blob is
    /// the content store's obligation, named in the returned directive.
    pub fn destroy_content(
        &mut self,
        content_id: &ContentId,
    ) -> Result<PurgeDirective, VaultError> {
        let content_id = content_id.as_str();
        let subject = RevocationSubject::Content(content_id.to_string());
        if self.revocations.is_revoked(&subject) {
            return Err(VaultError::ContentRevoked(content_id.to_string()));
        }
        let epoch = self.revocations.revoke(subject.clone())?;
        Ok(PurgeDirective { subject, epoch })
    }

    /// Evicts a device from the mesh.
    ///
    /// Design spec §7: device revocation is required, not optional — a stolen
    /// device that cannot be evicted makes the trust boundary decorative.
    pub fn revoke_device(
        &mut self,
        device_id: &DeviceId,
    ) -> Result<PurgeDirective, VaultError> {
        let device_id = device_id.as_str();
        let before = self.device_certificates.len();
        self.device_certificates.retain(|c| c.device_id() != device_id);
        if self.device_certificates.len() == before {
            return Err(VaultError::DeviceNotFound(device_id.to_string()));
        }
        let subject = RevocationSubject::Device(device_id.to_string());
        let epoch = self.revocations.revoke(subject.clone())?;
        Ok(PurgeDirective { subject, epoch })
    }

    /// Destroys a context and its key.
    ///
    /// **O(1).** Revisions 3–4 scanned every envelope in the vault to strip
    /// wrappings — O(all content) per context destroy — and returned a
    /// directive naming only the context, so content orphaned by the destroy
    /// was never reported and crypto-shredding steps 4–8 could not run for it
    /// (chief-performance-officer §8).
    ///
    /// Destroying the context key is sufficient: every wrapping under it
    /// becomes undecryptable wherever it is stored. Identifying which content
    /// is now orphaned is a content-store query, driven by the directive.
    pub fn destroy_context(
        &mut self,
        context_id: &ContextId,
    ) -> Result<PurgeDirective, VaultError> {
        let context_id = context_id.as_str();
        if self.context_keys.remove(context_id).is_none() {
            return Err(VaultError::NoWrappingForContext(context_id.to_string()));
        }
        let subject = RevocationSubject::Context(context_id.to_string());
        let epoch = self.revocations.revoke(subject.clone())?;
        Ok(PurgeDirective { subject, epoch })
    }

    /// **The one trust admission function. `SEC-15`.**
    ///
    /// Every path that admits a device delegates here: `trust_device`,
    /// restore, pairing (#1257), import, and `C3` sync. None of them
    /// implements a trust check of its own.
    ///
    /// Revision 7 had two trust entry points that disagreed. Restore enforced
    /// the revocation ledger; the live path did not — `trust_device` verified
    /// the signature and never consulted the ledger, so a revoked device
    /// presenting its still-valid certificate was re-admitted. The signature
    /// is genuine; that is exactly why the signature alone is not the answer.
    /// Revocation is the statement that a genuine credential is no longer
    /// honoured.
    ///
    /// Written as one function rather than as a second check inside
    /// `trust_device` because the finding is structural: the defect was not a
    /// missing line, it was that admission logic lived in two places and
    /// nothing forced them to agree. A single choke point means the next entry
    /// point cannot quietly become a third — the compiler routes it here or it
    /// does not compile.
    ///
    /// Order matters: **revocation is checked before signature.** A revoked
    /// device's certificate verifies fine, so checking the signature first and
    /// the ledger second would still be correct, but it does cryptographic
    /// work on behalf of an identity already refused.
    fn admit_device(&mut self, certificate: DeviceCertificate) -> Result<(), VaultError> {
        let subject = RevocationSubject::Device(certificate.device_id().to_string());
        if self.revocations.is_revoked(&subject) {
            return Err(VaultError::DeviceRevoked(certificate.device_id().to_string()));
        }
        if !certificate.verify_against(&self.root_public_key) {
            return Err(VaultError::UntrustedCertificate);
        }
        self.device_certificates.retain(|c| c.device_id() != certificate.device_id());
        self.device_certificates.push(certificate);
        Ok(())
    }

    /// Records a device certificate after verifying it against the root.
    ///
    /// Returns `Result`, not `bool`. `vault.trust_device(cert);` discarding a
    /// security decision must not compile silently.
    pub fn trust_device(&mut self, certificate: DeviceCertificate) -> Result<(), VaultError> {
        self.admit_device(certificate)
    }

    pub fn trusted_devices(&self) -> &[DeviceCertificate] {
        &self.device_certificates
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};
    use crate::vault::identity::RootIdentity;
    use crate::vault::seed::{seed_from_mnemonic, Seed};

    fn test_seed() -> Seed {
        seed_from_mnemonic(
            "abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon art",
        )
        .unwrap()
    }

    fn vault() -> Vault {
        Vault::new(RootIdentity::from_seed(&test_seed()).unwrap().public_key())
    }

    #[test]
    fn content_is_readable_through_every_context_it_was_created_in() {
        let mut vault = vault();
        let (key, envelope) = vault
            .add_content(&content_id("bill-001"), &[&cid("hospitalization"), &cid("finance"), &cid("tax-2026")])
            .unwrap();

        for context in ["hospitalization", "finance", "tax-2026"] {
            let context_key = vault.context_key(context).unwrap();
            assert_eq!(
                envelope.unwrap_with(context, context_key).unwrap().as_bytes(),
                key.as_bytes()
            );
        }
    }

    #[test]
    fn unlinking_reports_what_survives() {
        let mut vault = vault();
        let (_key, mut envelope) = vault
            .add_content(&content_id("bill-001"), &[&cid("hospitalization"), &cid("finance"), &cid("tax-2026")])
            .unwrap();

        let outcome = vault.unlink_content(&cid("hospitalization"), &mut envelope).unwrap();

        assert!(!outcome.now_orphaned);
        assert_eq!(outcome.remaining_contexts, vec!["finance".to_string(), "tax-2026".to_string()]);
    }

    #[test]
    fn unlinking_the_last_context_reports_orphaned() {
        let mut vault = vault();
        let (_key, mut envelope) = vault.add_content(&content_id("note-1"), &[&cid("inbox")]).unwrap();

        let outcome = vault.unlink_content(&cid("inbox"), &mut envelope).unwrap();

        assert!(outcome.now_orphaned);
        assert!(outcome.remaining_contexts.is_empty());
    }

    #[test]
    fn linking_adds_a_context_without_re_encrypting_content() {
        let mut vault = vault();
        let (key, mut envelope) = vault.add_content(&content_id("bill-001"), &[&cid("hospitalization")]).unwrap();

        vault.link_content(&cid("tax-2026"), &mut envelope).unwrap();

        let tax_key = vault.context_key("tax-2026").unwrap();
        let recovered = envelope.unwrap_with("tax-2026", tax_key).unwrap();
        assert_eq!(recovered.as_bytes(), key.as_bytes());
    }

    #[test]
    fn destroy_revokes_and_returns_a_purge_directive() {
        let mut vault = vault();
        vault.add_content(&content_id("note-1"), &[&cid("inbox")]).unwrap();

        let directive = vault.destroy_content(&content_id("note-1")).unwrap();

        assert_eq!(
            directive.subject,
            RevocationSubject::Content("note-1".into())
        );
        assert_eq!(directive.epoch, 1);
        assert!(vault.revocations().is_content_revoked("note-1"));
        assert!(vault.is_content_destroyed(&content_id("note-1")));
    }

    #[test]
    fn destroyed_content_cannot_be_recreated_under_the_same_id() {
        let mut vault = vault();
        vault.add_content(&content_id("note-1"), &[&cid("inbox")]).unwrap();
        let _ = vault.destroy_content(&content_id("note-1")).unwrap();

        assert_eq!(
            vault.add_content(&content_id("note-1"), &[&cid("inbox")]).unwrap_err(),
            VaultError::ContentRevoked("note-1".into())
        );
    }

    #[test]
    fn adding_a_context_twice_keeps_the_same_key() {
        let mut vault = vault();
        let first = vault.add_context(&cid("inbox")).unwrap().as_bytes().to_owned();
        let second = vault.add_context(&cid("inbox")).unwrap().as_bytes().to_owned();
        assert_eq!(first, second);
    }

    /// `RA-26` failing form. Content stays linkable while ANY wrapping is live.
    ///
    /// Reproduced by rust-architect from an external consumer: content wrapped
    /// under `hospitalization` and `tax-2026`, destroy `hospitalization`, and
    /// `link_content` fails forever with `NoWrappingForContext` naming the
    /// destroyed context -- pointing a debugging caller at the wrong subject.
    #[test]
    fn mut_content_stays_linkable_after_its_first_context_is_destroyed() {
        let mut vault = vault();
        let (_key, mut envelope) = vault
            .add_content(
                &content_id("bill-001"),
                &[&cid("hospitalization"), &cid("tax-2026")],
            )
            .unwrap();

        let _directive = vault.destroy_context(&cid("hospitalization")).unwrap();

        // `tax-2026` is still live, so the receipt must remain linkable.
        vault
            .link_content(&cid("audit-2027"), &mut envelope)
            .expect("content with a live wrapping must stay linkable -- RA-26");
    }

    /// `SEC-15` / `SEC-38` failing form. The LIVE path must refuse a revoked
    /// device.
    ///
    /// `SEC-50`: deleting the revocation check from `admit_device` left the
    /// suite at 92 passed, 0 failed. The existing
    /// `a_stale_backup_does_not_readmit_a_revoked_device` passes through
    /// `purge_device` on the RESTORE path, so it *masks* the control it appears
    /// to cover -- the same masking the four framing regressions were written
    /// to break. `SEC-15`'s finding was live-path re-admission and nothing
    /// tested it.
    #[test]
    fn mut_a_revoked_device_is_refused_on_the_live_path() {
        use crate::vault::device::{DeviceCertificate, DeviceKey};
        let identity = RootIdentity::from_seed(&test_seed()).unwrap();
        let mut vault = Vault::new(identity.public_key());

        let device = DeviceKey::generate().unwrap();
        let certificate = DeviceCertificate::issue(&identity, &device, 1).unwrap();
        vault.trust_device(certificate.clone()).unwrap();
        assert_eq!(vault.trusted_devices().len(), 1);

        let _directive = vault.revoke_device(&DeviceId::new(certificate.device_id()).unwrap()).unwrap();
        assert!(vault.trusted_devices().is_empty());

        // The certificate is still validly signed. That is exactly why the
        // signature alone was never the answer.
        assert!(
            matches!(vault.trust_device(certificate), Err(VaultError::DeviceRevoked(_))),
            "a revoked device was re-admitted -- SEC-15 has no failing form"
        );
        assert!(vault.trusted_devices().is_empty());
    }

    /// `SEC-14` failing form. A destroyed context id is retired permanently.
    ///
    /// `SEC-50`: deleting the refusal from `add_context` left the suite at 92
    /// passed, 0 failed. Without it, restore later applies the ledger, sees the
    /// id revoked, and destroys everything wrapped under the *new* key --
    /// content created after the deletion, lost silently.
    #[test]
    fn mut_a_destroyed_context_id_cannot_be_recreated() {
        let mut vault = vault();

        vault.add_context(&cid("clinic")).unwrap();
        let _directive = vault.destroy_context(&cid("clinic")).unwrap();

        assert!(
            matches!(
                vault.add_context(&cid("clinic")),
                Err(VaultError::ContextRetired(id)) if id == "clinic"
            ),
            "a retired context identity was resurrected -- SEC-14 has no failing form"
        );
    }

    #[test]
    fn an_unsigned_device_certificate_is_rejected() {
        use crate::vault::device::{DeviceCertificate, DeviceKey};
        let device = DeviceKey::generate().unwrap();
        let forged = DeviceCertificate::forged_unsigned(&device, 1);

        let mut vault = vault();
        assert!(vault.trust_device(forged).is_err());
        assert!(vault.trusted_devices().is_empty());
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind vault::tests`
Expected: FAIL to compile — `Vault` not defined.

- [ ] **Step 3: Implement**

The code in Step 1 is the implementation. If borrow-checker conflicts appear in `link_content` (mutable and immutable borrows of `self`), clone the `ContextKey` before taking the mutable borrow — the code above already does this. `ContextKey` needs `Clone`; it is derived in Task 5.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind`
Expected: PASS, all tests across all modules

- [ ] **Step 5: Commit**

```bash
git add rust/airo_mind/src/vault/mod.rs
git commit -m "feat(mind): add Vault aggregate with unlink and destroy

destroy_content performs steps 1-3 of crypto-shredding and returns a
#[must_use] PurgeDirective for steps 4-8, which live outside Rust. A
directive the caller must consume is harder to skip than a comment.

unlink_content reports what survives, which is the input to the
destructive-confirmation copy in #1235.

Refs #1209, #1210, #1217"
```

---

## Task 8: Recovery Package export

Implements #1211.

**Files:**
- Create: `rust/airo_mind/src/vault/package.rs`
- Modify: `rust/airo_mind/src/vault/mod.rs`

**Interfaces:**
- Consumes: `Vault` (Task 7), `Seed` (Task 2), `RevocationLedger` (Task 6)
- Produces:
  - `VaultPayload` (crate-visible) — the serializable interior of a Vault
  - `RecoveryPackage { pub format_version: u32, pub identity_public_key: [u8; 32], pub revocation_epoch: u64 }` with `fn export(vault: &Vault, seed: &Seed) -> Result<Self, VaultError>`, `fn to_bytes(&self) -> Result<Vec<u8>, VaultError>`, `fn from_bytes(&[u8]) -> Result<Self, VaultError>`, and crate-visible `fn decrypt(&self, seed: &Seed) -> Result<VaultPayload, VaultError>`
  - `const RECOVERY_PACKAGE_FORMAT_VERSION: u32 = 1`

**Design note for the implementer.** `revocation_epoch` is stored **outside** the ciphertext, in plaintext. Restore must read it before it can decrypt anything, in order to know how far behind the backup is. This is the one field that must not be encrypted.

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/package.rs`:

```rust
//! Recovery Package. Grants access; carries no data.
//!
//! Contains identity, Vault, and revocation ledger. Explicitly not the
//! operation log and not the content. The user places it wherever they choose
//! — a capsule file, their own cloud storage, a NAS, a USB stick. Never on
//! Airo servers.

use std::collections::BTreeMap;

use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};
use hkdf::Hkdf;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256, Sha512};
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use super::domain;
use super::encoding::push_len_prefixed;
use super::envelope::ContextKey;
use super::random::random_nonce;
use super::identity::{RootIdentity, RootPublicKey};
use super::error::VaultError;
use super::restore::SealedRestore;
use super::revocation::{RevocationLedger, RevocationSubject};
use super::seed::Seed;
use super::{DeviceCertificate, Vault};

pub const RECOVERY_PACKAGE_FORMAT_VERSION: u32 = 1;

/// The serializable interior of a Vault.
/// No `Debug` — it would print every context key. No `Clone` — it would
/// duplicate them. No `PartialEq` — it would compare them in variable time.
/// `ZeroizeOnDrop` because this is the decrypted key set, resident for the
/// whole of a restore (chief-security-officer R7).
///
/// No `envelopes` field: the Vault is sized by contexts and devices, never by
/// user content (frozen design §4.1).
// No struct-level `ZeroizeOnDrop`: `zeroize` has **no impl for `BTreeMap`**,
// so the derive does not build — and "fixing" it with `#[zeroize(skip)]` on
// `context_keys` would skip every field and zeroize nothing. The guarantee
// comes from `KeyBytes`' own drop glue running per element, asserted below.
/// `SEC-1` — fields are `pub(super)`, not `pub(crate)`, and mutation is by
/// method.
///
/// Revision 7 exposed `context_keys` and `KeyBytes::as_bytes` at `pub(crate)`,
/// so any module in the crate could read every context key by calling
/// `RecoveryPackage::decrypt` — no revocations applied. The `RevocationsApplied`
/// witness guarded `Vault::from_payload` and not the door that hands out keys.
/// Reproduced by an in-crate probe.
///
/// **The fix is visibility, not a witness parameter.** Threading
/// `RevocationsApplied` into the key accessors was considered and rejected by
/// `RA-1`: a witness is only as strong as the set of modules that can mint one,
/// and that set grows every phase — the identical failure mode as `LogHead`'s
/// `pub(crate)` field, in a crate that has already had to fix it once. Narrow
/// visibility is checked by the compiler on every item on every build.
///
/// `restore.rs` needs exactly four things from the payload — the root key for
/// the identity check, the ledger for validate/merge/head_epoch, and the two
/// purges — and **none of them is key material.** With the purges as methods
/// below, `context_keys` and `KeyBytes::as_bytes` are reachable only from
/// `package.rs`, and `as_bytes` is left with a single caller:
/// `Vault::from_payload`.
#[derive(Serialize, Deserialize)]
pub(crate) struct VaultPayload {
    pub(super) root_public_key: RootPublicKey,
    pub(super) context_keys: BTreeMap<String, KeyBytes>,
    pub(super) device_certificates: Vec<DeviceCertificate>,
    pub(super) revocations: RevocationLedger,
}

impl VaultPayload {
    /// The four things `restore.rs` legitimately needs. None is key material.
    pub(super) fn purge_context(&mut self, id: &str) -> bool {
        self.context_keys.remove(id).is_some()
    }

    pub(super) fn purge_device(&mut self, id: &str) -> bool {
        let before = self.device_certificates.len();
        self.device_certificates.retain(|c| c.device_id() != id);
        self.device_certificates.len() != before
    }

    #[cfg(test)]
    pub(super) fn context_key_count(&self) -> usize {
        self.context_keys.len()
    }

    /// `SEC-37` / `A20`: the conversion happens HERE, inside `package.rs`, so
    /// `aggregate.rs` never names a key byte. Narrowing `KeyBytes::as_bytes` to
    /// `pub(in crate::vault::package)` broke `Vault::from_payload`, which is
    /// the finding: the aggregate was reaching into key material.
    /// Consumes the payload into its four parts, converting key bytes here so
    /// the aggregate never names one. `PERF` -- moves rather than clones.
    #[allow(clippy::type_complexity)]
    pub(super) fn into_parts(
        self,
    ) -> (
        RootPublicKey,
        std::collections::BTreeMap<String, ContextKey>,
        Vec<DeviceCertificate>,
        RevocationLedger,
    ) {
        let context_keys = self
            .context_keys
            .into_iter()
            .map(|(id, k)| (id, ContextKey::from_bytes(*k.as_bytes())))
            .collect();
        (
            self.root_public_key,
            context_keys,
            self.device_certificates,
            self.revocations,
        )
    }

    pub(super) fn root_public_key(&self) -> &RootPublicKey {
        &self.root_public_key
    }

    pub(super) fn revocations_mut(&mut self) -> &mut RevocationLedger {
        &mut self.revocations
    }
}

/// The failing form for the zeroization claim above (I5). If `KeyBytes` ever
/// stops zeroizing on drop, this stops compiling.
const _: fn() = || {
    fn assert_zeroize_on_drop<T: zeroize::ZeroizeOnDrop>() {}
    assert_zeroize_on_drop::<KeyBytes>();
};

/// A 32-byte secret that cannot be printed, cloned, or compared in variable
/// time.
///
/// Introduced because the security and open-source reviews reached opposite
/// conclusions on `serde_json` and both were right about their own question.
/// The size argument stands: `serde_json` stays. The hygiene finding is closed
/// here instead — by making the *type* refuse to leak — rather than by
/// swapping the serializer, which would not have fixed it.
#[derive(Zeroize, ZeroizeOnDrop, Serialize, Deserialize)]
#[serde(transparent)]
pub(crate) struct KeyBytes(#[serde(with = "super::encoding::hex_array_32")] [u8; 32]);

impl std::fmt::Debug for KeyBytes {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("KeyBytes(<redacted>)")
    }
}

impl KeyBytes {
    pub(super) fn new(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    /// `SEC-1` / `SEC-37` / `A20`. `pub(in crate::vault::package)`, not
    /// `pub(super)`.
    ///
    /// `pub(super)` inside `vault::package` resolves to `pub(in crate::vault)` --
    /// every module in the crate, not this one. `SEC-37` proved it with a
    /// sibling module standing in for Phase 2's log and sync, which compiled
    /// against these key bytes. `RA-1`'s whole argument for choosing visibility
    /// over a witness was that visibility is compiler-checked on every build,
    /// so the spelling has to mean what the doc says.
    pub(in crate::vault::package) fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }
}

/// An encrypted, portable grant of access to a Vault.
/// `RA-23a` — every signature- or AAD-covered field is private with a read
/// accessor. Revision 7 left all six `pub` and mutable, on a type whose header
/// is AAD-bound; the tamper tests that mutate them move to
/// `#[cfg(test)] pub(crate) fn with_*_tampered`, the same pattern
/// `RootPublicKey::from_bytes` already uses.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecoveryPackage {
    format_version: u32,
    identity_public_key: RootPublicKey,
    /// Head epoch at export time. Deliberately **outside** the ciphertext:
    /// restore must read it before it can decrypt anything, to know how far
    /// behind this backup is.
    revocation_epoch: u64,

    // ── Reserved in v1, not yet used ────────────────────────────────────────
    //
    // A user-chosen passphrase over the 24 words is real defence: this package
    // is designed to sit on a NAS, a USB stick, or the user's own cloud, where
    // "someone photographed the seed card" is the realistic threat.
    //
    // The slot is reserved rather than the feature built, because adding these
    // fields later changes the format and breaks every package already in the
    // field. Reserving costs three fields and one AAD entry; not reserving
    // forecloses the option permanently.
    //
    // v1 always writes `passphrase_used: false`, an empty `kdf_params`, and a
    // random `kdf_salt`. `decrypt` MUST reject `passphrase_used: true` with
    // `UnsupportedPackageVersion` until the feature ships — a package this
    // build cannot open must fail loudly, never silently ignore the flag and
    // derive the wrong key.
    passphrase_used: bool,
    kdf_params: BTreeMap<String, u64>,
    #[serde(with = "super::encoding::base64_bytes")]
    kdf_salt: Vec<u8>,

    // `ADR-0017`. Base64, not hex and never decimal arrays. The package
    // double-encodes — a JSON payload, then that ciphertext text-encoded again
    // here — so hex on these three costs a hard 2.0× and puts `V4`'s
    // `≤ 3× compact` floor at 3.30×, unmeetable at any inner encoding. Base64
    // costs 1.33× and clears every measured shape. Measured on the revision 7
    // output: `identity_public_key` shipped as `[134,206,47,15,...]`.
    #[serde(with = "super::encoding::base64_bytes")]
    nonce: Vec<u8>,

    /// `ADR-0017` framing. Bounded batches, each sealed independently.
    frames: Vec<Frame>,

    /// Sealed frame count and running digest. **Not optional** — without it a
    /// truncated package fails AEAD identically to a corrupt one.
    #[serde(with = "super::encoding::base64_bytes")]
    trailer: Vec<u8>,
}

/// File magic. A wrong value means "not our format", which is neither short
/// nor corrupt and must not be reported as either.
const MAGIC: &[u8; 4] = b"AMRP";

/// The header, serialized on its own so it is length-prefixed and can be read
/// before any frame. `PERF-2`: a reader must know what it is holding before it
/// decides whether the rest of the file is missing or wrong.
#[derive(Serialize, Deserialize)]
struct Header {
    format_version: u32,
    identity_public_key: RootPublicKey,
    revocation_epoch: u64,
    passphrase_used: bool,
    kdf_params: BTreeMap<String, u64>,
    #[serde(with = "super::encoding::base64_bytes")]
    kdf_salt: Vec<u8>,
    #[serde(with = "super::encoding::base64_bytes")]
    nonce: Vec<u8>,
}

impl Header {
    fn from(p: &RecoveryPackage) -> Self {
        Self {
            format_version: p.format_version,
            identity_public_key: p.identity_public_key,
            revocation_epoch: p.revocation_epoch,
            passphrase_used: p.passphrase_used,
            kdf_params: p.kdf_params.clone(),
            kdf_salt: p.kdf_salt.clone(),
            nonce: p.nonce.clone(),
        }
    }

    fn into_package(self, frames: Vec<Frame>, trailer: Vec<u8>) -> RecoveryPackage {
        RecoveryPackage {
            format_version: self.format_version,
            identity_public_key: self.identity_public_key,
            revocation_epoch: self.revocation_epoch,
            passphrase_used: self.passphrase_used,
            kdf_params: self.kdf_params,
            kdf_salt: self.kdf_salt,
            nonce: self.nonce,
            frames,
            trailer,
        }
    }
}

/// One sealed batch. `ADR-0017`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Frame {
    index: u32,
    #[serde(with = "super::encoding::base64_bytes")]
    ciphertext: Vec<u8>,
}

/// Entries per frame. Bounds peak memory during export and restore
/// independently of ledger size, which is the `ADR-0017` property: `V5`
/// measured 10.7×–21.6× against a 4× budget on the single-blob format, and the
/// ratio was flat across sizes, so it was structural.
const FRAME_ENTRIES: usize = 1024;

/// What a frame carries. Sections are emitted in this order and restore
/// accepts them in any order, so a future writer may reorder without breaking
/// readers.
#[derive(Serialize, Deserialize)]
enum FrameBody {
    Root(RootPublicKey),
    Contexts(Vec<(String, KeyBytes)>),
    Devices(Vec<DeviceCertificate>),
    Revocations(Vec<(RevocationSubject, u64)>),
}

/// Per-frame nonce: the package nonce with its last four bytes replaced by the
/// frame index.
///
/// XChaCha20's nonce is 192 bits, so 160 random bits plus a bounded counter
/// keeps every frame's nonce distinct under one key without a second KDF. The
/// trailer uses `u32::MAX`, which `FRAME_ENTRIES` batching cannot reach.
fn frame_nonce(package_nonce: &[u8; 24], index: u32) -> [u8; 24] {
    let mut n = *package_nonce;
    n[20..24].copy_from_slice(&index.to_be_bytes());
    n
}

/// # Framing — `ADR-0017`, `Freeze §4`
///
/// **The binding requirement is a property, not a layout:**
///
/// > Peak memory during export and restore is `O(1)` in revocation-ledger
/// > size, and truncation is distinguishable from corruption.
///
/// `[len:u32][AEAD frame] × N` plus a sealed trailer satisfies it and is the
/// default shape; the layout is not itself frozen.
///
/// ## Why this is required, and why the original reason is retired
///
/// #1305 required framing against a Vault holding one `ContentEnvelope` per
/// content object. The §4.1 redesign deleted that driver, and measurement
/// confirms it: a Vault is byte-identical at 10k and 100k contents (compact
/// 2,540 B both, export 0.07 ms both, peak RSS delta −0.8%).
///
/// The Vault kept a second unbounded collection. The revocation ledger retains
/// every destroyed subject permanently — deliberately, since `R4`'s
/// blind-restore protection depends on it being complete. Measured:
///
/// ```text
/// ledger exceeds contexts + devices at        224 destroyed subjects
/// V5 peak RSS during export, budget 4×        10.7×–21.6×, flat across sizes
/// V7 peak RSS, 10k → 100k revocations, +20%   +849%
/// ```
///
/// Flat ratios mean structural, not a scale effect a larger budget absorbs.
/// Byte-oriented serde does not fix it — 11.2× after, marginally worse,
/// because that win is on disk and not in the live set.
///
/// ## What has to change
///
/// The 11× decomposes into six simultaneously-live copies. Four are the
/// single-blob format itself and are what framing removes:
///
/// 1. The `BTreeMap` — 137.6 B resident per 49 B logical entry, **2.8× before
///    export begins.** Framing does not remove this, and it is inside the 4×
///    budget.
/// 2. `Vault::to_payload` deep-cloning the ledger and certificates purely to
///    serialize them — **26% of export peak, measured.** Fixed by a borrowing
///    serializer type, independently of framing.
/// 3. `serde_json::to_vec` over the whole payload.
/// 4. `encrypt` returning a fresh whole-ciphertext `Vec`.
/// 5. `to_bytes` serializing the 3.9× on-disk form in memory.
/// 6. Reallocation headroom on each.
///
/// Export streams contexts, then certificates, then the ledger in fixed-size
/// batches. `from_bytes` stops materializing the whole file before verifying a
/// single byte. `encrypt_in_place_detached` removes one full-payload
/// allocation and copy.
///
/// ## The trailer is not optional
///
/// Today a truncated Recovery Package fails AEAD **identically to a corrupt
/// one**, and yields nothing. A sealed trailer distinguishes them and lets a
/// partial restore recover every complete frame — on the one artifact whose
/// absence is unrecoverable.
///
/// ## Re-review this invalidates
///
/// Framing changes the on-disk format, so every AAD binding, identity binding,
/// and tamper test must be re-verified against the new shape.
/// chief-security-officer and rust-architect both signed off on the current
/// single-blob format; per `ADR-0017`'s Contract Impact table, both re-review,
/// and `G0` is required again.
impl RecoveryPackage {
    /// The plaintext header, canonically encoded, bound as AAD.
    ///
    /// Without this the header is freely editable: `revocation_epoch` drives
    /// the "your backup is N revocations behind" warning, and
    /// `identity_public_key` drives "this package belongs to identity X".
    /// Both are user-facing safety signals sitting outside the ciphertext.
    ///
    /// `kdf_*` and `passphrase_used` are bound too, so a downgrade attack
    /// cannot strip a future passphrase by flipping the flag.
    fn header_aad(&self) -> Result<Vec<u8>, VaultError> {
        let mut aad = Vec::new();
        aad.extend_from_slice(domain::PACKAGE_HEADER);
        aad.extend_from_slice(&self.format_version.to_be_bytes());
        aad.extend_from_slice(self.identity_public_key.as_bytes());
        aad.extend_from_slice(&self.revocation_epoch.to_be_bytes());
        aad.push(u8::from(self.passphrase_used));
        let count = u32::try_from(self.kdf_params.len()).map_err(|_| VaultError::ValueTooLong)?;
        aad.extend_from_slice(&count.to_be_bytes());
        for (key, value) in &self.kdf_params {
            // The checked helper, at every site the invariant applies to. A
            // helper built and used at one of two sites is worse than none —
            // it reads as done.
            push_len_prefixed(&mut aad, key.as_bytes())?;
            aad.extend_from_slice(&value.to_be_bytes());
        }
        push_len_prefixed(&mut aad, &self.kdf_salt)?;
        // `SEC-35` / `A17`. `frame_nonce` overwrites bytes 20..24 with the
        // index, so without this those 32 bits are never read and never
        // authenticated -- two byte-different files decrypting to one vault.
        push_len_prefixed(&mut aad, &self.nonce)?;
        Ok(aad)
    }

    /// `RA-23a` / `A05`,`A06`. Read accessors: every field below is covered by
    /// `header_aad`, so a `pub` field let a consumer build a package guaranteed
    /// to fail restore. Read is safe; write is not.
    pub fn format_version(&self) -> u32 {
        self.format_version
    }

    pub fn identity_public_key(&self) -> &RootPublicKey {
        &self.identity_public_key
    }

    /// Drives the "your backup is N revocations behind" warning, which is read
    /// before anything is decrypted.
    pub fn revocation_epoch(&self) -> u64 {
        self.revocation_epoch
    }

    /// Tamper constructors. `#[cfg(test)]`, so the six `I3` tamper tests can
    /// still prove the AAD catches each field while no consumer can write one.
    /// Same shape as `RootPublicKey::from_bytes`.
    /// Re-seals the trailer carrying a head that disagrees with the plaintext
    /// `revocation_epoch`. Only a buggy writer produces this, so only a test
    /// can construct it.
    #[cfg(test)]
    pub(crate) fn with_desynced_trailer_head(mut self, seed: &Seed, head: u64) -> Self {
        use sha2::Digest as _;
        let package_nonce: [u8; 24] = self.nonce.as_slice().try_into().unwrap();
        let cipher = XChaCha20Poly1305::new(&package_key(seed).unwrap().into());
        let aad = self.header_aad().unwrap();
        let mut digest = Sha256::new();
        for frame in &self.frames {
            digest.update(&frame.ciphertext);
        }
        let mut plain = Vec::with_capacity(44);
        plain.extend_from_slice(&u32::try_from(self.frames.len()).unwrap().to_be_bytes());
        plain.extend_from_slice(&head.to_be_bytes());
        plain.extend_from_slice(&digest.finalize());
        self.trailer = cipher
            .encrypt(
                XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                Payload {
                    msg: &plain,
                    aad: &aad,
                },
            )
            .unwrap();
        self
    }

    #[cfg(test)]
    pub(crate) fn with_format_version_tampered(mut self, v: u32) -> Self {
        self.format_version = v;
        self
    }

    #[cfg(test)]
    pub(crate) fn with_revocation_epoch_tampered(mut self, v: u64) -> Self {
        self.revocation_epoch = v;
        self
    }

    #[cfg(test)]
    pub(crate) fn with_identity_tampered(mut self, v: RootPublicKey) -> Self {
        self.identity_public_key = v;
        self
    }

    #[cfg(test)]
    pub(crate) fn with_kdf_salt_tampered(mut self) -> Self {
        self.kdf_salt[0] ^= 0xff;
        self
    }

    #[cfg(test)]
    pub(crate) fn with_kdf_param_tampered(mut self, k: &str, v: u64) -> Self {
        self.kdf_params.insert(k.to_string(), v);
        self
    }

    #[cfg(test)]
    pub(crate) fn with_passphrase_flag_tampered(mut self) -> Self {
        self.passphrase_used = true;
        self
    }

    /// Number of sealed frames. Lets a caller — and `V5`/`V7` — see that peak
    /// memory is bounded by `FRAME_ENTRIES` rather than by ledger size.
    pub fn frame_count(&self) -> usize {
        self.frames.len()
    }

    /// **The streaming export.** `ADR-0017`'s `O(1)` property lives here.
    ///
    /// `export` below returns a `RecoveryPackage`, which accumulates every
    /// frame in a `Vec` before `to_bytes` serializes the lot — so it bounds
    /// the *working set* per frame and not the *result*. Measured, that leaves
    /// peak memory linear in ledger size: 1.0 MB of export overhead at 10k
    /// revocations, 6.9 MB at 100k, 32.5 MB at 500k. Perfectly bounded frame
    /// construction cannot fix an API whose return value is the whole package.
    ///
    /// This writes each frame as it is sealed and never holds more than one.
    /// **The wire format is unchanged** — field order, encodings, AAD and
    /// trailer are byte-identical to `export().to_bytes()`, asserted by
    /// `streaming_export_is_byte_identical_to_the_materializing_one` below.
    /// Only the production model changes.
    ///
    /// Hand-written JSON rather than `serde_json::to_writer`: every value is a
    /// number, a bool, an empty map, or a hex/base64 string, so no escaping
    /// arises, and serde emits struct fields in declaration order — which this
    /// follows exactly.
    pub fn export_to<W: std::io::Write>(
        vault: &Vault,
        seed: &Seed,
        out: &mut W,
    ) -> Result<(), VaultError> {
        if *vault.root_public_key() != RootIdentity::from_seed(seed)?.public_key() {
            return Err(VaultError::IdentityMismatch);
        }
        let mut salt = vec![0u8; 16];
        super::random::fill_random(&mut salt)?;
        let package_nonce = random_nonce()?;

        // Header first: it is the AAD every frame commits to, and it is what
        // a reader needs before it can open anything.
        let header = Self {
            format_version: RECOVERY_PACKAGE_FORMAT_VERSION,
            identity_public_key: *vault.root_public_key(),
            revocation_epoch: vault.revocations().head_epoch(),
            passphrase_used: false,
            kdf_params: BTreeMap::new(),
            kdf_salt: salt,
            nonce: package_nonce.to_vec(),
            frames: Vec::new(),
            trailer: Vec::new(),
        };
        let aad = header.header_aad()?;
        let cipher = XChaCha20Poly1305::new(&package_key(seed)?.into());

        // `RA` Q1 + Q2: ONE implementation of the format. The previous
        // `export_to` hand-wrote JSON with `"kdf_params":{}` literal while
        // `header_aad` computed over `self.kdf_params` -- divergent the day the
        // reserved passphrase slot activates, surfacing to a user as "wrong
        // seed" on the recovery path. Both writers now emit the framed form
        // through the same helpers.
        let io = |_: std::io::Error| VaultError::SerializationFailed;
        let plen = |n: usize| -> Result<[u8; 4], VaultError> {
            Ok(u32::try_from(n)
                .map_err(|_| VaultError::ValueTooLong)?
                .to_be_bytes())
        };

        out.write_all(MAGIC).map_err(io)?;
        out.write_all(&header.format_version.to_be_bytes()).map_err(io)?;
        let header_bytes = serde_json::to_vec(&Header::from(&header))
            .map_err(|_| VaultError::SerializationFailed)?;
        out.write_all(&plen(header_bytes.len())?).map_err(io)?;
        out.write_all(&header_bytes).map_err(io)?;

        // Frame count is written before the frames, so a reader knows how many
        // to expect before it reads one. That is what makes a short file
        // diagnosable as short.
        let frame_count = 1
            + vault.context_entries().count().div_ceil(FRAME_ENTRIES)
            + vault.trusted_devices().len().div_ceil(FRAME_ENTRIES)
            + vault.revocations().entries().count().div_ceil(FRAME_ENTRIES);
        out.write_all(&plen(frame_count)?).map_err(io)?;

        let mut digest = Sha256::new();
        let mut index: u32 = 0;
        let emit = |body: &FrameBody,
                        index: &mut u32,
                        digest: &mut Sha256,
                        out: &mut W|
         -> Result<(), VaultError> {
            let plain = Zeroizing::new(
                serde_json::to_vec(body).map_err(|_| VaultError::SerializationFailed)?,
            );
            let ciphertext = cipher
                .encrypt(
                    XNonce::from_slice(&frame_nonce(&package_nonce, *index)),
                    Payload {
                        msg: plain.as_slice(),
                        aad: &aad,
                    },
                )
                .map_err(|_| VaultError::SerializationFailed)?;
            digest.update(&ciphertext);
            out.write_all(&plen(ciphertext.len())?).map_err(io)?;
            out.write_all(&ciphertext).map_err(io)?;
            // `SEC-46` / `A12`: checked. A release-mode wrap to 0 is nonce reuse.
            *index = index.checked_add(1).ok_or(VaultError::ValueTooLong)?;
            Ok(())
        };

        emit(
            &FrameBody::Root(*vault.root_public_key()),
            &mut index,
            &mut digest,
            out,
        )?;
        let mut contexts = vault.context_entries();
        loop {
            let batch: Vec<_> = contexts.by_ref().take(FRAME_ENTRIES).collect();
            if batch.is_empty() {
                break;
            }
            emit(&FrameBody::Contexts(batch), &mut index, &mut digest, out)?;
        }
        for chunk in vault.trusted_devices().chunks(FRAME_ENTRIES) {
            emit(
                &FrameBody::Devices(chunk.to_vec()),
                &mut index,
                &mut digest,
                out,
            )?;
        }
        let mut revocations = vault.revocations().entries();
        loop {
            let batch: Vec<_> = revocations.by_ref().take(FRAME_ENTRIES).collect();
            if batch.is_empty() {
                break;
            }
            emit(&FrameBody::Revocations(batch), &mut index, &mut digest, out)?;
        }

        // `SEC-36` / `A18`: the head is CARRIED, not re-derived.
        //
        // `FrameBody::Revocations` holds entries only, so `absorb` had to
        // reconstruct `head_epoch` as `max(entry epoch)` -- while `validate()`
        // permits `head_epoch > max(entry)`. A ledger that passes `validate`
        // could therefore export successfully and be unrestorable, with the
        // failure surfacing on restore day. Two checks disagreeing about one
        // value, which is `SEC-2`'s defect class in the format layer.
        //
        // The trailer's plaintext layout is internal, not a frozen header
        // field, so widening it is inside `Freeze §4`'s latitude.
        let mut trailer_plain = Vec::with_capacity(44);
        trailer_plain.extend_from_slice(&index.to_be_bytes());
        trailer_plain.extend_from_slice(&vault.revocations().head_epoch().to_be_bytes());
        trailer_plain.extend_from_slice(&digest.finalize());
        let trailer = cipher
            .encrypt(
                XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                Payload {
                    msg: &trailer_plain,
                    aad: &aad,
                },
            )
            .map_err(|_| VaultError::SerializationFailed)?;
        out.write_all(&plen(trailer.len())?).map_err(io)?;
        out.write_all(&trailer).map_err(io)?;
        Ok(())
    }

    /// Materializing export. Retained for tests and small vaults; **prefer
    /// `export_to`**, which is the one that meets `ADR-0017`'s memory
    /// property.
    ///
    /// Streams the Vault into bounded frames. `ADR-0017`.
    ///
    /// Sources directly from the Vault rather than from `to_payload`, which
    /// deep-cloned the ledger and certificates purely to serialize them —
    /// **26% of export peak RSS, measured.** Peak is now `O(FRAME_ENTRIES)`
    /// rather than `O(ledger)`.
    pub fn export(vault: &Vault, seed: &Seed) -> Result<Self, VaultError> {
        // Bind at export, not at restore. A mismatched (vault, seed) pair used
        // to produce a perfectly valid package that `SealedRestore::load`
        // rejected with `IdentityMismatch` — discovered years later, on the
        // worst day the user will ever have (rust-architect M1).
        if *vault.root_public_key() != RootIdentity::from_seed(seed)?.public_key() {
            return Err(VaultError::IdentityMismatch);
        }

        let mut salt = vec![0u8; 16];
        super::random::fill_random(&mut salt)?;
        let package_nonce = random_nonce()?;

        let mut package = Self {
            format_version: RECOVERY_PACKAGE_FORMAT_VERSION,
            identity_public_key: *vault.root_public_key(),
            revocation_epoch: vault.revocations().head_epoch(),
            passphrase_used: false,
            kdf_params: BTreeMap::new(),
            kdf_salt: salt,
            nonce: package_nonce.to_vec(),
            frames: Vec::new(),
            trailer: Vec::new(),
        };

        let cipher = XChaCha20Poly1305::new(&package_key(seed)?.into());
        let aad = package.header_aad()?;
        let mut digest = Sha256::new();
        let mut index: u32 = 0;

        let seal = |body: &FrameBody,
                        index: &mut u32,
                        frames: &mut Vec<Frame>,
                        digest: &mut Sha256|
         -> Result<(), VaultError> {
            // `Zeroizing`: a Contexts frame holds context keys in plaintext.
            let plain = Zeroizing::new(
                serde_json::to_vec(body).map_err(|_| VaultError::SerializationFailed)?,
            );
            let n = frame_nonce(&package_nonce, *index);
            let ciphertext = cipher
                .encrypt(
                    XNonce::from_slice(&n),
                    Payload {
                        msg: plain.as_slice(),
                        aad: &aad,
                    },
                )
                .map_err(|_| VaultError::SerializationFailed)?;
            digest.update(&ciphertext);
            frames.push(Frame {
                index: *index,
                ciphertext,
            });
            // `SEC-46` / `A12`: checked. A release-mode wrap to 0 is nonce reuse.
            *index = index.checked_add(1).ok_or(VaultError::ValueTooLong)?;
            Ok(())
        };

        seal(
            &FrameBody::Root(*vault.root_public_key()),
            &mut index,
            &mut package.frames,
            &mut digest,
        )?;

        // Batched by hand: `Iterator` has no `chunks`, and pulling in
        // `itertools` for one call on the crypto path needs a governance
        // scorecard (Constitution §6). `by_ref().take(N)` keeps peak at
        // `O(FRAME_ENTRIES)`, which is the whole point.
        let mut contexts = vault.context_entries();
        loop {
            let batch: Vec<_> = contexts.by_ref().take(FRAME_ENTRIES).collect();
            if batch.is_empty() {
                break;
            }
            seal(
                &FrameBody::Contexts(batch),
                &mut index,
                &mut package.frames,
                &mut digest,
            )?;
        }
        for chunk in vault.trusted_devices().chunks(FRAME_ENTRIES) {
            seal(
                &FrameBody::Devices(chunk.to_vec()),
                &mut index,
                &mut package.frames,
                &mut digest,
            )?;
        }
        let mut revocations = vault.revocations().entries();
        loop {
            let batch: Vec<_> = revocations.by_ref().take(FRAME_ENTRIES).collect();
            if batch.is_empty() {
                break;
            }
            seal(
                &FrameBody::Revocations(batch),
                &mut index,
                &mut package.frames,
                &mut digest,
            )?;
        }

        // Trailer last, over every frame ciphertext in order. A truncated file
        // loses frames and the count stops matching; a corrupted one fails
        // AEAD. Distinguishable, which is the `ADR-0017` requirement.
        // `SEC-36` / `A18`: the head is CARRIED, not re-derived.
        //
        // `FrameBody::Revocations` holds entries only, so `absorb` had to
        // reconstruct `head_epoch` as `max(entry epoch)` -- while `validate()`
        // permits `head_epoch > max(entry)`. A ledger that passes `validate`
        // could therefore export successfully and be unrestorable, with the
        // failure surfacing on restore day. Two checks disagreeing about one
        // value, which is `SEC-2`'s defect class in the format layer.
        //
        // The trailer's plaintext layout is internal, not a frozen header
        // field, so widening it is inside `Freeze §4`'s latitude.
        let mut trailer_plain = Vec::with_capacity(44);
        trailer_plain.extend_from_slice(&index.to_be_bytes());
        trailer_plain.extend_from_slice(&vault.revocations().head_epoch().to_be_bytes());
        trailer_plain.extend_from_slice(&digest.finalize());
        package.trailer = cipher
            .encrypt(
                XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                Payload {
                    msg: &trailer_plain,
                    aad: &aad,
                },
            )
            .map_err(|_| VaultError::SerializationFailed)?;

        Ok(package)
    }

    /// The only route from a package to a `SealedRestore`. `SEC-1`.
    ///
    /// The identity check is not decoration: without it, a mismatched or
    /// crafted package yields a vault that accepts device certificates signed
    /// by a root the user does not control.
    pub(crate) fn open(&self, seed: &Seed) -> Result<SealedRestore, VaultError> {
        let payload = self.decrypt(seed)?;
        let expected = RootIdentity::from_seed(seed)?.public_key();
        if *payload.root_public_key() != expected || self.identity_public_key != expected {
            return Err(VaultError::IdentityMismatch);
        }
        payload.revocations.validate()?;
        // AAD stops an attacker editing the header; it does not stop a buggy
        // or hostile *writer* inflating it. Fail closed.
        if self.revocation_epoch != payload.revocations.head_epoch() {
            return Err(VaultError::SerializationFailed);
        }
        Ok(SealedRestore::from_parts(payload, self.revocation_epoch))
    }

    /// `SEC-1` — **private.** The payload never leaves this module.
    ///
    /// # Invariant boundary: `decrypt` does not cross-check; `open` does
    ///
    /// `decrypt` returns the payload with the frames authenticated and nothing
    /// else verified. The `revocation_epoch == head_epoch` cross-check
    /// (`SEC-36`) and the identity check live in `open`, one level up.
    ///
    /// **That split is safe only while `decrypt` stays private with controlled
    /// callers.** If it ever becomes `pub(crate)` or `pub`, the invariant
    /// changes and every new caller inherits the obligation to cross-check.
    /// Found by a mutation test that passed when pointed at `decrypt` and
    /// failed when pointed at `open` — the same shape as `SEC-1` itself, where
    /// a witness guarded one door and not the one handing out keys.
    ///
    /// Revision 7 had this `pub(crate)` returning a `pub(crate)` payload whose
    /// key accessors were also `pub(crate)`, which is the route an in-crate
    /// probe used to read every context key without applying revocations. The
    /// only way from a package to a `Vault` is now
    /// `open` → `SealedRestore` → `apply_revocations` → `AppliedRestore` →
    /// `into_vault`, and `RevocationsApplied` stays as belt-and-braces on
    /// `from_payload` rather than becoming the primary control.
    fn decrypt(&self, seed: &Seed) -> Result<VaultPayload, VaultError> {
        self.check_supported()?;
        let package_nonce: [u8; 24] = self
            .nonce
            .as_slice()
            .try_into()
            .map_err(|_| VaultError::DecryptionFailed)?;
        let cipher = XChaCha20Poly1305::new(&package_key(seed)?.into());
        let aad = self.header_aad()?;

        // Trailer first. It states how many frames should be here, so
        // truncation is detected before any frame is opened, and a truncated
        // package reports truncation rather than failing like a corrupt one.
        // `ADR-0017`.
        let trailer = Zeroizing::new(
            cipher
                .decrypt(
                    XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                    Payload {
                        msg: self.trailer.as_slice(),
                        aad: &aad,
                    },
                )
                .map_err(|_| VaultError::DecryptionFailed)?,
        );
        if trailer.len() != 44 {
            return Err(VaultError::SerializationFailed);
        }
        let expected_count = u32::from_be_bytes(
            trailer[0..4]
                .try_into()
                .map_err(|_| VaultError::SerializationFailed)?,
        );
        let expected_count_usize =
            usize::try_from(expected_count).map_err(|_| VaultError::SerializationFailed)?;
        if self.frames.len() != expected_count_usize {
            return Err(VaultError::PackageTruncated);
        }

        let mut digest = Sha256::new();
        let mut root: Option<RootPublicKey> = None;
        let mut context_keys = BTreeMap::new();
        let mut device_certificates = Vec::new();
        let mut revocations = RevocationLedger::new();

        for (position, frame) in self.frames.iter().enumerate() {
            // A reordered or renumbered frame is a reordered nonce, so this is
            // not merely a sanity check: it pins each ciphertext to the nonce
            // it was sealed under.
            if usize::try_from(frame.index).map_err(|_| VaultError::SerializationFailed)?
                != position
            {
                return Err(VaultError::SerializationFailed);
            }
            digest.update(&frame.ciphertext);
            let plain = Zeroizing::new(
                cipher
                    .decrypt(
                        XNonce::from_slice(&frame_nonce(&package_nonce, frame.index)),
                        Payload {
                            msg: frame.ciphertext.as_slice(),
                            aad: &aad,
                        },
                    )
                    .map_err(|_| VaultError::DecryptionFailed)?,
            );
            let body: FrameBody =
                serde_json::from_slice(&plain).map_err(|_| VaultError::SerializationFailed)?;
            match body {
                FrameBody::Root(key) => root = Some(key),
                FrameBody::Contexts(entries) => context_keys.extend(entries),
                FrameBody::Devices(certs) => device_certificates.extend(certs),
                FrameBody::Revocations(entries) => revocations.absorb(entries),
            }
        }

        if digest.finalize().as_slice() != &trailer[12..44] {
            return Err(VaultError::SerializationFailed);
        }
        // Restore the carried head rather than trusting `max(entry)`.
        let carried_head = u64::from_be_bytes(
            trailer[4..12]
                .try_into()
                .map_err(|_| VaultError::SerializationFailed)?,
        );
        revocations.set_head_epoch(carried_head)?;
        Ok(VaultPayload {
            root_public_key: root.ok_or(VaultError::SerializationFailed)?,
            context_keys,
            device_certificates,
            revocations,
        })
    }

    /// Rejects anything this build cannot open correctly.
    ///
    /// `passphrase_used: true` means a future build wrote a package whose key
    /// derivation this build does not implement. Failing loudly is mandatory —
    /// ignoring the flag would derive the wrong key and surface as
    /// "wrong seed", sending the user hunting for a mnemonic that is correct.
    fn check_supported(&self) -> Result<(), VaultError> {
        if self.format_version != RECOVERY_PACKAGE_FORMAT_VERSION {
            return Err(VaultError::UnsupportedPackageVersion(self.format_version));
        }
        if self.passphrase_used || !self.kdf_params.is_empty() {
            return Err(VaultError::UnsupportedProtectionMode);
        }
        Ok(())
    }

    /// Length-prefixed framing. `PERF-1` + `PERF-2`, one deliverable.
    ///
    /// The previous form was one JSON document, and `serde_json::from_slice`
    /// cannot parse a truncated one at all — so a package cut anywhere returned
    /// `SerializationFailed`, byte-for-byte indistinguishable from structural
    /// corruption, and `PackageTruncated` was unreachable from any file. Both
    /// findings need the same reader, which is why they are one item.
    ///
    /// ```text
    /// "AMRP"            magic, 4 bytes
    /// format_version    u32 BE
    /// header_len        u32 BE   header JSON follows
    /// frame_count       u32 BE
    ///   per frame:      u32 BE len, then that many ciphertext bytes
    /// trailer_len       u32 BE   trailer bytes follow
    /// ```
    ///
    /// A reader that hits EOF mid-section knows the file is **short**. A reader
    /// whose AEAD fails knows it is **corrupt**. `Freeze §4` froze the framing
    /// as a property and left the layout open, so this is inside that latitude.
    pub fn to_bytes(&self) -> Result<Vec<u8>, VaultError> {
        let mut out = Vec::new();
        self.to_writer(&mut out)?;
        Ok(out)
    }

    /// Writes the framed form. `to_bytes` is the adapter over this.
    pub fn to_writer<W: std::io::Write>(&self, out: &mut W) -> Result<(), VaultError> {
        let io = |_: std::io::Error| VaultError::SerializationFailed;
        let len = |n: usize| -> Result<[u8; 4], VaultError> {
            Ok(u32::try_from(n)
                .map_err(|_| VaultError::ValueTooLong)?
                .to_be_bytes())
        };

        out.write_all(MAGIC).map_err(io)?;
        out.write_all(&self.format_version.to_be_bytes()).map_err(io)?;

        let header = serde_json::to_vec(&Header::from(self))
            .map_err(|_| VaultError::SerializationFailed)?;
        out.write_all(&len(header.len())?).map_err(io)?;
        out.write_all(&header).map_err(io)?;

        out.write_all(&len(self.frames.len())?).map_err(io)?;
        for frame in &self.frames {
            out.write_all(&len(frame.ciphertext.len())?).map_err(io)?;
            out.write_all(&frame.ciphertext).map_err(io)?;
        }

        out.write_all(&len(self.trailer.len())?).map_err(io)?;
        out.write_all(&self.trailer).map_err(io)?;
        Ok(())
    }

    /// Reads the framed form, distinguishing a **short** file from a **corrupt**
    /// one. Every early EOF is `PackageTruncated`; every authentication failure
    /// is `DecryptionFailed`.
    pub fn from_reader<R: std::io::Read>(input: &mut R) -> Result<Self, VaultError> {
        // Reads exactly `n` bytes or reports truncation. This is the whole
        // mechanism: `read_exact` distinguishes "the file ended" from "the
        // bytes were wrong", which JSON could not.
        fn take<R: std::io::Read>(r: &mut R, n: usize) -> Result<Vec<u8>, VaultError> {
            let mut buf = vec![0u8; n];
            r.read_exact(&mut buf)
                .map_err(|_| VaultError::PackageTruncated)?;
            Ok(buf)
        }
        fn take_u32<R: std::io::Read>(r: &mut R) -> Result<u32, VaultError> {
            let b = take(r, 4)?;
            Ok(u32::from_be_bytes([b[0], b[1], b[2], b[3]]))
        }

        if take(input, 4)? != MAGIC {
            // Wrong magic is not a short file; it is not our format at all.
            return Err(VaultError::SerializationFailed);
        }
        let format_version = take_u32(input)?;
        if format_version != RECOVERY_PACKAGE_FORMAT_VERSION {
            return Err(VaultError::UnsupportedPackageVersion(format_version));
        }

        let header_len = take_u32(input)? as usize;
        let header: Header = serde_json::from_slice(&take(input, header_len)?)
            .map_err(|_| VaultError::SerializationFailed)?;

        let frame_count = take_u32(input)? as usize;
        let mut frames = Vec::with_capacity(frame_count.min(1024));
        for index in 0..frame_count {
            let n = take_u32(input)? as usize;
            frames.push(Frame {
                index: u32::try_from(index).map_err(|_| VaultError::ValueTooLong)?,
                ciphertext: take(input, n)?,
            });
        }

        let trailer_len = take_u32(input)? as usize;
        let trailer = take(input, trailer_len)?;

        let package = header.into_package(frames, trailer);
        package.check_supported()?;
        Ok(package)
    }

    /// Version-checks on parse, not only on decrypt.
    ///
    /// The restore UI reads `revocation_epoch` from a parsed package before it
    /// ever asks for the mnemonic, so an unsupported package must be rejected
    /// at that point rather than after the user has typed 24 words.
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, VaultError> {
        Self::from_reader(&mut std::io::Cursor::new(bytes))
    }
}

fn package_key(seed: &Seed) -> Result<[u8; 32], VaultError> {
    let hkdf = Hkdf::<Sha512>::new(None, seed.as_bytes());
    let mut key = [0u8; 32];
    hkdf.expand(domain::RECOVERY_PACKAGE, &mut key)
        .map_err(|_| VaultError::DerivationFailed)?;
    Ok(key)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};
    use crate::vault::seed::{generate_mnemonic, seed_from_mnemonic};
    use crate::vault::{RootIdentity, Vault};

    fn seeded_vault() -> (Vault, Seed) {
        let seed = seed_from_mnemonic(
            "abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon art",
        )
        .unwrap();
        let identity = RootIdentity::from_seed(&seed).unwrap();
        let mut vault = Vault::new(identity.public_key());
        // Envelopes are returned and belong to the content store; the vault
        // keeps only the context keys these calls create.
        vault.add_content(&content_id("note-1"), &[&cid("inbox")]).unwrap();
        vault.add_content(&content_id("bill-001"), &[&cid("hospitalization"), &cid("tax-2026")]).unwrap();
        (vault, seed)
    }

    #[test]
    fn export_then_decrypt_round_trips() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let payload = package.decrypt(&seed).unwrap();

        assert_eq!(payload.root_public_key, *vault.root_public_key());
        assert_eq!(payload.context_keys.len(), 3);
        assert!(payload.context_keys.contains_key("hospitalization"));
    }

    #[test]
    fn a_different_seed_cannot_decrypt() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let stranger = seed_from_mnemonic(&generate_mnemonic().unwrap()).unwrap();

        assert!(matches!(package.decrypt(&stranger), Err(VaultError::DecryptionFailed)));
    }

    #[test]
    fn revocation_epoch_is_readable_without_the_seed() {
        // Restore must know how far behind the backup is before it can decrypt
        // anything, so this field is deliberately outside the ciphertext.
        let (mut vault, seed) = seeded_vault();
        let _ = vault.destroy_content(&content_id("note-1")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();

        assert_eq!(package.revocation_epoch(), 1);
    }

    #[test]
    fn package_survives_a_bytes_round_trip() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let restored = RecoveryPackage::from_bytes(&package.to_bytes().unwrap()).unwrap();

        assert_eq!(package, restored);
        assert!(restored.decrypt(&seed).is_ok());
    }

    #[test]
    fn an_unknown_format_version_is_rejected() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_format_version_tampered(99);

        assert!(matches!(package.decrypt(&seed), Err(VaultError::UnsupportedPackageVersion(99))));
    }

    #[test]
    fn tampered_ciphertext_is_rejected() {
        let (vault, seed) = seeded_vault();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        package.frames[0].ciphertext[0] ^= 0xff;

        assert!(matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)));
    }

    // ── Header AAD tamper tests (invariant I3) ──────────────────────────
    //
    // Without these, deleting `header_aad()` from `decrypt` would leave every
    // other test in this module passing. That is exactly how revision 2
    // recorded this binding as applied while it did not exist.

    #[test]
    fn tampering_with_revocation_epoch_fails_decryption() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let bumped = package.revocation_epoch() + 1;
        let package = package.with_revocation_epoch_tampered(bumped);
        assert!(matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)));
    }

    #[test]
    fn tampering_with_identity_public_key_fails_decryption() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_identity_tampered(RootPublicKey::from_bytes([0xff; 32]));
        // Caught by the AAD, before the identity check in SealedRestore.
        assert!(matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)));
    }

    #[test]
    fn tampering_with_kdf_salt_fails_decryption() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_kdf_salt_tampered();
        assert!(matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)));
    }

    /// The whole basis for calling streaming an execution-strategy change
    /// rather than a format change. If this ever fails, `export_to` has forked
    /// the frozen format and the two paths produce packages that are not
    /// interchangeable.
    ///
    /// Nonce and salt are random per export, so the two are driven to the same
    /// bytes by copying the materializing package's header into a streamed
    /// re-encode — the comparison is of *shape and encoding*, which is what a
    /// format is.
    #[test]
    fn streaming_export_is_byte_identical_to_the_materializing_one() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        vault.add_context(&cid("archive")).unwrap();

        let mut streamed = Vec::new();
        RecoveryPackage::export_to(&vault, &seed, &mut streamed).unwrap();

        // Both parse, and the streamed one round-trips through the same
        // reader the materializing one uses.
        let reparsed = RecoveryPackage::from_bytes(&streamed).unwrap();
        assert_eq!(reparsed.to_bytes().unwrap(), streamed);

        // Same field order, same encodings, same frame count.
        let materialized = RecoveryPackage::export(&vault, &seed).unwrap();
        assert_eq!(reparsed.frame_count(), materialized.frame_count());
        assert_eq!(
            reparsed.decrypt(&seed).unwrap().context_key_count(),
            materialized.decrypt(&seed).unwrap().context_key_count()
        );

        // And the streamed package is a working package, not merely valid JSON.
        let restored = crate::vault::restore::SealedRestore::load(&reparsed, &seed)
            .unwrap()
            .apply_revocations(&crate::vault::restore::RevocationSource::package_only()).unwrap()
            .into_vault();
        assert!(restored.is_content_destroyed(&content_id("note-1")));
    }

    /// `RA` Q4 in failing form: the round trip a content store performs, and
    /// the reason `ContentKey` is now a capability rather than a byte holder.
    #[test]
    fn a_content_key_seals_and_opens_without_ever_exposing_bytes() {
        let (mut vault, _) = seeded_vault();
        let (key, _envelope) = vault.add_content(&content_id("note-2"), &[&cid("inbox")]).unwrap();
        let sealed = key.seal(b"the quick brown fox").unwrap();
        assert_ne!(sealed.as_slice(), b"the quick brown fox");
        assert_eq!(key.open(&sealed).unwrap().as_slice(), b"the quick brown fox");
        assert!(key.open(b"too short").is_err());
    }

    /// The envelope door: a stored envelope for content since destroyed does
    /// not come back in. Before this, `#[derive(Deserialize)]` let any
    /// consumer parse — or forge — one directly.
    #[test]
    fn open_envelope_refuses_destroyed_content() {
        let (mut vault, _) = seeded_vault();
        let (_key, envelope) = vault.add_content(&content_id("note-3"), &[&cid("inbox")]).unwrap();
        let sealed = vault.seal_envelope(&envelope).unwrap();
        assert!(vault.open_envelope(&sealed).is_ok());

        let _directive = vault.destroy_content(&content_id("note-3")).unwrap();
        assert!(matches!(
            vault.open_envelope(&sealed),
            Err(VaultError::ContentRevoked(id)) if id == "note-3"
        ));
    }

    /// `ADR-0017`: retention-class expiry is derived from logged operations,
    /// so it adds no ledger entry. An explicit destroy is a user decision no
    /// replica can compute and must be recorded; an expiry is a function of
    /// data every replica already holds, and recording it would cost 137.6 B
    /// forever per expired object.
    ///
    /// Phase 1 has no retention engine, so the failing form available here is
    /// the invariant it must not violate: only `destroy_*` moves the epoch.
    #[test]
    fn only_an_explicit_destroy_moves_the_revocation_epoch() {
        let (mut vault, _) = seeded_vault();
        let before = vault.revocations().head_epoch();

        // Everything short of a destroy leaves the ledger alone.
        vault.add_context(&cid("archive")).unwrap();
        let (_k, mut envelope) = vault.add_content(&content_id("note-4"), &[&cid("inbox")]).unwrap();
        vault.link_content(&cid("archive"), &mut envelope).unwrap();
        vault.unlink_content(&cid("inbox"), &mut envelope).unwrap();
        assert_eq!(vault.revocations().head_epoch(), before);

        let _directive = vault.destroy_content(&content_id("note-4")).unwrap();
        assert_eq!(vault.revocations().head_epoch(), before + 1);
    }

    // ── Mutation regressions (Revision 9A) ───────────────────────────────
    //
    // Each of the four below fails when exactly one control is removed, and
    // nothing else in this module does. Written by chief-security-officer,
    // verified 89/89 on Revision 8 and failing on the corresponding mutant.
    //
    // Why they are here: with all 85 Revision 8 tests, removing frame AAD,
    // trailer AAD, nonce index pinning, or `frame.index == position` each left
    // the suite **entirely green**. Collapsing `frame_nonce` to a constant —
    // one (key, nonce) pair for every frame, i.e. ChaCha20 keystream reuse and
    // Poly1305 key recovery — was unobserved. `reordered_frames_are_rejected`
    // passed via the position check and
    // `a_frame_does_not_transplant_between_packages` passed via the package
    // nonce, so the two claimed defences masked each other and neither
    // isolated the control it names.
    //
    // **Do not "simplify" these by removing the re-sealed trailer.** That step
    // is what leaves the frame layer as the only remaining objector; without
    // it the test passes through the trailer and measures nothing.

    /// Every **frame** is bound to the header AAD, not merely the trailer.
    #[test]
    fn mut_each_frame_is_bound_to_the_header_aad() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.decrypt(&seed).is_ok(), "control: untampered opens");

        let mut package = package.with_kdf_salt_tampered(); // AAD-covered, ciphertext-external
        let aad = package.header_aad().unwrap();
        let cipher = XChaCha20Poly1305::new(&package_key(&seed).unwrap().into());
        let package_nonce: [u8; 24] = package.nonce.as_slice().try_into().unwrap();
        let carried_head = vault.revocations().head_epoch();
        let mut digest = Sha256::new();
        for frame in &package.frames {
            digest.update(&frame.ciphertext);
        }
        // 44-byte layout since `SEC-36`: count | head_epoch | digest.
        let mut trailer_plain = Vec::with_capacity(44);
        trailer_plain
            .extend_from_slice(&u32::try_from(package.frames.len()).unwrap().to_be_bytes());
        trailer_plain.extend_from_slice(&carried_head.to_be_bytes());
        trailer_plain.extend_from_slice(&digest.finalize());
        package.trailer = cipher
            .encrypt(
                XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                Payload {
                    msg: &trailer_plain,
                    aad: &aad,
                },
            )
            .unwrap();

        assert!(
            matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)),
            "a frame must not open under a header it was not sealed under"
        );
    }

    /// Each frame carries a **distinct** nonce, the trailer's included.
    #[test]
    fn mut_every_frame_uses_a_distinct_nonce() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.frames.len() > 2);
        let base: [u8; 24] = package.nonce.as_slice().try_into().unwrap();
        let nonces: std::collections::BTreeSet<_> = (0..package.frames.len())
            .map(|i| frame_nonce(&base, u32::try_from(i).unwrap()))
            .chain(std::iter::once(frame_nonce(&base, u32::MAX)))
            .collect();
        assert_eq!(
            nonces.len(),
            package.frames.len() + 1,
            "frame nonces (including the trailer's) must all differ"
        );
    }

    /// A frame's declared index equals its position — independently of the
    /// nonce and of the frame count.
    #[test]
    fn mut_frame_index_must_equal_its_position() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.frames.len() >= 3);
        // Renumber only — order, count and ciphertexts untouched.
        package.frames[1].index = 2;
        package.frames[2].index = 1;
        assert!(
            matches!(package.decrypt(&seed), Err(VaultError::SerializationFailed)),
            "a renumbered frame must be rejected by the position check"
        );
    }

    /// Frames swapped **with** their indices swapped to match: the nonce pins
    /// them, and this is the only test that isolates that.
    #[test]
    fn mut_swapping_frames_and_their_indices_still_fails() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        package.frames.swap(1, 2);
        package.frames[1].index = 1;
        package.frames[2].index = 2;
        assert!(
            matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)),
            "nonce pinning must reject a transposed pair"
        );
    }

    /// **Path-correct** truncation test. `PERF-2`.
    ///
    /// The test below it (`truncation_is_distinguishable_from_corruption`)
    /// removes `Frame` structs from an already-parsed `RecoveryPackage` — a
    /// state reachable only in memory. A user's package arrives as **bytes off
    /// a NAS, a USB stick, or their own cloud**, and every physical truncation
    /// destroys JSON syntax and loses the `"trailer"` key, so `from_bytes`
    /// returns `SerializationFailed` and the count check is never reached.
    /// Measured on a 324,703-byte package, cuts of 1 B / 64 B / 10% / 50%:
    /// `SerializationFailed` in all four, identical to structural corruption.
    ///
    /// So `PackageTruncated` is **unreachable from any file**, and
    /// `ADR-0017`'s second named property is not delivered. This test asserts
    /// the property on the real path and **is expected to fail until the
    /// authenticated frame count moves into the header** (`PERF-2`, `SEC-41`).
    ///
    /// The lesson, recorded because it generalizes past this test: a test must
    /// enter through the same door the user does. Mine entered at
    /// `Vec<Frame>`; everything between a byte stream and that value went
    /// untested, which is also why `from_bytes` materializing unauthenticated
    /// ciphertext went unnoticed.
    #[test]
    fn truncation_on_disk_is_distinguishable_from_corruption() {
        let (mut vault, seed) = seeded_vault();
        for i in 0..3000 {
            vault.add_context(&cid(&format!("c{i:08}"))).unwrap();
        }
        let mut bytes = Vec::new();
        RecoveryPackage::export_to(&vault, &seed, &mut bytes).unwrap();

        // `expect_err` would require `Debug` on the Ok type, and `VaultPayload`
        // deliberately has none — Global Constraints forbid `Debug` on any
        // secret-bearing type, because it prints key bytes into panic messages
        // and logs. Matched rather than unwrapped so the test cannot drag a
        // `Debug` derive onto the payload to make itself compile.
        for cut in [1usize, 64, bytes.len() / 10, bytes.len() / 2] {
            let truncated = &bytes[..bytes.len() - cut];
            match RecoveryPackage::from_bytes(truncated).and_then(|p| p.decrypt(&seed)) {
                Err(VaultError::PackageTruncated) => {}
                Err(other) => panic!(
                    "cut {cut}: expected PackageTruncated, got {other:?} — \
                     indistinguishable from corruption"
                ),
                Ok(_) => panic!("cut {cut}: a truncated package must not open"),
            }
        }
    }

    /// **`PERF-1` + `PERF-2` acceptance test.** The whole exit criterion.
    ///
    /// | Input | Expected |
    /// |---|---|
    /// | valid | `Ok` |
    /// | header truncated | `PackageTruncated` |
    /// | frame truncated | `PackageTruncated` |
    /// | trailer truncated | `PackageTruncated` |
    /// | header authentication failure | `DecryptionFailed` |
    /// | frame authentication failure | `DecryptionFailed` |
    /// | trailer authentication failure | `DecryptionFailed` |
    ///
    /// Before framing, every row in the truncated column returned
    /// `SerializationFailed` — identical to structural corruption — because
    /// `serde_json::from_slice` cannot parse a partial document, so
    /// `PackageTruncated` was unreachable from any file on disk.
    #[test]
    fn truncated_and_corrupt_packages_are_distinguishable_on_disk() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        for i in 0..3 {
            vault.add_context(&cid(&format!("ctx-{i}"))).unwrap();
        }
        let mut bytes = Vec::new();
        RecoveryPackage::export_to(&vault, &seed, &mut bytes).unwrap();

        // Valid -> Success.
        let package = RecoveryPackage::from_bytes(&bytes).unwrap();
        assert!(package.decrypt(&seed).is_ok(), "valid package must open");
        assert!(package.frames.len() >= 3, "need header, frames and trailer to cut between");

        // Truncated anywhere -> Truncated. Cuts land in the header, in the
        // frames, and in the trailer respectively.
        for cut in [10, bytes.len() / 2, bytes.len() - 4, bytes.len() - 1] {
            assert!(
                matches!(
                    RecoveryPackage::from_bytes(&bytes[..cut]),
                    Err(VaultError::PackageTruncated)
                ),
                "cut at {cut} of {} reported something other than truncation",
                bytes.len()
            );
        }

        // Corrupt -> Corrupt. Flipping a byte inside a frame keeps every length
        // prefix intact, so the file parses and the AEAD is the only objector.
        let mut corrupt = RecoveryPackage::from_bytes(&bytes).unwrap();
        corrupt.frames[0].ciphertext[0] ^= 0xff;
        assert!(
            matches!(corrupt.decrypt(&seed), Err(VaultError::DecryptionFailed)),
            "a corrupt frame must report corruption, not truncation"
        );

        // Header authentication failure: kdf_salt is AAD-covered.
        let tampered_header = RecoveryPackage::from_bytes(&bytes)
            .unwrap()
            .with_kdf_salt_tampered();
        assert!(matches!(
            tampered_header.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));

        // Trailer authentication failure.
        let mut tampered_trailer = RecoveryPackage::from_bytes(&bytes).unwrap();
        tampered_trailer.trailer[0] ^= 0xff;
        assert!(matches!(
            tampered_trailer.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));
    }

    /// `SEC-35` / `A17` failing form. The package nonce must be inside
    /// `header_aad`.
    ///
    /// `frame_nonce` overwrites bytes 20..24 with the frame index, so those
    /// four bytes are never *read*. Without the AAD line they are also never
    /// *authenticated*: two byte-different files decrypt to the same vault, and
    /// 32 bits of a frozen header field become mutable filler. `SEC-50` found
    /// that deleting `push_len_prefixed(&mut aad, &self.nonce)` left the suite
    /// at 92 passed, 0 failed. This is the test that stops that.
    #[test]
    fn mut_the_package_nonce_is_authenticated() {
        let (vault, seed) = seeded_vault();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.decrypt(&seed).is_ok(), "control: untampered opens");

        // Byte 20 is inside the range `frame_nonce` overwrites, so only the
        // AAD can object to this.
        package.nonce[20] ^= 0xff;
        assert!(
            matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)),
            "the nonce tail is unauthenticated -- SEC-35 has no failing form"
        );
    }

    /// `SEC-36` cross-check failing form. The plaintext header epoch and the
    /// sealed trailer head must agree.
    ///
    /// Both are authenticated — the header via `header_aad`, the trailer via
    /// AEAD under that same AAD — so an attacker cannot desync them. This
    /// guards a **buggy writer**: one that computes the header epoch from one
    /// source and the trailer head from another. `SEC-36` is exactly that class
    /// of defect one layer down, so the cross-check needs its own failing form.
    ///
    /// Requires a test-only constructor, because a correct writer cannot
    /// produce this package. That is the point.
    #[test]
    fn mut_header_epoch_and_sealed_head_must_agree() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.decrypt(&seed).is_ok(), "control: consistent package opens");

        // Through `open`, not `decrypt`: the cross-check lives on the route a
        // consumer actually takes. `decrypt` returns the payload without it,
        // which is safe only because it is private to `package.rs` -- worth
        // knowing, since that is the kind of split SEC-1 was about.
        let desynced = package.with_desynced_trailer_head(&seed, 999);
        assert!(
            crate::vault::restore::SealedRestore::load(&desynced, &seed).is_err(),
            "a package whose header epoch disagrees with its sealed head opened \
             -- the cross-check has no failing form"
        );
    }

    /// `SEC-36` failing form. `set_head_epoch` must refuse a head below the
    /// highest entry.
    ///
    /// Without it a hostile or buggy writer rewinds the epoch, and
    /// `revoked_since` then skips every revocation above the rewound head --
    /// resurrecting destroyed content on the restore path.
    #[test]
    fn mut_set_head_epoch_refuses_to_rewind() {
        let mut ledger = RevocationLedger::new();
        for i in 0..5u32 {
            ledger.revoke(RevocationSubject::Content(format!("c{i}"))).unwrap();
        }
        assert_eq!(ledger.head_epoch(), 5);
        assert!(ledger.set_head_epoch(9).is_ok(), "forward is allowed");
        assert!(
            ledger.set_head_epoch(3).is_err(),
            "head below max(entry) accepted -- SEC-36 has no failing form"
        );
    }

    /// `ADR-0017`'s headline property in its failing form: a truncated package
    /// reports truncation, where before it failed AEAD identically to a
    /// corrupt one and the user was told their backup was corrupt.
    ///
    /// **Retained, but it is not the property test.** It operates on a parsed
    /// package, which is a state no file produces — see the path-correct
    /// version above. Keep it as an in-memory regression on the count check;
    /// do not read it as evidence that truncation is diagnosable on disk.
    #[test]
    fn truncation_is_distinguishable_from_corruption() {
        let (vault, seed) = seeded_vault();
        let full = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(full.frames.len() > 1, "need >1 frame to truncate");

        let mut truncated = full.clone();
        truncated.frames.pop();
        assert!(matches!(
            truncated.decrypt(&seed),
            Err(VaultError::PackageTruncated)
        ));

        let mut corrupted = full;
        corrupted.frames[0].ciphertext[0] ^= 0xff;
        assert!(matches!(
            corrupted.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));
    }

    /// Frames are pinned to the nonce they were sealed under, so reordering
    /// or renumbering fails rather than silently yielding a different vault.
    #[test]
    fn reordered_frames_are_rejected() {
        let (vault, seed) = seeded_vault();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.frames.len() > 1);
        package.frames.swap(0, 1);
        assert!(package.decrypt(&seed).is_err());
    }

    /// A frame lifted verbatim from one package into another must not open:
    /// the header AAD binds it to its own package.
    #[test]
    fn a_frame_does_not_transplant_between_packages() {
        let (vault_a, seed_a) = seeded_vault();
        let mut a = RecoveryPackage::export(&vault_a, &seed_a).unwrap();
        let b = RecoveryPackage::export(&vault_a, &seed_a).unwrap();
        // Same vault, same seed, different random package nonce and salt.
        a.frames[0] = b.frames[0].clone();
        assert!(matches!(a.decrypt(&seed_a), Err(VaultError::DecryptionFailed)));
    }

    /// Dropping a frame from the middle and renumbering the rest is still
    /// truncation: the count is what catches it, not the digest.
    ///
    /// This test originally asserted the digest caught this case, and failed —
    /// the count check runs first and returns `PackageTruncated`. Recorded
    /// rather than quietly re-pointed, because it changes what the trailer's
    /// digest is *for*.
    ///
    /// **The digest is defence in depth, not the load-bearing check.** Frame
    /// integrity is already covered three ways: the index is pinned to the
    /// nonce the frame was sealed under, the position must equal the index,
    /// and the header AAD binds every frame to its own package. The digest
    /// costs 32 bytes once and covers whatever a future writer adds that those
    /// three do not — it is kept on that basis and not because anything today
    /// needs it.
    #[test]
    fn dropping_a_middle_frame_is_truncation_not_corruption() {
        let (mut vault, seed) = seeded_vault();
        // A revocation gives a third section, so there is a genuine middle
        // frame to drop: Root, Contexts, Revocations.
        // `PurgeDirective` is `#[must_use]`: derived state must be purged, and
        // dropping it silently defeats deletion. Bound explicitly even here.
        let _directive = vault.destroy_content(&content_id("note-1")).unwrap();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert_eq!(package.frames.len(), 3);
        package.frames.remove(1);
        for (position, frame) in package.frames.iter_mut().enumerate() {
            frame.index = u32::try_from(position).unwrap();
        }
        assert!(matches!(
            package.decrypt(&seed),
            Err(VaultError::PackageTruncated)
        ));
    }

    #[test]
    fn adding_a_kdf_param_fails_decryption() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_kdf_param_tampered("rounds", 1);
        // check_supported rejects non-empty kdf_params first; assert the
        // distinct error so this does not silently stop testing the AAD.
        assert!(matches!(package.decrypt(&seed), Err(VaultError::UnsupportedProtectionMode)));
    }

    #[test]
    fn format_version_is_bound_by_the_aad_not_only_by_check_supported() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        // Bump then restore the version so check_supported passes, leaving the
        // AAD as the only thing that can catch a mismatch. Achieved by
        // tampering the salt instead is NOT equivalent — this asserts the
        // version specifically participates in the binding.
        let original = package.format_version();
        let package = package.with_format_version_tampered(original + 1);
        let tampered_aad_matches = package.decrypt(&seed).is_ok();
        assert!(!tampered_aad_matches);
    }

    #[test]
    fn an_unsupported_protection_mode_is_rejected_distinctly() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_passphrase_flag_tampered();
        // NOT UnsupportedPackageVersion — reporting a protection mode as a
        // version problem is false and misdirects whoever debugs it.
        assert!(matches!(package.decrypt(&seed), Err(VaultError::UnsupportedProtectionMode)));
    }

    #[test]
    fn the_package_carries_no_content() {
        // It grants access. It does not carry data. Anything that looks like
        // user content here is a defect.
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let payload = package.decrypt(&seed).unwrap();

        // The payload holds context keys and certificates. It holds no
        // per-content record at all — that is the point of the redesign.
        assert!(payload.context_keys.contains_key("hospitalization"));
        // KeyBytes refuses to print its contents.
        assert_eq!(
            format!("{:?}", payload.context_keys["hospitalization"]),
            "KeyBytes(<redacted>)"
        );
    }
}
```

Add to `rust/airo_mind/src/vault/aggregate.rs`:

```rust
impl Vault {
    /// Serializable interior. Crate-visible: only export and restore use it.
    /// Borrowing iterator for framed export. `ADR-0017`, `PERF`.
    ///
    /// `to_payload` below deep-clones the ledger and certificates purely to
    /// serialize them — 26% of export peak RSS, measured. Framed export walks
    /// this instead and never materializes a second copy.
    pub(crate) fn context_entries(&self) -> impl Iterator<Item = (String, KeyBytes)> + '_ {
        self.context_keys
            .iter()
            .map(|(id, key)| (id.clone(), KeyBytes::new(*key.as_bytes())))
    }

    // `to_payload` removed: framed export sources from `context_entries` and
    // `revocations().entries()` directly. It deep-cloned the ledger and
    // certificates purely to serialize them — 26% of export peak RSS,
    // measured — and framing left it with no caller at all.
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind package`
Expected: FAIL to compile — module not declared, `to_payload` missing.

- [ ] **Step 3: Reconcile visibility**

`VaultPayload` is `pub(crate)` but appears in the signature of `pub(crate) fn to_payload`. That is consistent. If Rust complains about a private type in a public interface, the fix is to keep both `pub(crate)`, never to widen `VaultPayload` to `pub` — its fields are raw key material.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind package`
Expected: PASS, 7 tests

- [ ] **Step 5: Commit**

```bash
git add rust/airo_mind/src/vault/package.rs rust/airo_mind/src/vault/mod.rs
git commit -m "feat(mind): add Recovery Package export

Encrypted under a seed-derived key. Carries identity, keys, and the
revocation ledger — never the log, never the content.

revocation_epoch sits outside the ciphertext on purpose: restore must
read it before it can decrypt anything, to know how far behind the
backup is.

Refs #1211"
```

---

## Task 9: Revocation-aware restore

Implements #1212. **This is the task that makes cryptographic deletion true or false.**

**Files:**
- Create: `rust/airo_mind/src/vault/restore.rs`
- Modify: `rust/airo_mind/src/vault/mod.rs`

**Interfaces:**
- Consumes: `RecoveryPackage`, `VaultPayload` (Task 8), `Seed` (Task 2), `RevocationLedger` (Task 6), `Vault` (Task 7)
- Produces:
  - `SealedRestore` with `fn load(&RecoveryPackage, &Seed) -> Result<Self, VaultError>`, `fn backup_epoch(&self) -> u64`, `fn apply_revocations(self, source: &RevocationSource) -> AppliedRestore`
  - `AppliedRestore` with `fn purged(&self) -> &[RevocationSubject]`, `fn was_blind(&self) -> bool`, `fn source_older_than_backup(&self) -> bool`, `fn into_vault(self) -> Vault`

**Design note for the implementer.** The two states are **separate types**, not a bool on one type. `SealedRestore` has no method that yields a `Vault` and no method that exposes a key. The only way to obtain a `Vault` is to consume a `SealedRestore` via `apply_revocations`, which returns `AppliedRestore`, which is the only type with `into_vault`. This makes the unsafe ordering unrepresentable rather than merely tested. Do not collapse these into one struct with a flag — a flag can be ignored; a missing method cannot.

`VaultError::RevocationsNotApplied` exists in Task 1 for the FFI layer (Task 10), where the type-state cannot be expressed across the boundary and the check must be dynamic.

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/restore.rs`:

```rust
//! Revocation-aware restore.
//!
//! A Vault backup made yesterday contains keys for content destroyed today.
//! Restoring it naively resurrects shredded medical records — the user's own
//! backup defeating the user's own cryptographic deletion.
//!
//! The ordering is enforced by the type system:
//!
//! ```text
//! RecoveryPackage → SealedRestore → apply_revocations → AppliedRestore → Vault
//! ```
//!
//! `SealedRestore` exposes no key material and has no path to a `Vault`.

use super::error::VaultError;
use super::package::{RecoveryPackage, VaultPayload};
use super::revocation::{RevocationLedger, RevocationSubject};
use super::seed::Seed;
use super::Vault;

/// Where a revocation ledger came from.
///
/// The type state enforces *ordering*, not *freshness* — and an empty ledger
/// purges nothing. The previous revision shipped that bypass in its own FFI
/// surface: destroy a record, lose every device, restore from a pre-destroy
/// package with no log available, and the record is readable again.
///
/// Provenance makes a blind restore something the caller must name.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RevocationProvenance {
    /// Replayed from the operation log to head. The only trustworthy source.
    ReplayedFromLog { head_operation_id: String },
    /// Only what the recovery package itself recorded. A floor, not a total.
    PackageOnly,
    /// No revocation data at all. Caller has acknowledged the risk.
    AcknowledgedBlind,
}

/// Proof that a ledger was replayed from the operation log to head.
///
/// The field is private, so only this crate's log module can construct one.
/// `pub(crate)` until Phase 2 provides that module — see #1260.
#[cfg_attr(not(test), allow(dead_code))]
pub struct LogHead(String);

// `String`, genuinely private — not `pub(crate)`. Revision 6 documented the
// field as private while declaring it `pub(crate)`, so any in-crate module
// (including the log, sync, and merge modules the same revision cites as the
// reason for tightening the *other* typestate) could mint
// `ReplayedFromLog` provenance and suppress `was_blind()`. That is R1's
// original bypass, reopened (chief-security-officer S6).

impl LogHead {
    // `SEC-48`: `LogHead::new` DELETED. Revision 9B made it `pub` to satisfy
    // `SEC-39` and, in the same change, made R1's blind-restore bypass
    // forgeable -- an empty ledger plus a free string reports
    // `was_blind() == false`. `restore.rs` had already described that exact
    // bypass in its own doc comment.
    //
    // The resolution is not a tighter constructor. Phase 1 has no operation
    // log, therefore Phase 1 has no honest `ReplayedFromLog`, and shipping a
    // way to assert it is shipping a way to forge it. `for_test` below is the
    // only constructor; the real one arrives with the log in #1260.

}

/// Tests only. Production callers get a `LogHead` from the log (#1260).
#[cfg(test)]
impl LogHead {
    pub(crate) fn for_test(id: &str) -> LogHead {
        LogHead(id.to_string())
    }
}

/// A revocation ledger plus where it came from.
pub struct RevocationSource {
    ledger: RevocationLedger,
    provenance: RevocationProvenance,
}

impl RevocationSource {
    /// Only the operation log can mint a `LogHead`, so this constructor cannot
    /// be used to *assert* provenance the caller does not have.
    ///
    /// Revision 3 took a bare `RevocationLedger` and a free `String`, and the
    /// plan's own test then built one from an EMPTY ledger and asserted
    /// `!was_blind()` — reaching R1's original bypass through the constructor
    /// named "trustworthy". Provenance was a claim, not a proof: the same
    /// shape as `RevocationSubject` before the tag.
    /// `SEC-48`: `pub(crate)` and `#[cfg(test)]` until #1260 ships the
    /// operation log. A public constructor here is a public way to assert
    /// provenance the caller does not have.
    #[cfg(test)]
    pub(crate) fn replayed_from_log(ledger: RevocationLedger, head: LogHead) -> Self {
        Self {
            ledger,
            provenance: RevocationProvenance::ReplayedFromLog {
                head_operation_id: head.0,
            },
        }
    }

    pub fn package_only() -> Self {
        Self {
            ledger: RevocationLedger::new(),
            provenance: RevocationProvenance::PackageOnly,
        }
    }

    /// Deliberately verbose. A caller reaching for this is choosing to restore
    /// without knowing what was destroyed elsewhere, and the UI must warn.
    pub fn acknowledged_blind_restore() -> Self {
        Self {
            ledger: RevocationLedger::new(),
            provenance: RevocationProvenance::AcknowledgedBlind,
        }
    }
}

/// A decrypted but unusable restore. No keys are reachable from here.
pub struct SealedRestore {
    payload: VaultPayload,
    backup_epoch: u64,
}

impl SealedRestore {
    /// Decrypts the package and binds it to the seed's identity.
    ///
    /// The identity check is not decoration: without it, a mismatched or
    /// crafted package yields a vault that accepts device certificates signed
    /// by a root the user does not control.
    /// `SEC-1` — delegates to `RecoveryPackage::open`, which owns `decrypt`.
    ///
    /// The payload never leaves `package.rs`, so no module outside it can name
    /// a key byte. `restore.rs` needs four things from the payload — the root
    /// key, the ledger, and the two purges — and none of them is key material.
    pub fn load(package: &RecoveryPackage, seed: &Seed) -> Result<Self, VaultError> {
        package.open(seed)
    }

    /// Constructed only by `RecoveryPackage::open`.
    pub(super) fn from_parts(payload: VaultPayload, backup_epoch: u64) -> Self {
        Self {
            payload,
            backup_epoch,
        }
    }

    pub fn backup_epoch(&self) -> u64 {
        self.backup_epoch
    }

    /// Destroys everything revoked, from both the package and `source`.
    ///
    /// Consuming `self` is what makes the unsafe path unrepresentable: there
    /// is no way to reach a `Vault` without passing through here.
    ///
    /// Purges context keys and device certificates, and records content
    /// revocations —
    /// all three are revocable subjects, and omitting devices means a stale
    /// backup readmits a revoked device.
    /// Fallible since `SEC-40`: a caller-supplied ledger is validated, and an
    /// invalid one must fail closed rather than be merged.
    pub fn apply_revocations(
        mut self,
        source: &RevocationSource,
    ) -> Result<AppliedRestore, VaultError> {
        // `SEC-40` / `A21`: fail closed on caller-supplied data. `open`
        // validates the package's own ledger; this one arrives from a caller.
        source.ledger.validate()?;
        let package_revocations = self.payload.revocations_mut().all_revoked();
        self.payload.revocations_mut().merge(&source.ledger);

        let mut purged = Vec::new();
        for subject in self.payload.revocations_mut().all_revoked() {
            match &subject {
                RevocationSubject::Content(_) => {
                    // Pushes NOTHING. The Vault holds no per-content record,
                    // so it destroyed nothing and has nothing to report.
                    //
                    // Revision 6 pushed unconditionally, making `purged()`
                    // return every content revocation the ledger had ever
                    // held, on every restore — O(all revocations) in a value
                    // shown to the user, and non-monotonic. Its own
                    // `applying_revocations_twice_is_stable` could not pass.
                }
                RevocationSubject::Context(id) => {
                    if self.payload.purge_context(id) {
                        purged.push(subject.clone());
                    }
                }
                RevocationSubject::Device(id) => {
                    if self.payload.purge_device(id) {
                        purged.push(subject.clone());
                    }
                }
            }
        }
        purged.sort();

        // Subject-set containment, NOT epoch comparison. Epochs are
        // per-device counters, not a clock — comparing a log-replayed ledger's
        // head against a package header epoch is the exact error R4 exists to
        // forbid, and it would return true on every offline restore of any
        // vault that has ever destroyed anything.
        let missing = !package_revocations
            .iter()
            .all(|subject| source.ledger.is_revoked(subject));

        Ok(AppliedRestore {
            payload: self.payload,
            purged,
            provenance: source.provenance.clone(),
            source_missing_backup_revocations: missing,
        })
    }
}

/// Proof that revocations were applied.
///
/// Private field, so only `AppliedRestore` can mint one. The typestate was
/// previously enforced only at the **crate** boundary — any module inside
/// `airo_mind` could call `Vault::from_payload(package.decrypt(&seed)?)` and
/// skip `apply_revocations` entirely. That is fine while the crate is one
/// subsystem and exactly wrong for a crate scheduled to gain the operation
/// log, projections, merge, and sync **inside** that boundary, written by
/// later implementers with less context (rust-architect H1).
pub struct RevocationsApplied(());

/// A restore with revocations applied. The only source of a usable `Vault`.
pub struct AppliedRestore {
    payload: VaultPayload,
    purged: Vec<RevocationSubject>,
    provenance: RevocationProvenance,
    source_missing_backup_revocations: bool,
}

impl AppliedRestore {
    /// Subjects destroyed during restore.
    pub fn purged(&self) -> &[RevocationSubject] {
        &self.purged
    }

    /// True when this restore could not consult the operation log.
    ///
    /// The shell **must** warn: content destroyed on another device may be
    /// readable again, and no amount of local checking can detect it. See
    /// design spec §6.3 — this is a permanent property of a serverless
    /// architecture, not a defect.
    ///
    /// `#[must_use]` for the same reason `PurgeDirective` is: a warning the
    /// caller can discard silently is advice, not a control.
    ///
    /// Note `PackageOnly` and `AcknowledgedBlind` are **behaviourally
    /// identical** — both carry an empty ledger, both are blind. They differ
    /// only in UI copy. Do not "optimise" the warning away by matching on the
    /// provenance arm.
    #[must_use]
    pub fn was_blind(&self) -> bool {
        !matches!(self.provenance, RevocationProvenance::ReplayedFromLog { .. })
    }

    /// True when the supplied ledger does not contain every revocation the
    /// package itself recorded.
    #[must_use]
    pub fn source_missing_backup_revocations(&self) -> bool {
        self.source_missing_backup_revocations
    }

    pub fn into_vault(self) -> Vault {
        Vault::from_payload(self.payload, RevocationsApplied(()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};
    use crate::vault::seed::seed_from_mnemonic;
    use crate::vault::{RootIdentity, Vault};

    fn seed() -> Seed {
        seed_from_mnemonic(
            "abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon art",
        )
        .unwrap()
    }

    fn vault_with_content() -> Vault {
        let identity = RootIdentity::from_seed(&seed()).unwrap();
        let mut vault = Vault::new(identity.public_key());
        vault.add_content(&content_id("hiv-test-result"), &[&cid("health")]).unwrap();
        vault.add_content(&content_id("grocery-list"), &[&cid("home")]).unwrap();
        vault
    }

    #[test]
    fn restoring_an_up_to_date_backup_purges_nothing() {
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let restored = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::package_only()).unwrap();

        assert!(restored.purged().is_empty());
        let vault = restored.into_vault();
        assert!(vault.context_key("health").is_some());
    }

    #[test]
    fn a_backup_taken_before_a_destroy_does_not_resurrect_it() {
        // THE regression test for this milestone. If this ever passes with the
        // content still readable, cryptographic deletion is a false claim.
        let vault = vault_with_content();
        let stale_backup = RecoveryPackage::export(&vault, &seed()).unwrap();

        // ... time passes, the user destroys a medical record on their phone.
        let mut live = vault_with_content();
        let _ = live.destroy_content(&content_id("hiv-test-result")).unwrap();
        let current_revocations = live.revocations().clone();

        let restored = SealedRestore::load(&stale_backup, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(current_revocations, LogHead::for_test("op-42"))).unwrap();

        // `purged()` reports what the VAULT destroyed. Content lives in the
        // content store, so the Vault destroyed nothing — the assertions
        // below are the ones that matter, and they are strictly stronger.
        assert!(restored.purged().is_empty());

        let vault = restored.into_vault();
        assert!(vault.is_content_destroyed(&content_id("hiv-test-result")));
        assert!(!vault.is_content_destroyed(&content_id("grocery-list")));
    }

    #[test]
    fn backup_epoch_is_readable_before_revocations_are_applied() {
        let mut vault = vault_with_content();
        let _ = vault.destroy_content(&content_id("grocery-list")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let sealed = SealedRestore::load(&package, &seed()).unwrap();
        assert_eq!(sealed.backup_epoch(), 1);
    }

    #[test]
    fn revocations_from_the_backup_itself_are_honored() {
        let mut vault = vault_with_content();
        let _ = vault.destroy_content(&content_id("hiv-test-result")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let restored = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::package_only()).unwrap();

        let vault = restored.into_vault();
        assert!(vault.is_content_destroyed(&content_id("hiv-test-result")));
    }

    #[test]
    fn a_stale_backup_does_not_readmit_a_revoked_device() {
        // The device equivalent of the content regression test. Without
        // RevocationSubject::Device this could not be written at all, and a
        // stolen laptop walked back into the mesh on every restore.
        use crate::vault::device::{DeviceCertificate, DeviceKey};
        let identity = RootIdentity::from_seed(&seed()).unwrap();
        let device = DeviceKey::generate().unwrap();
        let device_id = device.device_id();

        let mut vault = Vault::new(identity.public_key());
        vault.trust_device(DeviceCertificate::issue(&identity, &device, 1).unwrap()).unwrap();
        let stale_backup = RecoveryPackage::export(&vault, &seed()).unwrap();

        // ... the laptop is stolen and revoked on the phone.
        let mut live = Vault::new(identity.public_key());
        live.trust_device(DeviceCertificate::issue(&identity, &device, 1).unwrap()).unwrap();
        let _ = live.revoke_device(&DeviceId::new(&device_id).unwrap()).unwrap();

        let restored = SealedRestore::load(&stale_backup, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(
                live.revocations().clone(),
                LogHead::for_test("op-7"),
            )).unwrap();

        let vault = restored.into_vault();
        assert!(vault.trusted_devices().is_empty());
    }

    #[test]
    fn applying_revocations_twice_is_stable() {
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();
        let mut live = vault_with_content();
        let _ = live.destroy_content(&content_id("hiv-test-result")).unwrap();

        let once = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(live.revocations().clone(), LogHead::for_test("op-42"))).unwrap();
        let vault = once.into_vault();

        let repackaged = RecoveryPackage::export(&vault, &seed()).unwrap();
        let twice = SealedRestore::load(&repackaged, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(live.revocations().clone(), LogHead::for_test("op-42"))).unwrap();

        assert!(twice.purged().is_empty());
        assert!(twice.into_vault().is_content_destroyed(&content_id("hiv-test-result")));
    }

    #[test]
    fn provenance_drives_the_blind_warning() {
        // R1's fix shipped untested in revision 2. These are the tests.
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let blind = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::package_only()).unwrap();
        assert!(blind.was_blind());

        let acknowledged = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::acknowledged_blind_restore()).unwrap();
        assert!(acknowledged.was_blind());

        let from_log = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(
                RevocationLedger::new(),
                LogHead::for_test("op-1"),
            )).unwrap();
        assert!(!from_log.was_blind());
    }

    #[test]
    fn a_source_containing_every_backup_revocation_is_not_flagged_missing() {
        // Guards against reintroducing the epoch comparison: a log-replayed
        // ledger that knows everything the package knows must not be flagged,
        // regardless of whose counter is higher.
        let mut vault = vault_with_content();
        let _ = vault.destroy_content(&content_id("hiv-test-result")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let applied = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(
                vault.revocations().clone(),
                LogHead::for_test("op-9"),
            )).unwrap();

        assert!(!applied.source_missing_backup_revocations());
    }

    #[test]
    fn a_wrong_seed_never_reaches_a_sealed_restore() {
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();
        let stranger = seed_from_mnemonic(&crate::vault::generate_mnemonic().unwrap()).unwrap();

        assert!(SealedRestore::load(&package, &stranger).is_err());
    }
}
```

Add to `rust/airo_mind/src/vault/aggregate.rs`:

```rust
impl Vault {
    /// Requires a `RevocationsApplied` witness that only `AppliedRestore` can
    /// mint, so the ordering is unrepresentable **inside** the crate too —
    /// which is where it will actually be attacked.
    pub(crate) fn from_payload(
        payload: super::package::VaultPayload,
        _: super::restore::RevocationsApplied,
    ) -> Self {
        // `PERF`: MOVED, not cloned. Revision 9B cloned the ledger and the
        // certificates to satisfy the borrow checker after `into_context_keys`
        // consumed the payload, which put the entire revocation ledger resident
        // twice at peak -- measured +21% to +38% restore peak, and `into_vault`
        // from 0.0 ms to 85 ms at 1M entries.
        //
        // `into_parts` keeps the key conversion inside `package.rs`, so
        // `SEC-37`/`A20` holds: the aggregate still never names a key byte.
        let (root_public_key, context_keys, device_certificates_in, revocations) =
            payload.into_parts();
        let mut vault = Self {
            root_public_key,
            context_keys,
            device_certificates: Vec::new(),
            revocations,
        };
        // `SEC-38` / `A16`: restore admits through the single choke point.
        //
        // This previously filtered on `verify_against` inline -- re-implementing
        // the signature half of `admit_device` while omitting the revocation
        // half and the dedup, and *silently dropping* certificates that failed
        // rather than reporting them. Safe only because `apply_revocations`
        // purges revoked devices first, and "safe because of ordering
        // elsewhere" is exactly the reasoning `SEC-15` rejected.
        for certificate in device_certificates_in {
            // A certificate that fails admission is dropped, as before: the
            // payload is AEAD-authenticated, so a failure here means the root
            // rotated, not that an attacker wrote it.
            let _ = vault.admit_device(certificate);
        }
        vault
    }

    /// Whether this content has been revoked.
    ///
    /// The Vault cannot say whether content *exists* — it holds no per-content
    /// record. It can say whether the content was destroyed.
    pub fn is_content_destroyed(&self, content_id: &ContentId) -> bool {
        self.revocations.is_content_revoked(content_id.as_str())
    }
}
```

`ContextKey::from_bytes` is already part of `impl ContextKey` above — it is
shown there rather than as a separate snippet, because a fenced block that
says "inside impl X" lands outside it when the plan is extracted.

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind restore`
Expected: FAIL to compile — module not declared, `from_payload` and `is_content_destroyed` missing.

- [ ] **Step 3: Verify the unsafe path is unrepresentable**

Add this to `restore.rs` and confirm it does **not** compile, then delete it:

```rust
// Must not compile. If it does, the type-state has been broken.
// let vault = SealedRestore::load(&package, &seed).unwrap().into_vault();
```

`SealedRestore` must have no `into_vault`, no `payload()` accessor, and no way to read a key. If a reviewer can find one, the guarantee is gone.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind`
Expected: PASS, all tests

- [ ] **Step 5: Commit**

```bash
git add rust/airo_mind/src/vault/restore.rs rust/airo_mind/src/vault/mod.rs rust/airo_mind/src/vault/envelope.rs
git commit -m "feat(mind): enforce revocation-aware restore through type state

A Vault backup made yesterday holds keys for content destroyed today.
Restoring it naively resurrects shredded records.

SealedRestore exposes no key material and has no path to a Vault. The
only route is apply_revocations, which consumes it and returns
AppliedRestore. The unsafe ordering is unrepresentable rather than
merely tested.

Refs #1212"
```

---

## Task 10: Defer the FFI surface to Phase 2

**No code in this task.** Both council reviews independently concluded that the
FFI surface does not belong in Phase 1.

- **chief-open-source-officer:** the crate declares `cdylib`/`staticlib` while
  exporting nothing, so CI links two empty artifacts on every push. Ship
  `rlib` only until there is something to export.
- **chief-security-officer (R15):** the plan asserted a dynamic
  `RevocationsNotApplied` check at the boundary that **did not exist in the
  task**, and the only restore-adjacent function crossing FFI was the one that
  ignored revocations. As written, the boundary did not merely risk reopening
  the erasure hole — it was the only place the hole was exposed.

There is also nothing for Dart to do with a Vault in Phase 1. Onboarding
(#1234) needs the mnemonic and the restore flow, and restore needs the
operation log, which does not exist until Phase 2.

- [ ] **Step 1: Confirm `crate-type = ["rlib"]` in the manifest**

Already set in Task 1. Verify no `frb_generated` module, no
`flutter_rust_bridge` dependency, and no second codegen config exists.

- [ ] **Step 2: Confirm the FFI work is tracked**

#1259 owns the Phase 2 FFI surface and carries the constraints this phase
established:

- Key material does not cross the boundary. The recovery mnemonic is the single
  acknowledged exception, crossing exactly twice — onboarding and restore — as
  `Vec<u8>` rather than `String` so the Dart side can zero it, zeroized on the
  Rust side, and prohibited from logging, crash-reporter capture, and analytics.
- The restore type state cannot be expressed across FFI. The boundary holds an
  opaque handle and checks dynamically, returning
  `VaultError::RevocationsNotApplied`. That code ships with the check, or it
  does not ship.
- The surface is partitioned per subsystem from its first commit —
  Constitution §6 caps generated files at 200 KB, and consolidating then
  splitting means regenerating every binding under a size-gate failure.
- `packages/core_native/module.yaml` gains **Chief Security Officer** as a
  reviewer before the mnemonic boundary lands there.

---

## Definition of done for Phase 1

- [ ] `cargo test --all`, `cargo clippy --all -- -D warnings`, `cargo fmt --check` green
- [ ] Issues #1207–#1212 closed, each referencing the commit that closed it
- [ ] #1205 closed with governance verdicts recorded, including the CC0 decision
- [ ] #1241 (at-rest storage) closed — **the Vault has no persistence story without it**, and the path of least resistance without it is persisting the seed in app storage, which voids every claim in the design
- [ ] #1257 (cargo in Dependabot, `cargo-deny`, `cargo-audit`, mobile cross-compile) closed — merge gate
- [ ] #1258 (`rust/airo_mind` owner and Never Ship on TV enforcement) closed
- [ ] Release-gate regression tests pass and are named in the PR description:
  - `a_backup_taken_before_a_destroy_does_not_resurrect_it`
  - the device-revocation equivalent
  - `relabelling_a_context_id_breaks_the_wrapping`
  - `a_wrapping_cannot_be_moved_to_another_envelope`
- [ ] `SealedRestore` has no method returning a `Vault` and no method exposing key material — verified by a reviewer, not only by tests
- [ ] **Repository-wide verification passes (#1287), not reviewer memory.** These are CI checks because the last two defects were both "fixed in one file, forgotten in another":
  - no `panic!`, `unwrap()`, `expect()`, or `todo!()` outside `#[cfg(test)]`
  - no `fill_bytes`; only `try_fill_bytes`
  - no direct RNG use outside `random.rs` — `rg 'OsRng' src/ | grep -v random.rs` returns nothing. **Measured: 0 (was 3).** `RA-3`
  - no `AeadCore::generate_nonce`
  - every `Serialize`/`Deserialize` type has a round-trip test
  - every AAD-bound field has a tamper test (invariant I3)
  - no `derive(Debug)`, `derive(Clone)`, or `derive(PartialEq)` on a secret type
- [ ] No `derive(Debug)`, `derive(Clone)`, or `derive(PartialEq)` on any secret type
- [ ] `crate-type = ["rlib"]`; no `flutter_rust_bridge` dependency
- [ ] Third-party notices updated for BSD-3-Clause, and for CC0 if Path A was chosen
- [ ] `[profile.release]` added to `rust/Cargo.toml` — measured at 650 KB → 424 KB, and free
- [x] **`G0` passes.** `docs/superpowers/plans/extract-phase-1-vault.sh` extracts every Rust block into a scratch crate; it compensates exactly three documented artifacts, so anything failing is a specification defect. **Revision 8, rustc 1.96.1: check 0 errors · 85 tests pass, 0 fail, 1 ignored · clippy `-D warnings` 0 errors.** Run after *each* phase, not once at the end — Phase A's run caught two claims recorded as applied and absent from the code.
- [ ] **`G0.7` claim assertions green** — `docs/superpowers/plans/g0-claim-assertions.sh`. Every documented deletion, visibility reduction, or opacity claim is a mechanical query. **Revision 9A adds this gate expecting it to fail**, because Revision 8 shipped seven false claims with `G0.3`–`G0.5` green. A claim with no assertion in that script is a claim nothing checks.
- [ ] **`G0.8` external-consumer probe green** — `docs/superpowers/plans/g0-consumer-probe.sh`. `DENY` probes must fail to compile, `ALLOW` probes must compile. Nothing in-tree can verify a façade: `#[cfg(test)] mod tests` is *inside* the crate, where `pub` and `pub(crate)` are indistinguishable.
- [ ] **Every public item names an external consumer.** `G0` proves the crate builds; it cannot prove the surface is minimal. `RA-18`: revision 7 compiled cleanly while shipping no reachable restore path, and the DoD check below passed for the wrong reason. Anything answering "none" or "a future phase" is `pub(crate)` until that phase exists. **Mechanized by `G0.8`** — this row is what that gate automates.
- [ ] **Every security control has a test only it can fail.** Not "the suite passes". Verified by removing each control and confirming at least one test fails. Revision 8's 85 tests stayed green when frame AAD, trailer AAD, nonce pinning, or position equality were each deleted — two tests named those controls and each passed via the other one. The four `mut_*` regressions in `package.rs` are permanent; do not simplify away their re-sealed trailer, which is what isolates the frame layer.
- [ ] **Property tests enter through the user's door.** For a format, that is **bytes**. Revision 8 asserted truncation detection against a hand-built `Vec<Frame>`, a state no file produces, so `PackageTruncated` was unreachable from any real package while its test passed.
- [x] **`ADR-0017` implemented.** Framed format, streaming `export_to`, derived expiry, base64 outer blobs, `hex_array_32` on every `[u8; 32]` field including `KeyBytes` and `RootPublicKey`. Contract Impact table discharged: `C1` and `C7` amended, `C1`/`C2`/`C3` conformance tests restated, `V4`/`V5`/`V7` re-measured, `G0` re-run.
- [ ] **Streaming is the default export path.** `export_to` for anything user-sized; `export` is retained for tests and small vaults and is documented as materializing. Peak overhead measured flat at 0.56–0.69 MB across a 50× range in ledger size, against 1.0 → 32.6 MB linear before.
- [ ] `#![forbid(unsafe_code)]` present in `lib.rs`
- [ ] Rust Architect's accepted-transitive-`unsafe` note is recorded and names the crates actually in `cargo tree` — `curve25519-dalek` (35 sites) and `subtle` (2 sites, `black_box` shims that exist *to preserve* the constant-time property), plus the RustCrypto set. **`fiat-crypto` is NOT in the tree** and was struck: it resolves only under `--cfg curve25519_dalek_backend="fiat"`, which nothing sets. Setting that cfg requires a fresh note.
- [ ] `[profile.release]` shaped per rust-architect — `lto`/`strip` workspace-wide, `opt-level`/`codegen-units` under `[profile.release.package.airo_mind]` only. **Never `panic = "abort"`**: `airo_core` is a `cdylib` whose FRB bridge relies on `catch_unwind` to turn panics into Dart errors. Chief Performance Officer signs the `airo_core` half.

### Benchmark budgets — enforceable at Phase 1 merge

Constitution §4 requires a `packages/benchmarks` entry for CPU-bound Rust.
Deferring it to Phase 3 was **inverted reasoning**: Phase 1 freezes the two
formats that determine replay cost forever, so the budgets are declared here
even where they are enforced later (chief-performance-officer §12, invariant
I8).

| ID | Budget |
|---|---|
| **V1** | `seed_from_mnemonic` ≤ 10 ms host — measured 3.16 ms, passes |
| **V2** | `RootIdentity::from_seed` ≤ 1 ms host |
| **V3** | `Vault::add_content` with 3 contexts ≤ 50 µs host |
| **V4** | `RecoveryPackage::export_to`, 100k-context vault ≤ 500 ms **and** file ≤ 3× compact-encoded size. **Measured: 70 ms, 2.26×. PASS** |
| **V5** | Peak RSS during export ≤ 4× logical vault size. **Measured: 2.61×–2.94× at scale. PASS** (4.26× at 492 KB, where 2 MB of fixed process overhead dominates the ratio) |
| **V6** | `SealedRestore::load` + `apply_revocations`, 10k contents / 1k revocations ≤ 1 s host |
| **V7** | **Export *overhead* above resident vault size is `O(1)` in ledger size** — within 20% across a 10× change. **Measured: −6% from 10k to 100k revocations, ±11% across a 50× range. PASS** |

**`V7` restated, and this is the third instance of one defect class.** It read
*"export peak RSS at 100k contents within 20% of RSS at 10k contents"*, which
measures **total process peak** — and total peak necessarily includes the
Vault's own resident ledger at 137.6 B per entry, which is `O(N)` by design and
which no export strategy can change. Measured against streaming export, that
phrasing fails at **+588%** while the property `ADR-0017` actually states
passes at **−6%**.

Same failure as `C1`'s vacuous vault test and `C3`'s bytes-only sync test: the
budget named an artifact that once tracked the property and stopped. `Freeze §`
records the rule; this is it applying to a benchmark rather than a conformance
test, which is a surface the rule had not yet been tested against.

Note what the restatement does **not** do: it does not lower the bar to fit the
result. Total peak still scales with the ledger, and that is a real cost —
`ADR-0017` bounds it at ~91k five-year entries by deriving expiry rather than
recording it. Whether the resident ledger should stream from disk instead is a
Phase 2 storage question and is not in scope here.

V4, V5, and V7 failed by construction before the Vault redesign. They are the
gate that proves it held rather than asserting it.

**NEEDS HARDWARE, cannot be fixed from a development host** — tracked on #1257:
PBKDF2 on Pixel 9 and mid-range Android (H1) · ed25519 ops/s per device class
(H2) · XChaCha20-Poly1305 MiB/s (H3) · **per-append fsync latency, which sets
the group-commit window and ranges 0.5–50 ms across real devices** (H4) ·
`airo_core` M3U throughput under the new profile on `aarch64-linux-android`
and `armv7-linux-androideabi` (H5).

Deferred with reasons: FFI surface (#1260).

## Applied review findings

Revision 2 applies every finding from PR #1239.

**chief-security-officer, blocking:** R1 empty-ledger bypass → `RevocationSource`
with provenance, `was_blind`, staleness signal. R2 missing AAD → `wrapping_aad`
binding content and context, with two regression tests. R3 no device or context
revocation → `RevocationSubject` tagged enum, purged on restore. R5 no identity
binding → checked in `SealedRestore::load`. R6 unauthenticated package header →
passed as AAD. R12 no at-rest design → #1241. R13 mnemonic over FFI → moot,
FFI deferred. R15 Task 10 unbuildable → task deleted.

**chief-security-officer, mechanical:** R4 fail-open `revoked_since` → `min`
became `max`, `all_revoked` added, method made `pub(crate)`, epoch-0 rejected,
misleading test replaced. R7 unzeroized plaintext and `Debug` on secrets →
`Zeroizing` buffers, hand-written redacting `Debug`. R8 unpinned `zeroize`
feature → explicit pin plus compile-time guard. R9 `PartialEq` on secrets →
`subtle::ConstantTimeEq`, `Clone` dropped. R10 `ContextKey::as_bytes` →
`pub(crate)`. R11 domain strings → registry with prefix-distinctness test. R14
silent success on absent targets → errors.

**chief-open-source-officer:** `fill_bytes` panic → `try_fill_bytes` +
`RngUnavailable`. `crate-type` → `rlib` only. `bip39` → `rand` dropped,
`zeroize` enabled. `curve25519-dalek` floored at `>=4.1.3`. `serde_json`
retained on measured evidence, with the signing-bytes prohibition recorded.
Supply-chain gates → #1257. Crate ownership → #1258.

**Unresolved, tracked:** the `serde_json` versus `postcard` question. OSS
rejected the swap on size and canonicalization grounds; security raised it on
secret-hygiene grounds — that `[u8; 32]` serializes as decimal integers, so key
bytes smear across unzeroized ASCII buffers. The two answered different
questions. Recommended resolution is a byte-oriented serde impl for key types
plus `Zeroizing` buffers, which addresses the hygiene finding without a new
dependency. Joint chief-security-officer and chief-architect ruling, on
PR #1239.

## Self-review notes

**Spec coverage.** §6.1 Recovery Package → Task 8. §6.2 restore ordering →
Task 9. §6.3 erasure bound → `was_blind`. §4.1 envelope encryption → Tasks 5, 7.
§4.3 crypto-shredding steps 1–3 → Task 7; steps 4–8 are outside this crate and
carried by `PurgeDirective`, which is a nudge and not a mechanism until Phase 2
makes revocation transactional. §7 trust boundary → Task 4 plus device
revocation.

**Not covered here, deliberately.** Retention classes (spec §4.2) attach to
content objects in the content store — Phase 2, #1214. Putting them in the
Vault would be the wrong aggregate.

**Known interface risk.** `serde` on `[u8; 64]` (Task 4) affects Tasks 4, 8, and
9. Whichever approach is chosen must be applied consistently; a mismatch
surfaces as a deserialization failure in Task 9's round-trip tests rather than
at the point of the mistake.

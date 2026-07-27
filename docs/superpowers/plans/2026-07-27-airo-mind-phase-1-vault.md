# Airo Mind Phase 1 — Vault Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Airo Mind Vault — identity, device certificates, envelope encryption, revocation ledger, and revocation-aware recovery — as a standalone Rust crate with no Flutter dependency.

**Architecture:** A new `rust/airo_mind` workspace crate holding pure-Rust cryptographic state. A BIP39 seed derives a root Ed25519 identity. Each device generates its *own* keypair locally and receives a root-signed certificate, so the seed never leaves the device that created it. Content keys are wrapped independently under each granting context key (envelope encryption over a hypergraph, not a key tree). A monotonic revocation ledger records destroyed keys, and restore is type-state enforced: a `RecoveryPackage` cannot become a usable `Vault` without first applying revocations.

**Tech Stack:** Rust 2021, `ed25519-dalek` (signing), `chacha20poly1305` (XChaCha20-Poly1305 AEAD), `hkdf` + `sha2` (derivation), `bip39` (mnemonic), `zeroize`, `thiserror`, `serde` + `serde_json`.

**Spec:** `docs/superpowers/specs/2026-07-27-airo-mind-runtime-design.md` §4, §6
**Issues:** #1204 (scaffold), #1205 (governance), #1207–#1212 (Vault tasks), under epic #1193.

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
    ├── lib.rs             — crate root, re-exports, module docs
    └── vault/
        ├── mod.rs         — Vault aggregate + re-exports
        ├── error.rs       — VaultError
        ├── seed.rs        — Mnemonic ↔ Seed (Task 2)
        ├── identity.rs    — RootIdentity from Seed (Task 3)
        ├── device.rs      — DeviceKey, DeviceCertificate (Task 4)
        ├── envelope.rs    — ContentKey, ContextKey, ContentEnvelope (Task 5)
        ├── revocation.rs  — RevocationLedger (Task 6)
        ├── package.rs     — RecoveryPackage export (Task 7)
        └── restore.rs     — type-state restore (Task 8)
```

One responsibility per file. `mod.rs` holds only the `Vault` aggregate and re-exports; it must not grow logic.

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
| `bip39` | `2` | **caveat:** feature changes + a CC0 decision |

Version choice was validated as correct: `sha2 0.10` + `hkdf 0.12` share the
`digest 0.10` generation `flutter_rust_bridge` already pulls in. Moving to
`sha2 0.11` / `hkdf 0.13` would fork `digest` across two majors workspace-wide.

Measured binary impact: **+408 KB** stripped with `opt-level="z"` + fat LTO,
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

- [ ] **Step 3: Resolve the CC0 question — needs a decision before Task 2**

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
#[derive(Debug, Error, PartialEq, Eq)]
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

    #[error("cannot use a restored vault before applying revocations")]
    RevocationsNotApplied,

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
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_messages_are_actionable() {
        assert_eq!(
            VaultError::NoWrappingForContext("hospitalization".into()).to_string(),
            "no wrapping found for context `hospitalization`"
        );
        assert_eq!(
            VaultError::RevocationsNotApplied.to_string(),
            "cannot use a restored vault before applying revocations"
        );
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
# `rand` feature deliberately OFF: Mnemonic::from_entropy works without it, and
# dropping it removes four crates and leaves ONE CSPRNG stack rather than two,
# with an entropy buffer we own and can zeroize.
# `zeroize` feature ON: without it the mnemonic's word indices are never wiped —
# on the single most sensitive object in the design.
bip39 = { version = "2", default-features = false, features = ["std", "zeroize"] }
chacha20poly1305 = { version = "0.10", features = ["getrandom"] }
# Explicit feature pinning, not defaults. `zeroize` is what keeps the root
# private key out of freed memory; someone adding default-features = false for
# binary size later would silently remove it.
ed25519-dalek = { version = "2", default-features = false, features = ["std", "rand_core", "zeroize"] }
# RUSTSEC-2024-0344: timing variability in Scalar29/Scalar52 subtraction.
# 4.1.3 is the patched release. Floored explicitly so a downgrade fails.
curve25519-dalek = ">=4.1.3"
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
//! Airo Mind runtime.
//!
//! The runtime understands seven primitives and no domain concepts:
//! Identity, Operation, Content, Context, Capability, Projection, Vault.
//!
//! Rules for every module in this crate:
//!   - No panics. Return `Result`.
//!   - Every secret type is `Zeroize` + `ZeroizeOnDrop`.
//!   - Anything serialized uses `BTreeMap`, never `HashMap` — replay must be
//!     byte-identical across devices and platforms.

pub mod vault;
```

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

mod domain;
mod error;

pub use error::VaultError;
```

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
```

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
  - `fn generate_mnemonic() -> Zeroizing<String>` — 24 words
  - `fn seed_from_mnemonic(phrase: &str) -> Result<Seed, VaultError>`

- [ ] **Step 1: Write the failing test**

Create `rust/airo_mind/src/vault/seed.rs`:

```rust
//! Recovery seed. The root of everything the user can ever recover.

use bip39::Mnemonic;
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use super::error::VaultError;

/// A 64-byte BIP39 seed. Zeroized on drop.
///
/// No `Clone`: the seed is the one secret whose compromise is total and
/// unrecoverable, and silent duplication is how copies end up unzeroized.
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct Seed([u8; 64]);

impl Seed {
    pub fn as_bytes(&self) -> &[u8; 64] {
        &self.0
    }
}

/// Generates a fresh 24-word recovery mnemonic.
///
/// Shown to the user exactly once. There is no other copy, and no server-side
/// recovery path — that is the product promise, and it is also the reason the
/// onboarding flow (#1234) must confirm the user recorded it.
pub fn generate_mnemonic() -> Zeroizing<String> {
    // `Zeroizing` because this is the root secret in plaintext. The bip39
    // `zeroize` feature (pinned in Cargo.toml) covers the Mnemonic's internal
    // word indices; this covers the String we hand back.
    Zeroizing::new(
        Mnemonic::generate(24)
            .expect("24 is a valid BIP39 word count")
            .to_string(),
    )
}

/// Derives the 64-byte seed from a mnemonic phrase.
///
/// No passphrase. Adding one later is a breaking change to every existing
/// recovery package, so it is deliberately excluded rather than defaulted.
pub fn seed_from_mnemonic(phrase: &str) -> Result<Seed, VaultError> {
    let mnemonic = Mnemonic::parse(phrase).map_err(|_| VaultError::InvalidMnemonic)?;
    Ok(Seed(mnemonic.to_seed("")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generated_mnemonic_has_24_words() {
        let phrase = generate_mnemonic();
        assert_eq!(phrase.split_whitespace().count(), 24);
    }

    #[test]
    fn generated_mnemonic_round_trips_to_a_seed() {
        let phrase = generate_mnemonic();
        assert!(seed_from_mnemonic(&phrase).is_ok());
    }

    #[test]
    fn same_mnemonic_always_yields_the_same_seed() {
        let phrase = generate_mnemonic();
        let a = seed_from_mnemonic(&phrase).unwrap();
        let b = seed_from_mnemonic(&phrase).unwrap();
        assert_eq!(a.as_bytes(), b.as_bytes());
    }

    #[test]
    fn two_generated_mnemonics_differ() {
        assert_ne!(generate_mnemonic(), generate_mnemonic());
    }

    #[test]
    fn known_vector_is_stable_across_platforms() {
        // BIP39 test vector. If this assertion ever changes, every existing
        // recovery package in the world stops working. Treat a failure here as
        // a release blocker, never as a test to update.
        let phrase = "abandon abandon abandon abandon abandon abandon abandon \
                      abandon abandon abandon abandon abandon abandon abandon \
                      abandon abandon abandon abandon abandon abandon abandon \
                      abandon abandon art";
        let seed = seed_from_mnemonic(phrase).unwrap();
        assert_eq!(
            hex_lower(seed.as_bytes()),
            "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc1\
             9a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4"
        );
    }

    #[test]
    fn invalid_mnemonic_is_rejected() {
        assert_eq!(
            seed_from_mnemonic("not a real mnemonic phrase at all"),
            Err(VaultError::InvalidMnemonic)
        );
    }

    fn hex_lower(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }
}
```

Modify `rust/airo_mind/src/vault/mod.rs` — add below the existing `mod error;`:

```rust
mod seed;

pub use seed::{generate_mnemonic, seed_from_mnemonic, Seed};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind seed`
Expected: FAIL to compile — `bip39` not yet resolved, or `Mnemonic::generate` signature mismatch.

- [ ] **Step 3: Reconcile against the real `bip39` API**

The code above targets `bip39` v2. Run `cargo doc -p bip39 --open` or read `~/.cargo/registry/src/*/bip39-2*/src/lib.rs` and adjust the two call sites (`Mnemonic::generate`, `Mnemonic::parse`, `to_seed`) to the actual signatures. Do **not** change the known-vector assertion to make a test pass — if the vector fails, the derivation is wrong.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind seed`
Expected: PASS, 6 tests

- [ ] **Step 5: Commit**

```bash
git add rust/airo_mind/src/vault/seed.rs rust/airo_mind/src/vault/mod.rs
git commit -m "feat(mind): add recovery seed generation and mnemonic derivation

24-word BIP39 mnemonic, no passphrase. Pinned to a known test vector: if
that vector ever changes, every recovery package already in the world
stops working.

Refs #1207"
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

use ed25519_dalek::{Signature, Signer, SigningKey, Verifier, VerifyingKey};
use hkdf::Hkdf;
use sha2::Sha512;
use zeroize::ZeroizeOnDrop;

use super::error::VaultError;
use super::seed::Seed;

/// Domain separation for root identity derivation.
///
/// Changing this string invalidates every identity ever derived. It is
/// versioned so a future scheme can coexist rather than replace.
const ROOT_INFO: &[u8] = b"airo-mind/root-identity/v1";

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
        hkdf.expand(ROOT_INFO, &mut key_bytes)
            .map_err(|_| VaultError::DerivationFailed)?;
        Ok(Self {
            signing_key: SigningKey::from_bytes(&key_bytes),
        })
    }

    pub fn public_key(&self) -> [u8; 32] {
        self.signing_key.verifying_key().to_bytes()
    }

    /// Lowercase hex of the public key. Stable, human-comparable.
    pub fn identity_id(&self) -> String {
        self.public_key().iter().map(|b| format!("{b:02x}")).collect()
    }

    pub fn sign(&self, msg: &[u8]) -> [u8; 64] {
        self.signing_key.sign(msg).to_bytes()
    }
}

/// Verifies a signature against a public key.
///
/// Uses strict verification: rejects small-order and non-canonical keys that
/// permit signature malleability.
pub fn verify(public_key: &[u8; 32], msg: &[u8], signature: &[u8; 64]) -> bool {
    let Ok(verifying_key) = VerifyingKey::from_bytes(public_key) else {
        return false;
    };
    verifying_key
        .verify(msg, &Signature::from_bytes(signature))
        .is_ok()
}

#[cfg(test)]
mod tests {
    use super::*;
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
            &seed_from_mnemonic(&crate::vault::generate_mnemonic()).unwrap(),
        )
        .unwrap();
        let sig = theirs.sign(b"authorize device");
        assert!(!verify(&mine.public_key(), b"authorize device", &sig));
    }

    #[test]
    fn different_seeds_produce_different_identities() {
        let a = RootIdentity::from_seed(&test_seed()).unwrap();
        let b = RootIdentity::from_seed(
            &seed_from_mnemonic(&crate::vault::generate_mnemonic()).unwrap(),
        )
        .unwrap();
        assert_ne!(a.public_key(), b.public_key());
    }
}
```

Modify `rust/airo_mind/src/vault/mod.rs`:

```rust
mod identity;

pub use identity::{verify, RootIdentity};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind identity`
Expected: FAIL to compile — module not yet declared, or `ed25519_dalek` trait imports missing.

- [ ] **Step 3: Reconcile against the real `ed25519-dalek` v2 API**

`SigningKey::from_bytes` takes `&[u8; 32]`. `Signer`/`Verifier` traits must be in scope for `.sign()` / `.verify()`. Adjust imports if the compiler disagrees; do not weaken `verify` to a non-strict variant.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind identity`
Expected: PASS, 6 tests

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

use ed25519_dalek::{Signer, SigningKey};
use rand_core::OsRng;
use serde::{Deserialize, Serialize};
use zeroize::ZeroizeOnDrop;

use super::identity::{verify, RootIdentity};

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

impl Default for DeviceKey {
    fn default() -> Self {
        Self::generate()
    }
}

impl DeviceKey {
    pub fn generate() -> Self {
        Self {
            signing_key: SigningKey::generate(&mut OsRng),
        }
    }

    pub fn public_key(&self) -> [u8; 32] {
        self.signing_key.verifying_key().to_bytes()
    }

    pub fn device_id(&self) -> String {
        self.public_key().iter().map(|b| format!("{b:02x}")).collect()
    }

    pub fn sign(&self, msg: &[u8]) -> [u8; 64] {
        self.signing_key.sign(msg).to_bytes()
    }
}

/// A root-signed statement that a device belongs to this user's mesh.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct DeviceCertificate {
    pub device_id: String,
    pub device_public_key: [u8; 32],
    pub issued_at_epoch: u64,
    pub signature: [u8; 64],
}

impl DeviceCertificate {
    pub fn issue(root: &RootIdentity, device: &DeviceKey, issued_at_epoch: u64) -> Self {
        let mut certificate = Self {
            device_id: device.device_id(),
            device_public_key: device.public_key(),
            issued_at_epoch,
            signature: [0u8; 64],
        };
        certificate.signature = root.sign(&certificate.signing_payload());
        certificate
    }

    /// The exact bytes covered by the signature.
    ///
    /// Field order is fixed and length-prefixed so no two distinct
    /// certificates can ever produce the same payload.
    pub fn signing_payload(&self) -> Vec<u8> {
        let mut payload = Vec::new();
        payload.extend_from_slice(b"airo-mind/device-certificate/v1");
        payload.extend_from_slice(&(self.device_id.len() as u32).to_be_bytes());
        payload.extend_from_slice(self.device_id.as_bytes());
        payload.extend_from_slice(&self.device_public_key);
        payload.extend_from_slice(&self.issued_at_epoch.to_be_bytes());
        payload
    }

    pub fn verify_against(&self, root_public_key: &[u8; 32]) -> bool {
        if self.device_id != hex_lower(&self.device_public_key) {
            return false;
        }
        verify(root_public_key, &self.signing_payload(), &self.signature)
    }
}

fn hex_lower(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
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
        assert_ne!(DeviceKey::generate().public_key(), DeviceKey::generate().public_key());
    }

    #[test]
    fn issued_certificate_verifies_against_the_issuing_root() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let device = DeviceKey::generate();
        let certificate = DeviceCertificate::issue(&root, &device, 1);
        assert!(certificate.verify_against(&root.public_key()));
    }

    #[test]
    fn certificate_fails_against_a_different_root() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let stranger = RootIdentity::from_seed(
            &seed_from_mnemonic(&crate::vault::generate_mnemonic()).unwrap(),
        )
        .unwrap();
        let certificate = DeviceCertificate::issue(&root, &DeviceKey::generate(), 1);
        assert!(!certificate.verify_against(&stranger.public_key()));
    }

    #[test]
    fn swapping_the_public_key_invalidates_the_certificate() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let mut certificate = DeviceCertificate::issue(&root, &DeviceKey::generate(), 1);
        certificate.device_public_key = DeviceKey::generate().public_key();
        assert!(!certificate.verify_against(&root.public_key()));
    }

    #[test]
    fn device_id_must_match_the_public_key() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let mut certificate = DeviceCertificate::issue(&root, &DeviceKey::generate(), 1);
        certificate.device_id = "deadbeef".into();
        assert!(!certificate.verify_against(&root.public_key()));
    }

    #[test]
    fn changing_the_issue_epoch_invalidates_the_certificate() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let mut certificate = DeviceCertificate::issue(&root, &DeviceKey::generate(), 1);
        certificate.issued_at_epoch = 99;
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

- [ ] **Step 3: Reconcile serde on fixed-size arrays**

`[u8; 64]` does not implement `Serialize`/`Deserialize` by default in serde 1. Either enable a serde feature that supports large arrays, or add `#[serde(with = "...")]` helpers converting to `Vec<u8>` with a length check on deserialize. Pick one and apply it consistently — Tasks 5, 7, and 8 all serialize fixed-size arrays.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind device`
Expected: PASS, 6 tests

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

use chacha20poly1305::aead::{Aead, KeyInit, OsRng as AeadOsRng};
use chacha20poly1305::{AeadCore, XChaCha20Poly1305, XNonce};
use serde::{Deserialize, Serialize};
use zeroize::{Zeroize, ZeroizeOnDrop};

use super::error::VaultError;

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
    pub fn generate() -> Result<Self, VaultError> {
        Ok(Self(random_key()?))
    }

    pub fn as_bytes(&self) -> &[u8; 32] {
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
    pub fn generate() -> Result<Self, VaultError> {
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
}

/// One content key sealed under one context key.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
struct Wrapping {
    context_id: String,
    nonce: Vec<u8>,
    ciphertext: Vec<u8>,
}

/// All wrappings for one content object.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContentEnvelope {
    pub content_id: String,
    wrappings: Vec<Wrapping>,
}

impl ContentEnvelope {
    pub fn new(content_id: impl Into<String>) -> Self {
        Self {
            content_id: content_id.into(),
            wrappings: Vec::new(),
        }
    }

    /// Grants a context access to this content.
    ///
    /// Re-wrapping under a context that already has access replaces the
    /// existing wrapping rather than adding a duplicate.
    pub fn add_wrapping(
        &mut self,
        content_key: &ContentKey,
        context_id: &str,
        context_key: &ContextKey,
    ) -> Result<(), VaultError> {
        let cipher = XChaCha20Poly1305::new(context_key.as_bytes().into());
        let nonce = XNonce::from_slice(&random_nonce()?).to_owned();
        let aad = wrapping_aad(&self.content_id, context_id);
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
    pub fn remove_wrapping(&mut self, context_id: &str) -> bool {
        let before = self.wrappings.len();
        self.wrappings.retain(|w| w.context_id != context_id);
        self.wrappings.len() != before
    }

    pub fn unwrap_with(
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
        let aad = wrapping_aad(&self.content_id, context_id);
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

    pub fn context_ids(&self) -> Vec<&str> {
        self.wrappings.iter().map(|w| w.context_id.as_str()).collect()
    }

    /// True when no wrapping remains — the content is unrecoverable.
    ///
    /// This is the signal the survival computation in #1229 uses to tell a
    /// user "5 items exist nowhere else".
    pub fn is_orphaned(&self) -> bool {
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
fn wrapping_aad(content_id: &str, context_id: &str) -> Vec<u8> {
    let mut aad = Vec::new();
    aad.extend_from_slice(domain::CONTENT_WRAPPING);
    aad.extend_from_slice(&(content_id.len() as u32).to_be_bytes());
    aad.extend_from_slice(content_id.as_bytes());
    aad.extend_from_slice(&(context_id.len() as u32).to_be_bytes());
    aad.extend_from_slice(context_id.as_bytes());
    aad
}

/// `try_fill_bytes`, never `fill_bytes` — the latter panics when the OS RNG
/// fails, in a crate that promises no panics.
fn random_key() -> Result<[u8; 32], VaultError> {
    use rand_core::RngCore;
    let mut bytes = [0u8; 32];
    rand_core::OsRng
        .try_fill_bytes(&mut bytes)
        .map_err(|_| VaultError::RngUnavailable)?;
    Ok(bytes)
}

fn random_nonce() -> Result<[u8; 24], VaultError> {
    use rand_core::RngCore;
    let mut bytes = [0u8; 24];
    rand_core::OsRng
        .try_fill_bytes(&mut bytes)
        .map_err(|_| VaultError::RngUnavailable)?;
    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;

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

        assert_eq!(envelope.context_ids(), vec!["hospitalization"]);
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

pub use envelope::{ContentEnvelope, ContentKey, ContextKey};
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind envelope`
Expected: FAIL to compile — module not declared.

- [ ] **Step 3: Reconcile against the real `chacha20poly1305` v0.10 API**

`AeadCore::generate_nonce` requires the `getrandom` feature. `KeyInit::new` takes `&Key`, which is `&GenericArray<u8, U32>` — the `.into()` on `&[u8; 32]` should work, but adjust if the compiler disagrees. The `aead` re-export path may be `chacha20poly1305::aead` or require the `aead` crate directly.

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
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub enum RevocationSubject {
    Content(String),
    Context(String),
    Device(String),
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

    /// Records a revocation and returns the epoch assigned to it.
    ///
    /// Revoking the same content twice is a no-op that returns the original
    /// epoch — revocation is a fact, not an event count.
    pub fn revoke(&mut self, content_id: &str) -> u64 {
        if let Some(existing) = self.entries.get(content_id) {
            return *existing;
        }
        self.head_epoch += 1;
        self.entries.insert(content_id.to_string(), self.head_epoch);
        self.head_epoch
    }

    pub fn head_epoch(&self) -> u64 {
        self.head_epoch
    }

    pub fn is_revoked(&self, content_id: &str) -> bool {
        self.entries.contains_key(content_id)
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

    #[test]
    fn a_new_ledger_is_empty_at_epoch_zero() {
        let ledger = RevocationLedger::new();
        assert_eq!(ledger.head_epoch(), 0);
        assert!(!ledger.is_revoked("anything"));
    }

    #[test]
    fn revoking_advances_the_epoch() {
        let mut ledger = RevocationLedger::new();
        assert_eq!(ledger.revoke("note-1"), 1);
        assert_eq!(ledger.revoke("note-2"), 2);
        assert_eq!(ledger.head_epoch(), 2);
    }

    #[test]
    fn revoked_content_is_reported_as_revoked() {
        let mut ledger = RevocationLedger::new();
        ledger.revoke("note-1");
        assert!(ledger.is_revoked("note-1"));
        assert!(!ledger.is_revoked("note-2"));
    }

    #[test]
    fn revoking_twice_is_idempotent() {
        let mut ledger = RevocationLedger::new();
        let first = ledger.revoke("note-1");
        let second = ledger.revoke("note-1");
        assert_eq!(first, second);
        assert_eq!(ledger.head_epoch(), 1);
    }

    #[test]
    fn revoked_since_returns_only_later_revocations() {
        let mut ledger = RevocationLedger::new();
        ledger.revoke("old-1");
        ledger.revoke("old-2");
        let backup_epoch = ledger.head_epoch();
        ledger.revoke("new-1");
        ledger.revoke("new-2");

        let since = ledger.revoked_since(backup_epoch);
        assert_eq!(since, vec!["new-1".to_string(), "new-2".to_string()]);
    }

    #[test]
    fn revoked_since_zero_returns_everything() {
        let mut ledger = RevocationLedger::new();
        ledger.revoke("a");
        ledger.revoke("b");
        assert_eq!(ledger.revoked_since(0).len(), 2);
    }

    #[test]
    fn merge_is_order_independent() {
        let mut phone = RevocationLedger::new();
        phone.revoke("p1");
        phone.revoke("p2");

        let mut laptop = RevocationLedger::new();
        laptop.revoke("l1");

        let mut phone_first = phone.clone();
        phone_first.merge(&laptop);

        let mut laptop_first = laptop.clone();
        laptop_first.merge(&phone);

        assert_eq!(
            phone_first.revoked_since(0).len(),
            laptop_first.revoked_since(0).len()
        );
        for id in ["p1", "p2", "l1"] {
            assert!(phone_first.is_revoked(id));
            assert!(laptop_first.is_revoked(id));
        }
    }

    #[test]
    fn merge_is_idempotent() {
        let mut phone = RevocationLedger::new();
        phone.revoke("p1");
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
        phone.revoke("destroyed-medical-record");

        let mut laptop = RevocationLedger::new();
        laptop.revoke("unrelated");
        laptop.merge(&phone);

        assert!(laptop.is_revoked("destroyed-medical-record"));
    }

    #[test]
    fn serialization_round_trips() {
        let mut ledger = RevocationLedger::new();
        ledger.revoke("a");
        ledger.revoke("b");
        let json = serde_json::to_string(&ledger).unwrap();
        let restored: RevocationLedger = serde_json::from_str(&json).unwrap();
        assert_eq!(ledger, restored);
    }
}
```

Modify `rust/airo_mind/src/vault/mod.rs`:

```rust
mod revocation;

pub use revocation::RevocationLedger;
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
  - `Vault` with `fn new(root_public_key: [u8; 32]) -> Self`, `fn add_context(&mut self, &str) -> Result<&ContextKey, VaultError>`, `fn context_key(&self, &str) -> Option<&ContextKey>`, `fn add_content(&mut self, &str, &[&str]) -> Result<ContentKey, VaultError>`, `fn link_content(&mut self, &str, &str) -> Result<(), VaultError>`, `fn unlink_content(&mut self, &str, &str) -> Result<UnlinkOutcome, VaultError>`, `fn destroy_content(&mut self, &str) -> Result<PurgeDirective, VaultError>`, `fn revocations(&self) -> &RevocationLedger`, `fn trust_device(&mut self, DeviceCertificate) -> bool`, `fn revoke_device(&mut self, &str) -> Result<PurgeDirective, VaultError>`
  - `UnlinkOutcome { pub remaining_contexts: Vec<String>, pub now_orphaned: bool }`
  - `PurgeDirective { pub content_id: String, pub epoch: u64 }`

**Design note for the implementer.** `destroy_content` performs only steps 1–3 of crypto-shredding: destroy the key, append the revocation, drop the envelope. Steps 4–8 — projections, embeddings, search index, AI caches, snapshots — live outside this crate and outside Rust. `PurgeDirective` is the instruction the caller must act on. Returning it rather than silently completing is deliberate: #1217 tracks the steps that get skipped, and a directive the caller has to consume is harder to skip than a comment.

- [ ] **Step 1: Write the failing test**

Replace the body of `rust/airo_mind/src/vault/mod.rs` with the module declarations already present plus:

```rust
use std::collections::BTreeMap;

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
    pub content_id: String,
    pub epoch: u64,
}

/// Identity, keys, revocations, trust, device certificates.
///
/// The only mutable, non-append-only store in the system.
pub struct Vault {
    root_public_key: [u8; 32],
    context_keys: BTreeMap<String, ContextKey>,
    envelopes: BTreeMap<String, ContentEnvelope>,
    device_certificates: Vec<DeviceCertificate>,
    revocations: RevocationLedger,
}

impl Vault {
    pub fn new(root_public_key: [u8; 32]) -> Self {
        Self {
            root_public_key,
            context_keys: BTreeMap::new(),
            envelopes: BTreeMap::new(),
            device_certificates: Vec::new(),
            revocations: RevocationLedger::new(),
        }
    }

    pub fn root_public_key(&self) -> &[u8; 32] {
        &self.root_public_key
    }

    pub fn revocations(&self) -> &RevocationLedger {
        &self.revocations
    }

    /// Creates a context key if absent. Idempotent.
    ///
    /// Fallible because key generation is fallible — `or_insert_with` cannot
    /// carry a `Result`, so this is written long-hand.
    pub fn add_context(&mut self, context_id: &str) -> Result<&ContextKey, VaultError> {
        if !self.context_keys.contains_key(context_id) {
            let key = ContextKey::generate()?;
            self.context_keys.insert(context_id.to_string(), key);
        }
        self.context_keys
            .get(context_id)
            .ok_or_else(|| VaultError::NoWrappingForContext(context_id.to_string()))
    }

    pub(crate) fn context_key(&self, context_id: &str) -> Option<&ContextKey> {
        self.context_keys.get(context_id)
    }

    /// Creates content wrapped under every listed context.
    pub fn add_content(
        &mut self,
        content_id: &str,
        context_ids: &[&str],
    ) -> Result<ContentKey, VaultError> {
        if self.revocations.is_revoked(content_id) {
            return Err(VaultError::ContentRevoked(content_id.to_string()));
        }
        let content_key = ContentKey::generate().unwrap();
        let mut envelope = ContentEnvelope::new(content_id);
        for context_id in context_ids {
            self.add_context(context_id)?;
            let context_key = self
                .context_keys
                .get(*context_id)
                .ok_or_else(|| VaultError::NoWrappingForContext((*context_id).to_string()))?;
            envelope.add_wrapping(&content_key, context_id, context_key)?;
        }
        self.envelopes.insert(content_id.to_string(), envelope);
        Ok(content_key)
    }

    /// Grants an additional context access to existing content.
    pub fn link_content(&mut self, content_id: &str, context_id: &str) -> Result<(), VaultError> {
        if self.revocations.is_revoked(content_id) {
            return Err(VaultError::ContentRevoked(content_id.to_string()));
        }
        let existing_context = self
            .envelopes
            .get(content_id)
            .and_then(|e| e.context_ids().first().map(|s| s.to_string()))
            .ok_or_else(|| VaultError::NoWrappingForContext(content_id.to_string()))?;

        let source_key = self
            .context_keys
            .get(&existing_context)
            .ok_or_else(|| VaultError::NoWrappingForContext(existing_context.clone()))?;
        let content_key = self
            .envelopes
            .get(content_id)
            .ok_or_else(|| VaultError::NoWrappingForContext(content_id.to_string()))?
            .unwrap_with(&existing_context, source_key)?;

        self.add_context(context_id)?;
        let target_key = self
            .context_keys
            .get(context_id)
            .ok_or_else(|| VaultError::NoWrappingForContext(context_id.to_string()))?
            .clone();
        let envelope = self
            .envelopes
            .get_mut(content_id)
            .ok_or_else(|| VaultError::NoWrappingForContext(content_id.to_string()))?;
        envelope.add_wrapping(&content_key, context_id, &target_key)
    }

    /// Removes one context link. Does not destroy anything.
    pub fn unlink_content(
        &mut self,
        content_id: &str,
        context_id: &str,
    ) -> Result<UnlinkOutcome, VaultError> {
        let envelope = self
            .envelopes
            .get_mut(content_id)
            .ok_or_else(|| VaultError::NoWrappingForContext(content_id.to_string()))?;
        envelope.remove_wrapping(context_id);
        Ok(UnlinkOutcome {
            remaining_contexts: envelope.context_ids().iter().map(|s| s.to_string()).collect(),
            now_orphaned: envelope.is_orphaned(),
        })
    }

    /// Destroys content permanently. Steps 1–3 of crypto-shredding.
    pub fn destroy_content(&mut self, content_id: &str) -> Result<PurgeDirective, VaultError> {
        self.envelopes.remove(content_id);
        let epoch = self.revocations.revoke(content_id);
        Ok(PurgeDirective {
            content_id: content_id.to_string(),
            epoch,
        })
    }

    /// Records a device certificate after verifying it against the root.
    /// Returns whether the certificate was accepted.
    pub fn trust_device(&mut self, certificate: DeviceCertificate) -> bool {
        if !certificate.verify_against(&self.root_public_key) {
            return false;
        }
        self.device_certificates.retain(|c| c.device_id != certificate.device_id);
        self.device_certificates.push(certificate);
        true
    }

    pub fn trusted_devices(&self) -> &[DeviceCertificate] {
        &self.device_certificates
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn vault() -> Vault {
        Vault::new([7u8; 32])
    }

    #[test]
    fn content_is_readable_through_every_context_it_was_created_in() {
        let mut vault = vault();
        let key = vault.add_content("bill-001", &["hospitalization", "finance", "tax-2026"]).unwrap();

        for context in ["hospitalization", "finance", "tax-2026"] {
            let context_key = vault.context_key(context).unwrap();
            let envelope = &vault.envelopes["bill-001"];
            assert_eq!(envelope.unwrap_with(context, context_key).unwrap().as_bytes(), key.as_bytes());
        }
    }

    #[test]
    fn unlinking_reports_what_survives() {
        let mut vault = vault();
        vault.add_content("bill-001", &["hospitalization", "finance", "tax-2026"]).unwrap();

        let outcome = vault.unlink_content("bill-001", "hospitalization").unwrap();

        assert!(!outcome.now_orphaned);
        assert_eq!(outcome.remaining_contexts, vec!["finance".to_string(), "tax-2026".to_string()]);
    }

    #[test]
    fn unlinking_the_last_context_reports_orphaned() {
        let mut vault = vault();
        vault.add_content("note-1", &["inbox"]).unwrap();

        let outcome = vault.unlink_content("note-1", "inbox").unwrap();

        assert!(outcome.now_orphaned);
        assert!(outcome.remaining_contexts.is_empty());
    }

    #[test]
    fn linking_adds_a_context_without_re_encrypting_content() {
        let mut vault = vault();
        let key = vault.add_content("bill-001", &["hospitalization"]).unwrap();

        vault.link_content("bill-001", "tax-2026").unwrap();

        let tax_key = vault.context_key("tax-2026").unwrap();
        let recovered = vault.envelopes["bill-001"].unwrap_with("tax-2026", tax_key).unwrap();
        assert_eq!(recovered.as_bytes(), key.as_bytes());
    }

    #[test]
    fn destroy_revokes_and_returns_a_purge_directive() {
        let mut vault = vault();
        vault.add_content("note-1", &["inbox"]).unwrap();

        let directive = vault.destroy_content("note-1").unwrap();

        assert_eq!(directive.content_id, "note-1");
        assert_eq!(directive.epoch, 1);
        assert!(vault.revocations().is_revoked("note-1"));
        assert!(!vault.envelopes.contains_key("note-1"));
    }

    #[test]
    fn destroyed_content_cannot_be_recreated_under_the_same_id() {
        let mut vault = vault();
        vault.add_content("note-1", &["inbox"]).unwrap();
        vault.destroy_content("note-1").unwrap();

        assert_eq!(
            vault.add_content("note-1", &["inbox"]).unwrap_err(),
            VaultError::ContentRevoked("note-1".into())
        );
    }

    #[test]
    fn adding_a_context_twice_keeps_the_same_key() {
        let mut vault = vault();
        let first = vault.add_context("inbox").unwrap().as_bytes().to_owned();
        let second = vault.add_context("inbox").unwrap().as_bytes().to_owned();
        assert_eq!(first, second);
    }

    #[test]
    fn an_unsigned_device_certificate_is_rejected() {
        use crate::vault::{DeviceCertificate, DeviceKey};
        let device = DeviceKey::generate();
        let forged = DeviceCertificate {
            device_id: device.device_id(),
            device_public_key: device.public_key(),
            issued_at_epoch: 1,
            signature: [0u8; 64],
        };

        let mut vault = vault();
        assert!(!vault.trust_device(forged));
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

use chacha20poly1305::aead::{Aead, KeyInit, OsRng as AeadOsRng};
use chacha20poly1305::{AeadCore, XChaCha20Poly1305, XNonce};
use hkdf::Hkdf;
use serde::{Deserialize, Serialize};
use sha2::Sha512;

use super::envelope::ContentEnvelope;
use super::error::VaultError;
use super::revocation::RevocationLedger;
use super::seed::Seed;
use super::{DeviceCertificate, Vault};

pub const RECOVERY_PACKAGE_FORMAT_VERSION: u32 = 1;

/// Domain separation for the package encryption key.
const PACKAGE_INFO: &[u8] = b"airo-mind/recovery-package/v1";

/// The serializable interior of a Vault.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub(crate) struct VaultPayload {
    pub(crate) root_public_key: [u8; 32],
    pub(crate) context_keys: BTreeMap<String, [u8; 32]>,
    pub(crate) envelopes: BTreeMap<String, ContentEnvelope>,
    pub(crate) device_certificates: Vec<DeviceCertificate>,
    pub(crate) revocations: RevocationLedger,
}

/// An encrypted, portable grant of access to a Vault.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecoveryPackage {
    pub format_version: u32,
    pub identity_public_key: [u8; 32],
    /// Head epoch at export time. Deliberately **outside** the ciphertext:
    /// restore must read it before it can decrypt anything, to know how far
    /// behind this backup is.
    pub revocation_epoch: u64,
    nonce: Vec<u8>,
    ciphertext: Vec<u8>,
}

impl RecoveryPackage {
    pub fn export(vault: &Vault, seed: &Seed) -> Result<Self, VaultError> {
        let payload = vault.to_payload();
        let plaintext = serde_json::to_vec(&payload).map_err(|_| VaultError::SerializationFailed)?;

        let cipher = XChaCha20Poly1305::new(&package_key(seed)?.into());
        let nonce = XChaCha20Poly1305::generate_nonce(&mut AeadOsRng);
        let ciphertext = cipher
            .encrypt(&nonce, plaintext.as_slice())
            .map_err(|_| VaultError::SerializationFailed)?;

        Ok(Self {
            format_version: RECOVERY_PACKAGE_FORMAT_VERSION,
            identity_public_key: payload.root_public_key,
            revocation_epoch: payload.revocations.head_epoch(),
            nonce: nonce.to_vec(),
            ciphertext,
        })
    }

    pub(crate) fn decrypt(&self, seed: &Seed) -> Result<VaultPayload, VaultError> {
        if self.format_version != RECOVERY_PACKAGE_FORMAT_VERSION {
            return Err(VaultError::UnsupportedPackageVersion(self.format_version));
        }
        let nonce_bytes: [u8; 24] = self
            .nonce
            .as_slice()
            .try_into()
            .map_err(|_| VaultError::DecryptionFailed)?;
        let cipher = XChaCha20Poly1305::new(&package_key(seed)?.into());
        let plaintext = cipher
            .decrypt(XNonce::from_slice(&nonce_bytes), self.ciphertext.as_slice())
            .map_err(|_| VaultError::DecryptionFailed)?;
        serde_json::from_slice(&plaintext).map_err(|_| VaultError::SerializationFailed)
    }

    pub fn to_bytes(&self) -> Result<Vec<u8>, VaultError> {
        serde_json::to_vec(self).map_err(|_| VaultError::SerializationFailed)
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Self, VaultError> {
        serde_json::from_slice(bytes).map_err(|_| VaultError::SerializationFailed)
    }
}

fn package_key(seed: &Seed) -> Result<[u8; 32], VaultError> {
    let hkdf = Hkdf::<Sha512>::new(None, seed.as_bytes());
    let mut key = [0u8; 32];
    hkdf.expand(PACKAGE_INFO, &mut key)
        .map_err(|_| VaultError::DerivationFailed)?;
    Ok(key)
}

#[cfg(test)]
mod tests {
    use super::*;
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
        vault.add_content("note-1", &["inbox"]).unwrap();
        vault.add_content("bill-001", &["hospitalization", "tax-2026"]).unwrap();
        (vault, seed)
    }

    #[test]
    fn export_then_decrypt_round_trips() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let payload = package.decrypt(&seed).unwrap();

        assert_eq!(payload.root_public_key, *vault.root_public_key());
        assert_eq!(payload.envelopes.len(), 2);
        assert!(payload.context_keys.contains_key("hospitalization"));
    }

    #[test]
    fn a_different_seed_cannot_decrypt() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let stranger = seed_from_mnemonic(&generate_mnemonic()).unwrap();

        assert_eq!(package.decrypt(&stranger), Err(VaultError::DecryptionFailed));
    }

    #[test]
    fn revocation_epoch_is_readable_without_the_seed() {
        // Restore must know how far behind the backup is before it can decrypt
        // anything, so this field is deliberately outside the ciphertext.
        let (mut vault, seed) = seeded_vault();
        vault.destroy_content("note-1").unwrap();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();

        assert_eq!(package.revocation_epoch, 1);
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
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        package.format_version = 99;

        assert_eq!(package.decrypt(&seed), Err(VaultError::UnsupportedPackageVersion(99)));
    }

    #[test]
    fn tampered_ciphertext_is_rejected() {
        let (vault, seed) = seeded_vault();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        package.ciphertext[0] ^= 0xff;

        assert_eq!(package.decrypt(&seed), Err(VaultError::DecryptionFailed));
    }

    #[test]
    fn the_package_carries_no_content() {
        // It grants access. It does not carry data. Anything that looks like
        // user content here is a defect.
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let payload = package.decrypt(&seed).unwrap();

        // Envelopes hold wrapped keys and ids, never plaintext payloads.
        let json = serde_json::to_string(&payload.envelopes).unwrap();
        assert!(json.contains("bill-001"));
        assert!(!json.contains("plaintext"));
    }
}
```

Add to `rust/airo_mind/src/vault/mod.rs`:

```rust
mod package;

pub use package::{RecoveryPackage, RECOVERY_PACKAGE_FORMAT_VERSION};

impl Vault {
    /// Serializable interior. Crate-visible: only export and restore use it.
    pub(crate) fn to_payload(&self) -> package::VaultPayload {
        package::VaultPayload {
            root_public_key: self.root_public_key,
            context_keys: self
                .context_keys
                .iter()
                .map(|(id, key)| (id.clone(), *key.as_bytes()))
                .collect(),
            envelopes: self.envelopes.clone(),
            device_certificates: self.device_certificates.clone(),
            revocations: self.revocations.clone(),
        }
    }
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
use super::revocation::RevocationLedger;
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

/// A revocation ledger plus where it came from.
pub struct RevocationSource {
    ledger: RevocationLedger,
    provenance: RevocationProvenance,
}

impl RevocationSource {
    pub fn replayed_from_log(ledger: RevocationLedger, head_operation_id: String) -> Self {
        Self {
            ledger,
            provenance: RevocationProvenance::ReplayedFromLog { head_operation_id },
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
    pub fn load(package: &RecoveryPackage, seed: &Seed) -> Result<Self, VaultError> {
        let payload = package.decrypt(seed)?;
        let expected = RootIdentity::from_seed(seed)?.public_key();
        if payload.root_public_key != expected || package.identity_public_key != expected {
            return Err(VaultError::IdentityMismatch);
        }
        payload.revocations.validate()?;
        Ok(Self {
            payload,
            backup_epoch: package.revocation_epoch,
        })
    }

    pub fn backup_epoch(&self) -> u64 {
        self.backup_epoch
    }

    /// Destroys everything revoked, from both the package and `source`.
    ///
    /// Consuming `self` is what makes the unsafe path unrepresentable: there
    /// is no way to reach a `Vault` without passing through here.
    ///
    /// Purges content envelopes, context keys, **and device certificates** —
    /// all three are revocable subjects, and omitting devices means a stale
    /// backup readmits a revoked device.
    pub fn apply_revocations(mut self, source: &RevocationSource) -> AppliedRestore {
        self.payload.revocations.merge(&source.ledger);

        let mut purged = Vec::new();
        for subject in self.payload.revocations.all_revoked() {
            match &subject {
                RevocationSubject::Content(id) => {
                    if self.payload.envelopes.remove(id).is_some() {
                        purged.push(subject.clone());
                    }
                }
                RevocationSubject::Context(id) => {
                    if self.payload.context_keys.remove(id).is_some() {
                        purged.push(subject.clone());
                    }
                }
                RevocationSubject::Device(id) => {
                    let before = self.payload.device_certificates.len();
                    self.payload.device_certificates.retain(|c| &c.device_id != id);
                    if self.payload.device_certificates.len() != before {
                        purged.push(subject.clone());
                    }
                }
            }
        }
        purged.sort();

        // The caller handed us a ledger older than the backup itself. Not an
        // error — an offline restore is legitimate — but the UI must say so.
        let stale = source.ledger.head_epoch() < self.backup_epoch;

        AppliedRestore {
            payload: self.payload,
            purged,
            provenance: source.provenance.clone(),
            source_older_than_backup: stale,
        }
    }
}

/// A restore with revocations applied. The only source of a usable `Vault`.
pub struct AppliedRestore {
    payload: VaultPayload,
    purged: Vec<RevocationSubject>,
    provenance: RevocationProvenance,
    source_older_than_backup: bool,
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
    pub fn was_blind(&self) -> bool {
        !matches!(self.provenance, RevocationProvenance::ReplayedFromLog { .. })
    }

    /// True when the supplied ledger predates the backup being restored.
    pub fn source_older_than_backup(&self) -> bool {
        self.source_older_than_backup
    }

    pub fn into_vault(self) -> Vault {
        Vault::from_payload(self.payload)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
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
        vault.add_content("hiv-test-result", &["health"]).unwrap();
        vault.add_content("grocery-list", &["home"]).unwrap();
        vault
    }

    #[test]
    fn restoring_an_up_to_date_backup_purges_nothing() {
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let restored = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::package_only());

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
        live.destroy_content("hiv-test-result").unwrap();
        let current_revocations = live.revocations().clone();

        let restored = SealedRestore::load(&stale_backup, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(current_revocations, "op-42".into()));

        assert_eq!(restored.purged(), &["hiv-test-result".to_string()]);

        let vault = restored.into_vault();
        assert!(vault.revocations().is_revoked("hiv-test-result"));
        assert!(!vault.has_content("hiv-test-result"));
        assert!(vault.has_content("grocery-list"));
    }

    #[test]
    fn backup_epoch_is_readable_before_revocations_are_applied() {
        let mut vault = vault_with_content();
        vault.destroy_content("grocery-list").unwrap();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let sealed = SealedRestore::load(&package, &seed()).unwrap();
        assert_eq!(sealed.backup_epoch(), 1);
    }

    #[test]
    fn revocations_from_the_backup_itself_are_honored() {
        let mut vault = vault_with_content();
        vault.destroy_content("hiv-test-result").unwrap();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let restored = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::package_only());

        let vault = restored.into_vault();
        assert!(vault.revocations().is_revoked("hiv-test-result"));
        assert!(!vault.has_content("hiv-test-result"));
    }

    #[test]
    fn applying_revocations_twice_is_stable() {
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();
        let mut live = vault_with_content();
        live.destroy_content("hiv-test-result").unwrap();

        let once = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(live.revocations().clone(), "op-42".into()));
        let vault = once.into_vault();

        let repackaged = RecoveryPackage::export(&vault, &seed()).unwrap();
        let twice = SealedRestore::load(&repackaged, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(live.revocations().clone(), "op-42".into()));

        assert!(twice.purged().is_empty());
        assert!(!twice.into_vault().has_content("hiv-test-result"));
    }

    #[test]
    fn a_wrong_seed_never_reaches_a_sealed_restore() {
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();
        let stranger = seed_from_mnemonic(&crate::vault::generate_mnemonic()).unwrap();

        assert!(SealedRestore::load(&package, &stranger).is_err());
    }
}
```

Add to `rust/airo_mind/src/vault/mod.rs`:

```rust
mod restore;

pub use restore::{AppliedRestore, SealedRestore};

impl Vault {
    pub(crate) fn from_payload(payload: package::VaultPayload) -> Self {
        Self {
            root_public_key: payload.root_public_key,
            context_keys: payload
                .context_keys
                .into_iter()
                .map(|(id, bytes)| (id, ContextKey::from_bytes(bytes)))
                .collect(),
            envelopes: payload.envelopes,
            device_certificates: payload.device_certificates,
            revocations: payload.revocations,
        }
    }

    /// Whether content is still reachable in this Vault.
    pub fn has_content(&self, content_id: &str) -> bool {
        self.envelopes.contains_key(content_id)
    }
}
```

Add to `rust/airo_mind/src/vault/envelope.rs`, inside `impl ContextKey`:

```rust
    pub(crate) fn from_bytes(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test --manifest-path rust/Cargo.toml -p airo_mind restore`
Expected: FAIL to compile — module not declared, `from_payload` and `has_content` missing.

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
- [ ] No `fill_bytes` anywhere; `grep -rn "fill_bytes" rust/airo_mind/src` returns only `try_fill_bytes`
- [ ] No `derive(Debug)`, `derive(Clone)`, or `derive(PartialEq)` on any secret type
- [ ] `crate-type = ["rlib"]`; no `flutter_rust_bridge` dependency
- [ ] Third-party notices updated for BSD-3-Clause, and for CC0 if Path A was chosen
- [ ] `[profile.release]` added to `rust/Cargo.toml` — measured at 650 KB → 424 KB, and free
- [ ] Rust Architect has recorded an explicit "third-party audited `unsafe`, accepted" note for `curve25519-dalek`, `subtle`, and `fiat-crypto`, which trip the unreviewed-`unsafe` criterion transitively

Deferred with reasons: `packages/benchmarks` entry (Constitution §4 attaches the
benchmark requirement to merge and replay, which land in Phases 2–3); FFI
surface (#1259).

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

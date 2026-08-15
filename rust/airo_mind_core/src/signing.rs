//! Operation signing. `#1194`'s header field `signature`, and `C1`'s
//! "durable state exists only as Operations" reading requires every one of
//! them to carry one.
//!
//! # What this is, and what it is not
//!
//! `#1194`'s own issue body says it plainly: *"Blocked by Phase 1 (Vault) —
//! operations are signed and payloads are encrypted."* There is no device
//! identity or key hierarchy in this crate yet — Vault is a lifecycle
//! placeholder in [`crate::runtime`], nothing more. Shipping *"signed"* as a
//! checkbox with no verifiable mechanism behind it would be worse than
//! marking it undone, so this module gives every operation something real to
//! carry and verify today — a keyed digest over the header, keyed by the
//! device id the log already carries — while being explicit that
//! [`DeviceKeySigner`] is **not** a device certificate and does not resist an
//! attacker who can read the device id.
//!
//! What is real: [`Signer::sign`]/[`Verifier::verify`] are exercised on every
//! append, a tampered header fails verification (there is a test for it), and
//! the trait boundary is exactly where Phase 1's real Ed25519-over-device-
//! certificate signer plugs in — [`Runtime`](crate::runtime::Runtime) takes a
//! `Box<dyn Signer>`, so swapping the implementation is a constructor
//! argument, not a rewrite of anything that calls it.
//!
//! # Why a keyed digest and not a real signature scheme
//!
//! This crate carries zero dependencies (see `Cargo.toml`), so no ed25519
//! crate. A hand-rolled elliptic-curve implementation is exactly the kind of
//! `unsafe`-adjacent, security-critical code `C7` says must be *"isolated,
//! documented, benchmarked, fuzzed, audited"* before it is trusted with a
//! Vault's device keys — not something to improvise here as a side effect of
//! formalizing the operation log. [`Sha256`] already exists for a different
//! reason and is reused rather than adding a second hash implementation.

use crate::digest::Sha256;

/// Produces a signature over an operation header's canonical bytes
/// (`crate::runtime::canonical_header_bytes`, the same bytes
/// [`Verifier::verify`] must be given). Implementations decide what "signing"
/// means; the runtime never inspects the output beyond passing it back to a
/// matching [`Verifier`].
pub trait Signer: Send + Sync {
    fn sign(&self, canonical_header: &[u8]) -> Vec<u8>;
}

/// Checks a [`Signer`]'s output. Split from `Signer` because Phase 1's real
/// implementation verifies against a device's *public* certificate without
/// holding its private key — signing and verifying are different
/// capabilities even when, as here, one placeholder type implements both.
pub trait Verifier: Send + Sync {
    fn verify(&self, canonical_header: &[u8], signature: &[u8]) -> bool;
}

/// A type that can both sign and verify — what [`crate::runtime::OperationLog`]
/// needs, since this phase has one placeholder identity acting as both
/// parties. Blanket-implemented; nothing implements this trait directly.
pub trait SignerVerifier: Signer + Verifier {}
impl<T: Signer + Verifier> SignerVerifier for T {}

/// `sha256(device_key || canonical_header)`. Keyed by a per-device secret so
/// two devices produce different signatures over the same header — the
/// property a conformance test can check — without being anything close to a
/// real signature scheme: **no non-repudiation, no asymmetric verification
/// key, no resistance to an attacker who reads `device_key` off disk.**
///
/// `device_key` is deliberately not called a "private key" anywhere in this
/// module's public API, to avoid implying a guarantee it does not carry.
pub struct DeviceKeySigner {
    device_key: Vec<u8>,
}

impl DeviceKeySigner {
    pub fn new(device_key: impl Into<Vec<u8>>) -> Self {
        Self {
            device_key: device_key.into(),
        }
    }

    fn digest(&self, canonical_header: &[u8]) -> Vec<u8> {
        let mut h = Sha256::new();
        // Domain-separated and length-prefixed: `C7`'s "injective,
        // length-prefixed, domain-separated construction" for AAD-bound
        // fields applies here too, even though this is a placeholder --
        // getting the construction shape right now is free and is exactly
        // what makes swapping in a real MAC later a drop-in.
        h.update(b"airo-mind-op-sig-v1");
        h.update(&(self.device_key.len() as u32).to_be_bytes());
        h.update(&self.device_key);
        h.update(&(canonical_header.len() as u32).to_be_bytes());
        h.update(canonical_header);
        hex_to_bytes(&h.finish())
    }
}

impl Signer for DeviceKeySigner {
    fn sign(&self, canonical_header: &[u8]) -> Vec<u8> {
        self.digest(canonical_header)
    }
}

impl Verifier for DeviceKeySigner {
    fn verify(&self, canonical_header: &[u8], signature: &[u8]) -> bool {
        // Not constant-time: `C7` requires that of secret-vs-secret
        // comparisons. This compares a locally recomputed digest to a value
        // that already traveled in plaintext on this log, so timing leaks
        // nothing an attacker could not already read directly.
        self.digest(canonical_header) == signature
    }
}

fn hex_to_bytes(hex: &str) -> Vec<u8> {
    (0..hex.len())
        .step_by(2)
        .map(|i| {
            u8::from_str_radix(&hex[i..i + 2], 16).expect("Sha256::finish is always valid hex")
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_signature_verifies_against_the_same_header_it_was_taken_over() {
        let signer = DeviceKeySigner::new(b"device-a".to_vec());
        let header = b"seq=0;capability=notes;kind=note.create";
        let sig = signer.sign(header);
        assert!(signer.verify(header, &sig));
    }

    /// `C1`: durable state must be verifiable, and a verifier that accepts
    /// anything is not one. A single flipped byte in the header must be
    /// caught -- this is the "signature detects tampering" property `#1194`
    /// exists to make provable rather than assumed.
    #[test]
    fn a_tampered_header_fails_verification() {
        let signer = DeviceKeySigner::new(b"device-a".to_vec());
        let header = b"seq=0;capability=notes;kind=note.create".to_vec();
        let sig = signer.sign(&header);

        let mut tampered = header.clone();
        tampered[0] ^= 0x01;
        assert!(!signer.verify(&tampered, &sig));
    }

    #[test]
    fn a_tampered_signature_fails_verification() {
        let signer = DeviceKeySigner::new(b"device-a".to_vec());
        let header = b"seq=0;capability=notes;kind=note.create";
        let mut sig = signer.sign(header);
        sig[0] ^= 0x01;
        assert!(!signer.verify(header, &sig));
    }

    /// Two devices must not be interchangeable signers -- the property that
    /// makes `device_id` meaningful on the header at all.
    #[test]
    fn two_devices_produce_different_signatures_over_the_same_header() {
        let a = DeviceKeySigner::new(b"device-a".to_vec());
        let b = DeviceKeySigner::new(b"device-b".to_vec());
        let header = b"seq=0;capability=notes;kind=note.create";
        assert_ne!(a.sign(header), b.sign(header));
    }

    #[test]
    fn signing_is_deterministic_for_the_same_key_and_header() {
        let signer = DeviceKeySigner::new(b"device-a".to_vec());
        let header = b"seq=0;capability=notes;kind=note.create";
        assert_eq!(signer.sign(header), signer.sign(header));
    }
}

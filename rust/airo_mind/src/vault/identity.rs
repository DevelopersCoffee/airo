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
        assert!(id
            .chars()
            .all(|c| c.is_ascii_hexdigit() && !c.is_uppercase()));
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

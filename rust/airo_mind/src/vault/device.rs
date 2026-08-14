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
        assert_ne!(
            DeviceKey::generate().unwrap().public_key(),
            DeviceKey::generate().unwrap().public_key()
        );
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
        let certificate =
            DeviceCertificate::issue(&root, &DeviceKey::generate().unwrap(), 1).unwrap();
        assert!(!certificate.verify_against(&stranger.public_key()));
    }

    #[test]
    fn swapping_the_public_key_invalidates_the_certificate() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let certificate =
            DeviceCertificate::issue(&root, &DeviceKey::generate().unwrap(), 1).unwrap();
        let certificate =
            certificate.with_public_key_tampered(DeviceKey::generate().unwrap().public_key());
        assert!(!certificate.verify_against(&root.public_key()));
    }

    #[test]
    fn device_id_must_match_the_public_key() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let certificate =
            DeviceCertificate::issue(&root, &DeviceKey::generate().unwrap(), 1).unwrap();
        let certificate = certificate.with_device_id_tampered("deadbeef");
        assert!(!certificate.verify_against(&root.public_key()));
    }

    #[test]
    fn changing_the_issue_epoch_invalidates_the_certificate() {
        let root = RootIdentity::from_seed(&test_seed()).unwrap();
        let certificate =
            DeviceCertificate::issue(&root, &DeviceKey::generate().unwrap(), 1).unwrap();
        let certificate = certificate.with_issued_at_tampered(99);
        assert!(!certificate.verify_against(&root.public_key()));
    }
}

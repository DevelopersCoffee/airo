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

        envelope
            .add_wrapping(&content_key, "hospitalization", &hospital)
            .unwrap();

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

        envelope
            .add_wrapping(&content_key, "hospitalization", &hospital)
            .unwrap();
        envelope
            .add_wrapping(&content_key, "finance", &finance)
            .unwrap();
        envelope
            .add_wrapping(&content_key, "tax-2026", &tax)
            .unwrap();

        for (id, key) in [
            ("hospitalization", &hospital),
            ("finance", &finance),
            ("tax-2026", &tax),
        ] {
            assert_eq!(
                envelope.unwrap_with(id, key).unwrap().as_bytes(),
                content_key.as_bytes()
            );
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
        envelope
            .add_wrapping(&content_key, "hospitalization", &hospital)
            .unwrap();
        envelope
            .add_wrapping(&content_key, "tax-2026", &tax)
            .unwrap();

        assert!(envelope.remove_wrapping("hospitalization"));

        assert!(!envelope.is_orphaned());
        assert_eq!(
            envelope.unwrap_with("tax-2026", &tax).unwrap().as_bytes(),
            content_key.as_bytes()
        );
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
        envelope
            .add_wrapping(&content_key, "hospitalization", &hospital)
            .unwrap();

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
        envelope
            .add_wrapping(&content_key, "hospitalization", &hospital)
            .unwrap();

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
        envelope
            .add_wrapping(&content_key, "hospitalization", &hospital)
            .unwrap();

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
        envelope
            .add_wrapping(&content_key, "hospitalization", &hospital)
            .unwrap();
        envelope
            .add_wrapping(&content_key, "hospitalization", &hospital)
            .unwrap();

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
        envelope
            .add_wrapping(&content_key, "hospitalization", &hospital)
            .unwrap();

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

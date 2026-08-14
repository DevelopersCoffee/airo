use std::collections::BTreeMap;

use super::device::DeviceCertificate;
use super::envelope::{ContentEnvelope, ContentKey, ContextKey, SealedEnvelope};
use super::error::VaultError;
use super::identifier::{ContentId, ContextId, DeviceId};
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
        if self
            .revocations
            .is_revoked(&RevocationSubject::Context(context_id.to_string()))
        {
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
            return Err(VaultError::ContentRevoked(
                envelope.content_id().to_string(),
            ));
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
    pub fn revoke_device(&mut self, device_id: &DeviceId) -> Result<PurgeDirective, VaultError> {
        let device_id = device_id.as_str();
        let before = self.device_certificates.len();
        self.device_certificates
            .retain(|c| c.device_id() != device_id);
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
            return Err(VaultError::DeviceRevoked(
                certificate.device_id().to_string(),
            ));
        }
        if !certificate.verify_against(&self.root_public_key) {
            return Err(VaultError::UntrustedCertificate);
        }
        self.device_certificates
            .retain(|c| c.device_id() != certificate.device_id());
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
            .add_content(
                &content_id("bill-001"),
                &[&cid("hospitalization"), &cid("finance"), &cid("tax-2026")],
            )
            .unwrap();

        for context in ["hospitalization", "finance", "tax-2026"] {
            let context_key = vault.context_key(context).unwrap();
            assert_eq!(
                envelope
                    .unwrap_with(context, context_key)
                    .unwrap()
                    .as_bytes(),
                key.as_bytes()
            );
        }
    }

    #[test]
    fn unlinking_reports_what_survives() {
        let mut vault = vault();
        let (_key, mut envelope) = vault
            .add_content(
                &content_id("bill-001"),
                &[&cid("hospitalization"), &cid("finance"), &cid("tax-2026")],
            )
            .unwrap();

        let outcome = vault
            .unlink_content(&cid("hospitalization"), &mut envelope)
            .unwrap();

        assert!(!outcome.now_orphaned);
        assert_eq!(
            outcome.remaining_contexts,
            vec!["finance".to_string(), "tax-2026".to_string()]
        );
    }

    #[test]
    fn unlinking_the_last_context_reports_orphaned() {
        let mut vault = vault();
        let (_key, mut envelope) = vault
            .add_content(&content_id("note-1"), &[&cid("inbox")])
            .unwrap();

        let outcome = vault.unlink_content(&cid("inbox"), &mut envelope).unwrap();

        assert!(outcome.now_orphaned);
        assert!(outcome.remaining_contexts.is_empty());
    }

    #[test]
    fn linking_adds_a_context_without_re_encrypting_content() {
        let mut vault = vault();
        let (key, mut envelope) = vault
            .add_content(&content_id("bill-001"), &[&cid("hospitalization")])
            .unwrap();

        vault.link_content(&cid("tax-2026"), &mut envelope).unwrap();

        let tax_key = vault.context_key("tax-2026").unwrap();
        let recovered = envelope.unwrap_with("tax-2026", tax_key).unwrap();
        assert_eq!(recovered.as_bytes(), key.as_bytes());
    }

    #[test]
    fn destroy_revokes_and_returns_a_purge_directive() {
        let mut vault = vault();
        vault
            .add_content(&content_id("note-1"), &[&cid("inbox")])
            .unwrap();

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
        vault
            .add_content(&content_id("note-1"), &[&cid("inbox")])
            .unwrap();
        let _ = vault.destroy_content(&content_id("note-1")).unwrap();

        assert_eq!(
            vault
                .add_content(&content_id("note-1"), &[&cid("inbox")])
                .unwrap_err(),
            VaultError::ContentRevoked("note-1".into())
        );
    }

    #[test]
    fn adding_a_context_twice_keeps_the_same_key() {
        let mut vault = vault();
        let first = vault
            .add_context(&cid("inbox"))
            .unwrap()
            .as_bytes()
            .to_owned();
        let second = vault
            .add_context(&cid("inbox"))
            .unwrap()
            .as_bytes()
            .to_owned();
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

        let _directive = vault
            .revoke_device(&DeviceId::new(certificate.device_id()).unwrap())
            .unwrap();
        assert!(vault.trusted_devices().is_empty());

        // The certificate is still validly signed. That is exactly why the
        // signature alone was never the answer.
        assert!(
            matches!(
                vault.trust_device(certificate),
                Err(VaultError::DeviceRevoked(_))
            ),
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

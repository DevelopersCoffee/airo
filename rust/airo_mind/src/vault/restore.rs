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
        !matches!(
            self.provenance,
            RevocationProvenance::ReplayedFromLog { .. }
        )
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
        vault
            .add_content(&content_id("hiv-test-result"), &[&cid("health")])
            .unwrap();
        vault
            .add_content(&content_id("grocery-list"), &[&cid("home")])
            .unwrap();
        vault
    }

    #[test]
    fn restoring_an_up_to_date_backup_purges_nothing() {
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let restored = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::package_only())
            .unwrap();

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
        let _ = live
            .destroy_content(&content_id("hiv-test-result"))
            .unwrap();
        let current_revocations = live.revocations().clone();

        let restored = SealedRestore::load(&stale_backup, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(
                current_revocations,
                LogHead::for_test("op-42"),
            ))
            .unwrap();

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
        let _ = vault
            .destroy_content(&content_id("hiv-test-result"))
            .unwrap();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let restored = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::package_only())
            .unwrap();

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
        vault
            .trust_device(DeviceCertificate::issue(&identity, &device, 1).unwrap())
            .unwrap();
        let stale_backup = RecoveryPackage::export(&vault, &seed()).unwrap();

        // ... the laptop is stolen and revoked on the phone.
        let mut live = Vault::new(identity.public_key());
        live.trust_device(DeviceCertificate::issue(&identity, &device, 1).unwrap())
            .unwrap();
        let _ = live
            .revoke_device(&DeviceId::new(&device_id).unwrap())
            .unwrap();

        let restored = SealedRestore::load(&stale_backup, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(
                live.revocations().clone(),
                LogHead::for_test("op-7"),
            ))
            .unwrap();

        let vault = restored.into_vault();
        assert!(vault.trusted_devices().is_empty());
    }

    #[test]
    fn applying_revocations_twice_is_stable() {
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();
        let mut live = vault_with_content();
        let _ = live
            .destroy_content(&content_id("hiv-test-result"))
            .unwrap();

        let once = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(
                live.revocations().clone(),
                LogHead::for_test("op-42"),
            ))
            .unwrap();
        let vault = once.into_vault();

        let repackaged = RecoveryPackage::export(&vault, &seed()).unwrap();
        let twice = SealedRestore::load(&repackaged, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(
                live.revocations().clone(),
                LogHead::for_test("op-42"),
            ))
            .unwrap();

        assert!(twice.purged().is_empty());
        assert!(twice
            .into_vault()
            .is_content_destroyed(&content_id("hiv-test-result")));
    }

    #[test]
    fn provenance_drives_the_blind_warning() {
        // R1's fix shipped untested in revision 2. These are the tests.
        let vault = vault_with_content();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let blind = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::package_only())
            .unwrap();
        assert!(blind.was_blind());

        let acknowledged = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::acknowledged_blind_restore())
            .unwrap();
        assert!(acknowledged.was_blind());

        let from_log = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(
                RevocationLedger::new(),
                LogHead::for_test("op-1"),
            ))
            .unwrap();
        assert!(!from_log.was_blind());
    }

    #[test]
    fn a_source_containing_every_backup_revocation_is_not_flagged_missing() {
        // Guards against reintroducing the epoch comparison: a log-replayed
        // ledger that knows everything the package knows must not be flagged,
        // regardless of whose counter is higher.
        let mut vault = vault_with_content();
        let _ = vault
            .destroy_content(&content_id("hiv-test-result"))
            .unwrap();
        let package = RecoveryPackage::export(&vault, &seed()).unwrap();

        let applied = SealedRestore::load(&package, &seed())
            .unwrap()
            .apply_revocations(&RevocationSource::replayed_from_log(
                vault.revocations().clone(),
                LogHead::for_test("op-9"),
            ))
            .unwrap();

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

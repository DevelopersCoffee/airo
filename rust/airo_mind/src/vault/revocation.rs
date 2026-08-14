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
        assert_eq!(
            ledger
                .revoke(RevocationSubject::Content("note-1".into()))
                .unwrap(),
            1
        );
        assert_eq!(
            ledger
                .revoke(RevocationSubject::Content("note-2".into()))
                .unwrap(),
            2
        );
        assert_eq!(ledger.head_epoch(), 2);
    }

    #[test]
    fn revoked_content_is_reported_as_revoked() {
        let mut ledger = RevocationLedger::new();
        ledger
            .revoke(RevocationSubject::Content("note-1".into()))
            .unwrap();
        assert!(ledger.is_content_revoked("note-1"));
        assert!(!ledger.is_content_revoked("note-2"));
    }

    #[test]
    fn revoking_twice_is_idempotent() {
        let mut ledger = RevocationLedger::new();
        let first = ledger
            .revoke(RevocationSubject::Content("note-1".into()))
            .unwrap();
        let second = ledger
            .revoke(RevocationSubject::Content("note-1".into()))
            .unwrap();
        assert_eq!(first, second);
        assert_eq!(ledger.head_epoch(), 1);
    }

    #[test]
    fn revoked_since_returns_only_later_revocations() {
        let mut ledger = RevocationLedger::new();
        ledger
            .revoke(RevocationSubject::Content("old-1".into()))
            .unwrap();
        ledger
            .revoke(RevocationSubject::Content("old-2".into()))
            .unwrap();
        let backup_epoch = ledger.head_epoch();
        ledger
            .revoke(RevocationSubject::Content("new-1".into()))
            .unwrap();
        ledger
            .revoke(RevocationSubject::Content("new-2".into()))
            .unwrap();

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
        ledger
            .revoke(RevocationSubject::Content("a".into()))
            .unwrap();
        ledger
            .revoke(RevocationSubject::Content("b".into()))
            .unwrap();
        assert_eq!(ledger.revoked_since(0).len(), 2);
    }

    #[test]
    fn merge_is_order_independent() {
        let mut phone = RevocationLedger::new();
        phone
            .revoke(RevocationSubject::Content("p1".into()))
            .unwrap();
        phone
            .revoke(RevocationSubject::Content("p2".into()))
            .unwrap();

        let mut laptop = RevocationLedger::new();
        laptop
            .revoke(RevocationSubject::Content("l1".into()))
            .unwrap();

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
        phone
            .revoke(RevocationSubject::Content("p1".into()))
            .unwrap();
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
        phone
            .revoke(RevocationSubject::Content(
                "destroyed-medical-record".into(),
            ))
            .unwrap();

        let mut laptop = RevocationLedger::new();
        laptop
            .revoke(RevocationSubject::Content("unrelated".into()))
            .unwrap();
        laptop.merge(&phone);

        assert!(laptop.is_content_revoked("destroyed-medical-record"));
    }

    #[test]
    fn serialization_round_trips() {
        let mut ledger = RevocationLedger::new();
        ledger
            .revoke(RevocationSubject::Content("a".into()))
            .unwrap();
        ledger
            .revoke(RevocationSubject::Content("b".into()))
            .unwrap();
        let json = serde_json::to_string(&ledger).unwrap();
        let restored: RevocationLedger = serde_json::from_str(&json).unwrap();
        assert_eq!(ledger, restored);
    }
}

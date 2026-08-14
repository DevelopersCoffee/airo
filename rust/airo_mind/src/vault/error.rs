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

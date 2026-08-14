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
pub use device::{DeviceCertificate, DeviceKey};
pub use envelope::{ContentEnvelope, ContentKey, SealedEnvelope};
pub use error::VaultError;
pub use identifier::{ContentId, ContextId, DeviceId};
pub use identity::{RootIdentity, RootPublicKey};
pub use package::{RecoveryPackage, RECOVERY_PACKAGE_FORMAT_VERSION};
pub use restore::{AppliedRestore, RevocationProvenance, RevocationSource, SealedRestore};
pub use revocation::RevocationSubject;
pub use seed::{generate_mnemonic, seed_from_mnemonic, Seed};

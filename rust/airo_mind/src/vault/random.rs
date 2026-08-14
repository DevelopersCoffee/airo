//! Every RNG call site in the crate. There are no others.
//!
//! `try_fill_bytes`, never `fill_bytes` — the latter aborts the process when
//! the OS RNG fails, and `AeadCore::generate_nonce` panics for the same
//! reason. Early-boot entropy failure on Android is rare but real, and a panic
//! in the key-generation path of a medical-records vault is the wrong failure
//! mode.
//!
//! One module so the guarantee is greppable: `rg 'OsRng' src/ | grep -v
//! random.rs` must return nothing, which is the CI check the Definition of
//! Done promises.

use rand_core::RngCore;

use super::error::VaultError;

fn fill(out: &mut [u8]) -> Result<(), VaultError> {
    rand_core::OsRng
        .try_fill_bytes(out)
        .map_err(|_| VaultError::RngUnavailable)
}

pub(crate) fn random_key() -> Result<[u8; 32], VaultError> {
    let mut bytes = [0u8; 32];
    fill(&mut bytes)?;
    Ok(bytes)
}

pub(crate) fn random_nonce() -> Result<[u8; 24], VaultError> {
    let mut bytes = [0u8; 24];
    fill(&mut bytes)?;
    Ok(bytes)
}

/// Device signing-key seed and BIP-39 entropy are both 32 bytes, but they are
/// not keys and not nonces — a distinct name so the call sites read honestly.
pub(crate) fn random_bytes_32() -> Result<[u8; 32], VaultError> {
    let mut bytes = [0u8; 32];
    fill(&mut bytes)?;
    Ok(bytes)
}

/// Salt is variable-length by format, so this fills in place.
pub(crate) fn fill_random(out: &mut [u8]) -> Result<(), VaultError> {
    fill(out)
}

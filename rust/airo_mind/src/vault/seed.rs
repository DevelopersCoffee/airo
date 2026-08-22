//! Recovery seed. The root of everything the user can ever recover.
//!
//! BIP-39 implemented in-house rather than taken as a dependency: ~200 lines
//! auditable in full, verifiable against the complete official test vectors,
//! and three fewer crates on the path that generates the recovery secret for
//! medical and financial records.

use hmac::Hmac;
use sha2::{Digest, Sha256, Sha512};
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use super::error::VaultError;
use super::wordlist::WORDS;

/// 24 words = 256 bits of entropy + an 8-bit checksum.
const ENTROPY_BYTES: usize = 32;
const WORD_COUNT: usize = 24;
/// Fixed by BIP-39. Not a tunable.
const PBKDF2_ROUNDS: u32 = 2048;

/// A 64-byte BIP-39 seed. Zeroized on drop.
///
/// No `Clone`: the seed is the one secret whose compromise is total and
/// unrecoverable, and silent duplication is how copies end up unzeroized.
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct Seed([u8; 64]);

impl Seed {
    /// `SEC-33` / `A01`. `pub(crate)`: the two HKDF derivations need it and no
    /// consumer does. The 64-byte master seed is the one secret whose
    /// compromise is total.
    pub(crate) fn as_bytes(&self) -> &[u8; 64] {
        &self.0
    }
}

/// Generates a fresh 24-word recovery mnemonic.
///
/// Shown to the user exactly once. There is no other copy, and no server-side
/// recovery path — that is the product promise, and it is also the reason the
/// onboarding flow (#1234) must confirm the user recorded it.
pub fn generate_mnemonic() -> Result<Zeroizing<String>, VaultError> {
    let mut entropy = Zeroizing::new([0u8; ENTROPY_BYTES]);
    super::random::fill_random(entropy.as_mut())?;
    Ok(mnemonic_from_entropy(&entropy))
}

/// Encodes entropy as a mnemonic. Separated from generation so the official
/// test vectors can drive it directly.
fn mnemonic_from_entropy(entropy: &[u8; ENTROPY_BYTES]) -> Zeroizing<String> {
    // Checksum: the first `entropy_bits / 32` bits of SHA-256(entropy).
    let checksum = Sha256::digest(entropy);
    let checksum_bits = ENTROPY_BYTES * 8 / 32; // 8 for 256-bit entropy

    // Concatenate entropy || checksum bits, then read 11 bits per word.
    let mut bits = Vec::with_capacity(ENTROPY_BYTES * 8 + checksum_bits);
    for byte in entropy.iter() {
        for i in (0..8).rev() {
            bits.push((byte >> i) & 1 == 1);
        }
    }
    for i in 0..checksum_bits {
        bits.push((checksum[i / 8] >> (7 - (i % 8))) & 1 == 1);
    }

    let words: Vec<&str> = bits
        .chunks(11)
        .map(|chunk| {
            let index = chunk
                .iter()
                .fold(0usize, |acc, bit| (acc << 1) | *bit as usize);
            WORDS[index]
        })
        .collect();

    Zeroizing::new(words.join(" "))
}

/// Derives the 64-byte seed from a mnemonic phrase.
///
/// Validates word membership and the checksum before deriving — a typo must
/// fail here, not silently produce a valid-looking seed for the wrong vault.
///
/// No passphrase in v1. The Recovery Package reserves `passphrase_used`,
/// `kdf_params`, and `kdf_salt` so the option survives; see Task 8.
pub fn seed_from_mnemonic(phrase: &str) -> Result<Seed, VaultError> {
    seed_from_mnemonic_with_passphrase(phrase, "")
}

/// Derivation with an explicit passphrase.
///
/// `seed_from_mnemonic` calls this with `""`. It exists separately for two
/// reasons: the official BIP-39 vectors are published with the passphrase
/// `"TREZOR"` and cannot be used without it, and the Recovery Package format
/// already reserves `passphrase_used` / `kdf_params` / `kdf_salt` (Task 8), so
/// this is the entry point that slot will use.
pub(crate) fn seed_from_mnemonic_with_passphrase(
    phrase: &str,
    passphrase: &str,
) -> Result<Seed, VaultError> {
    let words = validate_mnemonic(phrase)?;

    // CANONICALIZE before derivation. BIP-39 specifies the PBKDF2 password as
    // the NFKD-normalized *sentence*: words joined by exactly one space, no
    // leading or trailing whitespace.
    //
    // Passing the raw input instead means a user who pastes 24 correct words
    // with a trailing newline or a double space passes validation, passes the
    // checksum, and then derives a completely different seed — surfacing as
    // "wrong seed" while their mnemonic is perfectly correct. On a recovery
    // path for medical and financial records that is the worst failure
    // available.
    //
    // v1 is English-only and NFKD is the identity on ASCII. Adding a
    // non-ASCII wordlist REQUIRES a Unicode normalization step here.
    let canonical = Zeroizing::new(words.join(" "));

    let mut salt = Zeroizing::new(Vec::with_capacity(8 + passphrase.len()));
    salt.extend_from_slice(b"mnemonic");
    salt.extend_from_slice(passphrase.as_bytes());

    Ok(Seed(pbkdf2_hmac_sha512(
        canonical.as_bytes(),
        &salt,
        PBKDF2_ROUNDS,
    )?))
}

/// Validates word membership and the checksum. Returns the words for
/// canonicalization.
///
/// A typo must fail here, not silently produce a valid-looking seed for a
/// vault that does not exist.
fn validate_mnemonic(phrase: &str) -> Result<Vec<&str>, VaultError> {
    let words: Vec<&str> = phrase.split_whitespace().collect();
    if words.len() != WORD_COUNT {
        return Err(VaultError::InvalidMnemonic);
    }

    // `u8` rather than `bool`: this buffer is a bit-for-bit expansion of the
    // entropy — the same secret in a more scannable form — so it must be
    // zeroized, and `Zeroize` is not implemented for `Vec<bool>`.
    let mut bits: Zeroizing<Vec<u8>> = Zeroizing::new(Vec::with_capacity(WORD_COUNT * 11));
    for word in &words {
        // Linear scan over 2048 entries. Note this is data-dependent and is
        // NOT constant time — see the note on the checksum comparison below.
        let index = WORDS
            .iter()
            .position(|candidate| candidate == word)
            .ok_or(VaultError::InvalidMnemonic)?;
        for i in (0..11).rev() {
            bits.push(((index >> i) & 1) as u8);
        }
    }

    let entropy_bits = ENTROPY_BYTES * 8;
    let mut entropy = Zeroizing::new([0u8; ENTROPY_BYTES]);
    for (i, bit) in bits[..entropy_bits].iter().enumerate() {
        if *bit == 1 {
            entropy[i / 8] |= 1 << (7 - (i % 8));
        }
    }

    // Checksum comparison is written branch-free for tidiness, but this
    // function is NOT constant time overall: the wordlist lookup above is a
    // data-dependent scan with an early return, and it dominates. That is
    // acceptable here — this runs once per restore against locally-entered
    // input, and the adversary is not measuring our timing. Stating the real
    // property rather than claiming one the code does not have (invariant I3).
    let expected = Sha256::digest(entropy.as_ref());
    let checksum_bits = entropy_bits / 32;
    let mut diff = 0u8;
    for i in 0..checksum_bits {
        let want = (expected[i / 8] >> (7 - (i % 8))) & 1;
        diff |= bits[entropy_bits + i] ^ want;
    }
    if diff != 0 {
        return Err(VaultError::InvalidMnemonic);
    }

    Ok(words)
}

/// Guards the bit-packing arithmetic. 256 entropy bits + 8 checksum bits = 264,
/// which is exactly 24 * 11. If `ENTROPY_BYTES` ever changes, a short final
/// chunk would silently fold to a small word index instead of failing.
const _: () = assert!((ENTROPY_BYTES * 8 + ENTROPY_BYTES * 8 / 32).is_multiple_of(11));

/// PBKDF2-HMAC-SHA512 producing exactly 64 bytes — one block, since SHA-512's
/// output is 64 bytes, so the block-index loop collapses to a single pass.
///
/// Hand-written rather than pulling the `pbkdf2` crate: this is the whole
/// algorithm, it is driven entirely by the official BIP-39 vectors in Step 1,
/// and it keeps the trusted computing base on the recovery path to `sha2` and
/// `hmac` alone.
fn pbkdf2_hmac_sha512(password: &[u8], salt: &[u8], rounds: u32) -> Result<[u8; 64], VaultError> {
    use hmac::Mac;

    // `.expect()` is forbidden outside tests (Global Constraints). HMAC does
    // accept any key length — which is exactly why mapping the error costs
    // nothing and a panic here would be gratuitous.
    let mut mac = <Hmac<Sha512> as Mac>::new_from_slice(password)
        .map_err(|_| VaultError::DerivationFailed)?;
    mac.update(salt);
    mac.update(&1u32.to_be_bytes()); // block index, big-endian
    let mut u = Zeroizing::new(mac.finalize().into_bytes().to_vec());

    let mut out = [0u8; 64];
    out.copy_from_slice(&u);

    for _ in 1..rounds {
        let mut mac = <Hmac<Sha512> as Mac>::new_from_slice(password)
            .map_err(|_| VaultError::DerivationFailed)?;
        mac.update(&u);
        // Each intermediate is the same secret in another form — zeroized on
        // reassignment because the binding is `Zeroizing`.
        u = Zeroizing::new(mac.finalize().into_bytes().to_vec());
        for (acc, byte) in out.iter_mut().zip(u.iter()) {
            *acc ^= byte;
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};

    #[test]
    fn generated_mnemonic_has_24_words() {
        let phrase = generate_mnemonic().unwrap();
        assert_eq!(phrase.split_whitespace().count(), 24);
    }

    #[test]
    fn generated_mnemonic_round_trips_to_a_seed() {
        let phrase = generate_mnemonic().unwrap();
        assert!(seed_from_mnemonic(&phrase).is_ok());
    }

    #[test]
    fn same_mnemonic_always_yields_the_same_seed() {
        let phrase = generate_mnemonic().unwrap();
        let a = seed_from_mnemonic(&phrase).unwrap();
        let b = seed_from_mnemonic(&phrase).unwrap();
        assert_eq!(a.as_bytes(), b.as_bytes());
    }

    #[test]
    fn two_generated_mnemonics_differ() {
        assert_ne!(*generate_mnemonic().unwrap(), *generate_mnemonic().unwrap());
    }

    #[test]
    fn wordlist_matches_the_specification() {
        // Index order IS the encoding: one moved entry silently changes every
        // mnemonic ever generated, and no other test would notice.
        //
        // The expected digest is not written here by hand. Compute it once from
        // the official english.txt and paste the result — see Step 3.
        assert_eq!(WORDS.len(), 2048);
        assert_eq!(WORDS[0], "abandon");
        assert_eq!(WORDS[2047], "zoo");
        assert_eq!(
            hex_lower(&Sha256::digest((WORDS.join("\n") + "\n").as_bytes())),
            // Source-level const with provenance independent of the fetch.
            // See Step 3 — a digest generated by the download command
            // validates nothing.
            crate::vault::wordlist::EXPECTED_WORDLIST_SHA256
        );
    }

    // No `#[ignore]`: Step 3's fixture is vendored and committed as of #1731,
    // so the vector set runs on every `cargo test`.
    #[test]
    fn official_vectors_encode_and_derive_correctly() {
        // Drives the COMPLETE Trezor reference vector set from a checked-in
        // fixture. Do not transcribe vectors by hand into this file: a
        // mistyped expectation either fails mysteriously or, worse, gets
        // "fixed" by bending the implementation to match it.
        //
        // Fixture format, one case per line, tab-separated:
        //     <entropy_hex>\t<mnemonic>\t<seed_hex>
        // Only the 256-bit (24-word) cases apply here; skip the rest.
        let raw = std::fs::read_to_string("tests/fixtures/bip39/vectors.tsv")
            .expect("vendored by Task 2 Step 3");
        let mut checked = 0;

        for line in raw.lines().filter(|l| !l.trim().is_empty()) {
            let mut parts = line.split('\t');
            let entropy_hex = parts.next().expect("entropy column");
            let expected_phrase = parts.next().expect("mnemonic column");
            let expected_seed = parts.next().expect("seed column");

            if entropy_hex.len() != ENTROPY_BYTES * 2 {
                continue; // not a 24-word case
            }

            let entropy: [u8; ENTROPY_BYTES] = hex_bytes(entropy_hex).try_into().expect("32 bytes");

            let phrase = mnemonic_from_entropy(&entropy);
            assert_eq!(&*phrase, expected_phrase, "encoding {entropy_hex}");

            // Official vectors use the passphrase "TREZOR".
            let seed = seed_from_mnemonic_with_passphrase(&phrase, "TREZOR").unwrap();
            assert_eq!(
                hex_lower(seed.as_bytes()),
                expected_seed,
                "derivation {entropy_hex}"
            );

            checked += 1;
        }

        // Guards against an empty or truncated fixture silently passing.
        assert!(
            checked >= 8,
            "expected the full 24-word vector set, got {checked}"
        );
    }

    #[test]
    fn a_single_wrong_word_fails_the_checksum() {
        // A typo must fail here, not silently derive a valid-looking seed for
        // a vault that does not exist. One substitution still has a 1/256
        // chance of matching the 8-bit checksum, so try until one is rejected.
        let phrase = generate_mnemonic().unwrap();
        let original: Vec<&str> = phrase.split_whitespace().collect();
        let rejected = WORDS.iter().copied().any(|candidate| {
            if candidate == original[5] {
                return false;
            }
            let mut words = original.clone();
            words[5] = candidate;
            matches!(
                seed_from_mnemonic(&words.join(" ")),
                Err(VaultError::InvalidMnemonic)
            )
        });
        assert!(
            rejected,
            "a one-word substitution must be able to fail the checksum"
        );
    }

    #[test]
    fn non_canonical_whitespace_derives_the_same_seed() {
        // The bug this guards: passing raw user input to PBKDF2 instead of the
        // canonical sentence. A pasted mnemonic with a trailing newline or a
        // double space passed validation and the checksum, then derived a
        // COMPLETELY DIFFERENT seed — surfacing as "wrong seed" while the
        // user's mnemonic was perfectly correct.
        let phrase = generate_mnemonic().unwrap();
        let messy = format!("  {}  \n", phrase.replace(' ', "  "));

        assert_eq!(
            seed_from_mnemonic(&messy).unwrap().as_bytes(),
            seed_from_mnemonic(&phrase).unwrap().as_bytes()
        );
    }

    #[test]
    fn a_word_outside_the_list_is_rejected() {
        let phrase = generate_mnemonic().unwrap();
        let mut words: Vec<&str> = phrase.split_whitespace().collect();
        words[0] = "notabip39word";
        assert!(matches!(
            seed_from_mnemonic(&words.join(" ")),
            Err(VaultError::InvalidMnemonic)
        ));
    }

    #[test]
    fn wrong_word_count_is_rejected() {
        let phrase = generate_mnemonic().unwrap();
        let short: Vec<&str> = phrase.split_whitespace().take(23).collect();
        assert!(matches!(
            seed_from_mnemonic(&short.join(" ")),
            Err(VaultError::InvalidMnemonic)
        ));
    }

    fn hex_bytes(hex: &str) -> Vec<u8> {
        (0..hex.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
            .collect()
    }

    #[test]
    fn invalid_mnemonic_is_rejected() {
        assert!(matches!(
            seed_from_mnemonic("not a real mnemonic phrase at all"),
            Err(VaultError::InvalidMnemonic)
        ));
    }

    fn hex_lower(bytes: &[u8]) -> String {
        crate::vault::encoding::hex_of(bytes)
    }
}

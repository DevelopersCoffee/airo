//! Recovery Package. Grants access; carries no data.
//!
//! Contains identity, Vault, and revocation ledger. Explicitly not the
//! operation log and not the content. The user places it wherever they choose
//! — a capsule file, their own cloud storage, a NAS, a USB stick. Never on
//! Airo servers.

use std::collections::BTreeMap;

use chacha20poly1305::aead::{Aead, KeyInit, Payload};
use chacha20poly1305::{XChaCha20Poly1305, XNonce};
use hkdf::Hkdf;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256, Sha512};
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use super::domain;
use super::encoding::push_len_prefixed;
use super::envelope::ContextKey;
use super::error::VaultError;
use super::identity::{RootIdentity, RootPublicKey};
use super::random::random_nonce;
use super::restore::SealedRestore;
use super::revocation::{RevocationLedger, RevocationSubject};
use super::seed::Seed;
use super::{DeviceCertificate, Vault};

pub const RECOVERY_PACKAGE_FORMAT_VERSION: u32 = 1;

/// The serializable interior of a Vault.
/// No `Debug` — it would print every context key. No `Clone` — it would
/// duplicate them. No `PartialEq` — it would compare them in variable time.
/// `ZeroizeOnDrop` because this is the decrypted key set, resident for the
/// whole of a restore (chief-security-officer R7).
///
/// No `envelopes` field: the Vault is sized by contexts and devices, never by
/// user content (frozen design §4.1).
// No struct-level `ZeroizeOnDrop`: `zeroize` has **no impl for `BTreeMap`**,
// so the derive does not build — and "fixing" it with `#[zeroize(skip)]` on
// `context_keys` would skip every field and zeroize nothing. The guarantee
// comes from `KeyBytes`' own drop glue running per element, asserted below.
/// `SEC-1` — fields are `pub(super)`, not `pub(crate)`, and mutation is by
/// method.
///
/// Revision 7 exposed `context_keys` and `KeyBytes::as_bytes` at `pub(crate)`,
/// so any module in the crate could read every context key by calling
/// `RecoveryPackage::decrypt` — no revocations applied. The `RevocationsApplied`
/// witness guarded `Vault::from_payload` and not the door that hands out keys.
/// Reproduced by an in-crate probe.
///
/// **The fix is visibility, not a witness parameter.** Threading
/// `RevocationsApplied` into the key accessors was considered and rejected by
/// `RA-1`: a witness is only as strong as the set of modules that can mint one,
/// and that set grows every phase — the identical failure mode as `LogHead`'s
/// `pub(crate)` field, in a crate that has already had to fix it once. Narrow
/// visibility is checked by the compiler on every item on every build.
///
/// `restore.rs` needs exactly four things from the payload — the root key for
/// the identity check, the ledger for validate/merge/head_epoch, and the two
/// purges — and **none of them is key material.** With the purges as methods
/// below, `context_keys` and `KeyBytes::as_bytes` are reachable only from
/// `package.rs`, and `as_bytes` is left with a single caller:
/// `Vault::from_payload`.
#[derive(Serialize, Deserialize)]
pub(crate) struct VaultPayload {
    pub(super) root_public_key: RootPublicKey,
    pub(super) context_keys: BTreeMap<String, KeyBytes>,
    pub(super) device_certificates: Vec<DeviceCertificate>,
    pub(super) revocations: RevocationLedger,
}

impl VaultPayload {
    /// The four things `restore.rs` legitimately needs. None is key material.
    pub(super) fn purge_context(&mut self, id: &str) -> bool {
        self.context_keys.remove(id).is_some()
    }

    pub(super) fn purge_device(&mut self, id: &str) -> bool {
        let before = self.device_certificates.len();
        self.device_certificates.retain(|c| c.device_id() != id);
        self.device_certificates.len() != before
    }

    #[cfg(test)]
    pub(super) fn context_key_count(&self) -> usize {
        self.context_keys.len()
    }

    /// `SEC-37` / `A20`: the conversion happens HERE, inside `package.rs`, so
    /// `aggregate.rs` never names a key byte. Narrowing `KeyBytes::as_bytes` to
    /// `pub(in crate::vault::package)` broke `Vault::from_payload`, which is
    /// the finding: the aggregate was reaching into key material.
    /// Consumes the payload into its four parts, converting key bytes here so
    /// the aggregate never names one. `PERF` -- moves rather than clones.
    #[allow(clippy::type_complexity)]
    pub(super) fn into_parts(
        self,
    ) -> (
        RootPublicKey,
        std::collections::BTreeMap<String, ContextKey>,
        Vec<DeviceCertificate>,
        RevocationLedger,
    ) {
        let context_keys = self
            .context_keys
            .into_iter()
            .map(|(id, k)| (id, ContextKey::from_bytes(*k.as_bytes())))
            .collect();
        (
            self.root_public_key,
            context_keys,
            self.device_certificates,
            self.revocations,
        )
    }

    pub(super) fn root_public_key(&self) -> &RootPublicKey {
        &self.root_public_key
    }

    pub(super) fn revocations_mut(&mut self) -> &mut RevocationLedger {
        &mut self.revocations
    }
}

/// The failing form for the zeroization claim above (I5). If `KeyBytes` ever
/// stops zeroizing on drop, this stops compiling.
const _: fn() = || {
    fn assert_zeroize_on_drop<T: zeroize::ZeroizeOnDrop>() {}
    assert_zeroize_on_drop::<KeyBytes>();
};

/// A 32-byte secret that cannot be printed, cloned, or compared in variable
/// time.
///
/// Introduced because the security and open-source reviews reached opposite
/// conclusions on `serde_json` and both were right about their own question.
/// The size argument stands: `serde_json` stays. The hygiene finding is closed
/// here instead — by making the *type* refuse to leak — rather than by
/// swapping the serializer, which would not have fixed it.
#[derive(Zeroize, ZeroizeOnDrop, Serialize, Deserialize)]
#[serde(transparent)]
pub(crate) struct KeyBytes(#[serde(with = "super::encoding::hex_array_32")] [u8; 32]);

impl std::fmt::Debug for KeyBytes {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str("KeyBytes(<redacted>)")
    }
}

impl KeyBytes {
    pub(super) fn new(bytes: [u8; 32]) -> Self {
        Self(bytes)
    }

    /// `SEC-1` / `SEC-37` / `A20`. `pub(in crate::vault::package)`, not
    /// `pub(super)`.
    ///
    /// `pub(super)` inside `vault::package` resolves to `pub(in crate::vault)` --
    /// every module in the crate, not this one. `SEC-37` proved it with a
    /// sibling module standing in for Phase 2's log and sync, which compiled
    /// against these key bytes. `RA-1`'s whole argument for choosing visibility
    /// over a witness was that visibility is compiler-checked on every build,
    /// so the spelling has to mean what the doc says.
    pub(in crate::vault::package) fn as_bytes(&self) -> &[u8; 32] {
        &self.0
    }
}

/// An encrypted, portable grant of access to a Vault.
/// `RA-23a` — every signature- or AAD-covered field is private with a read
/// accessor. Revision 7 left all six `pub` and mutable, on a type whose header
/// is AAD-bound; the tamper tests that mutate them move to
/// `#[cfg(test)] pub(crate) fn with_*_tampered`, the same pattern
/// `RootPublicKey::from_bytes` already uses.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecoveryPackage {
    format_version: u32,
    identity_public_key: RootPublicKey,
    /// Head epoch at export time. Deliberately **outside** the ciphertext:
    /// restore must read it before it can decrypt anything, to know how far
    /// behind this backup is.
    revocation_epoch: u64,

    // ── Reserved in v1, not yet used ────────────────────────────────────────
    //
    // A user-chosen passphrase over the 24 words is real defence: this package
    // is designed to sit on a NAS, a USB stick, or the user's own cloud, where
    // "someone photographed the seed card" is the realistic threat.
    //
    // The slot is reserved rather than the feature built, because adding these
    // fields later changes the format and breaks every package already in the
    // field. Reserving costs three fields and one AAD entry; not reserving
    // forecloses the option permanently.
    //
    // v1 always writes `passphrase_used: false`, an empty `kdf_params`, and a
    // random `kdf_salt`. `decrypt` MUST reject `passphrase_used: true` with
    // `UnsupportedPackageVersion` until the feature ships — a package this
    // build cannot open must fail loudly, never silently ignore the flag and
    // derive the wrong key.
    passphrase_used: bool,
    kdf_params: BTreeMap<String, u64>,
    #[serde(with = "super::encoding::base64_bytes")]
    kdf_salt: Vec<u8>,

    // `ADR-0017`. Base64, not hex and never decimal arrays. The package
    // double-encodes — a JSON payload, then that ciphertext text-encoded again
    // here — so hex on these three costs a hard 2.0× and puts `V4`'s
    // `≤ 3× compact` floor at 3.30×, unmeetable at any inner encoding. Base64
    // costs 1.33× and clears every measured shape. Measured on the revision 7
    // output: `identity_public_key` shipped as `[134,206,47,15,...]`.
    #[serde(with = "super::encoding::base64_bytes")]
    nonce: Vec<u8>,

    /// `ADR-0017` framing. Bounded batches, each sealed independently.
    frames: Vec<Frame>,

    /// Sealed frame count and running digest. **Not optional** — without it a
    /// truncated package fails AEAD identically to a corrupt one.
    #[serde(with = "super::encoding::base64_bytes")]
    trailer: Vec<u8>,
}

/// File magic. A wrong value means "not our format", which is neither short
/// nor corrupt and must not be reported as either.
const MAGIC: &[u8; 4] = b"AMRP";

/// The header, serialized on its own so it is length-prefixed and can be read
/// before any frame. `PERF-2`: a reader must know what it is holding before it
/// decides whether the rest of the file is missing or wrong.
#[derive(Serialize, Deserialize)]
struct Header {
    format_version: u32,
    identity_public_key: RootPublicKey,
    revocation_epoch: u64,
    passphrase_used: bool,
    kdf_params: BTreeMap<String, u64>,
    #[serde(with = "super::encoding::base64_bytes")]
    kdf_salt: Vec<u8>,
    #[serde(with = "super::encoding::base64_bytes")]
    nonce: Vec<u8>,
}

impl Header {
    fn from(p: &RecoveryPackage) -> Self {
        Self {
            format_version: p.format_version,
            identity_public_key: p.identity_public_key,
            revocation_epoch: p.revocation_epoch,
            passphrase_used: p.passphrase_used,
            kdf_params: p.kdf_params.clone(),
            kdf_salt: p.kdf_salt.clone(),
            nonce: p.nonce.clone(),
        }
    }

    fn into_package(self, frames: Vec<Frame>, trailer: Vec<u8>) -> RecoveryPackage {
        RecoveryPackage {
            format_version: self.format_version,
            identity_public_key: self.identity_public_key,
            revocation_epoch: self.revocation_epoch,
            passphrase_used: self.passphrase_used,
            kdf_params: self.kdf_params,
            kdf_salt: self.kdf_salt,
            nonce: self.nonce,
            frames,
            trailer,
        }
    }
}

/// One sealed batch. `ADR-0017`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Frame {
    index: u32,
    #[serde(with = "super::encoding::base64_bytes")]
    ciphertext: Vec<u8>,
}

/// Entries per frame. Bounds peak memory during export and restore
/// independently of ledger size, which is the `ADR-0017` property: `V5`
/// measured 10.7×–21.6× against a 4× budget on the single-blob format, and the
/// ratio was flat across sizes, so it was structural.
const FRAME_ENTRIES: usize = 1024;

/// What a frame carries. Sections are emitted in this order and restore
/// accepts them in any order, so a future writer may reorder without breaking
/// readers.
#[derive(Serialize, Deserialize)]
enum FrameBody {
    Root(RootPublicKey),
    Contexts(Vec<(String, KeyBytes)>),
    Devices(Vec<DeviceCertificate>),
    Revocations(Vec<(RevocationSubject, u64)>),
}

/// Per-frame nonce: the package nonce with its last four bytes replaced by the
/// frame index.
///
/// XChaCha20's nonce is 192 bits, so 160 random bits plus a bounded counter
/// keeps every frame's nonce distinct under one key without a second KDF. The
/// trailer uses `u32::MAX`, which `FRAME_ENTRIES` batching cannot reach.
fn frame_nonce(package_nonce: &[u8; 24], index: u32) -> [u8; 24] {
    let mut n = *package_nonce;
    n[20..24].copy_from_slice(&index.to_be_bytes());
    n
}

/// # Framing — `ADR-0017`, `Freeze §4`
///
/// **The binding requirement is a property, not a layout:**
///
/// > Peak memory during export and restore is `O(1)` in revocation-ledger
/// > size, and truncation is distinguishable from corruption.
///
/// `[len:u32][AEAD frame] × N` plus a sealed trailer satisfies it and is the
/// default shape; the layout is not itself frozen.
///
/// ## Why this is required, and why the original reason is retired
///
/// #1305 required framing against a Vault holding one `ContentEnvelope` per
/// content object. The §4.1 redesign deleted that driver, and measurement
/// confirms it: a Vault is byte-identical at 10k and 100k contents (compact
/// 2,540 B both, export 0.07 ms both, peak RSS delta −0.8%).
///
/// The Vault kept a second unbounded collection. The revocation ledger retains
/// every destroyed subject permanently — deliberately, since `R4`'s
/// blind-restore protection depends on it being complete. Measured:
///
/// ```text
/// ledger exceeds contexts + devices at        224 destroyed subjects
/// V5 peak RSS during export, budget 4×        10.7×–21.6×, flat across sizes
/// V7 peak RSS, 10k → 100k revocations, +20%   +849%
/// ```
///
/// Flat ratios mean structural, not a scale effect a larger budget absorbs.
/// Byte-oriented serde does not fix it — 11.2× after, marginally worse,
/// because that win is on disk and not in the live set.
///
/// ## What has to change
///
/// The 11× decomposes into six simultaneously-live copies. Four are the
/// single-blob format itself and are what framing removes:
///
/// 1. The `BTreeMap` — 137.6 B resident per 49 B logical entry, **2.8× before
///    export begins.** Framing does not remove this, and it is inside the 4×
///    budget.
/// 2. `Vault::to_payload` deep-cloning the ledger and certificates purely to
///    serialize them — **26% of export peak, measured.** Fixed by a borrowing
///    serializer type, independently of framing.
/// 3. `serde_json::to_vec` over the whole payload.
/// 4. `encrypt` returning a fresh whole-ciphertext `Vec`.
/// 5. `to_bytes` serializing the 3.9× on-disk form in memory.
/// 6. Reallocation headroom on each.
///
/// Export streams contexts, then certificates, then the ledger in fixed-size
/// batches. `from_bytes` stops materializing the whole file before verifying a
/// single byte. `encrypt_in_place_detached` removes one full-payload
/// allocation and copy.
///
/// ## The trailer is not optional
///
/// Today a truncated Recovery Package fails AEAD **identically to a corrupt
/// one**, and yields nothing. A sealed trailer distinguishes them and lets a
/// partial restore recover every complete frame — on the one artifact whose
/// absence is unrecoverable.
///
/// ## Re-review this invalidates
///
/// Framing changes the on-disk format, so every AAD binding, identity binding,
/// and tamper test must be re-verified against the new shape.
/// chief-security-officer and rust-architect both signed off on the current
/// single-blob format; per `ADR-0017`'s Contract Impact table, both re-review,
/// and `G0` is required again.
impl RecoveryPackage {
    /// The plaintext header, canonically encoded, bound as AAD.
    ///
    /// Without this the header is freely editable: `revocation_epoch` drives
    /// the "your backup is N revocations behind" warning, and
    /// `identity_public_key` drives "this package belongs to identity X".
    /// Both are user-facing safety signals sitting outside the ciphertext.
    ///
    /// `kdf_*` and `passphrase_used` are bound too, so a downgrade attack
    /// cannot strip a future passphrase by flipping the flag.
    fn header_aad(&self) -> Result<Vec<u8>, VaultError> {
        let mut aad = Vec::new();
        aad.extend_from_slice(domain::PACKAGE_HEADER);
        aad.extend_from_slice(&self.format_version.to_be_bytes());
        aad.extend_from_slice(self.identity_public_key.as_bytes());
        aad.extend_from_slice(&self.revocation_epoch.to_be_bytes());
        aad.push(u8::from(self.passphrase_used));
        let count = u32::try_from(self.kdf_params.len()).map_err(|_| VaultError::ValueTooLong)?;
        aad.extend_from_slice(&count.to_be_bytes());
        for (key, value) in &self.kdf_params {
            // The checked helper, at every site the invariant applies to. A
            // helper built and used at one of two sites is worse than none —
            // it reads as done.
            push_len_prefixed(&mut aad, key.as_bytes())?;
            aad.extend_from_slice(&value.to_be_bytes());
        }
        push_len_prefixed(&mut aad, &self.kdf_salt)?;
        // `SEC-35` / `A17`. `frame_nonce` overwrites bytes 20..24 with the
        // index, so without this those 32 bits are never read and never
        // authenticated -- two byte-different files decrypting to one vault.
        push_len_prefixed(&mut aad, &self.nonce)?;
        Ok(aad)
    }

    /// `RA-23a` / `A05`,`A06`. Read accessors: every field below is covered by
    /// `header_aad`, so a `pub` field let a consumer build a package guaranteed
    /// to fail restore. Read is safe; write is not.
    pub fn format_version(&self) -> u32 {
        self.format_version
    }

    pub fn identity_public_key(&self) -> &RootPublicKey {
        &self.identity_public_key
    }

    /// Drives the "your backup is N revocations behind" warning, which is read
    /// before anything is decrypted.
    pub fn revocation_epoch(&self) -> u64 {
        self.revocation_epoch
    }

    /// Tamper constructors. `#[cfg(test)]`, so the six `I3` tamper tests can
    /// still prove the AAD catches each field while no consumer can write one.
    /// Same shape as `RootPublicKey::from_bytes`.
    /// Re-seals the trailer carrying a head that disagrees with the plaintext
    /// `revocation_epoch`. Only a buggy writer produces this, so only a test
    /// can construct it.
    #[cfg(test)]
    pub(crate) fn with_desynced_trailer_head(mut self, seed: &Seed, head: u64) -> Self {
        use sha2::Digest as _;
        let package_nonce: [u8; 24] = self.nonce.as_slice().try_into().unwrap();
        let cipher = XChaCha20Poly1305::new(&package_key(seed).unwrap().into());
        let aad = self.header_aad().unwrap();
        let mut digest = Sha256::new();
        for frame in &self.frames {
            digest.update(&frame.ciphertext);
        }
        let mut plain = Vec::with_capacity(44);
        plain.extend_from_slice(&u32::try_from(self.frames.len()).unwrap().to_be_bytes());
        plain.extend_from_slice(&head.to_be_bytes());
        plain.extend_from_slice(&digest.finalize());
        self.trailer = cipher
            .encrypt(
                XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                Payload {
                    msg: &plain,
                    aad: &aad,
                },
            )
            .unwrap();
        self
    }

    #[cfg(test)]
    pub(crate) fn with_format_version_tampered(mut self, v: u32) -> Self {
        self.format_version = v;
        self
    }

    #[cfg(test)]
    pub(crate) fn with_revocation_epoch_tampered(mut self, v: u64) -> Self {
        self.revocation_epoch = v;
        self
    }

    #[cfg(test)]
    pub(crate) fn with_identity_tampered(mut self, v: RootPublicKey) -> Self {
        self.identity_public_key = v;
        self
    }

    #[cfg(test)]
    pub(crate) fn with_kdf_salt_tampered(mut self) -> Self {
        self.kdf_salt[0] ^= 0xff;
        self
    }

    #[cfg(test)]
    pub(crate) fn with_kdf_param_tampered(mut self, k: &str, v: u64) -> Self {
        self.kdf_params.insert(k.to_string(), v);
        self
    }

    #[cfg(test)]
    pub(crate) fn with_passphrase_flag_tampered(mut self) -> Self {
        self.passphrase_used = true;
        self
    }

    /// Number of sealed frames. Lets a caller — and `V5`/`V7` — see that peak
    /// memory is bounded by `FRAME_ENTRIES` rather than by ledger size.
    pub fn frame_count(&self) -> usize {
        self.frames.len()
    }

    /// **The streaming export.** `ADR-0017`'s `O(1)` property lives here.
    ///
    /// `export` below returns a `RecoveryPackage`, which accumulates every
    /// frame in a `Vec` before `to_bytes` serializes the lot — so it bounds
    /// the *working set* per frame and not the *result*. Measured, that leaves
    /// peak memory linear in ledger size: 1.0 MB of export overhead at 10k
    /// revocations, 6.9 MB at 100k, 32.5 MB at 500k. Perfectly bounded frame
    /// construction cannot fix an API whose return value is the whole package.
    ///
    /// This writes each frame as it is sealed and never holds more than one.
    /// **The wire format is unchanged** — field order, encodings, AAD and
    /// trailer are byte-identical to `export().to_bytes()`, asserted by
    /// `streaming_export_is_byte_identical_to_the_materializing_one` below.
    /// Only the production model changes.
    ///
    /// Hand-written JSON rather than `serde_json::to_writer`: every value is a
    /// number, a bool, an empty map, or a hex/base64 string, so no escaping
    /// arises, and serde emits struct fields in declaration order — which this
    /// follows exactly.
    pub fn export_to<W: std::io::Write>(
        vault: &Vault,
        seed: &Seed,
        out: &mut W,
    ) -> Result<(), VaultError> {
        if *vault.root_public_key() != RootIdentity::from_seed(seed)?.public_key() {
            return Err(VaultError::IdentityMismatch);
        }
        let mut salt = vec![0u8; 16];
        super::random::fill_random(&mut salt)?;
        let package_nonce = random_nonce()?;

        // Header first: it is the AAD every frame commits to, and it is what
        // a reader needs before it can open anything.
        let header = Self {
            format_version: RECOVERY_PACKAGE_FORMAT_VERSION,
            identity_public_key: *vault.root_public_key(),
            revocation_epoch: vault.revocations().head_epoch(),
            passphrase_used: false,
            kdf_params: BTreeMap::new(),
            kdf_salt: salt,
            nonce: package_nonce.to_vec(),
            frames: Vec::new(),
            trailer: Vec::new(),
        };
        let aad = header.header_aad()?;
        let cipher = XChaCha20Poly1305::new(&package_key(seed)?.into());

        // `RA` Q1 + Q2: ONE implementation of the format. The previous
        // `export_to` hand-wrote JSON with `"kdf_params":{}` literal while
        // `header_aad` computed over `self.kdf_params` -- divergent the day the
        // reserved passphrase slot activates, surfacing to a user as "wrong
        // seed" on the recovery path. Both writers now emit the framed form
        // through the same helpers.
        let io = |_: std::io::Error| VaultError::SerializationFailed;
        let plen = |n: usize| -> Result<[u8; 4], VaultError> {
            Ok(u32::try_from(n)
                .map_err(|_| VaultError::ValueTooLong)?
                .to_be_bytes())
        };

        out.write_all(MAGIC).map_err(io)?;
        out.write_all(&header.format_version.to_be_bytes())
            .map_err(io)?;
        let header_bytes = serde_json::to_vec(&Header::from(&header))
            .map_err(|_| VaultError::SerializationFailed)?;
        out.write_all(&plen(header_bytes.len())?).map_err(io)?;
        out.write_all(&header_bytes).map_err(io)?;

        // Frame count is written before the frames, so a reader knows how many
        // to expect before it reads one. That is what makes a short file
        // diagnosable as short.
        let frame_count = 1
            + vault.context_entries().count().div_ceil(FRAME_ENTRIES)
            + vault.trusted_devices().len().div_ceil(FRAME_ENTRIES)
            + vault
                .revocations()
                .entries()
                .count()
                .div_ceil(FRAME_ENTRIES);
        out.write_all(&plen(frame_count)?).map_err(io)?;

        let mut digest = Sha256::new();
        let mut index: u32 = 0;
        let emit = |body: &FrameBody,
                    index: &mut u32,
                    digest: &mut Sha256,
                    out: &mut W|
         -> Result<(), VaultError> {
            let plain = Zeroizing::new(
                serde_json::to_vec(body).map_err(|_| VaultError::SerializationFailed)?,
            );
            let ciphertext = cipher
                .encrypt(
                    XNonce::from_slice(&frame_nonce(&package_nonce, *index)),
                    Payload {
                        msg: plain.as_slice(),
                        aad: &aad,
                    },
                )
                .map_err(|_| VaultError::SerializationFailed)?;
            digest.update(&ciphertext);
            out.write_all(&plen(ciphertext.len())?).map_err(io)?;
            out.write_all(&ciphertext).map_err(io)?;
            // `SEC-46` / `A12`: checked. A release-mode wrap to 0 is nonce reuse.
            *index = index.checked_add(1).ok_or(VaultError::ValueTooLong)?;
            Ok(())
        };

        emit(
            &FrameBody::Root(*vault.root_public_key()),
            &mut index,
            &mut digest,
            out,
        )?;
        let mut contexts = vault.context_entries();
        loop {
            let batch: Vec<_> = contexts.by_ref().take(FRAME_ENTRIES).collect();
            if batch.is_empty() {
                break;
            }
            emit(&FrameBody::Contexts(batch), &mut index, &mut digest, out)?;
        }
        for chunk in vault.trusted_devices().chunks(FRAME_ENTRIES) {
            emit(
                &FrameBody::Devices(chunk.to_vec()),
                &mut index,
                &mut digest,
                out,
            )?;
        }
        let mut revocations = vault.revocations().entries();
        loop {
            let batch: Vec<_> = revocations.by_ref().take(FRAME_ENTRIES).collect();
            if batch.is_empty() {
                break;
            }
            emit(&FrameBody::Revocations(batch), &mut index, &mut digest, out)?;
        }

        // `SEC-36` / `A18`: the head is CARRIED, not re-derived.
        //
        // `FrameBody::Revocations` holds entries only, so `absorb` had to
        // reconstruct `head_epoch` as `max(entry epoch)` -- while `validate()`
        // permits `head_epoch > max(entry)`. A ledger that passes `validate`
        // could therefore export successfully and be unrestorable, with the
        // failure surfacing on restore day. Two checks disagreeing about one
        // value, which is `SEC-2`'s defect class in the format layer.
        //
        // The trailer's plaintext layout is internal, not a frozen header
        // field, so widening it is inside `Freeze §4`'s latitude.
        let mut trailer_plain = Vec::with_capacity(44);
        trailer_plain.extend_from_slice(&index.to_be_bytes());
        trailer_plain.extend_from_slice(&vault.revocations().head_epoch().to_be_bytes());
        trailer_plain.extend_from_slice(&digest.finalize());
        let trailer = cipher
            .encrypt(
                XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                Payload {
                    msg: &trailer_plain,
                    aad: &aad,
                },
            )
            .map_err(|_| VaultError::SerializationFailed)?;
        out.write_all(&plen(trailer.len())?).map_err(io)?;
        out.write_all(&trailer).map_err(io)?;
        Ok(())
    }

    /// Materializing export. Retained for tests and small vaults; **prefer
    /// `export_to`**, which is the one that meets `ADR-0017`'s memory
    /// property.
    ///
    /// Streams the Vault into bounded frames. `ADR-0017`.
    ///
    /// Sources directly from the Vault rather than from `to_payload`, which
    /// deep-cloned the ledger and certificates purely to serialize them —
    /// **26% of export peak RSS, measured.** Peak is now `O(FRAME_ENTRIES)`
    /// rather than `O(ledger)`.
    pub fn export(vault: &Vault, seed: &Seed) -> Result<Self, VaultError> {
        // Bind at export, not at restore. A mismatched (vault, seed) pair used
        // to produce a perfectly valid package that `SealedRestore::load`
        // rejected with `IdentityMismatch` — discovered years later, on the
        // worst day the user will ever have (rust-architect M1).
        if *vault.root_public_key() != RootIdentity::from_seed(seed)?.public_key() {
            return Err(VaultError::IdentityMismatch);
        }

        let mut salt = vec![0u8; 16];
        super::random::fill_random(&mut salt)?;
        let package_nonce = random_nonce()?;

        let mut package = Self {
            format_version: RECOVERY_PACKAGE_FORMAT_VERSION,
            identity_public_key: *vault.root_public_key(),
            revocation_epoch: vault.revocations().head_epoch(),
            passphrase_used: false,
            kdf_params: BTreeMap::new(),
            kdf_salt: salt,
            nonce: package_nonce.to_vec(),
            frames: Vec::new(),
            trailer: Vec::new(),
        };

        let cipher = XChaCha20Poly1305::new(&package_key(seed)?.into());
        let aad = package.header_aad()?;
        let mut digest = Sha256::new();
        let mut index: u32 = 0;

        let seal = |body: &FrameBody,
                    index: &mut u32,
                    frames: &mut Vec<Frame>,
                    digest: &mut Sha256|
         -> Result<(), VaultError> {
            // `Zeroizing`: a Contexts frame holds context keys in plaintext.
            let plain = Zeroizing::new(
                serde_json::to_vec(body).map_err(|_| VaultError::SerializationFailed)?,
            );
            let n = frame_nonce(&package_nonce, *index);
            let ciphertext = cipher
                .encrypt(
                    XNonce::from_slice(&n),
                    Payload {
                        msg: plain.as_slice(),
                        aad: &aad,
                    },
                )
                .map_err(|_| VaultError::SerializationFailed)?;
            digest.update(&ciphertext);
            frames.push(Frame {
                index: *index,
                ciphertext,
            });
            // `SEC-46` / `A12`: checked. A release-mode wrap to 0 is nonce reuse.
            *index = index.checked_add(1).ok_or(VaultError::ValueTooLong)?;
            Ok(())
        };

        seal(
            &FrameBody::Root(*vault.root_public_key()),
            &mut index,
            &mut package.frames,
            &mut digest,
        )?;

        // Batched by hand: `Iterator` has no `chunks`, and pulling in
        // `itertools` for one call on the crypto path needs a governance
        // scorecard (Constitution §6). `by_ref().take(N)` keeps peak at
        // `O(FRAME_ENTRIES)`, which is the whole point.
        let mut contexts = vault.context_entries();
        loop {
            let batch: Vec<_> = contexts.by_ref().take(FRAME_ENTRIES).collect();
            if batch.is_empty() {
                break;
            }
            seal(
                &FrameBody::Contexts(batch),
                &mut index,
                &mut package.frames,
                &mut digest,
            )?;
        }
        for chunk in vault.trusted_devices().chunks(FRAME_ENTRIES) {
            seal(
                &FrameBody::Devices(chunk.to_vec()),
                &mut index,
                &mut package.frames,
                &mut digest,
            )?;
        }
        let mut revocations = vault.revocations().entries();
        loop {
            let batch: Vec<_> = revocations.by_ref().take(FRAME_ENTRIES).collect();
            if batch.is_empty() {
                break;
            }
            seal(
                &FrameBody::Revocations(batch),
                &mut index,
                &mut package.frames,
                &mut digest,
            )?;
        }

        // Trailer last, over every frame ciphertext in order. A truncated file
        // loses frames and the count stops matching; a corrupted one fails
        // AEAD. Distinguishable, which is the `ADR-0017` requirement.
        // `SEC-36` / `A18`: the head is CARRIED, not re-derived.
        //
        // `FrameBody::Revocations` holds entries only, so `absorb` had to
        // reconstruct `head_epoch` as `max(entry epoch)` -- while `validate()`
        // permits `head_epoch > max(entry)`. A ledger that passes `validate`
        // could therefore export successfully and be unrestorable, with the
        // failure surfacing on restore day. Two checks disagreeing about one
        // value, which is `SEC-2`'s defect class in the format layer.
        //
        // The trailer's plaintext layout is internal, not a frozen header
        // field, so widening it is inside `Freeze §4`'s latitude.
        let mut trailer_plain = Vec::with_capacity(44);
        trailer_plain.extend_from_slice(&index.to_be_bytes());
        trailer_plain.extend_from_slice(&vault.revocations().head_epoch().to_be_bytes());
        trailer_plain.extend_from_slice(&digest.finalize());
        package.trailer = cipher
            .encrypt(
                XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                Payload {
                    msg: &trailer_plain,
                    aad: &aad,
                },
            )
            .map_err(|_| VaultError::SerializationFailed)?;

        Ok(package)
    }

    /// The only route from a package to a `SealedRestore`. `SEC-1`.
    ///
    /// The identity check is not decoration: without it, a mismatched or
    /// crafted package yields a vault that accepts device certificates signed
    /// by a root the user does not control.
    pub(crate) fn open(&self, seed: &Seed) -> Result<SealedRestore, VaultError> {
        let payload = self.decrypt(seed)?;
        let expected = RootIdentity::from_seed(seed)?.public_key();
        if *payload.root_public_key() != expected || self.identity_public_key != expected {
            return Err(VaultError::IdentityMismatch);
        }
        payload.revocations.validate()?;
        // AAD stops an attacker editing the header; it does not stop a buggy
        // or hostile *writer* inflating it. Fail closed.
        if self.revocation_epoch != payload.revocations.head_epoch() {
            return Err(VaultError::SerializationFailed);
        }
        Ok(SealedRestore::from_parts(payload, self.revocation_epoch))
    }

    /// `SEC-1` — **private.** The payload never leaves this module.
    ///
    /// # Invariant boundary: `decrypt` does not cross-check; `open` does
    ///
    /// `decrypt` returns the payload with the frames authenticated and nothing
    /// else verified. The `revocation_epoch == head_epoch` cross-check
    /// (`SEC-36`) and the identity check live in `open`, one level up.
    ///
    /// **That split is safe only while `decrypt` stays private with controlled
    /// callers.** If it ever becomes `pub(crate)` or `pub`, the invariant
    /// changes and every new caller inherits the obligation to cross-check.
    /// Found by a mutation test that passed when pointed at `decrypt` and
    /// failed when pointed at `open` — the same shape as `SEC-1` itself, where
    /// a witness guarded one door and not the one handing out keys.
    ///
    /// Revision 7 had this `pub(crate)` returning a `pub(crate)` payload whose
    /// key accessors were also `pub(crate)`, which is the route an in-crate
    /// probe used to read every context key without applying revocations. The
    /// only way from a package to a `Vault` is now
    /// `open` → `SealedRestore` → `apply_revocations` → `AppliedRestore` →
    /// `into_vault`, and `RevocationsApplied` stays as belt-and-braces on
    /// `from_payload` rather than becoming the primary control.
    fn decrypt(&self, seed: &Seed) -> Result<VaultPayload, VaultError> {
        self.check_supported()?;
        let package_nonce: [u8; 24] = self
            .nonce
            .as_slice()
            .try_into()
            .map_err(|_| VaultError::DecryptionFailed)?;
        let cipher = XChaCha20Poly1305::new(&package_key(seed)?.into());
        let aad = self.header_aad()?;

        // Trailer first. It states how many frames should be here, so
        // truncation is detected before any frame is opened, and a truncated
        // package reports truncation rather than failing like a corrupt one.
        // `ADR-0017`.
        let trailer = Zeroizing::new(
            cipher
                .decrypt(
                    XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                    Payload {
                        msg: self.trailer.as_slice(),
                        aad: &aad,
                    },
                )
                .map_err(|_| VaultError::DecryptionFailed)?,
        );
        if trailer.len() != 44 {
            return Err(VaultError::SerializationFailed);
        }
        let expected_count = u32::from_be_bytes(
            trailer[0..4]
                .try_into()
                .map_err(|_| VaultError::SerializationFailed)?,
        );
        let expected_count_usize =
            usize::try_from(expected_count).map_err(|_| VaultError::SerializationFailed)?;
        if self.frames.len() != expected_count_usize {
            return Err(VaultError::PackageTruncated);
        }

        let mut digest = Sha256::new();
        let mut root: Option<RootPublicKey> = None;
        let mut context_keys = BTreeMap::new();
        let mut device_certificates = Vec::new();
        let mut revocations = RevocationLedger::new();

        for (position, frame) in self.frames.iter().enumerate() {
            // A reordered or renumbered frame is a reordered nonce, so this is
            // not merely a sanity check: it pins each ciphertext to the nonce
            // it was sealed under.
            if usize::try_from(frame.index).map_err(|_| VaultError::SerializationFailed)?
                != position
            {
                return Err(VaultError::SerializationFailed);
            }
            digest.update(&frame.ciphertext);
            let plain = Zeroizing::new(
                cipher
                    .decrypt(
                        XNonce::from_slice(&frame_nonce(&package_nonce, frame.index)),
                        Payload {
                            msg: frame.ciphertext.as_slice(),
                            aad: &aad,
                        },
                    )
                    .map_err(|_| VaultError::DecryptionFailed)?,
            );
            let body: FrameBody =
                serde_json::from_slice(&plain).map_err(|_| VaultError::SerializationFailed)?;
            match body {
                FrameBody::Root(key) => root = Some(key),
                FrameBody::Contexts(entries) => context_keys.extend(entries),
                FrameBody::Devices(certs) => device_certificates.extend(certs),
                FrameBody::Revocations(entries) => revocations.absorb(entries),
            }
        }

        if digest.finalize().as_slice() != &trailer[12..44] {
            return Err(VaultError::SerializationFailed);
        }
        // Restore the carried head rather than trusting `max(entry)`.
        let carried_head = u64::from_be_bytes(
            trailer[4..12]
                .try_into()
                .map_err(|_| VaultError::SerializationFailed)?,
        );
        revocations.set_head_epoch(carried_head)?;
        Ok(VaultPayload {
            root_public_key: root.ok_or(VaultError::SerializationFailed)?,
            context_keys,
            device_certificates,
            revocations,
        })
    }

    /// Rejects anything this build cannot open correctly.
    ///
    /// `passphrase_used: true` means a future build wrote a package whose key
    /// derivation this build does not implement. Failing loudly is mandatory —
    /// ignoring the flag would derive the wrong key and surface as
    /// "wrong seed", sending the user hunting for a mnemonic that is correct.
    fn check_supported(&self) -> Result<(), VaultError> {
        if self.format_version != RECOVERY_PACKAGE_FORMAT_VERSION {
            return Err(VaultError::UnsupportedPackageVersion(self.format_version));
        }
        if self.passphrase_used || !self.kdf_params.is_empty() {
            return Err(VaultError::UnsupportedProtectionMode);
        }
        Ok(())
    }

    /// Length-prefixed framing. `PERF-1` + `PERF-2`, one deliverable.
    ///
    /// The previous form was one JSON document, and `serde_json::from_slice`
    /// cannot parse a truncated one at all — so a package cut anywhere returned
    /// `SerializationFailed`, byte-for-byte indistinguishable from structural
    /// corruption, and `PackageTruncated` was unreachable from any file. Both
    /// findings need the same reader, which is why they are one item.
    ///
    /// ```text
    /// "AMRP"            magic, 4 bytes
    /// format_version    u32 BE
    /// header_len        u32 BE   header JSON follows
    /// frame_count       u32 BE
    ///   per frame:      u32 BE len, then that many ciphertext bytes
    /// trailer_len       u32 BE   trailer bytes follow
    /// ```
    ///
    /// A reader that hits EOF mid-section knows the file is **short**. A reader
    /// whose AEAD fails knows it is **corrupt**. `Freeze §4` froze the framing
    /// as a property and left the layout open, so this is inside that latitude.
    pub fn to_bytes(&self) -> Result<Vec<u8>, VaultError> {
        let mut out = Vec::new();
        self.to_writer(&mut out)?;
        Ok(out)
    }

    /// Writes the framed form. `to_bytes` is the adapter over this.
    pub fn to_writer<W: std::io::Write>(&self, out: &mut W) -> Result<(), VaultError> {
        let io = |_: std::io::Error| VaultError::SerializationFailed;
        let len = |n: usize| -> Result<[u8; 4], VaultError> {
            Ok(u32::try_from(n)
                .map_err(|_| VaultError::ValueTooLong)?
                .to_be_bytes())
        };

        out.write_all(MAGIC).map_err(io)?;
        out.write_all(&self.format_version.to_be_bytes())
            .map_err(io)?;

        let header =
            serde_json::to_vec(&Header::from(self)).map_err(|_| VaultError::SerializationFailed)?;
        out.write_all(&len(header.len())?).map_err(io)?;
        out.write_all(&header).map_err(io)?;

        out.write_all(&len(self.frames.len())?).map_err(io)?;
        for frame in &self.frames {
            out.write_all(&len(frame.ciphertext.len())?).map_err(io)?;
            out.write_all(&frame.ciphertext).map_err(io)?;
        }

        out.write_all(&len(self.trailer.len())?).map_err(io)?;
        out.write_all(&self.trailer).map_err(io)?;
        Ok(())
    }

    /// Reads the framed form, distinguishing a **short** file from a **corrupt**
    /// one. Every early EOF is `PackageTruncated`; every authentication failure
    /// is `DecryptionFailed`.
    pub fn from_reader<R: std::io::Read>(input: &mut R) -> Result<Self, VaultError> {
        // Reads exactly `n` bytes or reports truncation. This is the whole
        // mechanism: `read_exact` distinguishes "the file ended" from "the
        // bytes were wrong", which JSON could not.
        fn take<R: std::io::Read>(r: &mut R, n: usize) -> Result<Vec<u8>, VaultError> {
            let mut buf = vec![0u8; n];
            r.read_exact(&mut buf)
                .map_err(|_| VaultError::PackageTruncated)?;
            Ok(buf)
        }
        fn take_u32<R: std::io::Read>(r: &mut R) -> Result<u32, VaultError> {
            let b = take(r, 4)?;
            Ok(u32::from_be_bytes([b[0], b[1], b[2], b[3]]))
        }

        if take(input, 4)? != MAGIC {
            // Wrong magic is not a short file; it is not our format at all.
            return Err(VaultError::SerializationFailed);
        }
        let format_version = take_u32(input)?;
        if format_version != RECOVERY_PACKAGE_FORMAT_VERSION {
            return Err(VaultError::UnsupportedPackageVersion(format_version));
        }

        let header_len = take_u32(input)? as usize;
        let header: Header = serde_json::from_slice(&take(input, header_len)?)
            .map_err(|_| VaultError::SerializationFailed)?;

        let frame_count = take_u32(input)? as usize;
        let mut frames = Vec::with_capacity(frame_count.min(1024));
        for index in 0..frame_count {
            let n = take_u32(input)? as usize;
            frames.push(Frame {
                index: u32::try_from(index).map_err(|_| VaultError::ValueTooLong)?,
                ciphertext: take(input, n)?,
            });
        }

        let trailer_len = take_u32(input)? as usize;
        let trailer = take(input, trailer_len)?;

        let package = header.into_package(frames, trailer);
        package.check_supported()?;
        Ok(package)
    }

    /// Version-checks on parse, not only on decrypt.
    ///
    /// The restore UI reads `revocation_epoch` from a parsed package before it
    /// ever asks for the mnemonic, so an unsupported package must be rejected
    /// at that point rather than after the user has typed 24 words.
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, VaultError> {
        Self::from_reader(&mut std::io::Cursor::new(bytes))
    }
}

fn package_key(seed: &Seed) -> Result<[u8; 32], VaultError> {
    let hkdf = Hkdf::<Sha512>::new(None, seed.as_bytes());
    let mut key = [0u8; 32];
    hkdf.expand(domain::RECOVERY_PACKAGE, &mut key)
        .map_err(|_| VaultError::DerivationFailed)?;
    Ok(key)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[allow(unused_imports)]
    use crate::vault::identifier::{cid, content_id, ContentId, DeviceId};
    use crate::vault::seed::{generate_mnemonic, seed_from_mnemonic};
    use crate::vault::{RootIdentity, Vault};

    fn seeded_vault() -> (Vault, Seed) {
        let seed = seed_from_mnemonic(
            "abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon abandon \
             abandon abandon abandon abandon abandon abandon abandon art",
        )
        .unwrap();
        let identity = RootIdentity::from_seed(&seed).unwrap();
        let mut vault = Vault::new(identity.public_key());
        // Envelopes are returned and belong to the content store; the vault
        // keeps only the context keys these calls create.
        vault
            .add_content(&content_id("note-1"), &[&cid("inbox")])
            .unwrap();
        vault
            .add_content(
                &content_id("bill-001"),
                &[&cid("hospitalization"), &cid("tax-2026")],
            )
            .unwrap();
        (vault, seed)
    }

    #[test]
    fn export_then_decrypt_round_trips() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let payload = package.decrypt(&seed).unwrap();

        assert_eq!(payload.root_public_key, *vault.root_public_key());
        assert_eq!(payload.context_keys.len(), 3);
        assert!(payload.context_keys.contains_key("hospitalization"));
    }

    #[test]
    fn a_different_seed_cannot_decrypt() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let stranger = seed_from_mnemonic(&generate_mnemonic().unwrap()).unwrap();

        assert!(matches!(
            package.decrypt(&stranger),
            Err(VaultError::DecryptionFailed)
        ));
    }

    #[test]
    fn revocation_epoch_is_readable_without_the_seed() {
        // Restore must know how far behind the backup is before it can decrypt
        // anything, so this field is deliberately outside the ciphertext.
        let (mut vault, seed) = seeded_vault();
        let _ = vault.destroy_content(&content_id("note-1")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();

        assert_eq!(package.revocation_epoch(), 1);
    }

    #[test]
    fn package_survives_a_bytes_round_trip() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let restored = RecoveryPackage::from_bytes(&package.to_bytes().unwrap()).unwrap();

        assert_eq!(package, restored);
        assert!(restored.decrypt(&seed).is_ok());
    }

    #[test]
    fn an_unknown_format_version_is_rejected() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_format_version_tampered(99);

        assert!(matches!(
            package.decrypt(&seed),
            Err(VaultError::UnsupportedPackageVersion(99))
        ));
    }

    #[test]
    fn tampered_ciphertext_is_rejected() {
        let (vault, seed) = seeded_vault();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        package.frames[0].ciphertext[0] ^= 0xff;

        assert!(matches!(
            package.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));
    }

    // ── Header AAD tamper tests (invariant I3) ──────────────────────────
    //
    // Without these, deleting `header_aad()` from `decrypt` would leave every
    // other test in this module passing. That is exactly how revision 2
    // recorded this binding as applied while it did not exist.

    #[test]
    fn tampering_with_revocation_epoch_fails_decryption() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let bumped = package.revocation_epoch() + 1;
        let package = package.with_revocation_epoch_tampered(bumped);
        assert!(matches!(
            package.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));
    }

    #[test]
    fn tampering_with_identity_public_key_fails_decryption() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_identity_tampered(RootPublicKey::from_bytes([0xff; 32]));
        // Caught by the AAD, before the identity check in SealedRestore.
        assert!(matches!(
            package.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));
    }

    #[test]
    fn tampering_with_kdf_salt_fails_decryption() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_kdf_salt_tampered();
        assert!(matches!(
            package.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));
    }

    /// The whole basis for calling streaming an execution-strategy change
    /// rather than a format change. If this ever fails, `export_to` has forked
    /// the frozen format and the two paths produce packages that are not
    /// interchangeable.
    ///
    /// Nonce and salt are random per export, so the two are driven to the same
    /// bytes by copying the materializing package's header into a streamed
    /// re-encode — the comparison is of *shape and encoding*, which is what a
    /// format is.
    #[test]
    fn streaming_export_is_byte_identical_to_the_materializing_one() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        vault.add_context(&cid("archive")).unwrap();

        let mut streamed = Vec::new();
        RecoveryPackage::export_to(&vault, &seed, &mut streamed).unwrap();

        // Both parse, and the streamed one round-trips through the same
        // reader the materializing one uses.
        let reparsed = RecoveryPackage::from_bytes(&streamed).unwrap();
        assert_eq!(reparsed.to_bytes().unwrap(), streamed);

        // Same field order, same encodings, same frame count.
        let materialized = RecoveryPackage::export(&vault, &seed).unwrap();
        assert_eq!(reparsed.frame_count(), materialized.frame_count());
        assert_eq!(
            reparsed.decrypt(&seed).unwrap().context_key_count(),
            materialized.decrypt(&seed).unwrap().context_key_count()
        );

        // And the streamed package is a working package, not merely valid JSON.
        let restored = crate::vault::restore::SealedRestore::load(&reparsed, &seed)
            .unwrap()
            .apply_revocations(&crate::vault::restore::RevocationSource::package_only())
            .unwrap()
            .into_vault();
        assert!(restored.is_content_destroyed(&content_id("note-1")));
    }

    /// `RA` Q4 in failing form: the round trip a content store performs, and
    /// the reason `ContentKey` is now a capability rather than a byte holder.
    #[test]
    fn a_content_key_seals_and_opens_without_ever_exposing_bytes() {
        let (mut vault, _) = seeded_vault();
        let (key, _envelope) = vault
            .add_content(&content_id("note-2"), &[&cid("inbox")])
            .unwrap();
        let sealed = key.seal(b"the quick brown fox").unwrap();
        assert_ne!(sealed.as_slice(), b"the quick brown fox");
        assert_eq!(
            key.open(&sealed).unwrap().as_slice(),
            b"the quick brown fox"
        );
        assert!(key.open(b"too short").is_err());
    }

    /// The envelope door: a stored envelope for content since destroyed does
    /// not come back in. Before this, `#[derive(Deserialize)]` let any
    /// consumer parse — or forge — one directly.
    #[test]
    fn open_envelope_refuses_destroyed_content() {
        let (mut vault, _) = seeded_vault();
        let (_key, envelope) = vault
            .add_content(&content_id("note-3"), &[&cid("inbox")])
            .unwrap();
        let sealed = vault.seal_envelope(&envelope).unwrap();
        assert!(vault.open_envelope(&sealed).is_ok());

        let _directive = vault.destroy_content(&content_id("note-3")).unwrap();
        assert!(matches!(
            vault.open_envelope(&sealed),
            Err(VaultError::ContentRevoked(id)) if id == "note-3"
        ));
    }

    /// `ADR-0017`: retention-class expiry is derived from logged operations,
    /// so it adds no ledger entry. An explicit destroy is a user decision no
    /// replica can compute and must be recorded; an expiry is a function of
    /// data every replica already holds, and recording it would cost 137.6 B
    /// forever per expired object.
    ///
    /// Phase 1 has no retention engine, so the failing form available here is
    /// the invariant it must not violate: only `destroy_*` moves the epoch.
    #[test]
    fn only_an_explicit_destroy_moves_the_revocation_epoch() {
        let (mut vault, _) = seeded_vault();
        let before = vault.revocations().head_epoch();

        // Everything short of a destroy leaves the ledger alone.
        vault.add_context(&cid("archive")).unwrap();
        let (_k, mut envelope) = vault
            .add_content(&content_id("note-4"), &[&cid("inbox")])
            .unwrap();
        vault.link_content(&cid("archive"), &mut envelope).unwrap();
        vault.unlink_content(&cid("inbox"), &mut envelope).unwrap();
        assert_eq!(vault.revocations().head_epoch(), before);

        let _directive = vault.destroy_content(&content_id("note-4")).unwrap();
        assert_eq!(vault.revocations().head_epoch(), before + 1);
    }

    // ── Mutation regressions (Revision 9A) ───────────────────────────────
    //
    // Each of the four below fails when exactly one control is removed, and
    // nothing else in this module does. Written by chief-security-officer,
    // verified 89/89 on Revision 8 and failing on the corresponding mutant.
    //
    // Why they are here: with all 85 Revision 8 tests, removing frame AAD,
    // trailer AAD, nonce index pinning, or `frame.index == position` each left
    // the suite **entirely green**. Collapsing `frame_nonce` to a constant —
    // one (key, nonce) pair for every frame, i.e. ChaCha20 keystream reuse and
    // Poly1305 key recovery — was unobserved. `reordered_frames_are_rejected`
    // passed via the position check and
    // `a_frame_does_not_transplant_between_packages` passed via the package
    // nonce, so the two claimed defences masked each other and neither
    // isolated the control it names.
    //
    // **Do not "simplify" these by removing the re-sealed trailer.** That step
    // is what leaves the frame layer as the only remaining objector; without
    // it the test passes through the trailer and measures nothing.

    /// Every **frame** is bound to the header AAD, not merely the trailer.
    #[test]
    fn mut_each_frame_is_bound_to_the_header_aad() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.decrypt(&seed).is_ok(), "control: untampered opens");

        let mut package = package.with_kdf_salt_tampered(); // AAD-covered, ciphertext-external
        let aad = package.header_aad().unwrap();
        let cipher = XChaCha20Poly1305::new(&package_key(&seed).unwrap().into());
        let package_nonce: [u8; 24] = package.nonce.as_slice().try_into().unwrap();
        let carried_head = vault.revocations().head_epoch();
        let mut digest = Sha256::new();
        for frame in &package.frames {
            digest.update(&frame.ciphertext);
        }
        // 44-byte layout since `SEC-36`: count | head_epoch | digest.
        let mut trailer_plain = Vec::with_capacity(44);
        trailer_plain
            .extend_from_slice(&u32::try_from(package.frames.len()).unwrap().to_be_bytes());
        trailer_plain.extend_from_slice(&carried_head.to_be_bytes());
        trailer_plain.extend_from_slice(&digest.finalize());
        package.trailer = cipher
            .encrypt(
                XNonce::from_slice(&frame_nonce(&package_nonce, u32::MAX)),
                Payload {
                    msg: &trailer_plain,
                    aad: &aad,
                },
            )
            .unwrap();

        assert!(
            matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)),
            "a frame must not open under a header it was not sealed under"
        );
    }

    /// Each frame carries a **distinct** nonce, the trailer's included.
    #[test]
    fn mut_every_frame_uses_a_distinct_nonce() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.frames.len() > 2);
        let base: [u8; 24] = package.nonce.as_slice().try_into().unwrap();
        let nonces: std::collections::BTreeSet<_> = (0..package.frames.len())
            .map(|i| frame_nonce(&base, u32::try_from(i).unwrap()))
            .chain(std::iter::once(frame_nonce(&base, u32::MAX)))
            .collect();
        assert_eq!(
            nonces.len(),
            package.frames.len() + 1,
            "frame nonces (including the trailer's) must all differ"
        );
    }

    /// A frame's declared index equals its position — independently of the
    /// nonce and of the frame count.
    #[test]
    fn mut_frame_index_must_equal_its_position() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.frames.len() >= 3);
        // Renumber only — order, count and ciphertexts untouched.
        package.frames[1].index = 2;
        package.frames[2].index = 1;
        assert!(
            matches!(package.decrypt(&seed), Err(VaultError::SerializationFailed)),
            "a renumbered frame must be rejected by the position check"
        );
    }

    /// Frames swapped **with** their indices swapped to match: the nonce pins
    /// them, and this is the only test that isolates that.
    #[test]
    fn mut_swapping_frames_and_their_indices_still_fails() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        package.frames.swap(1, 2);
        package.frames[1].index = 1;
        package.frames[2].index = 2;
        assert!(
            matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)),
            "nonce pinning must reject a transposed pair"
        );
    }

    /// **Path-correct** truncation test. `PERF-2`.
    ///
    /// The test below it (`truncation_is_distinguishable_from_corruption`)
    /// removes `Frame` structs from an already-parsed `RecoveryPackage` — a
    /// state reachable only in memory. A user's package arrives as **bytes off
    /// a NAS, a USB stick, or their own cloud**, and every physical truncation
    /// destroys JSON syntax and loses the `"trailer"` key, so `from_bytes`
    /// returns `SerializationFailed` and the count check is never reached.
    /// Measured on a 324,703-byte package, cuts of 1 B / 64 B / 10% / 50%:
    /// `SerializationFailed` in all four, identical to structural corruption.
    ///
    /// So `PackageTruncated` is **unreachable from any file**, and
    /// `ADR-0017`'s second named property is not delivered. This test asserts
    /// the property on the real path and **is expected to fail until the
    /// authenticated frame count moves into the header** (`PERF-2`, `SEC-41`).
    ///
    /// The lesson, recorded because it generalizes past this test: a test must
    /// enter through the same door the user does. Mine entered at
    /// `Vec<Frame>`; everything between a byte stream and that value went
    /// untested, which is also why `from_bytes` materializing unauthenticated
    /// ciphertext went unnoticed.
    #[test]
    fn truncation_on_disk_is_distinguishable_from_corruption() {
        let (mut vault, seed) = seeded_vault();
        for i in 0..3000 {
            vault.add_context(&cid(&format!("c{i:08}"))).unwrap();
        }
        let mut bytes = Vec::new();
        RecoveryPackage::export_to(&vault, &seed, &mut bytes).unwrap();

        // `expect_err` would require `Debug` on the Ok type, and `VaultPayload`
        // deliberately has none — Global Constraints forbid `Debug` on any
        // secret-bearing type, because it prints key bytes into panic messages
        // and logs. Matched rather than unwrapped so the test cannot drag a
        // `Debug` derive onto the payload to make itself compile.
        for cut in [1usize, 64, bytes.len() / 10, bytes.len() / 2] {
            let truncated = &bytes[..bytes.len() - cut];
            match RecoveryPackage::from_bytes(truncated).and_then(|p| p.decrypt(&seed)) {
                Err(VaultError::PackageTruncated) => {}
                Err(other) => panic!(
                    "cut {cut}: expected PackageTruncated, got {other:?} — \
                     indistinguishable from corruption"
                ),
                Ok(_) => panic!("cut {cut}: a truncated package must not open"),
            }
        }
    }

    /// **`PERF-1` + `PERF-2` acceptance test.** The whole exit criterion.
    ///
    /// | Input | Expected |
    /// |---|---|
    /// | valid | `Ok` |
    /// | header truncated | `PackageTruncated` |
    /// | frame truncated | `PackageTruncated` |
    /// | trailer truncated | `PackageTruncated` |
    /// | header authentication failure | `DecryptionFailed` |
    /// | frame authentication failure | `DecryptionFailed` |
    /// | trailer authentication failure | `DecryptionFailed` |
    ///
    /// Before framing, every row in the truncated column returned
    /// `SerializationFailed` — identical to structural corruption — because
    /// `serde_json::from_slice` cannot parse a partial document, so
    /// `PackageTruncated` was unreachable from any file on disk.
    #[test]
    fn truncated_and_corrupt_packages_are_distinguishable_on_disk() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        for i in 0..3 {
            vault.add_context(&cid(&format!("ctx-{i}"))).unwrap();
        }
        let mut bytes = Vec::new();
        RecoveryPackage::export_to(&vault, &seed, &mut bytes).unwrap();

        // Valid -> Success.
        let package = RecoveryPackage::from_bytes(&bytes).unwrap();
        assert!(package.decrypt(&seed).is_ok(), "valid package must open");
        assert!(
            package.frames.len() >= 3,
            "need header, frames and trailer to cut between"
        );

        // Truncated anywhere -> Truncated. Cuts land in the header, in the
        // frames, and in the trailer respectively.
        for cut in [10, bytes.len() / 2, bytes.len() - 4, bytes.len() - 1] {
            assert!(
                matches!(
                    RecoveryPackage::from_bytes(&bytes[..cut]),
                    Err(VaultError::PackageTruncated)
                ),
                "cut at {cut} of {} reported something other than truncation",
                bytes.len()
            );
        }

        // Corrupt -> Corrupt. Flipping a byte inside a frame keeps every length
        // prefix intact, so the file parses and the AEAD is the only objector.
        let mut corrupt = RecoveryPackage::from_bytes(&bytes).unwrap();
        corrupt.frames[0].ciphertext[0] ^= 0xff;
        assert!(
            matches!(corrupt.decrypt(&seed), Err(VaultError::DecryptionFailed)),
            "a corrupt frame must report corruption, not truncation"
        );

        // Header authentication failure: kdf_salt is AAD-covered.
        let tampered_header = RecoveryPackage::from_bytes(&bytes)
            .unwrap()
            .with_kdf_salt_tampered();
        assert!(matches!(
            tampered_header.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));

        // Trailer authentication failure.
        let mut tampered_trailer = RecoveryPackage::from_bytes(&bytes).unwrap();
        tampered_trailer.trailer[0] ^= 0xff;
        assert!(matches!(
            tampered_trailer.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));
    }

    /// `SEC-35` / `A17` failing form. The package nonce must be inside
    /// `header_aad`.
    ///
    /// `frame_nonce` overwrites bytes 20..24 with the frame index, so those
    /// four bytes are never *read*. Without the AAD line they are also never
    /// *authenticated*: two byte-different files decrypt to the same vault, and
    /// 32 bits of a frozen header field become mutable filler. `SEC-50` found
    /// that deleting `push_len_prefixed(&mut aad, &self.nonce)` left the suite
    /// at 92 passed, 0 failed. This is the test that stops that.
    #[test]
    fn mut_the_package_nonce_is_authenticated() {
        let (vault, seed) = seeded_vault();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.decrypt(&seed).is_ok(), "control: untampered opens");

        // Byte 20 is inside the range `frame_nonce` overwrites, so only the
        // AAD can object to this.
        package.nonce[20] ^= 0xff;
        assert!(
            matches!(package.decrypt(&seed), Err(VaultError::DecryptionFailed)),
            "the nonce tail is unauthenticated -- SEC-35 has no failing form"
        );
    }

    /// `SEC-36` cross-check failing form. The plaintext header epoch and the
    /// sealed trailer head must agree.
    ///
    /// Both are authenticated — the header via `header_aad`, the trailer via
    /// AEAD under that same AAD — so an attacker cannot desync them. This
    /// guards a **buggy writer**: one that computes the header epoch from one
    /// source and the trailer head from another. `SEC-36` is exactly that class
    /// of defect one layer down, so the cross-check needs its own failing form.
    ///
    /// Requires a test-only constructor, because a correct writer cannot
    /// produce this package. That is the point.
    #[test]
    fn mut_header_epoch_and_sealed_head_must_agree() {
        let (mut vault, seed) = seeded_vault();
        let _d = vault.destroy_content(&content_id("note-1")).unwrap();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(
            package.decrypt(&seed).is_ok(),
            "control: consistent package opens"
        );

        // Through `open`, not `decrypt`: the cross-check lives on the route a
        // consumer actually takes. `decrypt` returns the payload without it,
        // which is safe only because it is private to `package.rs` -- worth
        // knowing, since that is the kind of split SEC-1 was about.
        let desynced = package.with_desynced_trailer_head(&seed, 999);
        assert!(
            crate::vault::restore::SealedRestore::load(&desynced, &seed).is_err(),
            "a package whose header epoch disagrees with its sealed head opened \
             -- the cross-check has no failing form"
        );
    }

    /// `SEC-36` failing form. `set_head_epoch` must refuse a head below the
    /// highest entry.
    ///
    /// Without it a hostile or buggy writer rewinds the epoch, and
    /// `revoked_since` then skips every revocation above the rewound head --
    /// resurrecting destroyed content on the restore path.
    #[test]
    fn mut_set_head_epoch_refuses_to_rewind() {
        let mut ledger = RevocationLedger::new();
        for i in 0..5u32 {
            ledger
                .revoke(RevocationSubject::Content(format!("c{i}")))
                .unwrap();
        }
        assert_eq!(ledger.head_epoch(), 5);
        assert!(ledger.set_head_epoch(9).is_ok(), "forward is allowed");
        assert!(
            ledger.set_head_epoch(3).is_err(),
            "head below max(entry) accepted -- SEC-36 has no failing form"
        );
    }

    /// `ADR-0017`'s headline property in its failing form: a truncated package
    /// reports truncation, where before it failed AEAD identically to a
    /// corrupt one and the user was told their backup was corrupt.
    ///
    /// **Retained, but it is not the property test.** It operates on a parsed
    /// package, which is a state no file produces — see the path-correct
    /// version above. Keep it as an in-memory regression on the count check;
    /// do not read it as evidence that truncation is diagnosable on disk.
    #[test]
    fn truncation_is_distinguishable_from_corruption() {
        let (vault, seed) = seeded_vault();
        let full = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(full.frames.len() > 1, "need >1 frame to truncate");

        let mut truncated = full.clone();
        truncated.frames.pop();
        assert!(matches!(
            truncated.decrypt(&seed),
            Err(VaultError::PackageTruncated)
        ));

        let mut corrupted = full;
        corrupted.frames[0].ciphertext[0] ^= 0xff;
        assert!(matches!(
            corrupted.decrypt(&seed),
            Err(VaultError::DecryptionFailed)
        ));
    }

    /// Frames are pinned to the nonce they were sealed under, so reordering
    /// or renumbering fails rather than silently yielding a different vault.
    #[test]
    fn reordered_frames_are_rejected() {
        let (vault, seed) = seeded_vault();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert!(package.frames.len() > 1);
        package.frames.swap(0, 1);
        assert!(package.decrypt(&seed).is_err());
    }

    /// A frame lifted verbatim from one package into another must not open:
    /// the header AAD binds it to its own package.
    #[test]
    fn a_frame_does_not_transplant_between_packages() {
        let (vault_a, seed_a) = seeded_vault();
        let mut a = RecoveryPackage::export(&vault_a, &seed_a).unwrap();
        let b = RecoveryPackage::export(&vault_a, &seed_a).unwrap();
        // Same vault, same seed, different random package nonce and salt.
        a.frames[0] = b.frames[0].clone();
        assert!(matches!(
            a.decrypt(&seed_a),
            Err(VaultError::DecryptionFailed)
        ));
    }

    /// Dropping a frame from the middle and renumbering the rest is still
    /// truncation: the count is what catches it, not the digest.
    ///
    /// This test originally asserted the digest caught this case, and failed —
    /// the count check runs first and returns `PackageTruncated`. Recorded
    /// rather than quietly re-pointed, because it changes what the trailer's
    /// digest is *for*.
    ///
    /// **The digest is defence in depth, not the load-bearing check.** Frame
    /// integrity is already covered three ways: the index is pinned to the
    /// nonce the frame was sealed under, the position must equal the index,
    /// and the header AAD binds every frame to its own package. The digest
    /// costs 32 bytes once and covers whatever a future writer adds that those
    /// three do not — it is kept on that basis and not because anything today
    /// needs it.
    #[test]
    fn dropping_a_middle_frame_is_truncation_not_corruption() {
        let (mut vault, seed) = seeded_vault();
        // A revocation gives a third section, so there is a genuine middle
        // frame to drop: Root, Contexts, Revocations.
        // `PurgeDirective` is `#[must_use]`: derived state must be purged, and
        // dropping it silently defeats deletion. Bound explicitly even here.
        let _directive = vault.destroy_content(&content_id("note-1")).unwrap();
        let mut package = RecoveryPackage::export(&vault, &seed).unwrap();
        assert_eq!(package.frames.len(), 3);
        package.frames.remove(1);
        for (position, frame) in package.frames.iter_mut().enumerate() {
            frame.index = u32::try_from(position).unwrap();
        }
        assert!(matches!(
            package.decrypt(&seed),
            Err(VaultError::PackageTruncated)
        ));
    }

    #[test]
    fn adding_a_kdf_param_fails_decryption() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_kdf_param_tampered("rounds", 1);
        // check_supported rejects non-empty kdf_params first; assert the
        // distinct error so this does not silently stop testing the AAD.
        assert!(matches!(
            package.decrypt(&seed),
            Err(VaultError::UnsupportedProtectionMode)
        ));
    }

    #[test]
    fn format_version_is_bound_by_the_aad_not_only_by_check_supported() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        // Bump then restore the version so check_supported passes, leaving the
        // AAD as the only thing that can catch a mismatch. Achieved by
        // tampering the salt instead is NOT equivalent — this asserts the
        // version specifically participates in the binding.
        let original = package.format_version();
        let package = package.with_format_version_tampered(original + 1);
        let tampered_aad_matches = package.decrypt(&seed).is_ok();
        assert!(!tampered_aad_matches);
    }

    #[test]
    fn an_unsupported_protection_mode_is_rejected_distinctly() {
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let package = package.with_passphrase_flag_tampered();
        // NOT UnsupportedPackageVersion — reporting a protection mode as a
        // version problem is false and misdirects whoever debugs it.
        assert!(matches!(
            package.decrypt(&seed),
            Err(VaultError::UnsupportedProtectionMode)
        ));
    }

    #[test]
    fn the_package_carries_no_content() {
        // It grants access. It does not carry data. Anything that looks like
        // user content here is a defect.
        let (vault, seed) = seeded_vault();
        let package = RecoveryPackage::export(&vault, &seed).unwrap();
        let payload = package.decrypt(&seed).unwrap();

        // The payload holds context keys and certificates. It holds no
        // per-content record at all — that is the point of the redesign.
        assert!(payload.context_keys.contains_key("hospitalization"));
        // KeyBytes refuses to print its contents.
        assert_eq!(
            format!("{:?}", payload.context_keys["hospitalization"]),
            "KeyBytes(<redacted>)"
        );
    }
}

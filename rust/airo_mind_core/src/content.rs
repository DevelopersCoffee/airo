//! The content store. `#1194`'s other half of `C1`: *"the content store holds
//! encrypted content objects and their wrapping sets"* and design doc §3.1:
//! *"Payload behind `ContentID`, never inlined."*
//!
//! # What this is, and what it is not
//!
//! Content-addressed, deduplicating, file-backed: `put` hashes the bytes and
//! writes them once under that hash; a second `put` of identical bytes is a
//! no-op that returns the same [`ContentId`]. That shape is what design §4.1
//! needs — a hospital bill wrapped by three contexts is one object, not
//! three — even before any context ever wraps anything.
//!
//! It is **not encrypted yet**. §4.1's envelope encryption (`wrap(CK,
//! ContextKey)`, the wrapping set living with the object) is Phase 1's Vault:
//! identity and the key hierarchy do not exist in this crate, and encrypting
//! against a key nobody can rotate or revoke would be theatre. Every object
//! here is plaintext-on-disk today. The shape does not change when Vault
//! lands — `put`/`get`/[`ContentId`] stay the same signatures, `put` starts
//! sealing under a content key instead of writing bytes verbatim — which is
//! the same "build the shape now, fill in the semantics later" trade
//! [`crate::store::MeetingStore`]'s doc comment already makes explicit.
//!
//! # A known, documented gap this creates
//!
//! §3.1's header-disclosure rule requires `payloadHash` to cover the
//! **ciphertext**, never the plaintext, because a plaintext hash is an
//! equality oracle — two operations with the same hash reveal identical
//! content even after crypto-shredding, using exactly the header field the
//! rule was written to police. [`OperationHeader::payload_hash`] in
//! [`crate::runtime`] currently hashes plaintext, because there is no
//! ciphertext yet to hash. This must move the moment content encryption
//! lands; it is called out again at that field's definition so it cannot be
//! missed twice.

use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};

use crate::digest::Sha256;

/// Overwrites every byte of the file at `path` with `fill`, then `fsync`s.
/// Used by [`ContentStore::remove`]'s secure-erase pass — see its doc for why
/// a plain unlink is not enough. Writes in fixed-size chunks rather than
/// building one `len`-sized buffer, so destroying a large object does not
/// require allocating a same-sized scratch buffer.
fn overwrite_in_place(path: &Path, len: u64, fill: u8) -> Result<(), ContentStoreError> {
    const CHUNK: usize = 64 * 1024;
    let mut f = File::options().write(true).open(path)?;
    f.seek(SeekFrom::Start(0))?;
    let buf = [fill; CHUNK];
    let mut remaining = len;
    while remaining > 0 {
        let n = remaining.min(CHUNK as u64) as usize;
        f.write_all(&buf[..n])?;
        remaining -= n as u64;
    }
    f.sync_data()?;
    Ok(())
}

/// A content-addressed identifier: lowercase hex SHA-256 of the object's
/// bytes as stored (plaintext today; ciphertext once Vault lands — see the
/// module doc). Two objects with the same bytes always share one id, which is
/// what makes storage content-addressed rather than merely file-backed.
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct ContentId(String);

impl ContentId {
    /// For a caller that already has a hash (e.g. a header's `payload_hash`)
    /// and wants to address the store without re-hashing. Does not verify
    /// anything is stored under it — [`ContentStore::get`] is the only check
    /// that matters.
    pub fn from_hex(hex: impl Into<String>) -> Self {
        Self(hex.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl std::fmt::Display for ContentId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

#[derive(Debug)]
pub enum ContentStoreError {
    Io(String),
    /// The bytes read back from disk do not hash to the file's own name.
    /// Content-addressed storage makes this a **corruption** signal, not a
    /// business error: nothing but disk damage or an out-of-band edit
    /// produces it, because `put` never writes to a path whose hash does not
    /// match.
    Corrupt {
        id: String,
        found: String,
    },
}

impl std::fmt::Display for ContentStoreError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io(m) => write!(f, "content store I/O error: {m}"),
            Self::Corrupt { id, found } => write!(
                f,
                "content object {id} is corrupt: bytes on disk hash to {found}"
            ),
        }
    }
}

impl std::error::Error for ContentStoreError {}

impl From<std::io::Error> for ContentStoreError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e.to_string())
    }
}

fn sha256_hex(bytes: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(bytes);
    h.finish()
}

/// Content-addressed, deduplicating, file-backed. One file per distinct
/// object, named by its own hash — a directory listing this store is already
/// a manifest of every `ContentId` durable on this device.
pub struct ContentStore {
    dir: PathBuf,
}

impl ContentStore {
    pub fn open(dir: impl Into<PathBuf>) -> Result<Self, ContentStoreError> {
        let dir = dir.into();
        fs::create_dir_all(&dir)?;
        Ok(Self { dir })
    }

    fn path_for(&self, id: &ContentId) -> PathBuf {
        self.dir.join(id.as_str())
    }

    /// Stores `bytes` under their own hash. Content-addressed: writing the
    /// same bytes twice is idempotent and touches disk once — `put` checks
    /// existence before writing, so a second `put` of an already-stored
    /// object is a stat, not a write.
    ///
    /// Written to a temp file and renamed into place, so a reader can never
    /// observe a partially written object at its final path — `rename` is
    /// atomic on every platform this crate ships to.
    pub fn put(&self, bytes: &[u8]) -> Result<ContentId, ContentStoreError> {
        let id = ContentId(sha256_hex(bytes));
        let path = self.path_for(&id);
        if path.exists() {
            return Ok(id);
        }
        let tmp = self
            .dir
            .join(format!("{}.tmp-{}", id.as_str(), std::process::id()));
        {
            let mut f = File::create(&tmp)?;
            f.write_all(bytes)?;
            f.sync_data()?;
        }
        fs::rename(&tmp, &path)?;
        Ok(id)
    }

    /// Reads an object back, verifying it still hashes to its own name.
    /// `None` if nothing is stored under `id` — a missing object is a normal
    /// outcome (never written, or already destroyed), distinct from
    /// [`ContentStoreError::Corrupt`], which means something *is* there and
    /// it is wrong.
    pub fn get(&self, id: &ContentId) -> Result<Option<Vec<u8>>, ContentStoreError> {
        let path = self.path_for(id);
        let mut file = match File::open(&path) {
            Ok(f) => f,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
            Err(e) => return Err(e.into()),
        };
        let mut bytes = Vec::new();
        file.read_to_end(&mut bytes)?;
        let found = sha256_hex(&bytes);
        if found != id.as_str() {
            return Err(ContentStoreError::Corrupt {
                id: id.to_string(),
                found,
            });
        }
        Ok(Some(bytes))
    }

    pub fn contains(&self, id: &ContentId) -> bool {
        self.path_for(id).exists()
    }

    /// Deletes the local blob. `#1194`'s mechanical half of `DestroyContent`
    /// (design §4.3 step 3): removing the encrypted blob. The rest of §4.3 —
    /// destroying every wrapping, appending `RevokeContentKey`, sweeping
    /// derived state — needs the Vault's revocation ledger and does not exist
    /// in this crate yet; a caller relying on this alone for real destruction
    /// is relying on convention, exactly as `crate::runtime`'s module doc and
    /// design §4.3's own closing paragraph already say plainly.
    ///
    /// `#1217` closed the honesty gap this left: a plain `fs::remove_file`
    /// only unlinks a directory entry — the bytes themselves can still sit on
    /// disk until the filesystem reuses the blocks, readable by anything that
    /// walks raw disk sectors or an undelete tool. This now overwrites the
    /// object's bytes in place (twice — once with zeros, once with `0xFF`,
    /// each `fsync`'d) and truncates to zero length *before* unlinking, so a
    /// reader who reopens the path a moment later, or recovers the inode
    /// after the unlink, finds no trace of the original content. This is a
    /// best-effort software erasure, not a cryptographic guarantee — it does
    /// not defend against flash-storage wear-leveling relocating a block
    /// before the overwrite reaches it, filesystem snapshots, or a backup
    /// taken before this ran. `#1193` (Vault, crypto-shredding) is what makes
    /// destruction unconditional regardless of medium; this is the
    /// conservative, real thing this crate can do without it.
    ///
    /// Idempotent: removing an already-absent object is not an error, the
    /// same "no file yet is empty, not broken" discipline
    /// [`crate::store::MeetingStore`] uses.
    pub fn remove(&self, id: &ContentId) -> Result<(), ContentStoreError> {
        let path = self.path_for(id);
        let len = match fs::metadata(&path) {
            Ok(meta) => meta.len(),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(()),
            Err(e) => return Err(e.into()),
        };
        if len > 0 {
            overwrite_in_place(&path, len, 0x00)?;
            overwrite_in_place(&path, len, 0xFF)?;
        }
        // Truncate to zero length before unlinking: on a filesystem where the
        // unlink alone leaves a recoverable inode (a still-open handle
        // elsewhere, a crash between overwrite and unlink), a zero-length
        // file has nothing left to recover from that path either.
        if let Ok(f) = File::options().write(true).open(&path) {
            let _ = f.set_len(0);
            let _ = f.sync_data();
        }
        match fs::remove_file(&path) {
            Ok(()) => Ok(()),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(e) => Err(e.into()),
        }
    }

    pub fn dir(&self) -> &Path {
        &self.dir
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(name: &str) -> PathBuf {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("airo_mind_content_{name}_{unique}"))
    }

    #[test]
    fn put_then_get_round_trips() {
        let dir = temp_dir("roundtrip");
        let store = ContentStore::open(&dir).unwrap();
        let id = store.put(b"hello content").unwrap();
        assert_eq!(store.get(&id).unwrap().unwrap(), b"hello content");
        let _ = fs::remove_dir_all(&dir);
    }

    /// Design §4.1: content is addressed by its own bytes, so identical
    /// objects always collapse to one id and one file on disk.
    #[test]
    fn identical_bytes_deduplicate_to_the_same_id_and_one_file() {
        let dir = temp_dir("dedup");
        let store = ContentStore::open(&dir).unwrap();
        let first = store.put(b"same bytes").unwrap();
        let second = store.put(b"same bytes").unwrap();
        assert_eq!(first, second);
        assert_eq!(fs::read_dir(&dir).unwrap().count(), 1);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn different_bytes_get_different_ids() {
        let dir = temp_dir("distinct");
        let store = ContentStore::open(&dir).unwrap();
        let a = store.put(b"a").unwrap();
        let b = store.put(b"b").unwrap();
        assert_ne!(a, b);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn a_missing_object_is_none_not_an_error() {
        let dir = temp_dir("missing");
        let store = ContentStore::open(&dir).unwrap();
        let ghost = ContentId::from_hex("0".repeat(64));
        assert!(store.get(&ghost).unwrap().is_none());
        let _ = fs::remove_dir_all(&dir);
    }

    /// The corruption case: a file on disk whose bytes no longer hash to its
    /// own filename. Content-addressed storage turns this into a checkable
    /// fact instead of a silent wrong-content bug.
    #[test]
    fn tampered_bytes_are_detected_as_corruption_not_returned_silently() {
        let dir = temp_dir("corrupt");
        let store = ContentStore::open(&dir).unwrap();
        let id = store.put(b"original").unwrap();
        fs::write(dir.join(id.as_str()), b"tampered").unwrap();

        let err = store.get(&id).unwrap_err();
        assert!(matches!(err, ContentStoreError::Corrupt { .. }));
        let _ = fs::remove_dir_all(&dir);
    }

    /// `#1194` / design §4.3 step 3: the mechanical piece of `DestroyContent`
    /// this crate can perform today.
    #[test]
    fn remove_deletes_the_blob_and_is_idempotent() {
        let dir = temp_dir("remove");
        let store = ContentStore::open(&dir).unwrap();
        let id = store.put(b"to be destroyed").unwrap();
        assert!(store.contains(&id));

        store.remove(&id).unwrap();
        assert!(!store.contains(&id));
        assert!(store.get(&id).unwrap().is_none());

        // Removing again is not an error.
        store.remove(&id).unwrap();
        let _ = fs::remove_dir_all(&dir);
    }

    /// A store reopened at the same path (a restarted process) sees what an
    /// earlier handle wrote — the durability property the operation log
    /// already proves for itself, needed here too because content is the
    /// other durable store `C1` names.
    #[test]
    fn content_survives_reopening_the_store() {
        let dir = temp_dir("reopen");
        let id = {
            let store = ContentStore::open(&dir).unwrap();
            store.put(b"persisted").unwrap()
        };
        let reopened = ContentStore::open(&dir).unwrap();
        assert_eq!(reopened.get(&id).unwrap().unwrap(), b"persisted");
        let _ = fs::remove_dir_all(&dir);
    }
}

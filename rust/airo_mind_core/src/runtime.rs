//! The Operation → Persist → Replay → Projection substrate. `#1194`
//! (condition 4: *"every durable object is reachable from the operation
//! log"*) and half of `#1195` (condition 5: *"every projection can be
//! deleted and rebuilt"* — the other half lives in [`crate::projection`]).
//!
//! `#1338` shipped this as a deliberately minimal skeleton: a local, unsigned
//! record with no content store, so a single capability (Notes) could prove
//! `Operation → Persist → Replay → Projection` end to end through the
//! Supervisor's own lifecycle. This module is that skeleton formalized against
//! `C1`'s and `C2`'s actual text and `#1194`'s scope table:
//!
//! - **The full header** design doc §3.1 specifies — `operationId`,
//!   `parentOperationId`, `entityId`, `contextIds[]`, `schemaId`,
//!   `capabilityId`, `deviceId`, `timestamp`, `versionVector`, `payloadHash`,
//!   `signature` — is now on [`Operation`], not just `seq`/`capability`/
//!   `kind`/`payload`/`recorded_at_ms`.
//! - **A content store** ([`crate::content::ContentStore`]) exists, and
//!   [`Runtime::attach_content`] is implemented rather than declared
//!   out-of-scope.
//! - **Every operation is signed** ([`crate::signing`]) and a tampered header
//!   fails verification — with the honest caveat, documented at
//!   [`crate::signing`]'s module doc, that the signer is a placeholder until
//!   Phase 1's Vault exists.
//! - **The wire format is versioned** (a leading format-version byte), so a
//!   future incompatible change has somewhere to signal it rather than
//!   silently misparsing an old log.
//! - **Concurrent writers are safe.** `Self::append` used to open a fresh
//!   file handle per call and assign `seq` with an independent atomic —two
//!   threads could interleave a write with a `seq` assignment from the other,
//!   producing a log whose on-disk order did not match its `seq` order. Both
//!   now happen under one lock ([`LogWriterState`]), so `seq` assignment and
//!   the byte write it labels are one atomic step.
//!
//! # Still explicitly deferred (not this phase's job)
//!
//! - **Real device identity and signing keys.** Phase 1 (Vault). This
//!   module's `device_id` is generated locally and persisted beside the log;
//!   it is not issued by anything and proves nothing about the device to a
//!   peer. See [`crate::signing`].
//! - **Content encryption.** Phase 1 (Vault's key hierarchy). The content
//!   store holds plaintext; see [`crate::content`]'s module doc for the
//!   `payload_hash`-over-plaintext gap this creates and why it is called out
//!   twice rather than fixed by working around it here.
//! - **Group-commit batching.** Each `append` still flushes and `fsync`s
//!   immediately (`C1` allows batching within a bounded window; it does not
//!   require it). Batching is a throughput optimization behind the same
//!   `OperationLog::append` signature, not a shape change.
//! - **Sync, contexts, capability packs, and Vault verbs** — `AuthorizeDevice`
//!   / `RevokeDevice` / `RevokeContentKey` in [`crate::verb::Verb`] have no
//!   handler here beyond being valid wire values. They are Phase 1/7's verbs,
//!   declared now (so the format does not have to change to add them) and
//!   implemented later.
//!
//! # Determinism (`C2`)
//!
//! [`OperationLog::replay`] reads the file front-to-back once and returns
//! operations in the order they were written. No `HashMap` iteration
//! (`version_vector` is a `BTreeMap`), no wall-clock read, no locale, on this
//! path. `recorded_at_ms` is supplied by the caller and never sampled inside
//! the runtime.

use std::collections::BTreeMap;
use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::Mutex;

use crate::content::{ContentId, ContentStore, ContentStoreError};
use crate::digest::Sha256;
use crate::engine::EngineError;
use crate::event::{CapabilityEvent, EventBus};
use crate::lifecycle::{EngineName, ManagedEngine};
use crate::signing::{DeviceKeySigner, SignerVerifier};
use crate::supervisor::Supervisor;
use crate::verb::Verb;

fn sha256_hex(bytes: &[u8]) -> String {
    let mut h = Sha256::new();
    h.update(bytes);
    h.finish()
}

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

/// One durable entry in the operation log. Design doc §3.1's full header,
/// plus the payload/content-id pair that carries the capability's own data.
///
/// `capability`/`kind`/`payload`/`recorded_at_ms` are the four fields
/// `#1338`'s skeleton already shipped and [`crate::notes`] already depends on
/// by name — unchanged, so nothing that already reads them needed to move.
/// Everything else is new with this formalization.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Operation {
    /// Monotonic, gap-free, assigned by [`OperationLog::append`] under one
    /// lock shared with the byte write it labels — see the module doc.
    pub seq: u64,
    /// `operationId` (§3.1). Content-derived: `sha256(device_id, seq,
    /// capability, kind, payload_hash, recorded_at_ms)`. Deterministic and
    /// citable without depending on a signature having been produced yet.
    pub operation_id: String,
    /// `parentOperationId` (§3.1). `None` for every operation this phase
    /// emits — no capability shipped here threads causal parentage yet — but
    /// the field exists so a future capability does not need a format
    /// change to start setting it.
    pub parent_operation_id: Option<String>,
    /// `entityId` (§3.1). Empty string for a capability that has not adopted
    /// the entity/property model (`""` rather than `Option` — an operation
    /// with no entity, like `InstallPack`, has this by construction rather
    /// than as a documented magic value).
    pub entity_id: String,
    /// `contextIds[]` (§3.1). Empty for the same reason.
    pub context_ids: Vec<String>,
    /// `schemaId` (§3.1). Empty until a capability declares a real schema
    /// fingerprint (§5.5) — not yet in scope.
    pub schema_id: String,
    /// `capabilityId` (§3.1). Kept named `capability` — the name
    /// `#1338`/`crate::notes` already uses.
    pub capability: String,
    /// The verb or the capability's own vocabulary. [`Self::verb`] parses
    /// this against [`crate::verb::Verb`] when it is one of the nineteen
    /// canonical verbs; a capability's free-form string (`"note.create"`)
    /// simply does not match, which is not an error — `C5`: the runtime
    /// knows no domains, and both forms share this one field.
    pub kind: String,
    /// `deviceId` (§3.1). See the module doc: locally generated, not
    /// Vault-issued, this phase.
    pub device_id: String,
    /// `timestamp` (§3.1). Supplied by the caller, never sampled here
    /// (`C2`). Kept named `recorded_at_ms` for the same reason `capability`
    /// keeps its name.
    pub recorded_at_ms: u64,
    /// `versionVector` (§3.1). Single-device today: `{device_id: seq + 1}`,
    /// this device's own operation count after this one. Multi-device merge
    /// is Phase 3's sync work and is explicitly out of scope here (both
    /// `#1194` and `#1195` name Sync as blocked-on / out-of-scope).
    pub version_vector: BTreeMap<String, u64>,
    /// `payloadHash` (§3.1). Hex SHA-256. **Known gap**, documented in full
    /// at [`crate::content`]'s module doc: this hashes `payload` as written
    /// — plaintext today, because there is no ciphertext yet — which is
    /// exactly the equality-oracle risk §3.1 warns against. Must move to
    /// hashing ciphertext the moment content encryption lands.
    pub payload_hash: String,
    /// `signature` (§3.1). See [`crate::signing`] for what this does and
    /// does not prove today.
    pub signature: Vec<u8>,
    /// The capability's own small, inline arguments (a note's title and
    /// body, a property's new value). Not routed through the content store —
    /// §3.1's "payload behind `ContentID`, never inlined" describes the
    /// **Content primitive** (design §2's table: potentially large,
    /// independently addressable user data), not every operation's
    /// arguments. `SetProperty` carrying one property inline is the shape
    /// §3.2 itself describes.
    pub payload: Vec<u8>,
    /// Set when this operation's real payload lives in the content store
    /// (`CreateContent`, `LinkContent`, and similar) rather than inline.
    /// `payload` is empty when this is `Some`.
    pub content_id: Option<ContentId>,
}

impl Operation {
    /// Parses [`Self::kind`] against the fixed verb set, when it is one of
    /// the nineteen. `None` for a capability's own free-form vocabulary.
    pub fn verb(&self) -> Option<Verb> {
        Verb::parse_kind(&self.kind)
    }

    /// The exact bytes [`Self::signature`] was produced over. Reconstructible
    /// from the operation alone — needed so a verifier does not have to be
    /// the same object that produced the signature.
    pub fn canonical_header(&self) -> Vec<u8> {
        canonical_header_bytes(
            self.seq,
            &self.operation_id,
            self.parent_operation_id.as_deref(),
            &self.entity_id,
            &self.context_ids,
            &self.schema_id,
            &self.capability,
            &self.kind,
            &self.device_id,
            self.recorded_at_ms,
            &self.version_vector,
            &self.payload_hash,
        )
    }
}

#[allow(clippy::too_many_arguments)]
fn canonical_header_bytes(
    seq: u64,
    operation_id: &str,
    parent_operation_id: Option<&str>,
    entity_id: &str,
    context_ids: &[String],
    schema_id: &str,
    capability: &str,
    kind: &str,
    device_id: &str,
    recorded_at_ms: u64,
    version_vector: &BTreeMap<String, u64>,
    payload_hash: &str,
) -> Vec<u8> {
    let mut out = Vec::new();
    out.extend_from_slice(&seq.to_be_bytes());
    push_str(&mut out, operation_id);
    push_opt_str(&mut out, parent_operation_id);
    push_str(&mut out, entity_id);
    out.extend_from_slice(&(context_ids.len() as u32).to_be_bytes());
    for c in context_ids {
        push_str(&mut out, c);
    }
    push_str(&mut out, schema_id);
    push_str(&mut out, capability);
    push_str(&mut out, kind);
    push_str(&mut out, device_id);
    out.extend_from_slice(&recorded_at_ms.to_be_bytes());
    // `BTreeMap` iterates in key order — deterministic, `C2`-safe, unlike a
    // `HashMap` this same field would tempt someone to reach for.
    out.extend_from_slice(&(version_vector.len() as u32).to_be_bytes());
    for (device, count) in version_vector {
        push_str(&mut out, device);
        out.extend_from_slice(&count.to_be_bytes());
    }
    push_str(&mut out, payload_hash);
    out
}

// ---------------------------------------------------------------------------
// Operation log — the data-plane half of `C1` this module implements
// ---------------------------------------------------------------------------

/// Why a log operation failed.
#[derive(Debug)]
pub enum OperationLogError {
    Io(String),
    /// The file's tail did not parse as a complete record. Treated as the
    /// end of the durable log rather than a hard failure — a process killed
    /// mid-`write` leaves a torn tail, and `C6`'s graceful-shutdown guarantee
    /// is what is supposed to prevent this in the real group-commit buffer.
    TornTail,
    /// The log's leading format-version byte does not match anything this
    /// build understands. Refused rather than misparsed — a wire-format
    /// change is a decision `#1194`'s scope table asks for, not a silent
    /// reinterpretation of old bytes.
    UnsupportedVersion(u8),
    /// The header this record just produced does not verify under its own
    /// signature immediately after being written. Defensive: proves the
    /// sign/verify round trip on every single append rather than trusting it
    /// abstractly — see the ingest-time obligation in `C2`.
    SignatureMismatchOnWrite,
}

impl std::fmt::Display for OperationLogError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io(m) => write!(f, "operation log I/O error: {m}"),
            Self::TornTail => write!(f, "operation log tail is truncated"),
            Self::UnsupportedVersion(v) => {
                write!(f, "operation log format version {v} is not supported")
            }
            Self::SignatureMismatchOnWrite => {
                write!(
                    f,
                    "a freshly written operation failed its own signature check"
                )
            }
        }
    }
}

impl std::error::Error for OperationLogError {}

impl From<std::io::Error> for OperationLogError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e.to_string())
    }
}

/// The only format version this build writes or accepts.
const FORMAT_VERSION: u8 = 1;

/// What [`OperationLog::append`] needs beyond what only the log itself
/// knows (`seq`, `device_id`, `version_vector`, `operation_id`, `signature`).
#[allow(clippy::too_many_arguments)]
pub struct AppendRequest<'a> {
    pub capability: &'a str,
    pub kind: &'a str,
    pub payload: &'a [u8],
    pub recorded_at_ms: u64,
    pub entity_id: &'a str,
    pub parent_operation_id: Option<&'a str>,
    pub context_ids: &'a [&'a str],
    pub schema_id: &'a str,
    pub content_id: Option<ContentId>,
}

/// The mutable, lock-guarded half of [`OperationLog`]: the persistent write
/// handle and the next sequence number, updated together. This is what makes
/// concurrent appends safe — two threads racing `OperationLog::append` take
/// this lock in turn, so `seq` assignment and the byte write it labels can
/// never interleave with another thread's.
struct LogWriterState {
    next_seq: u64,
    file: File,
}

/// Sequential, append-only, file-backed operation log.
///
/// `C1`: *"writes are sequential and append-only; no in-place rewrite."*
/// Every [`Self::append`] writes one encoded record under
/// [`LogWriterState`]'s lock and flushes + `fsync`s before returning.
pub struct OperationLog {
    path: PathBuf,
    device_id: String,
    signer: Arc<dyn SignerVerifier>,
    state: Mutex<LogWriterState>,
}

impl OperationLog {
    /// Opens the log at `path`, creating it (and a format-version byte) if
    /// absent. `device_id` is persisted beside the log
    /// ([`load_or_create_device_id`]) so restarts keep the same identity —
    /// load-bearing for [`Operation::version_vector`] to mean anything across
    /// a restart.
    pub fn open(path: impl Into<PathBuf>) -> Result<Self, OperationLogError> {
        let path = path.into();
        let device_id = load_or_create_device_id(&path)?;
        let signer: Arc<dyn SignerVerifier> =
            Arc::new(DeviceKeySigner::new(device_id.as_bytes().to_vec()));
        Self::open_with_identity(path, device_id, signer)
    }

    /// As [`Self::open`], with an explicit device id and signer — the seam a
    /// test (or, later, Phase 1's Vault) uses to control identity rather than
    /// accept whatever was generated on first open.
    pub fn open_with_identity(
        path: impl Into<PathBuf>,
        device_id: String,
        signer: Arc<dyn SignerVerifier>,
    ) -> Result<Self, OperationLogError> {
        let path = path.into();
        let is_new = !path.exists();
        if is_new {
            let mut f = OpenOptions::new()
                .create(true)
                .write(true)
                .truncate(true)
                .open(&path)?;
            f.write_all(&[FORMAT_VERSION])?;
            f.sync_data()?;
        }
        let existing = Self::read_all(&path)?;
        let next_seq = existing.last().map(|op| op.seq + 1).unwrap_or(0);
        let file = OpenOptions::new().append(true).open(&path)?;
        Ok(Self {
            path,
            device_id,
            signer,
            state: Mutex::new(LogWriterState { next_seq, file }),
        })
    }

    pub fn device_id(&self) -> &str {
        &self.device_id
    }

    /// Appends one operation and returns it with its assigned `seq`.
    /// `seq` assignment, header construction, signing, the byte write, and
    /// the durability sync all happen under one lock — see the module doc's
    /// concurrent-writer-safety note.
    pub fn append(&self, req: AppendRequest<'_>) -> Result<Operation, OperationLogError> {
        let mut guard = self.state.lock().unwrap();
        let seq = guard.next_seq;

        let payload_hash = sha256_hex(req.payload);
        let operation_id = sha256_hex(
            format!(
                "{}\u{1f}{}\u{1f}{}\u{1f}{}\u{1f}{}\u{1f}{}",
                self.device_id, seq, req.capability, req.kind, payload_hash, req.recorded_at_ms
            )
            .as_bytes(),
        );
        let context_ids: Vec<String> = req.context_ids.iter().map(|s| s.to_string()).collect();
        let mut version_vector = BTreeMap::new();
        version_vector.insert(self.device_id.clone(), seq + 1);

        let canonical = canonical_header_bytes(
            seq,
            &operation_id,
            req.parent_operation_id,
            req.entity_id,
            &context_ids,
            req.schema_id,
            req.capability,
            req.kind,
            &self.device_id,
            req.recorded_at_ms,
            &version_vector,
            &payload_hash,
        );
        let signature = self.signer.sign(&canonical);
        // Ingest-time obligation (`C2`): verify before the record is
        // considered durable, not after.
        if !self.signer.verify(&canonical, &signature) {
            return Err(OperationLogError::SignatureMismatchOnWrite);
        }

        let op = Operation {
            seq,
            operation_id,
            parent_operation_id: req.parent_operation_id.map(str::to_string),
            entity_id: req.entity_id.to_string(),
            context_ids,
            schema_id: req.schema_id.to_string(),
            capability: req.capability.to_string(),
            kind: req.kind.to_string(),
            device_id: self.device_id.clone(),
            recorded_at_ms: req.recorded_at_ms,
            version_vector,
            payload_hash,
            signature,
            payload: req.payload.to_vec(),
            content_id: req.content_id,
        };

        guard.file.write_all(&encode(&op))?;
        guard.file.flush()?;
        guard.file.sync_data()?;
        guard.next_seq = seq + 1;

        Ok(op)
    }

    /// Replays every durable operation, in write order, in a single pass over
    /// the file. `C2`: *"replay is a single pass"* · *"the same log produces
    /// byte-identical state on every device."* Does **not** re-verify
    /// signatures — `C2`: *"replay below the watermark does not re-verify"*;
    /// every record here was already verified at [`Self::append`] time. Use
    /// [`Self::replay_reverifying`] to check anyway (what the conformance
    /// suite uses to prove tamper detection on the file itself).
    pub fn replay(&self) -> Result<Vec<Operation>, OperationLogError> {
        Self::read_all(&self.path)
    }

    /// As [`Self::replay`], but re-verifies every signature against
    /// [`Self::device_id`]'s signer. Not the normal path (`C2` explicitly
    /// forbids re-verifying below the watermark, for cost reasons on a large
    /// log) — this exists so the conformance suite can prove a tampered file
    /// is detectable at all, rather than merely trusting the in-memory
    /// `Signer`/`Verifier` unit tests.
    pub fn replay_reverifying(&self) -> Result<Vec<Operation>, ReplayVerifyError> {
        let ops = self.replay().map_err(ReplayVerifyError::Log)?;
        for op in &ops {
            if !self.signer.verify(&op.canonical_header(), &op.signature) {
                return Err(ReplayVerifyError::Unverifiable(op.seq));
            }
        }
        Ok(ops)
    }

    /// How many operations are durable right now.
    pub fn len(&self) -> Result<usize, OperationLogError> {
        Ok(Self::read_all(&self.path)?.len())
    }

    pub fn is_empty(&self) -> Result<bool, OperationLogError> {
        Ok(self.len()? == 0)
    }

    fn read_all(path: &Path) -> Result<Vec<Operation>, OperationLogError> {
        let mut file = match File::open(path) {
            Ok(f) => f,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
            Err(e) => return Err(e.into()),
        };
        let mut bytes = Vec::new();
        file.read_to_end(&mut bytes)?;
        if bytes.is_empty() {
            return Ok(Vec::new());
        }
        let version = bytes[0];
        if version != FORMAT_VERSION {
            return Err(OperationLogError::UnsupportedVersion(version));
        }
        decode_all(&bytes[1..])
    }
}

#[derive(Debug)]
pub enum ReplayVerifyError {
    Log(OperationLogError),
    /// `op.seq` failed its signature check on replay.
    Unverifiable(u64),
}

impl std::fmt::Display for ReplayVerifyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Log(e) => write!(f, "{e}"),
            Self::Unverifiable(seq) => write!(f, "operation {seq} failed signature verification"),
        }
    }
}

impl std::error::Error for ReplayVerifyError {}

/// Reads (or generates and persists) a per-log device id, in a sibling file
/// `<path>.device_id`. Not Vault-issued (see the module doc) — generated
/// once from the path, the process id, and the current time, which is enough
/// entropy to make two freshly created logs on the same machine unlikely to
/// collide without pulling in a UUID/RNG dependency this crate does not
/// carry.
fn load_or_create_device_id(log_path: &Path) -> Result<String, OperationLogError> {
    let id_path = device_id_path(log_path);
    if let Ok(existing) = std::fs::read_to_string(&id_path) {
        let trimmed = existing.trim();
        if !trimmed.is_empty() {
            return Ok(trimmed.to_string());
        }
    }
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    let seed = format!(
        "{}\u{1f}{}\u{1f}{}",
        log_path.display(),
        std::process::id(),
        nanos
    );
    let device_id = sha256_hex(seed.as_bytes())[..16].to_string();
    std::fs::write(&id_path, &device_id)?;
    Ok(device_id)
}

fn device_id_path(log_path: &Path) -> PathBuf {
    let mut name = log_path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    name.push_str(".device_id");
    log_path.with_file_name(name)
}

fn content_dir_for(log_path: &Path) -> PathBuf {
    let mut name = log_path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_default();
    name.push_str(".content");
    log_path.with_file_name(name)
}

// ---------------------------------------------------------------------------
// Wire format — hand-rolled: this crate carries zero dependencies (see the
// note in `Cargo.toml`), so no serde. Every field is length-prefixed and
// fixed-width integers are big-endian, which is what makes the format itself
// platform-independent — part of `C2`'s byte-identical-on-every-platform
// guarantee. `FORMAT_VERSION` (currently `1`) gates this whole shape; a
// future incompatible change bumps it and adds a branch, per `C1`'s
// "migrations are pure, total, forward-only" (`crate::projection` — not this
// module's job, since this module never rewrites the log itself).
// ---------------------------------------------------------------------------

fn push_str(out: &mut Vec<u8>, s: &str) {
    let bytes = s.as_bytes();
    out.extend_from_slice(&(bytes.len() as u32).to_be_bytes());
    out.extend_from_slice(bytes);
}

fn push_opt_str(out: &mut Vec<u8>, s: Option<&str>) {
    match s {
        Some(s) => {
            out.push(1);
            push_str(out, s);
        }
        None => out.push(0),
    }
}

fn encode(op: &Operation) -> Vec<u8> {
    let mut out = Vec::new();
    out.extend_from_slice(&op.seq.to_be_bytes());
    push_str(&mut out, &op.operation_id);
    push_opt_str(&mut out, op.parent_operation_id.as_deref());
    push_str(&mut out, &op.entity_id);
    out.extend_from_slice(&(op.context_ids.len() as u32).to_be_bytes());
    for c in &op.context_ids {
        push_str(&mut out, c);
    }
    push_str(&mut out, &op.schema_id);
    push_str(&mut out, &op.capability);
    push_str(&mut out, &op.kind);
    push_str(&mut out, &op.device_id);
    out.extend_from_slice(&op.recorded_at_ms.to_be_bytes());
    out.extend_from_slice(&(op.version_vector.len() as u32).to_be_bytes());
    for (device, count) in &op.version_vector {
        push_str(&mut out, device);
        out.extend_from_slice(&count.to_be_bytes());
    }
    push_str(&mut out, &op.payload_hash);
    out.extend_from_slice(&(op.signature.len() as u32).to_be_bytes());
    out.extend_from_slice(&op.signature);
    out.extend_from_slice(&(op.payload.len() as u32).to_be_bytes());
    out.extend_from_slice(&op.payload);
    push_opt_str(&mut out, op.content_id.as_ref().map(|c| c.as_str()));
    out
}

/// Decodes every complete record in `bytes`, in order. A torn tail (fewer
/// bytes than the last record's declared length) stops decoding at the last
/// complete record rather than erroring.
fn decode_all(bytes: &[u8]) -> Result<Vec<Operation>, OperationLogError> {
    let mut ops = Vec::new();
    let mut cursor = 0usize;
    while let Some((op, consumed)) = decode_one(&bytes[cursor..]) {
        ops.push(op);
        cursor += consumed;
    }
    Ok(ops)
}

fn decode_one(bytes: &[u8]) -> Option<(Operation, usize)> {
    let mut pos = 0usize;

    let seq = read_u64(bytes, &mut pos)?;
    let operation_id = read_string(bytes, &mut pos)?;
    let parent_operation_id = read_opt_string(bytes, &mut pos)?;
    let entity_id = read_string(bytes, &mut pos)?;
    let context_count = read_u32(bytes, &mut pos)? as usize;
    let mut context_ids = Vec::with_capacity(context_count);
    for _ in 0..context_count {
        context_ids.push(read_string(bytes, &mut pos)?);
    }
    let schema_id = read_string(bytes, &mut pos)?;
    let capability = read_string(bytes, &mut pos)?;
    let kind = read_string(bytes, &mut pos)?;
    let device_id = read_string(bytes, &mut pos)?;
    let recorded_at_ms = read_u64(bytes, &mut pos)?;
    let vv_count = read_u32(bytes, &mut pos)? as usize;
    let mut version_vector = BTreeMap::new();
    for _ in 0..vv_count {
        let device = read_string(bytes, &mut pos)?;
        let count = read_u64(bytes, &mut pos)?;
        version_vector.insert(device, count);
    }
    let payload_hash = read_string(bytes, &mut pos)?;
    let signature = read_bytes(bytes, &mut pos)?;
    let payload = read_bytes(bytes, &mut pos)?;
    let content_id = read_opt_string(bytes, &mut pos)?.map(ContentId::from_hex);

    Some((
        Operation {
            seq,
            operation_id,
            parent_operation_id,
            entity_id,
            context_ids,
            schema_id,
            capability,
            kind,
            device_id,
            recorded_at_ms,
            version_vector,
            payload_hash,
            signature,
            payload,
            content_id,
        },
        pos,
    ))
}

fn read_u64(bytes: &[u8], pos: &mut usize) -> Option<u64> {
    let end = *pos + 8;
    let slice: [u8; 8] = bytes.get(*pos..end)?.try_into().ok()?;
    *pos = end;
    Some(u64::from_be_bytes(slice))
}

fn read_u32(bytes: &[u8], pos: &mut usize) -> Option<u32> {
    let end = *pos + 4;
    let slice: [u8; 4] = bytes.get(*pos..end)?.try_into().ok()?;
    *pos = end;
    Some(u32::from_be_bytes(slice))
}

fn read_bytes(bytes: &[u8], pos: &mut usize) -> Option<Vec<u8>> {
    let len = read_u32(bytes, pos)? as usize;
    let end = *pos + len;
    let slice = bytes.get(*pos..end)?;
    *pos = end;
    Some(slice.to_vec())
}

fn read_string(bytes: &[u8], pos: &mut usize) -> Option<String> {
    String::from_utf8(read_bytes(bytes, pos)?).ok()
}

fn read_opt_string(bytes: &[u8], pos: &mut usize) -> Option<Option<String>> {
    let tag = *bytes.get(*pos)?;
    *pos += 1;
    match tag {
        0 => Some(None),
        1 => Some(Some(read_string(bytes, pos)?)),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Managed engines — the `#1302` lifecycle seam this module fills in
// ---------------------------------------------------------------------------

/// The Vault lifecycle placeholder. See the module docs: this is not Phase
/// 1's Vault, only the dependency slot `Replay` must wait on.
struct VaultEngine;

impl ManagedEngine for VaultEngine {
    fn start(&self) -> Result<(), EngineError> {
        Ok(())
    }

    fn stop(&self) {}
}

/// Wraps [`OperationLog`] as a `#1302` [`ManagedEngine`]: `start` proves the
/// log is openable before anything depends on it being up, `stop` is a no-op
/// because every write already synced itself.
struct ReplayEngine {
    log: Arc<OperationLog>,
}

impl ManagedEngine for ReplayEngine {
    fn start(&self) -> Result<(), EngineError> {
        self.log
            .replay()
            .map(|_| ())
            .map_err(|e| EngineError::Backend(e.to_string()))
    }

    fn stop(&self) {}
}

/// The projection engine's lifecycle slot. [`crate::projection`] is where
/// concrete projections and the delete-and-rebuild machinery for `#1195`
/// live; this stays a lifecycle placeholder for the same reason it was one in
/// `#1338` — a projection is folded fresh from [`Runtime::replay`] on every
/// query, so there is no cached state for this slot to own or restart.
struct ProjectionEngine;

impl ManagedEngine for ProjectionEngine {
    fn start(&self) -> Result<(), EngineError> {
        Ok(())
    }

    fn stop(&self) {}
}

pub const VAULT_ENGINE: EngineName = "vault";
pub const REPLAY_ENGINE: EngineName = "replay";
pub const PROJECTION_ENGINE: EngineName = "projection";

// ---------------------------------------------------------------------------
// Runtime — the six-function surface, `C5`
// ---------------------------------------------------------------------------

/// Why a Runtime API call failed.
#[derive(Debug)]
pub enum RuntimeApiError {
    Log(OperationLogError),
    Content(ContentStoreError),
    /// The Supervisor's engine lifecycle refused the call.
    Lifecycle(crate::supervisor::RuntimeError),
    /// The function exists on the six-function surface (`C5`) but is not
    /// implemented yet. `instantiate_context` (contexts are Phase 5) and
    /// `sync` (Phase 3+, explicitly out of scope for `#1194`/`#1195`)
    /// remain here; `attach_content` no longer does.
    OutOfScope(&'static str),
}

impl std::fmt::Display for RuntimeApiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Log(e) => write!(f, "{e}"),
            Self::Content(e) => write!(f, "{e}"),
            Self::Lifecycle(e) => write!(f, "{e}"),
            Self::OutOfScope(what) => {
                write!(f, "{what} is out of scope for this phase")
            }
        }
    }
}

impl std::error::Error for RuntimeApiError {}

impl From<OperationLogError> for RuntimeApiError {
    fn from(e: OperationLogError) -> Self {
        Self::Log(e)
    }
}

impl From<ContentStoreError> for RuntimeApiError {
    fn from(e: ContentStoreError) -> Self {
        Self::Content(e)
    }
}

/// A read-model built by folding an operation log. `C4`: *"every projection
/// is rebuildable, cache-only, and disposable."* [`crate::projection`] is
/// where `#1195`'s generalized engine and conformance tests live; this trait
/// is the seam they and [`Runtime::query_projection`] share.
pub trait Projection: Sized {
    fn rebuild(ops: &[Operation]) -> Self;
}

/// A capability-facing request to emit an operation. Everything beyond the
/// four fields `#1338` already had (`capability`/`kind`/`payload`/
/// `recorded_at_ms`) defaults to empty/`None` through
/// [`Runtime::emit_operation`] — a capability that has not adopted the
/// entity/property model pays nothing for the fields it does not use.
#[allow(clippy::too_many_arguments)]
pub struct OperationRequest<'a> {
    pub capability: &'a str,
    pub kind: &'a str,
    pub payload: &'a [u8],
    pub recorded_at_ms: u64,
    pub entity_id: &'a str,
    pub parent_operation_id: Option<&'a str>,
    pub context_ids: &'a [&'a str],
    pub schema_id: &'a str,
    /// When set, stored in the content store first; the resulting
    /// [`ContentId`] is attached to the operation and `payload` is expected
    /// to carry only small structural arguments (or be empty).
    pub content: Option<&'a [u8]>,
}

/// `Operation → Persist → Replay → Projection`, wired through the `#1302`
/// Supervisor's engine lifecycle. `C5`'s six-function surface:
/// [`Self::emit_operation`], [`Self::attach_content`],
/// [`Self::query_projection`], [`Self::instantiate_context`],
/// [`Self::replay`], [`Self::sync`].
pub struct Runtime {
    supervisor: Supervisor,
    log: Arc<OperationLog>,
    content: Arc<ContentStore>,
    /// The in-process, non-durable event bus `#1295`'s `emit_event` publishes
    /// to. Not a lifecycle engine (`ProjectionEngine`'s reasoning applies
    /// here too — no durable state for a Supervisor slot to own or restart)
    /// and not reachable from a capability except through
    /// [`crate::capability_api::CapabilityApi::emit_event`].
    event_bus: Arc<EventBus>,
}

impl Runtime {
    /// Boots the runtime with only the Supervisor and the three lifecycle
    /// engines this phase needs — condition 1 of `#1311`: *"the runtime boots
    /// with only the Supervisor."*
    pub fn boot(
        budget: crate::budget::ResourceBudget,
        log_path: impl Into<PathBuf>,
    ) -> Result<Self, RuntimeApiError> {
        let log_path = log_path.into();
        let content_dir = content_dir_for(&log_path);
        let log = Arc::new(OperationLog::open(&log_path)?);
        let content = Arc::new(ContentStore::open(&content_dir)?);
        let mut supervisor = Supervisor::new(budget);

        // `C6`: "dependency ordering is enforced: Vault before Replay before
        // Projection."
        supervisor.register_engine(VAULT_ENGINE, &[], Box::new(VaultEngine));
        supervisor.register_engine(
            REPLAY_ENGINE,
            &[VAULT_ENGINE],
            Box::new(ReplayEngine { log: log.clone() }),
        );
        supervisor.register_engine(
            PROJECTION_ENGINE,
            &[REPLAY_ENGINE],
            Box::new(ProjectionEngine),
        );

        supervisor
            .start_engine(VAULT_ENGINE)
            .map_err(RuntimeApiError::Lifecycle)?;
        supervisor
            .start_engine(REPLAY_ENGINE)
            .map_err(RuntimeApiError::Lifecycle)?;
        supervisor
            .start_engine(PROJECTION_ENGINE)
            .map_err(RuntimeApiError::Lifecycle)?;

        Ok(Self {
            supervisor,
            log,
            content,
            event_bus: Arc::new(EventBus::new()),
        })
    }

    /// Every engine's lifecycle state, in registration order.
    pub fn engine_health(&self) -> Vec<(EngineName, crate::lifecycle::EngineState)> {
        self.supervisor.health()
    }

    /// This device's id, as persisted beside the log. See the module doc:
    /// locally generated, not yet Vault-issued.
    pub fn device_id(&self) -> &str {
        self.log.device_id()
    }

    /// The only write path onto the log for a capability that has not
    /// adopted the entity/property/verb model — `#1338`'s original
    /// signature, unchanged, so [`crate::notes`] needed no edits for this
    /// formalization.
    pub fn emit_operation(
        &self,
        capability: &str,
        kind: &str,
        payload: &[u8],
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        self.emit_operation_ex(OperationRequest {
            capability,
            kind,
            payload,
            recorded_at_ms,
            entity_id: "",
            parent_operation_id: None,
            context_ids: &[],
            schema_id: "",
            content: None,
        })
    }

    /// Emits one of the nineteen fixed [`Verb`]s (`#1194`'s scope table),
    /// with a real entity/context/schema header. The verb-based counterpart
    /// to [`Self::emit_operation`], for a capability built against the
    /// formal graph vocabulary rather than free-form `kind` strings.
    #[allow(clippy::too_many_arguments)]
    pub fn emit_verb_operation(
        &self,
        capability: &str,
        verb: Verb,
        entity_id: &str,
        context_ids: &[&str],
        schema_id: &str,
        payload: &[u8],
        content: Option<&[u8]>,
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        self.emit_operation_ex(OperationRequest {
            capability,
            kind: verb.as_str(),
            payload,
            recorded_at_ms,
            entity_id,
            parent_operation_id: None,
            context_ids,
            schema_id,
            content,
        })
    }

    /// The full seam both [`Self::emit_operation`] and
    /// [`Self::emit_verb_operation`] funnel through. When `req.content` is
    /// set it is written to the content store first and the operation
    /// carries only its [`ContentId`] — §3.1's "payload behind `ContentID`,
    /// never inlined" for the Content primitive.
    pub fn emit_operation_ex(
        &self,
        req: OperationRequest<'_>,
    ) -> Result<Operation, RuntimeApiError> {
        let content_id = match req.content {
            Some(bytes) => Some(self.content.put(bytes)?),
            None => None,
        };
        let op = self.log.append(AppendRequest {
            capability: req.capability,
            kind: req.kind,
            payload: req.payload,
            recorded_at_ms: req.recorded_at_ms,
            entity_id: req.entity_id,
            parent_operation_id: req.parent_operation_id,
            context_ids: req.context_ids,
            schema_id: req.schema_id,
            content_id,
        })?;
        // `C6`: "metrics -- one place that knows operations/sec."
        self.supervisor.record_op(REPLAY_ENGINE);
        Ok(op)
    }

    /// Replays the entire durable log, in write order, in one pass.
    pub fn replay(&self) -> Result<Vec<Operation>, RuntimeApiError> {
        Ok(self.log.replay()?)
    }

    /// Rebuilds a projection from a fresh replay. Never from cached state —
    /// `C4`: *"a projection may be deleted at any time and rebuilt from the
    /// log with zero data loss."*
    pub fn query_projection<P: Projection>(&self) -> Result<P, RuntimeApiError> {
        let ops = self.replay()?;
        Ok(P::rebuild(&ops))
    }

    /// Stores `bytes` in the content store, content-addressed. `#1194`'s
    /// scope: *"content-addressed encrypted content store"* (encrypted is
    /// Phase 1's Vault — see [`crate::content`]'s module doc for the gap this
    /// leaves today). This does **not** append an operation; a capability
    /// that wants the attachment reachable from the log emits `CreateContent`
    /// via [`Self::emit_verb_operation`] with `content: Some(bytes)`, which
    /// calls this internally and links the resulting id into the header —
    /// this method alone is for a capability that needs a `ContentId` before
    /// it knows what operation will reference it.
    pub fn attach_content(&self, bytes: &[u8]) -> Result<ContentId, RuntimeApiError> {
        Ok(self.content.put(bytes)?)
    }

    /// Reads content back by id.
    pub fn read_content(&self, id: &ContentId) -> Result<Option<Vec<u8>>, RuntimeApiError> {
        Ok(self.content.get(id)?)
    }

    /// Condition 8 of `#1311` (`#1217`): *"`DestroyContent` removes every
    /// reachable representation of user content, except immutable structural
    /// metadata intentionally retained by design."*
    ///
    /// # Why this cannot be `emit_verb_operation(Verb::DestroyContent, ...)`
    ///
    /// `C5`'s governing question: *"can it be implemented entirely by
    /// emitting operations and consuming projections? If no, either the
    /// runtime is missing a generic primitive that should be added once for
    /// everyone, or the capability is bypassing the runtime."* An append-only
    /// operation log cannot make its own past payload bytes disappear by
    /// appending a new operation — the physical erasure this condition
    /// requires happens in [`ContentStore`], which no operation, by itself,
    /// touches. This method is that missing generic primitive: the one seam
    /// that reaches both the content store and the log in one durability
    /// boundary, so no capability needs (or is able) to reach the content
    /// store directly to get real destruction.
    ///
    /// # What actually happens, in order, and why the order is load-bearing
    ///
    /// 1. **The bytes are physically erased first**
    ///    ([`ContentStore::remove`]'s secure overwrite-then-unlink — see its
    ///    doc). Before anything durable records that this happened.
    /// 2. **Only then** is a `DestroyContent` operation appended, carrying
    ///    `content_id` (already-public content-addressed metadata — the hash
    ///    of bytes that no longer exist proves nothing about them, which is
    ///    exactly the "immutable structural metadata intentionally retained"
    ///    this condition's own carve-out names) but **no payload**: nothing
    ///    about the destroyed bytes is copied into the log by the act of
    ///    destroying them.
    ///
    ///    Reversing this order would mean a crash between the two steps could
    ///    leave a log that *claims* content is destroyed while the bytes are
    ///    still fully readable on disk — a false guarantee is worse than a
    ///    missing one. This order's failure mode is the opposite and
    ///    safe-by-default: a crash after step 1 but before step 2 leaves the
    ///    bytes gone and the log not yet reflecting it, which a caller can
    ///    safely retry (removing already-absent bytes is idempotent).
    ///
    /// # What this does not (yet) do
    ///
    /// `#1217`'s eight steps assume Phase 1's Vault (crypto-shredding a
    /// content key, `RevokeContentKey` on a revocation ledger) and Phase 3's
    /// derived-state sweep (embeddings, search index, AI caches) — neither
    /// exists in this crate yet (see [`crate::content`]'s and this module's
    /// own "still explicitly deferred" notes). What this method provides
    /// instead, conservatively, for what *does* exist here: the content
    /// store's bytes are genuinely gone from disk (not merely logically
    /// deleted), and [`crate::projection::ContentLedgerProjection`] — the one
    /// derived-state projection this phase's substrate has — reflects the
    /// destruction on every rebuild.
    pub fn destroy_content(
        &self,
        capability: &str,
        content_id: ContentId,
        entity_id: &str,
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        // Step 1: physically unrecoverable first (idempotent if already
        // gone — see `ContentStore::remove`'s doc).
        self.content.remove(&content_id)?;

        // Step 2: the tombstone. No payload, no bytes -- only the id of what
        // was destroyed, which is exactly the structural metadata condition
        // 8's carve-out names.
        let op = self.log.append(AppendRequest {
            capability,
            kind: Verb::DestroyContent.as_str(),
            payload: &[],
            recorded_at_ms,
            entity_id,
            parent_operation_id: None,
            context_ids: &[],
            schema_id: "",
            content_id: Some(content_id),
        })?;
        self.supervisor.record_op(REPLAY_ENGINE);
        Ok(op)
    }

    /// Out of scope for this phase. Contexts are Phase 5.
    pub fn instantiate_context(&self) -> Result<(), RuntimeApiError> {
        Err(RuntimeApiError::OutOfScope("instantiate_context"))
    }

    /// Creates a context node — design §5.8: *"contexts belong to the user,
    /// not the capability."* `context_id` is this operation's `entity_id`,
    /// the same overload [`Verb::CreateEntity`] already uses for "the node
    /// this operation is primarily about" — there is no separate context-id
    /// field in the wire format, so a context and an entity share the one
    /// the header already has. `label` is the context's small, inline
    /// display name (a hospitalization's title, a project's name), the same
    /// "small inline argument" shape [`Self::emit_verb_operation`]'s
    /// `payload` already carries for `CreateEntity`.
    ///
    /// Not routed through [`crate::capability_api::CapabilityApi::instantiate_context`]
    /// — that surface is still stubbed pending `#1197`'s context-template
    /// work (a capability shipping a *named template* to instantiate). This
    /// is the lower-level primitive a template's implementation would call:
    /// one bare context node, no template resolution attached.
    pub fn create_context(
        &self,
        capability: &str,
        context_id: &str,
        label: &[u8],
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        let op = self.log.append(AppendRequest {
            capability,
            kind: Verb::CreateContext.as_str(),
            payload: label,
            recorded_at_ms,
            entity_id: context_id,
            parent_operation_id: None,
            context_ids: &[],
            schema_id: "",
            content_id: None,
        })?;
        self.supervisor.record_op(REPLAY_ENGINE);
        Ok(op)
    }

    /// Links already-stored content into one or more contexts — one
    /// hyperedge per context named, design §4.1: *"content links to many
    /// contexts and is owned by none."* `content_id` must already exist
    /// (from a prior `CreateContent` or [`Self::attach_content`]); this
    /// stores no new bytes, only records which contexts now hold this
    /// content — see [`crate::projection::ContextHypergraphProjection`] for
    /// where that fact is read back.
    ///
    /// Modeled at the log/projection level, not as real per-context key
    /// wrappings: `#1209`'s envelope encryption has not landed in this crate
    /// yet (see [`crate::content`]'s module doc for the same gap already
    /// documented for the content store itself). The shape here does not
    /// change when `#1209` lands — `LinkContent` already carries exactly the
    /// `(content_id, context_ids[])` pair real wrapping needs; the fold in
    /// [`crate::projection::ContextHypergraphProjection`] would move from
    /// modeling membership to modeling actual `wrap(CK, ContextKey)` calls
    /// underneath the same operation shape.
    pub fn link_content(
        &self,
        capability: &str,
        content_id: ContentId,
        entity_id: &str,
        context_ids: &[&str],
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        let op = self.log.append(AppendRequest {
            capability,
            kind: Verb::LinkContent.as_str(),
            payload: &[],
            recorded_at_ms,
            entity_id,
            parent_operation_id: None,
            context_ids,
            schema_id: "",
            content_id: Some(content_id),
        })?;
        self.supervisor.record_op(REPLAY_ENGINE);
        Ok(op)
    }

    /// Removes one or more context wrappings from already-stored content —
    /// design §3.2: *"`UnlinkContent` removes one context link"*, distinct
    /// from [`Self::destroy_content`], which removes every wrapping and is
    /// irreversible. The UI must never conflate the two; this method alone
    /// never touches the content store or crypto-shreds anything.
    ///
    /// Does not compute what survives — call
    /// [`crate::projection::ContextHypergraphProjection::survival_if_unlinked`]
    /// against a fresh [`Self::query_projection`] first if the caller needs
    /// that answer before committing to this call (the confirmation-dialog
    /// use case design §4.1 names).
    pub fn unlink_content(
        &self,
        capability: &str,
        content_id: ContentId,
        entity_id: &str,
        context_ids: &[&str],
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        let op = self.log.append(AppendRequest {
            capability,
            kind: Verb::UnlinkContent.as_str(),
            payload: &[],
            recorded_at_ms,
            entity_id,
            parent_operation_id: None,
            context_ids,
            schema_id: "",
            content_id: Some(content_id),
        })?;
        self.supervisor.record_op(REPLAY_ENGINE);
        Ok(op)
    }

    /// Links two or more contexts to each other — design §5.8's
    /// restructuring graph (*"merging two journeys, re-filing a decade of
    /// documents... only links change"*), distinct from
    /// [`Self::link_content`]'s content-to-context hyperedges. Recorded
    /// symmetrically in [`crate::projection::ContextHypergraphProjection`]:
    /// `from_context_id` and each of `to_context_ids` become mutually
    /// linked, so a caller does not need to know which side "owns" the
    /// edge to read it back.
    pub fn link_context(
        &self,
        capability: &str,
        from_context_id: &str,
        to_context_ids: &[&str],
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        let op = self.log.append(AppendRequest {
            capability,
            kind: Verb::LinkContext.as_str(),
            payload: &[],
            recorded_at_ms,
            entity_id: from_context_id,
            parent_operation_id: None,
            context_ids: to_context_ids,
            schema_id: "",
            content_id: None,
        })?;
        self.supervisor.record_op(REPLAY_ENGINE);
        Ok(op)
    }

    /// Removes a [`Self::link_context`] edge. Restructuring, not
    /// destruction — no context and no content is deleted by this call, only
    /// the structural edge between two contexts.
    pub fn unlink_context(
        &self,
        capability: &str,
        from_context_id: &str,
        to_context_ids: &[&str],
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        let op = self.log.append(AppendRequest {
            capability,
            kind: Verb::UnlinkContext.as_str(),
            payload: &[],
            recorded_at_ms,
            entity_id: from_context_id,
            parent_operation_id: None,
            context_ids: to_context_ids,
            schema_id: "",
            content_id: None,
        })?;
        self.supervisor.record_op(REPLAY_ENGINE);
        Ok(op)
    }

    /// Registers a new listener on the in-process event bus. Not part of
    /// `#1295`'s five-function capability surface (that surface only exposes
    /// the write side, `emit_event`, via
    /// [`crate::capability_api::CapabilityApi`]) — this is the runtime-level
    /// read side something outside a capability (a UI layer, a test) uses to
    /// observe what capabilities publish. See [`crate::event`]'s module doc
    /// for exactly what this does and does not guarantee.
    pub fn subscribe_events(&self) -> std::sync::mpsc::Receiver<CapabilityEvent> {
        self.event_bus.subscribe()
    }

    /// Publishes one event to every live subscriber. `pub(crate)`, not
    /// `pub`: the only intended caller is
    /// [`crate::capability_api::CapabilityApi::emit_event`] — a capability
    /// reaches this exclusively through that narrower surface, never
    /// [`Runtime`] directly.
    pub(crate) fn publish_event(&self, event: CapabilityEvent) {
        self.event_bus.publish(event);
    }

    /// Out of scope for this phase. Both `#1194` and `#1195` name Sync as
    /// blocked-on / explicitly excluded.
    pub fn sync(&self) -> Result<(), RuntimeApiError> {
        Err(RuntimeApiError::OutOfScope("sync"))
    }

    /// Re-verifies one operation against this runtime's signer, **and**
    /// that `payload_hash` still matches `payload` — the signature alone
    /// only covers the header (`payload_hash` is what the header commits to,
    /// per §3.1; the raw payload bytes are not themselves signed), so a
    /// payload tampered without updating its hash would pass a
    /// signature-only check while still being wrong. Not the normal replay
    /// path (`C2` forbids re-verifying below the watermark) — the seam a
    /// conformance test uses to prove a tampered operation is detectable at
    /// all.
    pub fn verify_operation(&self, op: &Operation) -> bool {
        sha256_hex(&op.payload) == op.payload_hash && self.log_verify(op)
    }

    fn log_verify(&self, op: &Operation) -> bool {
        self.log
            .signer
            .verify(&op.canonical_header(), &op.signature)
    }

    /// Stops every engine in reverse dependency order and seals the
    /// Supervisor's shutdown buffer. `C6`: graceful shutdown.
    pub fn shutdown(&self) {
        self.supervisor.shutdown();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::budget::ResourceBudget;

    fn temp_log_path(name: &str) -> PathBuf {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("airo_mind_runtime_test_{name}_{unique}.log"))
    }

    fn cleanup(path: &Path) {
        let _ = std::fs::remove_file(path);
        let _ = std::fs::remove_file(device_id_path(path));
        let _ = std::fs::remove_dir_all(content_dir_for(path));
    }

    #[test]
    fn boots_with_only_the_supervisor_and_its_three_lifecycle_engines() {
        let path = temp_log_path("boot");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        assert_eq!(
            runtime.engine_health(),
            vec![
                (VAULT_ENGINE, crate::lifecycle::EngineState::Running),
                (REPLAY_ENGINE, crate::lifecycle::EngineState::Running),
                (PROJECTION_ENGINE, crate::lifecycle::EngineState::Running),
            ]
        );
        cleanup(&path);
    }

    #[test]
    fn vault_starts_before_replay_before_projection() {
        let path = temp_log_path("order");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        for (name, state) in runtime.engine_health() {
            assert_eq!(
                state,
                crate::lifecycle::EngineState::Running,
                "{name} did not reach Running"
            );
        }
        cleanup(&path);
    }

    #[test]
    fn emit_operation_persists_and_replay_returns_it_in_order() {
        let path = temp_log_path("persist");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        runtime
            .emit_operation("notes", "note.create", b"first", 1000)
            .unwrap();
        runtime
            .emit_operation("notes", "note.create", b"second", 2000)
            .unwrap();

        let replayed = runtime.replay().unwrap();
        assert_eq!(replayed.len(), 2);
        assert_eq!(replayed[0].seq, 0);
        assert_eq!(replayed[0].payload, b"first");
        assert_eq!(replayed[1].seq, 1);
        assert_eq!(replayed[1].payload, b"second");

        cleanup(&path);
    }

    #[test]
    fn reopening_the_log_resumes_sequence_numbering() {
        let path = temp_log_path("resume");
        {
            let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
            runtime
                .emit_operation("notes", "note.create", b"a", 1)
                .unwrap();
            runtime
                .emit_operation("notes", "note.create", b"b", 2)
                .unwrap();
            runtime.shutdown();
        }
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let third = runtime
            .emit_operation("notes", "note.create", b"c", 3)
            .unwrap();
        assert_eq!(third.seq, 2, "sequence numbering must survive a restart");

        cleanup(&path);
    }

    /// `#1194`: `device_id` must also survive a restart, or `version_vector`
    /// means nothing across sessions.
    #[test]
    fn reopening_the_log_keeps_the_same_device_id() {
        let path = temp_log_path("device_id_stable");
        let first_id = {
            let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
            runtime.device_id().to_string()
        };
        let second_id = {
            let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
            runtime.device_id().to_string()
        };
        assert_eq!(first_id, second_id);
        cleanup(&path);
    }

    #[test]
    fn instantiate_context_and_sync_are_explicitly_out_of_scope() {
        let path = temp_log_path("out_of_scope");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        assert!(matches!(
            runtime.instantiate_context(),
            Err(RuntimeApiError::OutOfScope("instantiate_context"))
        ));
        assert!(matches!(
            runtime.sync(),
            Err(RuntimeApiError::OutOfScope("sync"))
        ));
        cleanup(&path);
    }

    /// `#1194`: `attach_content` is implemented, not declared out-of-scope,
    /// as of this formalization.
    #[test]
    fn attach_content_round_trips_through_read_content() {
        let path = temp_log_path("attach_content");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let id = runtime.attach_content(b"a real content object").unwrap();
        assert_eq!(
            runtime.read_content(&id).unwrap().unwrap(),
            b"a real content object"
        );
        cleanup(&path);
    }

    /// `#1194` scope: *"payload behind `ContentID`, never inlined"* for the
    /// Content primitive. Emitting `CreateContent` with `content: Some(..)`
    /// stores the bytes in the content store and the operation carries only
    /// the resulting id.
    #[test]
    fn create_content_stores_bytes_out_of_line_and_links_the_content_id() {
        let path = temp_log_path("create_content");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        let op = runtime
            .emit_verb_operation(
                "notes",
                Verb::CreateContent,
                "content-1",
                &[],
                "",
                b"",
                Some(b"the actual bytes"),
                1,
            )
            .unwrap();

        assert!(op.payload.is_empty(), "payload stays inline-empty");
        let content_id = op
            .content_id
            .expect("CreateContent must attach a content id");
        assert_eq!(
            runtime.read_content(&content_id).unwrap().unwrap(),
            b"the actual bytes"
        );
        cleanup(&path);
    }

    #[test]
    fn every_operation_header_field_is_populated() {
        let path = temp_log_path("full_header");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let op = runtime
            .emit_verb_operation(
                "notes",
                Verb::CreateEntity,
                "n1",
                &["ctx-a", "ctx-b"],
                "schema-1",
                b"payload",
                None,
                42,
            )
            .unwrap();

        assert!(!op.operation_id.is_empty());
        assert_eq!(op.parent_operation_id, None);
        assert_eq!(op.entity_id, "n1");
        assert_eq!(
            op.context_ids,
            vec!["ctx-a".to_string(), "ctx-b".to_string()]
        );
        assert_eq!(op.schema_id, "schema-1");
        assert_eq!(op.capability, "notes");
        assert_eq!(op.kind, "CreateEntity");
        assert_eq!(op.verb(), Some(Verb::CreateEntity));
        assert_eq!(op.device_id, runtime.device_id());
        assert_eq!(op.recorded_at_ms, 42);
        assert_eq!(op.version_vector.get(runtime.device_id()), Some(&1));
        assert_eq!(op.payload_hash, sha256_hex(b"payload"));
        assert!(!op.signature.is_empty());
        assert!(runtime.verify_operation(&op));

        cleanup(&path);
    }

    /// `#1194`: a tampered operation must fail verification. Proven against
    /// the log's own re-verifying replay, not only the `Signer` unit tests.
    #[test]
    fn a_tampered_operation_fails_verification() {
        let path = temp_log_path("tamper");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let op = runtime
            .emit_operation("notes", "note.create", b"original", 1)
            .unwrap();
        assert!(runtime.verify_operation(&op));

        let mut tampered = op.clone();
        tampered.payload = b"forged".to_vec();
        assert!(
            !runtime.verify_operation(&tampered),
            "changing the payload must invalidate the signature"
        );

        let mut tampered_entity = op.clone();
        tampered_entity.entity_id = "someone-elses-entity".to_string();
        assert!(!runtime.verify_operation(&tampered_entity));

        cleanup(&path);
    }

    /// `#1194`'s concurrent-writer-safety requirement: `seq` assignment and
    /// the byte write it labels are one atomic step, so N threads appending
    /// concurrently produce a contiguous, gap-free, non-corrupt log.
    #[test]
    fn concurrent_appends_from_multiple_threads_produce_a_gap_free_uncorrupted_log() {
        let path = temp_log_path("concurrent");
        let runtime = Arc::new(Runtime::boot(ResourceBudget::new(2048), &path).unwrap());

        const THREADS: usize = 8;
        const PER_THREAD: usize = 25;
        let mut handles = Vec::new();
        for t in 0..THREADS {
            let runtime = runtime.clone();
            handles.push(std::thread::spawn(move || {
                for i in 0..PER_THREAD {
                    runtime
                        .emit_operation(
                            "notes",
                            "note.create",
                            format!("t{t}-{i}").as_bytes(),
                            (t * PER_THREAD + i) as u64,
                        )
                        .unwrap();
                }
            }));
        }
        for h in handles {
            h.join().unwrap();
        }

        let ops = runtime.replay().unwrap();
        assert_eq!(ops.len(), THREADS * PER_THREAD);

        let mut seqs: Vec<u64> = ops.iter().map(|op| op.seq).collect();
        seqs.sort_unstable();
        let expected: Vec<u64> = (0..(THREADS * PER_THREAD) as u64).collect();
        assert_eq!(seqs, expected, "seq must be contiguous and gap-free");

        // Every record decoded cleanly (no interleaved/corrupt bytes) and
        // every signature verifies -- a corrupted interleave would produce
        // either a decode failure (already ruled out by the length check
        // above) or a header that no longer matches its signature.
        assert!(runtime.log.replay_reverifying().is_ok());

        cleanup(&path);
    }

    #[test]
    fn empty_log_replays_to_nothing() {
        let path = temp_log_path("empty");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        assert!(runtime.replay().unwrap().is_empty());
        cleanup(&path);
    }

    #[test]
    fn a_torn_tail_is_treated_as_the_end_of_the_durable_log() {
        let path = temp_log_path("torn");
        {
            let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
            runtime
                .emit_operation("notes", "note.create", b"whole", 1)
                .unwrap();
        }
        {
            let mut file = OpenOptions::new().append(true).open(&path).unwrap();
            file.write_all(&[1, 2, 3]).unwrap();
        }
        let recovered = OperationLog::open(&path).unwrap().replay().unwrap();
        assert_eq!(recovered.len(), 1);
        assert_eq!(recovered[0].payload, b"whole");

        cleanup(&path);
    }

    #[test]
    fn an_unsupported_format_version_is_refused_rather_than_misparsed() {
        let path = temp_log_path("bad_version");
        std::fs::write(&path, [99u8]).unwrap();
        let err = match OperationLog::open(&path) {
            Ok(_) => panic!("expected an unsupported-version error"),
            Err(e) => e,
        };
        assert!(matches!(err, OperationLogError::UnsupportedVersion(99)));
        cleanup(&path);
    }
}

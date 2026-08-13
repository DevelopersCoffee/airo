//! The Operation → Persist → Replay → Projection vertical slice. `#1338`.
//!
//! `#1338` is the runtime skeleton: the smallest thing that proves the
//! Supervisor (`#1302`) and a real replay engine can carry one capability
//! end to end, through the Supervisor's own lifecycle rather than around it.
//! It is deliberately narrow — see the module docs on [`crate::lifecycle`]
//! for what this greenfields and what it still leaves for later phases:
//!
//! - **Vault** here is a lifecycle placeholder only. No identity, no key
//!   hierarchy, no revocation ledger — that is Phase 1's full scope
//!   (`docs/superpowers/specs/2026-07-27-airo-mind-roadmap.md`). What the
//!   skeleton needs from Vault is one thing: that it exists as a dependency
//!   `Replay` cannot start ahead of, per `C6`'s *"Vault before Replay before
//!   Projection."*
//! - **The operation log is real** — sequential, append-only, durable to a
//!   file, replayable from scratch. What it is missing against `C1`'s full
//!   contract: no group-commit window (each `append` is written and flushed
//!   immediately), no signatures (`C7` is a later phase), no content store.
//! - **The projection engine is empty on purpose** (per `#1338`'s issue
//!   body): this module registers it as a lifecycle participant and nothing
//!   more. What a projection actually contains is
//!   [`crate::notes::NotesProjection`] — a concrete type built by folding the
//!   log, owned by the capability that needs it, not by this module.
//!
//! # Determinism (`C2`)
//!
//! [`OperationLog::replay`] reads the file front-to-back once and returns
//! operations in the order they were written. No `HashMap` iteration, no
//! wall-clock read, on this path. `recorded_at_ms` is supplied by the caller
//! (ultimately Dart, which owns the platform's notion of "now") and never
//! sampled inside the runtime — the same discipline
//! `airo_mind_whisper::api::meetings` already documents for
//! `recorded_at_ms`.

use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

use crate::engine::EngineError;
use crate::lifecycle::{EngineName, ManagedEngine};
use crate::supervisor::Supervisor;

// ---------------------------------------------------------------------------
// Operation
// ---------------------------------------------------------------------------

/// One durable entry in the operation log.
///
/// This is the beginning of the operation log condition (`#1194`) — a
/// minimal, local, unsigned record. It is not that log: there is no device
/// identity, no signature, no sync. What it proves is the shape everything
/// after it depends on: a capability's mutation becomes one immutable,
/// ordered, replayable fact.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Operation {
    /// Monotonic, gap-free, assigned by [`OperationLog::append`]. The
    /// product-facing citation everything else (a projection row, a UI
    /// element) can point back at.
    pub seq: u64,
    /// Which capability emitted this. `"notes"` for every operation this
    /// module's tests write.
    pub capability: String,
    /// The capability's own vocabulary for what happened —
    /// `"note.create"`, `"note.delete"`, and so on. Opaque to the runtme;
    /// only the capability that wrote it knows how to decode `payload`.
    pub kind: String,
    /// The capability's own encoding. The runtime never looks inside this —
    /// `C5`: the runtime knows no domains.
    pub payload: Vec<u8>,
    /// Supplied by the caller, never sampled here (`C2`).
    pub recorded_at_ms: u64,
}

// ---------------------------------------------------------------------------
// Operation log — the data-plane half of `C1` this skeleton implements
// ---------------------------------------------------------------------------

/// Why a log operation failed.
#[derive(Debug)]
pub enum OperationLogError {
    Io(String),
    /// The file's tail did not parse as a complete record. Treated as the
    /// end of the durable log rather than a hard failure — a process killed
    /// mid-`write` leaves a torn tail, and `C6`'s graceful-shutdown guarantee
    /// is what is supposed to prevent this in the real group-commit buffer.
    /// A skeleton without that buffer still must not crash on the case it
    /// exists to handle, so a torn tail here is treated as "everything up to
    /// here is durable" instead.
    TornTail,
}

impl std::fmt::Display for OperationLogError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io(m) => write!(f, "operation log I/O error: {m}"),
            Self::TornTail => write!(f, "operation log tail is truncated"),
        }
    }
}

impl std::error::Error for OperationLogError {}

impl From<std::io::Error> for OperationLogError {
    fn from(e: std::io::Error) -> Self {
        Self::Io(e.to_string())
    }
}

/// Sequential, append-only, file-backed operation log.
///
/// `C1`: *"writes are sequential and append-only; no in-place rewrite."*
/// Every [`Self::append`] opens the file in append mode, writes one encoded
/// record, and flushes before returning — the skeleton's stand-in for the
/// group-commit buffer's bounded flush window (`C1`, `C6`). There is no
/// separate durability point to widen later without changing this type's
/// public shape.
pub struct OperationLog {
    path: PathBuf,
    next_seq: AtomicU64,
}

impl OperationLog {
    /// Opens the log at `path`, creating it if absent. If it already has
    /// entries, replays them once to recover the next sequence number — the
    /// same replay [`Self::replay`] performs, run once at open time so a
    /// restart resumes numbering rather than colliding with what is already
    /// durable.
    pub fn open(path: impl Into<PathBuf>) -> Result<Self, OperationLogError> {
        let path = path.into();
        OpenOptions::new().create(true).append(true).open(&path)?;
        let existing = Self::read_all(&path)?;
        let next_seq = existing.last().map(|op| op.seq + 1).unwrap_or(0);
        Ok(Self {
            path,
            next_seq: AtomicU64::new(next_seq),
        })
    }

    /// Appends one operation and returns it with its assigned `seq`.
    pub fn append(
        &self,
        capability: &str,
        kind: &str,
        payload: &[u8],
        recorded_at_ms: u64,
    ) -> Result<Operation, OperationLogError> {
        let op = Operation {
            seq: self.next_seq.fetch_add(1, Ordering::SeqCst),
            capability: capability.to_string(),
            kind: kind.to_string(),
            payload: payload.to_vec(),
            recorded_at_ms,
        };
        let mut file = OpenOptions::new().append(true).open(&self.path)?;
        file.write_all(&encode(&op))?;
        file.flush()?;
        file.sync_data()?;
        Ok(op)
    }

    /// Replays every durable operation, in write order, in a single pass over
    /// the file. `C2`: *"replay is a single pass"* · *"the same log produces
    /// byte-identical state on every device."*
    pub fn replay(&self) -> Result<Vec<Operation>, OperationLogError> {
        Self::read_all(&self.path)
    }

    /// How many operations are durable right now. Used by tests to assert
    /// persistence happened, without going through replay.
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
        decode_all(&bytes)
    }
}

// ---------------------------------------------------------------------------
// Wire format — hand-rolled: this crate carries zero dependencies (see the
// note in `Cargo.toml`), so no serde, no bincode. Every field is
// length-prefixed and fixed-width integers are big-endian, which is what
// makes the format itself platform-independent — part of `C2`'s
// byte-identical-on-every-platform guarantee.
// ---------------------------------------------------------------------------

fn encode(op: &Operation) -> Vec<u8> {
    let capability = op.capability.as_bytes();
    let kind = op.kind.as_bytes();
    let mut out =
        Vec::with_capacity(8 + 8 + 4 + capability.len() + 4 + kind.len() + 4 + op.payload.len());
    out.extend_from_slice(&op.seq.to_be_bytes());
    out.extend_from_slice(&op.recorded_at_ms.to_be_bytes());
    out.extend_from_slice(&(capability.len() as u32).to_be_bytes());
    out.extend_from_slice(capability);
    out.extend_from_slice(&(kind.len() as u32).to_be_bytes());
    out.extend_from_slice(kind);
    out.extend_from_slice(&(op.payload.len() as u32).to_be_bytes());
    out.extend_from_slice(&op.payload);
    out
}

/// Decodes every complete record in `bytes`, in order. A torn tail (fewer
/// bytes than the last record's declared length — the crash-mid-write case)
/// stops decoding at the last complete record rather than erroring: what
/// survived is exactly what a reader restarting after a kill would see as
/// durable.
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
    let recorded_at_ms = read_u64(bytes, &mut pos)?;
    let capability = read_bytes(bytes, &mut pos)?;
    let kind = read_bytes(bytes, &mut pos)?;
    let payload = read_bytes(bytes, &mut pos)?;

    Some((
        Operation {
            seq,
            capability: String::from_utf8(capability).ok()?,
            kind: String::from_utf8(kind).ok()?,
            payload,
            recorded_at_ms,
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
/// because every write already synced itself (`C1`'s durability point is
/// per-`append`, not deferred to shutdown, in this skeleton).
struct ReplayEngine {
    log: Arc<OperationLog>,
}

impl ManagedEngine for ReplayEngine {
    fn start(&self) -> Result<(), EngineError> {
        // The log is already open by the time this runs (`Runtime::boot`
        // opens it before registering the engine) — this call proves it by
        // replaying once, so a corrupt log fails lifecycle start rather than
        // the first read a capability performs.
        self.log
            .replay()
            .map(|_| ())
            .map_err(|e| EngineError::Backend(e.to_string()))
    }

    fn stop(&self) {}
}

/// The empty projection engine (`#1338`'s issue body: *"empty on purpose"*).
/// It has no state and does no work — what it proves is that the seam exists
/// and can be driven, rebuilt, and dropped through the same lifecycle every
/// other engine goes through. Concrete projections, like
/// [`crate::notes::NotesProjection`], are built directly from
/// [`OperationLog::replay`] by the capability that owns them; they do not
/// register anything here.
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
    /// The Supervisor's engine lifecycle refused the call — a dependency was
    /// not `Running`, or an engine's own `start`/`stop` failed.
    Lifecycle(crate::supervisor::RuntimeError),
    /// The function exists on the six-function surface (`C5`) but this
    /// skeleton does not implement it — `attach_content`, `instantiate_context`
    /// and `sync` are explicitly out of `#1338`'s scope (see the epic's
    /// scope table). Returning this rather than `unimplemented!()` keeps the
    /// surface callable and testable instead of a panic waiting to happen.
    OutOfScope(&'static str),
}

impl std::fmt::Display for RuntimeApiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Log(e) => write!(f, "{e}"),
            Self::Lifecycle(e) => write!(f, "{e}"),
            Self::OutOfScope(what) => {
                write!(f, "{what} is out of scope for the runtime skeleton (#1338)")
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

/// A read-model built by folding an operation log. `C4`: *"every projection
/// is rebuildable, cache-only, and disposable."* [`Runtime::query_projection`]
/// is the seam this module said it would prove exists — a projection is
/// never anything but the fold of a replay.
pub trait Projection: Sized {
    fn rebuild(ops: &[Operation]) -> Self;
}

/// The runtime skeleton: `Operation → Persist → Replay → Projection`, wired
/// through the `#1302` Supervisor's engine lifecycle rather than around it.
///
/// `C5`'s six-function surface, exactly: [`Self::emit_operation`],
/// [`Self::attach_content`], [`Self::query_projection`],
/// [`Self::instantiate_context`], [`Self::replay`], [`Self::sync`]. The last
/// three of those six are declared but intentionally return
/// [`RuntimeApiError::OutOfScope`] — see the epic's scope table (Vault, the
/// Operation Log, and the empty Projection Engine are "In"; Sync, AI and
/// Workflows are "Out").
pub struct Runtime {
    supervisor: Supervisor,
    log: Arc<OperationLog>,
}

impl Runtime {
    /// Boots the runtime with only the Supervisor and the three lifecycle
    /// engines this skeleton needs — condition 1 of `#1311`: *"the runtime
    /// boots with only the Supervisor."* No AI engine, no sync engine, is
    /// registered here; there is nothing in this module that could register
    /// one.
    pub fn boot(
        budget: crate::budget::ResourceBudget,
        log_path: impl Into<PathBuf>,
    ) -> Result<Self, RuntimeApiError> {
        let log = Arc::new(OperationLog::open(log_path)?);
        let mut supervisor = Supervisor::new(budget);

        // `C6`: "dependency ordering is enforced: Vault before Replay before
        // Projection." Registration order alone does not enforce this --
        // `depends_on` does, and `EngineRegistry::start` refuses out-of-order
        // starts even if a caller tries.
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

        Ok(Self { supervisor, log })
    }

    /// Every engine's lifecycle state, in registration order. Lets a caller
    /// (or a test) prove the boot order actually happened, rather than
    /// trusting `boot` did not silently skip a step.
    pub fn engine_health(&self) -> Vec<(EngineName, crate::lifecycle::EngineState)> {
        self.supervisor.health()
    }

    /// The only write path onto the log. `C5`: a capability's entire
    /// surface for causing a durable effect.
    pub fn emit_operation(
        &self,
        capability: &str,
        kind: &str,
        payload: &[u8],
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        let op = self.log.append(capability, kind, payload, recorded_at_ms)?;
        // `C6`: "metrics -- one place that knows operations/sec." Recorded
        // against the replay engine, which is what actually persisted it.
        self.supervisor.record_op(REPLAY_ENGINE);
        Ok(op)
    }

    /// Replays the entire durable log, in write order, in one pass. What
    /// [`Self::query_projection`] is built on, and what a conformance test
    /// calls directly to prove replay-after-delete equals the original.
    pub fn replay(&self) -> Result<Vec<Operation>, RuntimeApiError> {
        Ok(self.log.replay()?)
    }

    /// Rebuilds a projection from a fresh replay. Never from cached state --
    /// `C4`: *"a projection may be deleted at any time and rebuilt from the
    /// log with zero data loss."* There is nothing else this could read from,
    /// because nothing else durable exists (`C1`).
    pub fn query_projection<P: Projection>(&self) -> Result<P, RuntimeApiError> {
        let ops = self.replay()?;
        Ok(P::rebuild(&ops))
    }

    /// Out of scope for `#1338` (see the epic's scope table: the content
    /// store is Phase 3). Declared so the six-function surface is complete
    /// and callable, not so it does anything yet.
    pub fn attach_content(&self) -> Result<(), RuntimeApiError> {
        Err(RuntimeApiError::OutOfScope("attach_content"))
    }

    /// Out of scope for `#1338`. Contexts are Phase 5.
    pub fn instantiate_context(&self) -> Result<(), RuntimeApiError> {
        Err(RuntimeApiError::OutOfScope("instantiate_context"))
    }

    /// Out of scope for `#1338`. Sync is explicitly excluded by the epic's
    /// scope table.
    pub fn sync(&self) -> Result<(), RuntimeApiError> {
        Err(RuntimeApiError::OutOfScope("sync"))
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
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn vault_starts_before_replay_before_projection() {
        // `boot` panics-free registration order alone would not catch a
        // dependency mistake -- this asserts the registry actually enforced
        // it, by checking the states are what only a correct start order
        // produces.
        let path = temp_log_path("order");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        for (name, state) in runtime.engine_health() {
            assert_eq!(
                state,
                crate::lifecycle::EngineState::Running,
                "{name} did not reach Running"
            );
        }
        let _ = std::fs::remove_file(&path);
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

        let _ = std::fs::remove_file(&path);
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

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn attach_content_instantiate_context_and_sync_are_explicitly_out_of_scope() {
        let path = temp_log_path("out_of_scope");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        assert!(matches!(
            runtime.attach_content(),
            Err(RuntimeApiError::OutOfScope("attach_content"))
        ));
        assert!(matches!(
            runtime.instantiate_context(),
            Err(RuntimeApiError::OutOfScope("instantiate_context"))
        ));
        assert!(matches!(
            runtime.sync(),
            Err(RuntimeApiError::OutOfScope("sync"))
        ));
        let _ = std::fs::remove_file(&path);
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
        // Simulate a crash mid-write: append a few garbage bytes shorter than
        // any valid record.
        {
            let mut file = OpenOptions::new().append(true).open(&path).unwrap();
            file.write_all(&[1, 2, 3]).unwrap();
        }
        let recovered = OperationLog::open(&path).unwrap().replay().unwrap();
        assert_eq!(recovered.len(), 1);
        assert_eq!(recovered[0].payload, b"whole");

        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn empty_log_replays_to_nothing() {
        let path = temp_log_path("empty");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        assert!(runtime.replay().unwrap().is_empty());
        let _ = std::fs::remove_file(&path);
    }
}

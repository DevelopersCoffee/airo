//! The Notes capability. `#1338`'s vertical slice: the one capability that
//! exercises `Operation → Persist → Replay → Projection` end to end.
//!
//! `C5`: a capability emits operations and consumes projections, nothing
//! else. [`NotesCapability`] holds a `&Runtime` and nothing durable of its
//! own (`I2`, `I4`) — every note it creates, edits, or deletes exists only
//! as an [`crate::runtime::Operation`] in [`Runtime`]'s log. Delete the
//! [`NotesProjection`] this module returns and rebuild it from
//! [`Runtime::replay`]; the result is required to be identical, and the
//! conformance test in this module's `tests` proves it, not documents it.

use std::collections::BTreeMap;

use crate::runtime::{Operation, Projection, Runtime, RuntimeApiError};

/// The capability name every Notes operation is tagged with in the log.
pub const NOTES_CAPABILITY: &str = "notes";

const KIND_CREATE: &str = "note.create";
const KIND_EDIT: &str = "note.edit";
const KIND_DELETE: &str = "note.delete";

/// One note mutation, as the capability encodes it into an operation's
/// payload. The runtime never decodes this — `C5`: it knows no domains.
#[derive(Clone, Debug, PartialEq, Eq)]
enum NoteOp {
    Create {
        id: String,
        title: String,
        body: String,
    },
    Edit {
        id: String,
        title: String,
        body: String,
    },
    Delete {
        id: String,
    },
}

impl NoteOp {
    fn kind(&self) -> &'static str {
        match self {
            Self::Create { .. } => KIND_CREATE,
            Self::Edit { .. } => KIND_EDIT,
            Self::Delete { .. } => KIND_DELETE,
        }
    }

    /// Hand-rolled, matching [`crate::runtime`]'s wire-format discipline:
    /// this crate carries zero dependencies, so no serde. `id`/`title`/`body`
    /// are each length-prefixed UTF-8.
    fn encode(&self) -> Vec<u8> {
        match self {
            Self::Create { id, title, body } | Self::Edit { id, title, body } => {
                let mut out = Vec::new();
                push_str(&mut out, id);
                push_str(&mut out, title);
                push_str(&mut out, body);
                out
            }
            Self::Delete { id } => {
                let mut out = Vec::new();
                push_str(&mut out, id);
                out
            }
        }
    }

    fn decode(kind: &str, payload: &[u8]) -> Option<Self> {
        let mut pos = 0usize;
        match kind {
            KIND_CREATE | KIND_EDIT => {
                let id = pop_str(payload, &mut pos)?;
                let title = pop_str(payload, &mut pos)?;
                let body = pop_str(payload, &mut pos)?;
                Some(if kind == KIND_CREATE {
                    Self::Create { id, title, body }
                } else {
                    Self::Edit { id, title, body }
                })
            }
            KIND_DELETE => {
                let id = pop_str(payload, &mut pos)?;
                Some(Self::Delete { id })
            }
            _ => None,
        }
    }
}

fn push_str(out: &mut Vec<u8>, s: &str) {
    let bytes = s.as_bytes();
    out.extend_from_slice(&(bytes.len() as u32).to_be_bytes());
    out.extend_from_slice(bytes);
}

fn pop_str(bytes: &[u8], pos: &mut usize) -> Option<String> {
    let len_bytes: [u8; 4] = bytes.get(*pos..*pos + 4)?.try_into().ok()?;
    let len = u32::from_be_bytes(len_bytes) as usize;
    *pos += 4;
    let s = bytes.get(*pos..*pos + len)?;
    *pos += len;
    String::from_utf8(s.to_vec()).ok()
}

/// One note, as the projection holds it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Note {
    pub id: String,
    pub title: String,
    pub body: String,
    /// The operation's `recorded_at_ms` at the time of the mutation that most
    /// recently touched this note.
    pub updated_at_ms: u64,
}

/// The Notes read-model. `C4`: cache-only, rebuildable, disposable — this is
/// never written to directly, only ever produced by
/// [`Projection::rebuild`] folding the log.
///
/// `BTreeMap`, not `HashMap`: `C2` forbids `HashMap` iteration on a path
/// that must be byte-identical across platforms, and while this type is not
/// itself replayed, `Eq` over it (which the conformance test relies on) must
/// not depend on hash-iteration order either.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct NotesProjection {
    notes: BTreeMap<String, Note>,
}

impl NotesProjection {
    pub fn get(&self, id: &str) -> Option<&Note> {
        self.notes.get(id)
    }

    /// Every note, ordered by id — deterministic, and matching the
    /// determinism the underlying `BTreeMap` already gives for free.
    pub fn all(&self) -> Vec<&Note> {
        self.notes.values().collect()
    }

    pub fn len(&self) -> usize {
        self.notes.len()
    }

    pub fn is_empty(&self) -> bool {
        self.notes.is_empty()
    }
}

impl Projection for NotesProjection {
    /// Folds the log in one pass, in order. `replay_passes == 1`, `C2`: this
    /// is a single `for` loop over `ops`, and `rebuild_counting` (private,
    /// used by the conformance test) proves each operation is visited
    /// exactly once rather than merely asserting the code looks like it
    /// should.
    fn rebuild(ops: &[Operation]) -> Self {
        Self::rebuild_counting(ops).0
    }
}

impl NotesProjection {
    /// Same fold as [`Projection::rebuild`], plus the number of operations
    /// visited. Not part of the public seam — `query_projection::<P>` only
    /// ever calls `rebuild` — but the one way a conformance test can assert
    /// "single pass" as a measured fact rather than an assumption about the
    /// implementation.
    fn rebuild_counting(ops: &[Operation]) -> (Self, usize) {
        let mut notes = BTreeMap::new();
        let mut visits = 0usize;
        for op in ops {
            if op.capability != NOTES_CAPABILITY {
                continue;
            }
            visits += 1;
            let Some(note_op) = NoteOp::decode(&op.kind, &op.payload) else {
                continue;
            };
            match note_op {
                NoteOp::Create { id, title, body } | NoteOp::Edit { id, title, body } => {
                    notes.insert(
                        id.clone(),
                        Note {
                            id,
                            title,
                            body,
                            updated_at_ms: op.recorded_at_ms,
                        },
                    );
                }
                NoteOp::Delete { id } => {
                    notes.remove(&id);
                }
            }
        }
        (Self { notes }, visits)
    }
}

/// The Notes capability. `C5`: passive, holds no durable state of its own —
/// every method here either calls [`Runtime::emit_operation`] or
/// [`Runtime::query_projection`], and nothing else. There is no field on
/// this type besides the runtime reference, which is what makes "the
/// capability holds no durable storage of its own" (`I2`, `I4`) true by
/// construction rather than by convention.
pub struct NotesCapability<'a> {
    runtime: &'a Runtime,
}

impl<'a> NotesCapability<'a> {
    pub fn new(runtime: &'a Runtime) -> Self {
        Self { runtime }
    }

    /// Emits a `note.create` operation. The only way a note comes into
    /// existence — there is no direct write path to [`NotesProjection`].
    pub fn create_note(
        &self,
        id: impl Into<String>,
        title: impl Into<String>,
        body: impl Into<String>,
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        let op = NoteOp::Create {
            id: id.into(),
            title: title.into(),
            body: body.into(),
        };
        self.runtime
            .emit_operation(NOTES_CAPABILITY, op.kind(), &op.encode(), recorded_at_ms)
    }

    pub fn edit_note(
        &self,
        id: impl Into<String>,
        title: impl Into<String>,
        body: impl Into<String>,
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        let op = NoteOp::Edit {
            id: id.into(),
            title: title.into(),
            body: body.into(),
        };
        self.runtime
            .emit_operation(NOTES_CAPABILITY, op.kind(), &op.encode(), recorded_at_ms)
    }

    pub fn delete_note(
        &self,
        id: impl Into<String>,
        recorded_at_ms: u64,
    ) -> Result<Operation, RuntimeApiError> {
        let op = NoteOp::Delete { id: id.into() };
        self.runtime
            .emit_operation(NOTES_CAPABILITY, op.kind(), &op.encode(), recorded_at_ms)
    }

    /// Reads the current projection. Always a fresh fold of the log
    /// (`Runtime::query_projection`) — never a cache this capability keeps
    /// itself, because keeping one would be exactly the durable state `C5`
    /// forbids it from owning.
    pub fn notes(&self) -> Result<NotesProjection, RuntimeApiError> {
        self.runtime.query_projection::<NotesProjection>()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::budget::ResourceBudget;
    use crate::runtime::Runtime;

    fn temp_log_path(name: &str) -> std::path::PathBuf {
        let unique = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("airo_mind_notes_test_{name}_{unique}.log"))
    }

    /// The single most important test in `#1338`: create a note, confirm it
    /// is durable, wipe the in-memory projection, replay the persisted
    /// operations, and confirm the rebuilt projection is identical to what
    /// existed before the wipe. This is `C4`'s "delete and rebuild with zero
    /// data loss" and condition 5 of `#1311`, proven rather than asserted by
    /// comment.
    #[test]
    fn a_note_survives_projection_deletion_and_replay() {
        let path = temp_log_path("survive");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let notes = NotesCapability::new(&runtime);

        notes
            .create_note("n1", "Groceries", "milk, eggs", 1_000)
            .unwrap();
        notes
            .create_note("n2", "Throwaway", "delete me", 2_000)
            .unwrap();
        notes
            .edit_note("n1", "Groceries", "milk, eggs, bread", 3_000)
            .unwrap();
        notes.delete_note("n2", 4_000).unwrap();

        // 1. Confirm persisted: the log itself, independent of any
        //    projection, holds every operation.
        assert_eq!(runtime.replay().unwrap().len(), 4);

        // 2. The projection before the wipe.
        let before = notes.notes().unwrap();
        assert_eq!(before.len(), 1, "n2 was deleted, only n1 should remain");
        let n1_before = before.get("n1").cloned().unwrap();
        assert_eq!(n1_before.title, "Groceries");
        assert_eq!(n1_before.body, "milk, eggs, bread");
        assert!(before.get("n2").is_none());

        // 3. "Wipe" the in-memory projection: `before` goes out of scope
        //    here (nothing retains it), simulating `C4`'s "deleted at any
        //    time." There is no cache anywhere else to fall back on --
        //    `NotesCapability` holds none (`I2`, `I4`).
        drop(before);

        // 4. Replay from persisted operations and rebuild.
        let ops = runtime.replay().unwrap();
        let after = NotesProjection::rebuild(&ops);

        // 5. Zero data loss: identical state.
        let n1_after = after.get("n1").cloned().unwrap();
        assert_eq!(n1_before, n1_after);
        assert_eq!(after.len(), 1);
        assert!(after.get("n2").is_none());

        // Also identical through the capability's own read path, not just
        // the type under test directly.
        let via_capability = notes.notes().unwrap();
        assert_eq!(via_capability, after);

        let _ = std::fs::remove_file(&path);
    }

    /// `C2`: `replay_passes == 1`, asserted rather than documented. Every
    /// Notes operation in the log is visited exactly once while folding —
    /// not zero (a bug that would drop it), not two (a bug that would
    /// double-apply it).
    #[test]
    fn replay_visits_every_notes_operation_exactly_once() {
        let path = temp_log_path("single_pass");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let notes = NotesCapability::new(&runtime);

        for i in 0..25 {
            notes
                .create_note(format!("n{i}"), format!("title {i}"), "body", i)
                .unwrap();
        }

        let ops = runtime.replay().unwrap();
        let (_, visits) = NotesProjection::rebuild_counting(&ops);
        assert_eq!(
            visits,
            ops.len(),
            "every operation in a single-capability log must be visited exactly once per rebuild"
        );

        // Rebuilding twice from the same ops must be idempotent -- another
        // face of `replay_passes == 1`: a second rebuild is a second single
        // pass, not a continuation of the first.
        let first = NotesProjection::rebuild(&ops);
        let second = NotesProjection::rebuild(&ops);
        assert_eq!(first, second);

        let _ = std::fs::remove_file(&path);
    }

    /// `C5` / `I2` / `I4`: the capability holds no durable storage of its
    /// own. Mechanically, not just by convention: its only field is the
    /// runtime reference, so its size is exactly one pointer.
    #[test]
    fn the_capability_holds_nothing_but_a_runtime_reference() {
        assert_eq!(
            std::mem::size_of::<NotesCapability<'_>>(),
            std::mem::size_of::<&Runtime>(),
            "NotesCapability must carry no field besides the runtime reference"
        );
    }

    /// A capability denied all filesystem access still passes its own
    /// suite (`S3`): `NotesCapability` never calls `std::fs` itself --
    /// grep-verified, the same technique `airo_mind_whisper::api::meetings`
    /// uses to keep `ADR-0018 §4` honest.
    #[test]
    fn the_capability_never_touches_the_filesystem_directly() {
        let source = include_str!("notes.rs");
        // The only `std::fs`/file mentions allowed are in this very
        // assertion's string literals and the `#[cfg(test)]` helpers below
        // it, which is why the check runs against everything ABOVE the test
        // module rather than the whole file.
        let production_code = source.split("#[cfg(test)]").next().unwrap();
        assert!(
            !production_code.contains("std::fs"),
            "NotesCapability must reach storage only through Runtime::emit_operation / query_projection"
        );
    }

    #[test]
    fn uninstalling_the_capability_leaves_the_log_untouched() {
        // "Uninstall" has no code path yet at this skeleton stage -- there is
        // no registry to remove a capability from. What is proven here is
        // the property that will make uninstall safe once one exists: the
        // capability itself owns nothing that a real uninstall would need to
        // clean up. Dropping it (`_capability` going out of scope) is a
        // no-op against durable state.
        let path = temp_log_path("uninstall");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        {
            let capability = NotesCapability::new(&runtime);
            capability
                .create_note("n1", "Survives", "uninstall", 1)
                .unwrap();
        }
        // The capability value is gone; the operation is not.
        assert_eq!(runtime.replay().unwrap().len(), 1);
        let notes = NotesCapability::new(&runtime).notes().unwrap();
        assert_eq!(notes.len(), 1);

        let _ = std::fs::remove_file(&path);
    }
}

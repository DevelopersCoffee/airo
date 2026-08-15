//! The projection engine. `#1195` (condition 5: *"every projection can be
//! deleted and rebuilt"*), the other half of `C4` from
//! [`crate::runtime::Projection`].
//!
//! # What `#1338` already proved, and what was missing
//!
//! [`crate::runtime::Runtime::query_projection`] already never caches: every
//! call is a fresh [`crate::runtime::Runtime::replay`] folded through
//! [`crate::runtime::Projection::rebuild`]. `C4`'s *"delete at any time and
//! rebuild with zero data loss"* was true by construction from `#1338`
//! onward — there was never anything to delete in the first place, which is
//! the strongest form of "cache-only" there is.
//!
//! What `#1338` proved this property for was exactly one projection
//! ([`crate::notes::NotesProjection`]) fed by exactly one capability. `#1195`
//! asks the harder question the design doc's own diagram implies: *"the
//! graph is not synchronized... the graph is rebuilt"* — one shared entity
//! graph, folded from operations that many different capabilities emit. This
//! module is that second projection: [`EntityGraphProjection`], built from
//! [`crate::verb::Verb::CreateEntity`] / `SetProperty` / `AddRelation` /
//! `RemoveRelation`, independent of which capability emitted them — proof
//! that `#1195`'s "delete and rebuild" is a property of the **engine**, not
//! an accident of Notes' own shape.
//!
//! # Still explicitly deferred
//!
//! - **Knowledge graph / timeline / full-text search projections** named in
//!   `#1195`'s scope table beyond the generic entity graph this module adds.
//!   [`EntityGraphProjection`] is the substrate a timeline or search index
//!   would fold further; building those specific views is follow-on work,
//!   not a substrate question.
//! - **Snapshotting.** `#1195`'s own "open decision" — cache-only vs.
//!   authoritative snapshots — says to *"decide with measurements from a
//!   realistic log, not in the abstract."* There is no realistic log to
//!   measure yet, so no snapshot cache exists. Every projection here is a
//!   full replay, which trivially satisfies "cache-only" and "zero data
//!   loss" but does not yet address the cold-start-bounded half of the
//!   contract at scale.
//! - **Targeted invalidation.** With no cache, every "invalidation" is
//!   already the whole projection, which is `C4`'s `invalidation: full` —
//!   the correct default, per the contract, until a specific projection
//!   needs `targeted` and the cache to make it meaningful.

use std::collections::{BTreeMap, BTreeSet};

use crate::content::ContentId;
use crate::runtime::{Operation, Projection};
use crate::verb::Verb;

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

fn pop_bytes(bytes: &[u8], pos: &mut usize) -> Option<Vec<u8>> {
    let len_bytes: [u8; 4] = bytes.get(*pos..*pos + 4)?.try_into().ok()?;
    let len = u32::from_be_bytes(len_bytes) as usize;
    *pos += 4;
    let s = bytes.get(*pos..*pos + len)?;
    *pos += len;
    Some(s.to_vec())
}

/// A `SetProperty` operation's payload: one property name and its raw value.
/// Encoded the same length-prefixed way every other wire shape in this crate
/// is — see [`crate::runtime`]'s module doc for why (no serde dependency).
pub fn encode_set_property(name: &str, value: &[u8]) -> Vec<u8> {
    let mut out = Vec::new();
    push_str(&mut out, name);
    out.extend_from_slice(&(value.len() as u32).to_be_bytes());
    out.extend_from_slice(value);
    out
}

fn decode_set_property(payload: &[u8]) -> Option<(String, Vec<u8>)> {
    let mut pos = 0usize;
    let name = pop_str(payload, &mut pos)?;
    let value = pop_bytes(payload, &mut pos)?;
    Some((name, value))
}

/// An `AddRelation`/`RemoveRelation` operation's payload: the relation's name
/// and the target entity id. The **source** entity is the operation's
/// `entity_id` header field, not repeated in the payload.
pub fn encode_relation(relation_name: &str, target_entity_id: &str) -> Vec<u8> {
    let mut out = Vec::new();
    push_str(&mut out, relation_name);
    push_str(&mut out, target_entity_id);
    out
}

fn decode_relation(payload: &[u8]) -> Option<(String, String)> {
    let mut pos = 0usize;
    let relation_name = pop_str(payload, &mut pos)?;
    let target = pop_str(payload, &mut pos)?;
    Some((relation_name, target))
}

/// One entity's fold state: its label (from `CreateEntity`'s payload, when
/// non-empty), its properties, and its outgoing relations.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct EntityRecord {
    pub label: String,
    /// `BTreeMap`, not `HashMap`: `C2` forbids hash-iteration order on any
    /// path whose equality a conformance test relies on.
    pub properties: BTreeMap<String, Vec<u8>>,
    /// `(relation_name, target_entity_id)`. A `BTreeSet` so `AddRelation`
    /// twice with the same pair is idempotent by construction — matching
    /// the `reference` primitive's `union` default merge (design §5.3).
    pub relations: BTreeSet<(String, String)>,
}

/// The shared entity graph. `C4` / design §3: *"the graph is rebuilt"* — this
/// is that graph, folded from every capability's `CreateEntity` /
/// `SetProperty` / `AddRelation` / `RemoveRelation` operations, regardless of
/// which capability emitted them. Never written to directly; only ever
/// produced by [`Projection::rebuild`] folding the log, the same discipline
/// [`crate::notes::NotesProjection`] already follows.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct EntityGraphProjection {
    entities: BTreeMap<String, EntityRecord>,
}

impl EntityGraphProjection {
    pub fn get(&self, entity_id: &str) -> Option<&EntityRecord> {
        self.entities.get(entity_id)
    }

    pub fn len(&self) -> usize {
        self.entities.len()
    }

    pub fn is_empty(&self) -> bool {
        self.entities.is_empty()
    }

    pub fn entity_ids(&self) -> Vec<&str> {
        self.entities.keys().map(String::as_str).collect()
    }
}

impl Projection for EntityGraphProjection {
    /// Folds the log in one pass, in order (`C2`: `replay_passes == 1`).
    /// Operations with no `entity_id`, or whose `kind` is not one of the
    /// four entity verbs, are skipped — a mixed-capability log (Notes plus
    /// entity-graph operations) folds correctly because this projection
    /// simply ignores what is not its concern, the same way
    /// [`crate::notes::NotesProjection::rebuild`] ignores every operation
    /// whose `capability` is not `"notes"`.
    fn rebuild(ops: &[Operation]) -> Self {
        Self::rebuild_counting(ops).0
    }
}

impl EntityGraphProjection {
    /// Same fold as [`Projection::rebuild`], plus the number of entity-verb
    /// operations visited — the measured, not assumed, single-pass proof a
    /// conformance test relies on.
    pub fn rebuild_counting(ops: &[Operation]) -> (Self, usize) {
        let mut entities: BTreeMap<String, EntityRecord> = BTreeMap::new();
        let mut visits = 0usize;

        for op in ops {
            let Some(verb) = op.verb() else { continue };
            if op.entity_id.is_empty() {
                continue;
            }
            match verb {
                Verb::CreateEntity => {
                    visits += 1;
                    let record = entities.entry(op.entity_id.clone()).or_default();
                    if !op.payload.is_empty() {
                        if let Ok(label) = String::from_utf8(op.payload.clone()) {
                            record.label = label;
                        }
                    }
                }
                Verb::SetProperty => {
                    if let Some((name, value)) = decode_set_property(&op.payload) {
                        visits += 1;
                        entities
                            .entry(op.entity_id.clone())
                            .or_default()
                            .properties
                            .insert(name, value);
                    }
                }
                Verb::AddRelation => {
                    if let Some((relation, target)) = decode_relation(&op.payload) {
                        visits += 1;
                        entities
                            .entry(op.entity_id.clone())
                            .or_default()
                            .relations
                            .insert((relation, target));
                    }
                }
                Verb::RemoveRelation => {
                    if let Some((relation, target)) = decode_relation(&op.payload) {
                        visits += 1;
                        if let Some(record) = entities.get_mut(&op.entity_id) {
                            record.relations.remove(&(relation, target));
                        }
                    }
                }
                _ => {}
            }
        }

        (Self { entities }, visits)
    }
}

// ---------------------------------------------------------------------------
// Content ledger — condition 8 (`#1217`): `DestroyContent` invalidates every
// projection derived from that content.
// ---------------------------------------------------------------------------

/// Which content ids the log currently considers reachable, folded from
/// `CreateContent` and `DestroyContent` operations alone. `C4`: *"`DestroyContent`
/// invalidates every projection derived from that content"* — this is the
/// projection that statement is about at the Content primitive's own level,
/// underneath any capability-specific view built on top of it.
///
/// A content id present here is *reachable* — `Runtime::read_content` is
/// expected to return `Some` for it (assuming the bytes are actually still on
/// disk, which [`crate::content::ContentStore`] guarantees for anything not
/// yet destroyed). A content id in [`Self::destroyed`] is exactly the
/// opposite: [`crate::runtime::Runtime::destroy_content`] already erased the
/// bytes before this operation was even appended (see that method's doc for
/// why that ordering, not the reverse, is what makes the guarantee real
/// rather than a race), so this projection is confirming a fact that is
/// already true on disk, not the thing that makes it true.
///
/// `DestroyContent` is terminal: once a content id is destroyed, a later
/// `CreateContent` bearing the *same* id cannot resurrect it — the bytes it
/// would need to re-derive that id from are gone, so nothing can actually
/// produce them again. Order in the log still matters for what this
/// projection reports, which is why `destroyed` always wins regardless of
/// which operation comes first structurally.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ContentLedgerProjection {
    live: BTreeSet<ContentId>,
    destroyed: BTreeSet<ContentId>,
}

impl ContentLedgerProjection {
    /// `true` only for a content id this log has seen created and never seen
    /// destroyed. A content id this projection never heard of at all (never
    /// created through the verb-based path) is also `false` here — this
    /// projection can only speak to what it was told.
    pub fn is_live(&self, id: &ContentId) -> bool {
        self.live.contains(id)
    }

    /// `true` for a content id this log has recorded a `DestroyContent` for.
    pub fn is_destroyed(&self, id: &ContentId) -> bool {
        self.destroyed.contains(id)
    }

    pub fn live_content_ids(&self) -> impl Iterator<Item = &ContentId> {
        self.live.iter()
    }

    pub fn destroyed_content_ids(&self) -> impl Iterator<Item = &ContentId> {
        self.destroyed.iter()
    }

    pub fn live_count(&self) -> usize {
        self.live.len()
    }

    pub fn destroyed_count(&self) -> usize {
        self.destroyed.len()
    }
}

impl Projection for ContentLedgerProjection {
    /// Single pass, `C2`: visits `CreateContent` and `DestroyContent`
    /// operations only, in log order, and nothing else — a mixed-capability
    /// log folds correctly the same way [`EntityGraphProjection::rebuild`]
    /// does.
    fn rebuild(ops: &[Operation]) -> Self {
        let mut live = BTreeSet::new();
        let mut destroyed = BTreeSet::new();

        for op in ops {
            let Some(verb) = op.verb() else { continue };
            let Some(content_id) = &op.content_id else {
                continue;
            };
            match verb {
                Verb::CreateContent => {
                    if !destroyed.contains(content_id) {
                        live.insert(content_id.clone());
                    }
                }
                Verb::DestroyContent => {
                    live.remove(content_id);
                    destroyed.insert(content_id.clone());
                }
                _ => {}
            }
        }

        Self { live, destroyed }
    }
}

/// `#1195`'s explicit, supported, tested rebuild-from-scratch operation:
/// drop whatever projection state a caller was holding, replay the log, and
/// fold it fresh. This is a thin, documented name for what
/// [`crate::runtime::Runtime::query_projection`] already does — the point is
/// that it has a name and is called out as a first-class operation rather
/// than an incidental consequence of never caching.
pub fn rebuild_from_scratch<P: Projection>(ops: &[Operation]) -> P {
    P::rebuild(ops)
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
        std::env::temp_dir().join(format!("airo_mind_projection_test_{name}_{unique}.log"))
    }

    fn cleanup(path: &std::path::Path) {
        let _ = std::fs::remove_file(path);
        let mut device_id = path.file_name().unwrap().to_string_lossy().into_owned();
        device_id.push_str(".device_id");
        let _ = std::fs::remove_file(path.with_file_name(device_id));
        let mut content = path.file_name().unwrap().to_string_lossy().into_owned();
        content.push_str(".content");
        let _ = std::fs::remove_dir_all(path.with_file_name(content));
    }

    #[test]
    fn create_entity_set_property_and_relations_fold_into_one_graph() {
        let path = temp_log_path("fold");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        runtime
            .emit_verb_operation(
                "notes",
                Verb::CreateEntity,
                "note-1",
                &[],
                "",
                b"Note",
                None,
                1,
            )
            .unwrap();
        runtime
            .emit_verb_operation(
                "notes",
                Verb::SetProperty,
                "note-1",
                &[],
                "",
                &encode_set_property("title", b"Groceries"),
                None,
                2,
            )
            .unwrap();
        runtime
            .emit_verb_operation(
                "notes",
                Verb::CreateEntity,
                "person-1",
                &[],
                "",
                b"Person",
                None,
                3,
            )
            .unwrap();
        runtime
            .emit_verb_operation(
                "notes",
                Verb::AddRelation,
                "note-1",
                &[],
                "",
                &encode_relation("authoredBy", "person-1"),
                None,
                4,
            )
            .unwrap();

        let graph: EntityGraphProjection = runtime.query_projection().unwrap();
        assert_eq!(graph.len(), 2);
        let note = graph.get("note-1").unwrap();
        assert_eq!(note.label, "Note");
        assert_eq!(note.properties.get("title").unwrap(), b"Groceries");
        assert!(note
            .relations
            .contains(&("authoredBy".to_string(), "person-1".to_string())));

        cleanup(&path);
    }

    #[test]
    fn remove_relation_undoes_a_prior_add_relation() {
        let path = temp_log_path("remove_relation");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        runtime
            .emit_verb_operation("notes", Verb::CreateEntity, "a", &[], "", b"", None, 1)
            .unwrap();
        runtime
            .emit_verb_operation(
                "notes",
                Verb::AddRelation,
                "a",
                &[],
                "",
                &encode_relation("links", "b"),
                None,
                2,
            )
            .unwrap();
        runtime
            .emit_verb_operation(
                "notes",
                Verb::RemoveRelation,
                "a",
                &[],
                "",
                &encode_relation("links", "b"),
                None,
                3,
            )
            .unwrap();

        let graph: EntityGraphProjection = runtime.query_projection().unwrap();
        assert!(graph.get("a").unwrap().relations.is_empty());

        cleanup(&path);
    }

    /// `#1195`'s core proof, generalized beyond Notes: **two independent
    /// projections**, fed from a **mixed-capability log**, both survive
    /// delete-and-rebuild with zero data loss. This is condition 5 of
    /// `#1311` proven at the engine level, not only for the one capability
    /// `#1338` shipped it against.
    #[test]
    fn two_projections_survive_delete_and_rebuild_with_zero_data_loss() {
        let path = temp_log_path("two_projections");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let notes = crate::notes::NotesCapability::new(&runtime);

        // Notes capability operations (opaque `kind` strings).
        notes
            .create_note("n1", "Groceries", "milk, eggs", 1_000)
            .unwrap();
        notes
            .edit_note("n1", "Groceries", "milk, eggs, bread", 2_000)
            .unwrap();

        // Entity-graph verb operations, interleaved in the same log.
        runtime
            .emit_verb_operation(
                "relationships",
                Verb::CreateEntity,
                "person-1",
                &[],
                "",
                b"Person",
                None,
                3_000,
            )
            .unwrap();
        runtime
            .emit_verb_operation(
                "relationships",
                Verb::SetProperty,
                "person-1",
                &[],
                "",
                &encode_set_property("name", b"Ada"),
                None,
                4_000,
            )
            .unwrap();

        // State before any "deletion".
        let notes_before = notes.notes().unwrap();
        let graph_before: EntityGraphProjection = runtime.query_projection().unwrap();
        assert_eq!(notes_before.len(), 1);
        assert_eq!(graph_before.len(), 1);

        // "Delete": drop every in-memory projection. Nothing else retains
        // this state -- both projection types hold no cache of their own
        // (`I2`, `I4`), and `NotesCapability` holds only the runtime
        // reference.
        drop(notes_before);
        drop(graph_before);

        // Rebuild from the log alone, via #1195's named operation.
        let ops = runtime.replay().unwrap();
        let notes_after: crate::notes::NotesProjection = rebuild_from_scratch(&ops);
        let graph_after: EntityGraphProjection = rebuild_from_scratch(&ops);

        // Zero data loss, for both projections independently.
        assert_eq!(notes_after.len(), 1);
        let n1 = notes_after.get("n1").unwrap();
        assert_eq!(n1.title, "Groceries");
        assert_eq!(n1.body, "milk, eggs, bread");

        assert_eq!(graph_after.len(), 1);
        assert_eq!(
            graph_after
                .get("person-1")
                .unwrap()
                .properties
                .get("name")
                .unwrap(),
            b"Ada"
        );

        // And through the ordinary query path too, not just the direct
        // `rebuild_from_scratch` call.
        assert_eq!(notes.notes().unwrap(), notes_after);
        let graph_via_query: EntityGraphProjection = runtime.query_projection().unwrap();
        assert_eq!(graph_via_query, graph_after);

        cleanup(&path);
    }

    /// `C2`: `replay_passes == 1`. Every entity-verb operation is visited
    /// exactly once; a mixed-capability log (Notes operations present too)
    /// must not inflate the count.
    #[test]
    fn rebuild_visits_every_entity_verb_operation_exactly_once() {
        let path = temp_log_path("single_pass");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let notes = crate::notes::NotesCapability::new(&runtime);

        for i in 0..10 {
            notes.create_note(format!("n{i}"), "t", "b", i).unwrap();
        }
        for i in 0..15 {
            runtime
                .emit_verb_operation(
                    "relationships",
                    Verb::CreateEntity,
                    &format!("e{i}"),
                    &[],
                    "",
                    b"",
                    None,
                    i,
                )
                .unwrap();
        }

        let ops = runtime.replay().unwrap();
        let (_, visits) = EntityGraphProjection::rebuild_counting(&ops);
        assert_eq!(
            visits, 15,
            "only the fifteen entity-verb operations should be visited"
        );

        let first = EntityGraphProjection::rebuild(&ops);
        let second = EntityGraphProjection::rebuild(&ops);
        assert_eq!(first, second, "rebuild must be a pure function of the log");

        cleanup(&path);
    }

    #[test]
    fn an_empty_log_rebuilds_to_an_empty_graph() {
        let path = temp_log_path("empty");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
        let graph: EntityGraphProjection = runtime.query_projection().unwrap();
        assert!(graph.is_empty());
        cleanup(&path);
    }
}

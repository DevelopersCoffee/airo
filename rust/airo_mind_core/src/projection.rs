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

// ---------------------------------------------------------------------------
// Context hypergraph — `#1229`: contexts as nodes, content links to many of
// them, hyperedges rather than a tree. Design doc §4.1 / §5.8, `#1197`'s
// scope.
// ---------------------------------------------------------------------------

/// One context node's fold state. A context is user data (design §5.8:
/// *"contexts belong to the user, not the capability"*) — this record holds
/// only what `CreateContext` declared, never anything a capability could
/// reclaim by uninstalling itself.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ContextRecord {
    pub label: String,
}

/// What a hypothetical or real destructive action (`UnlinkContent` /
/// `DestroyContent`) would leave behind, computed *before* the action is
/// taken. Design doc, framed for #1229: *"the input to every destructive
/// confirmation dialog... the UI cannot tell the user the difference between
/// '17 items leave this journey and remain in Finance' and '5 items exist
/// nowhere else and will be destroyed' without it."*
///
/// `surviving_contexts` is always sorted (`BTreeSet` fold) — deterministic
/// for a confirmation dialog to render without re-sorting.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SurvivalReport {
    pub content_id: ContentId,
    /// Every context that would still hold this content after the action.
    /// Empty means the content would exist nowhere else.
    pub surviving_contexts: Vec<String>,
    /// `true` exactly when `surviving_contexts` is empty — named
    /// separately so a caller does not have to remember that an empty
    /// `Vec` is the "exists nowhere else" signal rather than an error or an
    /// unlinked-from-everything-including-itself edge case.
    pub exists_nowhere_else: bool,
}

/// The context hypergraph. `C4` / design §4.1: *"content does not belong to a
/// hierarchy. It belongs to a set of contexts."* Folded from
/// [`Verb::CreateContext`] / [`Verb::LinkContext`] / [`Verb::UnlinkContext`]
/// (context nodes and the context-to-context restructuring graph — design
/// §5.8's "merging two journeys... only links change") and
/// [`Verb::CreateContent`] / [`Verb::LinkContent`] / [`Verb::UnlinkContent`] /
/// [`Verb::DestroyContent`] (the content-to-context hyperedges — design
/// §4.1's wrapping set, modeled here at the log/projection level rather than
/// as real per-context key wrappings: `#1209`, the envelope-encryption
/// substrate this issue's scope references, has not landed in this crate
/// yet — see [`crate::content`]'s module doc for the same "build the shape
/// now, encrypt later" trade already made for the content store itself).
///
/// A content object's *current* wrapping set is exactly the contexts named on
/// its `CreateContent`'s own `context_ids` header field, plus every
/// `LinkContent`, minus every `UnlinkContent`, in log order — until a
/// `DestroyContent` is seen for it, which is terminal: no `Link`/`Unlink`
/// after a destroy can revive or further mutate that content's wrapping set,
/// the same "destroyed always wins regardless of order" discipline
/// [`ContentLedgerProjection`] already follows.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ContextHypergraphProjection {
    contexts: BTreeMap<String, ContextRecord>,
    /// context id -> the other context ids it is linked to (symmetric: an
    /// edge is recorded on both ends, so `linked_contexts` reads either
    /// direction without knowing which side issued the `LinkContext`).
    context_links: BTreeMap<String, BTreeSet<String>>,
    /// content id -> the set of context ids currently wrapping it.
    content_links: BTreeMap<ContentId, BTreeSet<String>>,
    /// content ids seen on a `DestroyContent` — terminal, see the struct doc.
    destroyed_content: BTreeSet<ContentId>,
}

impl ContextHypergraphProjection {
    pub fn context(&self, context_id: &str) -> Option<&ContextRecord> {
        self.contexts.get(context_id)
    }

    pub fn context_exists(&self, context_id: &str) -> bool {
        self.contexts.contains_key(context_id)
    }

    pub fn context_count(&self) -> usize {
        self.contexts.len()
    }

    /// The contexts `context_id` is linked to via `LinkContext` —
    /// design §5.8's restructuring graph, not the content-wrapping set.
    pub fn linked_contexts(&self, context_id: &str) -> Vec<&str> {
        self.context_links
            .get(context_id)
            .map(|set| set.iter().map(String::as_str).collect())
            .unwrap_or_default()
    }

    /// `true` once a `DestroyContent` has been seen for `content_id`.
    /// Terminal — see the struct doc.
    pub fn is_content_destroyed(&self, content_id: &ContentId) -> bool {
        self.destroyed_content.contains(content_id)
    }

    /// The contexts currently wrapping `content_id` — design §4.1's "at
    /// least one valid wrapping" set, right now, in this fold. Empty for
    /// destroyed content and for a content id this projection never saw
    /// linked to any context.
    pub fn contexts_for_content(&self, content_id: &ContentId) -> Vec<&str> {
        self.content_links
            .get(content_id)
            .map(|set| set.iter().map(String::as_str).collect())
            .unwrap_or_default()
    }

    /// `true` exactly when `contexts_for_content` is non-empty — design
    /// §4.1: *"content remains recoverable while at least one valid
    /// wrapping exists."*
    pub fn content_survives(&self, content_id: &ContentId) -> bool {
        !self.is_content_destroyed(content_id)
            && self
                .content_links
                .get(content_id)
                .is_some_and(|set| !set.is_empty())
    }

    /// The survival computation `#1229` scopes as P0: what would remain of
    /// `content_id`'s wrapping set if `contexts_to_remove` were unlinked
    /// right now, without actually unlinking anything. Pure and read-only —
    /// a caller runs this before emitting the real `UnlinkContent`, to drive
    /// a confirmation dialog with the true answer rather than a guess.
    pub fn survival_if_unlinked(
        &self,
        content_id: &ContentId,
        contexts_to_remove: &[&str],
    ) -> SurvivalReport {
        let current = self
            .content_links
            .get(content_id)
            .cloned()
            .unwrap_or_default();
        let removed: BTreeSet<String> = contexts_to_remove.iter().map(|s| s.to_string()).collect();
        let surviving_contexts: Vec<String> = current.difference(&removed).cloned().collect();
        SurvivalReport {
            content_id: content_id.clone(),
            exists_nowhere_else: surviving_contexts.is_empty(),
            surviving_contexts,
        }
    }

    /// As [`Self::survival_if_unlinked`], for the other destructive verb:
    /// `DestroyContent` removes every wrapping at once, so this is always
    /// `exists_nowhere_else: true` by definition — the useful information a
    /// confirmation dialog needs from this call is not the (trivial) answer
    /// but pairing it with [`Self::contexts_for_content`] beforehand to show
    /// *what* is about to be lost, which `Destroy` and `Unlink` must never
    /// let a caller conflate (design §3.2).
    pub fn survival_if_destroyed(&self, content_id: &ContentId) -> SurvivalReport {
        SurvivalReport {
            content_id: content_id.clone(),
            surviving_contexts: Vec::new(),
            exists_nowhere_else: true,
        }
    }
}

impl Projection for ContextHypergraphProjection {
    /// Single pass (`C2`), folding six verbs: `CreateContext`/`LinkContext`/
    /// `UnlinkContext` for the context-to-context graph, `CreateContent`/
    /// `LinkContent`/`UnlinkContent`/`DestroyContent` for the content
    /// hyperedges. Everything else is skipped, the same "ignore what is not
    /// its concern" discipline every projection in this module follows.
    fn rebuild(ops: &[Operation]) -> Self {
        let mut contexts: BTreeMap<String, ContextRecord> = BTreeMap::new();
        let mut context_links: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
        let mut content_links: BTreeMap<ContentId, BTreeSet<String>> = BTreeMap::new();
        let mut destroyed_content: BTreeSet<ContentId> = BTreeSet::new();

        for op in ops {
            let Some(verb) = op.verb() else { continue };
            match verb {
                Verb::CreateContext => {
                    if op.entity_id.is_empty() {
                        continue;
                    }
                    let record = contexts.entry(op.entity_id.clone()).or_default();
                    if !op.payload.is_empty() {
                        if let Ok(label) = String::from_utf8(op.payload.clone()) {
                            record.label = label;
                        }
                    }
                }
                Verb::LinkContext => {
                    if op.entity_id.is_empty() {
                        continue;
                    }
                    for target in &op.context_ids {
                        context_links
                            .entry(op.entity_id.clone())
                            .or_default()
                            .insert(target.clone());
                        context_links
                            .entry(target.clone())
                            .or_default()
                            .insert(op.entity_id.clone());
                    }
                }
                Verb::UnlinkContext => {
                    if op.entity_id.is_empty() {
                        continue;
                    }
                    for target in &op.context_ids {
                        if let Some(set) = context_links.get_mut(&op.entity_id) {
                            set.remove(target);
                        }
                        if let Some(set) = context_links.get_mut(target) {
                            set.remove(&op.entity_id);
                        }
                    }
                }
                Verb::CreateContent => {
                    let Some(content_id) = &op.content_id else {
                        continue;
                    };
                    if destroyed_content.contains(content_id) {
                        continue;
                    }
                    let set = content_links.entry(content_id.clone()).or_default();
                    for ctx in &op.context_ids {
                        set.insert(ctx.clone());
                    }
                }
                Verb::LinkContent => {
                    let Some(content_id) = &op.content_id else {
                        continue;
                    };
                    if destroyed_content.contains(content_id) {
                        continue;
                    }
                    let set = content_links.entry(content_id.clone()).or_default();
                    for ctx in &op.context_ids {
                        set.insert(ctx.clone());
                    }
                }
                Verb::UnlinkContent => {
                    let Some(content_id) = &op.content_id else {
                        continue;
                    };
                    if destroyed_content.contains(content_id) {
                        continue;
                    }
                    if let Some(set) = content_links.get_mut(content_id) {
                        for ctx in &op.context_ids {
                            set.remove(ctx);
                        }
                    }
                }
                Verb::DestroyContent => {
                    let Some(content_id) = &op.content_id else {
                        continue;
                    };
                    content_links.remove(content_id);
                    destroyed_content.insert(content_id.clone());
                }
                _ => {}
            }
        }

        Self {
            contexts,
            context_links,
            content_links,
            destroyed_content,
        }
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

    // -----------------------------------------------------------------
    // Context hypergraph -- `#1229`
    // -----------------------------------------------------------------

    /// The "hyper" part: one content object linked into three contexts at
    /// once, none of which owns it. Design doc §4.1's hospital-bill example,
    /// almost verbatim.
    #[test]
    fn one_content_object_can_belong_to_many_contexts_simultaneously() {
        let path = temp_log_path("hyperedge");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        runtime
            .create_context("finance", "hospitalization", b"Hospitalization", 1)
            .unwrap();
        runtime
            .create_context("finance", "finance", b"Finance", 2)
            .unwrap();
        runtime
            .create_context("finance", "tax-2026", b"Tax Year 2026", 3)
            .unwrap();

        let content_id = runtime
            .emit_verb_operation(
                "finance",
                Verb::CreateContent,
                "bill-1",
                &["hospitalization"],
                "",
                b"",
                Some(b"hospital bill bytes"),
                4,
            )
            .unwrap()
            .content_id
            .unwrap();

        runtime
            .link_content(
                "finance",
                content_id.clone(),
                "bill-1",
                &["finance", "tax-2026"],
                5,
            )
            .unwrap();

        let graph: ContextHypergraphProjection = runtime.query_projection().unwrap();
        let mut contexts = graph.contexts_for_content(&content_id);
        contexts.sort_unstable();
        assert_eq!(contexts, vec!["finance", "hospitalization", "tax-2026"]);
        assert!(graph.content_survives(&content_id));

        cleanup(&path);
    }

    /// Unlinking from one context must not destroy content that survives in
    /// another -- `Unlink` and `Destroy` are never the same action.
    #[test]
    fn unlinking_from_one_context_does_not_destroy_content_that_survives_elsewhere() {
        let path = temp_log_path("unlink_survives");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        let content_id = runtime
            .emit_verb_operation(
                "finance",
                Verb::CreateContent,
                "bill-1",
                &["hospitalization", "finance"],
                "",
                b"",
                Some(b"hospital bill bytes"),
                1,
            )
            .unwrap()
            .content_id
            .unwrap();

        runtime
            .unlink_content(
                "finance",
                content_id.clone(),
                "bill-1",
                &["hospitalization"],
                2,
            )
            .unwrap();

        let graph: ContextHypergraphProjection = runtime.query_projection().unwrap();
        assert_eq!(graph.contexts_for_content(&content_id), vec!["finance"]);
        assert!(
            graph.content_survives(&content_id),
            "content with a remaining wrapping must still be considered live"
        );
        assert!(!graph.is_content_destroyed(&content_id));

        // The bytes themselves are untouched -- `UnlinkContent` never
        // reaches the content store.
        assert_eq!(
            runtime.read_content(&content_id).unwrap().unwrap(),
            b"hospital bill bytes"
        );

        cleanup(&path);
    }

    /// The survival computation itself, run *before* the destructive action
    /// -- design §4.1's confirmation-dialog use case: "17 items survive
    /// elsewhere" vs "5 items exist nowhere else."
    #[test]
    fn survival_if_unlinked_reports_what_remains_without_mutating_anything() {
        let path = temp_log_path("survival_preview");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        let content_id = runtime
            .emit_verb_operation(
                "finance",
                Verb::CreateContent,
                "bill-1",
                &["hospitalization", "finance", "tax-2026"],
                "",
                b"",
                Some(b"bytes"),
                1,
            )
            .unwrap()
            .content_id
            .unwrap();

        let graph: ContextHypergraphProjection = runtime.query_projection().unwrap();
        let report = graph.survival_if_unlinked(&content_id, &["hospitalization"]);
        assert_eq!(report.content_id, content_id);
        assert!(!report.exists_nowhere_else);
        let mut survivors = report.surviving_contexts.clone();
        survivors.sort_unstable();
        assert_eq!(survivors, vec!["finance", "tax-2026"]);

        // A preview must not have mutated the log or the live projection --
        // the real wrapping set is unchanged.
        let after: ContextHypergraphProjection = runtime.query_projection().unwrap();
        let mut still_live = after.contexts_for_content(&content_id);
        still_live.sort_unstable();
        assert_eq!(
            still_live,
            vec!["finance", "hospitalization", "tax-2026"],
            "survival_if_unlinked must be read-only"
        );

        cleanup(&path);
    }

    /// Unlinking the *last* remaining context reference reports
    /// `exists_nowhere_else` -- the signal a confirmation dialog uses to
    /// warn the user this action is effectively equivalent to destruction,
    /// even though it is technically only an `Unlink`.
    #[test]
    fn unlinking_the_last_context_reports_exists_nowhere_else() {
        let path = temp_log_path("last_link");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        let content_id = runtime
            .emit_verb_operation(
                "finance",
                Verb::CreateContent,
                "bill-1",
                &["hospitalization"],
                "",
                b"",
                Some(b"bytes"),
                1,
            )
            .unwrap()
            .content_id
            .unwrap();

        let graph: ContextHypergraphProjection = runtime.query_projection().unwrap();
        let report = graph.survival_if_unlinked(&content_id, &["hospitalization"]);
        assert!(report.exists_nowhere_else);
        assert!(report.surviving_contexts.is_empty());

        cleanup(&path);
    }

    /// `DestroyContent` is terminal: once seen, no later `LinkContent` can
    /// resurrect the content's wrapping set, mirroring
    /// [`ContentLedgerProjection`]'s own "destroyed always wins" rule.
    #[test]
    fn destroy_content_is_terminal_and_a_later_link_cannot_revive_it() {
        let path = temp_log_path("destroy_terminal");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        let content_id = runtime
            .emit_verb_operation(
                "finance",
                Verb::CreateContent,
                "bill-1",
                &["hospitalization"],
                "",
                b"",
                Some(b"bytes"),
                1,
            )
            .unwrap()
            .content_id
            .unwrap();

        runtime
            .destroy_content("finance", content_id.clone(), "bill-1", 2)
            .unwrap();

        // A later attempt to link the now-destroyed content into another
        // context must not resurrect it in the projection.
        runtime
            .link_content("finance", content_id.clone(), "bill-1", &["finance"], 3)
            .unwrap();

        let graph: ContextHypergraphProjection = runtime.query_projection().unwrap();
        assert!(graph.is_content_destroyed(&content_id));
        assert!(!graph.content_survives(&content_id));
        assert!(graph.contexts_for_content(&content_id).is_empty());

        let survival = graph.survival_if_destroyed(&content_id);
        assert!(survival.exists_nowhere_else);
        assert!(survival.surviving_contexts.is_empty());

        cleanup(&path);
    }

    /// Context restructuring -- design §5.8: "merging two journeys... moves
    /// no content and rewrites no history. Only links change." `LinkContext`
    /// creates a structural edge between two context nodes without touching
    /// any content's own wrapping set.
    #[test]
    fn context_restructuring_only_changes_links_never_content() {
        let path = temp_log_path("restructure");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        runtime
            .create_context("journeys", "journey-a", b"Journey A", 1)
            .unwrap();
        runtime
            .create_context("journeys", "journey-b", b"Journey B", 2)
            .unwrap();
        let content_id = runtime
            .emit_verb_operation(
                "journeys",
                Verb::CreateContent,
                "doc-1",
                &["journey-a"],
                "",
                b"",
                Some(b"a decade of documents"),
                3,
            )
            .unwrap()
            .content_id
            .unwrap();

        // "Merge" journey-a into journey-b: a structural edge, not a content
        // move.
        runtime
            .link_context("journeys", "journey-a", &["journey-b"], 4)
            .unwrap();

        let graph: ContextHypergraphProjection = runtime.query_projection().unwrap();
        assert_eq!(graph.linked_contexts("journey-a"), vec!["journey-b"]);
        // Symmetric: readable from either side without knowing who issued
        // the `LinkContext`.
        assert_eq!(graph.linked_contexts("journey-b"), vec!["journey-a"]);

        // The content's own wrapping set is untouched by the restructuring.
        assert_eq!(graph.contexts_for_content(&content_id), vec!["journey-a"]);

        // Unlinking the restructuring edge removes only the edge.
        runtime
            .unlink_context("journeys", "journey-a", &["journey-b"], 5)
            .unwrap();
        let after: ContextHypergraphProjection = runtime.query_projection().unwrap();
        assert!(after.linked_contexts("journey-a").is_empty());
        assert!(after.linked_contexts("journey-b").is_empty());
        assert_eq!(after.contexts_for_content(&content_id), vec!["journey-a"]);

        cleanup(&path);
    }

    /// Condition 5's own pattern, applied to the context hypergraph: delete
    /// every in-memory projection and rebuild purely from the log -- the
    /// hyperedges, the survival answer, and the restructuring graph must all
    /// come back identical.
    #[test]
    fn the_context_hypergraph_rebuilds_correctly_from_the_operation_log() {
        let path = temp_log_path("rebuild");
        let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

        runtime
            .create_context("finance", "hospitalization", b"Hospitalization", 1)
            .unwrap();
        runtime
            .create_context("finance", "finance", b"Finance", 2)
            .unwrap();
        let content_id = runtime
            .emit_verb_operation(
                "finance",
                Verb::CreateContent,
                "bill-1",
                &["hospitalization"],
                "",
                b"",
                Some(b"bytes"),
                3,
            )
            .unwrap()
            .content_id
            .unwrap();
        runtime
            .link_content("finance", content_id.clone(), "bill-1", &["finance"], 4)
            .unwrap();
        runtime
            .link_context("finance", "hospitalization", &["finance"], 5)
            .unwrap();

        let before: ContextHypergraphProjection = runtime.query_projection().unwrap();
        let mut before_contexts: Vec<String> = before
            .contexts_for_content(&content_id)
            .into_iter()
            .map(String::from)
            .collect();
        before_contexts.sort_unstable();
        drop(before);

        let ops = runtime.replay().unwrap();
        let after: ContextHypergraphProjection = rebuild_from_scratch(&ops);
        let mut after_contexts: Vec<String> = after
            .contexts_for_content(&content_id)
            .into_iter()
            .map(String::from)
            .collect();
        after_contexts.sort_unstable();

        assert_eq!(before_contexts, after_contexts);
        assert_eq!(after_contexts, vec!["finance", "hospitalization"]);
        assert!(after.context_exists("hospitalization"));
        assert!(after.context_exists("finance"));
        assert_eq!(
            after.context("hospitalization").unwrap().label,
            "Hospitalization"
        );
        assert_eq!(after.linked_contexts("hospitalization"), vec!["finance"]);

        // Rebuilding twice from the same log is a pure function -- same
        // discipline `rebuild_visits_every_entity_verb_operation_exactly_once`
        // proves for `EntityGraphProjection`.
        let again: ContextHypergraphProjection = rebuild_from_scratch(&ops);
        assert_eq!(after, again);

        cleanup(&path);
    }
}

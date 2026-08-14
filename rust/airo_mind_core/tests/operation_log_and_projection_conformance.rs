//! Operation log and projection conformance — contract `C1`/`C2`/`C4`,
//! `#1194` and `#1195`.
//!
//! Black-box, against `airo_mind_core`'s public API only, the same style as
//! `tests/supervisor_conformance.rs`. Written against the contracts, not the
//! implementation — a real Vault-issued device identity or a real signature
//! scheme should not require rewriting these tests, only the `Runtime`
//! construction they start from.
//!
//! Two groups:
//! - **Operation log** (`#1194`, condition 4): the full header exists, is
//!   signed, is content-addressed for out-of-line content, and survives
//!   concurrent writers.
//! - **Projection engine** (`#1195`, condition 5): the delete-and-rebuild,
//!   zero-data-loss proof, generalized across two independent projections
//!   fed by a mixed-capability log — not just Notes.

use std::sync::Arc;

use airo_mind_core::{
    encode_relation, encode_set_property, rebuild_from_scratch, EntityGraphProjection,
    NotesCapability, NotesProjection, ResourceBudget, Runtime, Verb,
};

fn temp_log_path(name: &str) -> std::path::PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!("airo_mind_conformance_{name}_{unique}.log"))
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

// ---------------------------------------------------------------------------
// #1194 — Operation log
// ---------------------------------------------------------------------------

/// Design doc §3.1's full header — condition 4's *"every durable object is
/// reachable from the operation log"* is only meaningful if the object
/// reachable there actually carries the fields the design promises.
#[test]
fn an_operation_carries_the_full_c1_header() {
    let path = temp_log_path("full_header");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let op = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateEntity,
            "entity-1",
            &["context-a"],
            "schema-1",
            b"payload bytes",
            None,
            1_700_000_000,
        )
        .unwrap();

    assert!(!op.operation_id.is_empty(), "operationId");
    assert_eq!(op.parent_operation_id, None, "parentOperationId");
    assert_eq!(op.entity_id, "entity-1", "entityId");
    assert_eq!(
        op.context_ids,
        vec!["context-a".to_string()],
        "contextIds[]"
    );
    assert_eq!(op.schema_id, "schema-1", "schemaId");
    assert_eq!(op.capability, "notes", "capabilityId");
    assert_eq!(op.device_id, runtime.device_id(), "deviceId");
    assert_eq!(op.recorded_at_ms, 1_700_000_000, "timestamp");
    assert!(!op.version_vector.is_empty(), "versionVector");
    assert!(!op.payload_hash.is_empty(), "payloadHash");
    assert!(!op.signature.is_empty(), "signature");

    cleanup(&path);
}

/// `#1194`'s scope table names nineteen verbs across five groups. Every one
/// of them must be a valid `kind` on the wire — a round trip through the log
/// proves the format accepts all nineteen, not just the four this crate has
/// a projection for.
#[test]
fn every_scoped_verb_round_trips_through_the_log() {
    let path = temp_log_path("all_verbs");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    for verb in Verb::all() {
        runtime
            .emit_verb_operation("capabilities-probe", *verb, "e", &[], "", b"", None, 1)
            .unwrap();
    }

    let ops = runtime.replay().unwrap();
    assert_eq!(ops.len(), Verb::all().len());
    for (op, verb) in ops.iter().zip(Verb::all()) {
        assert_eq!(op.verb(), Some(*verb));
    }

    cleanup(&path);
}

/// §3.1: *"payload behind `ContentID`, never inlined"* for the Content
/// primitive, over a content-addressed store — `#1194`'s scope names this
/// explicitly.
#[test]
fn content_is_addressed_and_deduplicated_across_operations() {
    let path = temp_log_path("content_addressed");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let first = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateContent,
            "c1",
            &[],
            "",
            b"",
            Some(b"identical bytes"),
            1,
        )
        .unwrap();
    let second = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateContent,
            "c2",
            &[],
            "",
            b"",
            Some(b"identical bytes"),
            2,
        )
        .unwrap();

    assert_eq!(
        first.content_id, second.content_id,
        "identical content must share one content id"
    );
    assert_eq!(
        runtime
            .read_content(&first.content_id.unwrap())
            .unwrap()
            .unwrap(),
        b"identical bytes"
    );

    cleanup(&path);
}

/// The concurrent-writer-safety requirement, stated as a black-box property:
/// many capabilities, many threads, one runtime, and the resulting log has
/// exactly the right number of operations with a contiguous `seq` — no lost
/// writes, no duplicated `seq`, no torn records.
#[test]
fn many_capabilities_writing_concurrently_produce_one_consistent_log() {
    let path = temp_log_path("many_capabilities");
    let runtime = Arc::new(Runtime::boot(ResourceBudget::new(2048), &path).unwrap());

    const CAPABILITIES: usize = 4;
    const OPS_PER_CAPABILITY: usize = 40;
    let mut handles = Vec::new();
    for c in 0..CAPABILITIES {
        let runtime = runtime.clone();
        handles.push(std::thread::spawn(move || {
            let capability = format!("capability-{c}");
            for i in 0..OPS_PER_CAPABILITY {
                runtime
                    .emit_verb_operation(
                        &capability,
                        Verb::CreateEntity,
                        &format!("e-{c}-{i}"),
                        &[],
                        "",
                        b"",
                        None,
                        i as u64,
                    )
                    .unwrap();
            }
        }));
    }
    for h in handles {
        h.join().unwrap();
    }

    let ops = runtime.replay().unwrap();
    assert_eq!(ops.len(), CAPABILITIES * OPS_PER_CAPABILITY);

    let mut seqs: Vec<u64> = ops.iter().map(|op| op.seq).collect();
    seqs.sort_unstable();
    seqs.dedup();
    assert_eq!(
        seqs.len(),
        CAPABILITIES * OPS_PER_CAPABILITY,
        "no duplicate seq under concurrent writers"
    );
    assert_eq!(seqs.first(), Some(&0));
    assert_eq!(
        seqs.last(),
        Some(&((CAPABILITIES * OPS_PER_CAPABILITY - 1) as u64))
    );

    cleanup(&path);
}

// ---------------------------------------------------------------------------
// #1195 — Projection engine
// ---------------------------------------------------------------------------

/// **The headline proof for condition 5.** Two independent projections, fed
/// from one mixed-capability log, both survive their in-memory state being
/// dropped entirely and rebuilding from the persisted log alone — with
/// identical results. Generalizes `#1338`'s Notes-only proof to the engine
/// itself.
#[test]
fn two_independent_projections_survive_full_deletion_and_rebuild_with_zero_data_loss() {
    let path = temp_log_path("zero_data_loss");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let notes = NotesCapability::new(&runtime);

    notes
        .create_note("n1", "Groceries", "milk, eggs", 1_000)
        .unwrap();
    notes
        .create_note("n2", "Throwaway", "delete me", 2_000)
        .unwrap();
    notes.delete_note("n2", 3_000).unwrap();

    runtime
        .emit_verb_operation(
            "graph",
            Verb::CreateEntity,
            "person-1",
            &[],
            "",
            b"Person",
            None,
            4_000,
        )
        .unwrap();
    runtime
        .emit_verb_operation(
            "graph",
            Verb::SetProperty,
            "person-1",
            &[],
            "",
            &encode_set_property("name", b"Ada Lovelace"),
            None,
            5_000,
        )
        .unwrap();
    runtime
        .emit_verb_operation(
            "graph",
            Verb::AddRelation,
            "person-1",
            &[],
            "",
            &encode_relation("wrote", "note-n1"),
            None,
            6_000,
        )
        .unwrap();

    // Snapshot both projections before any "deletion".
    let notes_before = notes.notes().unwrap();
    let graph_before: EntityGraphProjection = runtime.query_projection().unwrap();
    assert_eq!(notes_before.len(), 1);
    assert_eq!(graph_before.len(), 1);

    // Delete: every in-memory projection this test held goes out of scope.
    // Neither projection type, nor `NotesCapability`, retains a cache of its
    // own (`I2`, `I4`) -- there is nothing else durable to fall back on.
    drop(notes_before);
    drop(graph_before);

    // Rebuild from the persisted log alone, via #1195's named operation.
    let ops = runtime.replay().unwrap();
    let notes_after: NotesProjection = rebuild_from_scratch(&ops);
    let graph_after: EntityGraphProjection = rebuild_from_scratch(&ops);

    assert_eq!(notes_after.len(), 1, "n2 was deleted, only n1 survives");
    let n1 = notes_after.get("n1").unwrap();
    assert_eq!(n1.title, "Groceries");
    assert_eq!(n1.body, "milk, eggs");
    assert!(notes_after.get("n2").is_none());

    assert_eq!(graph_after.len(), 1);
    let person = graph_after.get("person-1").unwrap();
    assert_eq!(person.label, "Person");
    assert_eq!(person.properties.get("name").unwrap(), b"Ada Lovelace");
    assert!(person
        .relations
        .contains(&("wrote".to_string(), "note-n1".to_string())));

    // And the ordinary query path reaches the same state -- rebuilding is
    // not a special code path, it is the only code path.
    assert_eq!(notes.notes().unwrap(), notes_after);
    let graph_via_query: EntityGraphProjection = runtime.query_projection().unwrap();
    assert_eq!(graph_via_query, graph_after);

    cleanup(&path);
}

/// `C4`: rebuild is a pure function of the log — running it twice from the
/// same operations must not depend on anything but the operations
/// themselves.
#[test]
fn rebuilding_the_same_log_twice_produces_identical_projections() {
    let path = temp_log_path("pure_function");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let notes = NotesCapability::new(&runtime);
    for i in 0..12 {
        notes
            .create_note(format!("n{i}"), format!("title {i}"), "body", i)
            .unwrap();
    }

    let ops = runtime.replay().unwrap();
    let first: NotesProjection = rebuild_from_scratch(&ops);
    let second: NotesProjection = rebuild_from_scratch(&ops);
    assert_eq!(first, second);

    let first_graph: EntityGraphProjection = rebuild_from_scratch(&ops);
    let second_graph: EntityGraphProjection = rebuild_from_scratch(&ops);
    assert_eq!(first_graph, second_graph);

    cleanup(&path);
}

/// A rebuilt projection must not see operations from a capability it does
/// not own — `EntityGraphProjection` folding over a log that also contains
/// Notes operations must ignore them entirely, and vice versa.
#[test]
fn a_projection_ignores_operations_outside_its_own_concern() {
    let path = temp_log_path("ignores_foreign_ops");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let notes = NotesCapability::new(&runtime);

    notes.create_note("n1", "t", "b", 1).unwrap();
    runtime
        .emit_verb_operation("graph", Verb::CreateEntity, "e1", &[], "", b"", None, 2)
        .unwrap();

    let notes_projection = notes.notes().unwrap();
    assert_eq!(notes_projection.len(), 1);
    assert!(notes_projection.get("e1").is_none());

    let graph: EntityGraphProjection = runtime.query_projection().unwrap();
    assert_eq!(graph.len(), 1);
    assert!(graph.get("n1").is_none());

    cleanup(&path);
}

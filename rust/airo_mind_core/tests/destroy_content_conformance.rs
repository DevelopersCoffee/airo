//! `DestroyContent` conformance — condition 8 of `#1311` (`#1217`), contracts
//! `C4` and `C7`.
//!
//! Black-box, against `airo_mind_core`'s public API only, the same style as
//! `tests/operation_log_and_projection_conformance.rs`.
//!
//! Condition 8, verbatim: *"`DestroyContent` removes every reachable
//! representation of user content, except immutable structural metadata
//! intentionally retained by design."*
//!
//! `C7`'s conformance bar, verbatim: *"destroy then assert no reachable
//! representation survives."* Per this suite's own stated philosophy (the
//! conformance-suite doc's opening section), a test that only calls the API
//! and checks the API's own claim about itself is not proof — this file
//! reads the content store's directory on disk directly, the same way an
//! attacker or a forensic recovery tool would, rather than trusting
//! `read_content`'s `None` alone.

use std::io::Read;

use airo_mind_core::{CapabilityApi, ContentLedgerProjection, ResourceBudget, Runtime, Verb};

fn temp_log_path(name: &str) -> std::path::PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!("airo_mind_destroy_conformance_{name}_{unique}.log"))
}

fn content_dir_for(path: &std::path::Path) -> std::path::PathBuf {
    let mut content = path.file_name().unwrap().to_string_lossy().into_owned();
    content.push_str(".content");
    path.with_file_name(content)
}

fn cleanup(path: &std::path::Path) {
    let _ = std::fs::remove_file(path);
    let mut device_id = path.file_name().unwrap().to_string_lossy().into_owned();
    device_id.push_str(".device_id");
    let _ = std::fs::remove_file(path.with_file_name(device_id));
    let _ = std::fs::remove_dir_all(content_dir_for(path));
}

/// **The critical proof.** Destroyed content must be gone from the raw bytes
/// on disk, not merely unreachable through the API. This test writes content
/// containing a unique marker, destroys it, then walks the content store's
/// directory itself (every file, every byte) and asserts the marker appears
/// nowhere — the file is gone, and nothing else in the directory carries a
/// copy of it either.
#[test]
fn destroyed_content_bytes_are_not_recoverable_from_disk() {
    let path = temp_log_path("disk_unrecoverable");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let marker = b"UNIQUE-MARKER-that-must-never-survive-a-destroy-9f3c7a";
    let op = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateContent,
            "doc-1",
            &[],
            "",
            b"",
            Some(marker),
            1,
        )
        .unwrap();
    let content_id = op.content_id.clone().unwrap();

    // Before destruction: the file exists and really does contain the
    // marker -- proves the "not found" assertion below is meaningful rather
    // than trivially true because nothing was ever written.
    let dir = content_dir_for(&path);
    let path_on_disk = dir.join(content_id.as_str());
    assert!(
        path_on_disk.exists(),
        "content file must exist before destroy"
    );
    let mut before_bytes = Vec::new();
    std::fs::File::open(&path_on_disk)
        .unwrap()
        .read_to_end(&mut before_bytes)
        .unwrap();
    assert_eq!(before_bytes, marker);

    runtime
        .destroy_content("notes", content_id.clone(), "doc-1", 2)
        .unwrap();

    // (a) The API says it's gone.
    assert!(runtime.read_content(&content_id).unwrap().is_none());

    // (b) The file itself is gone -- not present under its content-addressed
    // name at all.
    assert!(
        !path_on_disk.exists(),
        "the destroyed object's file must not exist on disk"
    );

    // (c) The marker does not appear anywhere else in the content
    // directory -- no stray temp file, no leftover copy under a different
    // name. This is the actual disk inspection: read every remaining file
    // in the directory and search its raw bytes for the marker.
    let mut found_marker_anywhere = false;
    for entry in std::fs::read_dir(&dir).unwrap() {
        let entry = entry.unwrap();
        if entry.path().is_file() {
            let mut bytes = Vec::new();
            if std::fs::File::open(entry.path())
                .and_then(|mut f| f.read_to_end(&mut bytes))
                .is_ok()
                && bytes.windows(marker.len()).any(|w| w == marker.as_slice())
            {
                found_marker_anywhere = true;
            }
        }
    }
    assert!(
        !found_marker_anywhere,
        "the destroyed content's bytes must not survive anywhere in the content store's directory"
    );

    cleanup(&path);
}

/// The tombstone operation itself never carries the destroyed bytes. Proven
/// by replaying the log and confirming no operation's payload contains the
/// marker -- the log growing by exactly one small record, not by
/// re-embedding what was just destroyed.
#[test]
fn the_destroy_operation_does_not_carry_the_destroyed_bytes() {
    let path = temp_log_path("no_payload_leak");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let marker = b"payload-must-not-leak-into-the-tombstone-op";
    let op = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateContent,
            "doc-1",
            &[],
            "",
            b"",
            Some(marker),
            1,
        )
        .unwrap();
    let content_id = op.content_id.clone().unwrap();

    let destroy_op = runtime
        .destroy_content("notes", content_id, "doc-1", 2)
        .unwrap();

    assert!(
        destroy_op.payload.is_empty(),
        "the tombstone operation must carry no payload"
    );
    assert_eq!(destroy_op.verb(), Some(Verb::DestroyContent));

    let ops = runtime.replay().unwrap();
    for replayed in &ops {
        let contains_marker = replayed.payload.len() >= marker.len()
            && replayed
                .payload
                .windows(marker.len())
                .any(|w| w == marker.as_slice());
        assert!(
            !contains_marker,
            "no operation in the log may carry the destroyed bytes in its payload"
        );
    }

    cleanup(&path);
}

/// Condition 8's own text: *"the operation log survives intact — signatures
/// still verify, structure is preserved."* A destroy must not corrupt, skip,
/// or invalidate anything about the log's own signing/replay guarantees.
#[test]
fn destroy_leaves_the_operation_log_internally_consistent() {
    let path = temp_log_path("log_consistent");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let op = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateContent,
            "doc-1",
            &[],
            "",
            b"",
            Some(b"some content"),
            1,
        )
        .unwrap();
    let content_id = op.content_id.clone().unwrap();

    let destroy_op = runtime
        .destroy_content("notes", content_id, "doc-1", 2)
        .unwrap();

    // The tombstone operation is itself signed and verifies, same as any
    // other operation -- destruction is not a special, unsigned path.
    assert!(runtime.verify_operation(&destroy_op));

    // Every operation in the log, including the tombstone, re-verifies under
    // a full re-verifying replay -- C2's ingest-time guarantee was not
    // bypassed for this operation.
    let ops = runtime.replay().unwrap();
    assert_eq!(ops.len(), 2, "CreateContent + DestroyContent, both durable");
    assert_eq!(ops[1].seq, 1, "seq is contiguous across the destroy");

    cleanup(&path);
}

/// **Zero-data-loss for everything else** (condition 5 must not regress).
/// Destroying one piece of content must not touch any other content, entity,
/// or note in the log -- proven by rebuilding every projection after the
/// destroy and confirming the untouched data is byte-identical to before.
#[test]
fn destroying_one_object_leaves_all_other_data_intact_through_delete_and_rebuild() {
    use airo_mind_core::{encode_set_property, rebuild_from_scratch, EntityGraphProjection};

    let path = temp_log_path("other_data_survives");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    // A note, untouched by anything below.
    let notes = airo_mind_core::NotesCapability::new(&runtime);
    notes
        .create_note("n1", "Groceries", "milk, eggs", 1)
        .unwrap();

    // An entity-graph fact, untouched.
    runtime
        .emit_verb_operation(
            "graph",
            Verb::CreateEntity,
            "person-1",
            &[],
            "",
            b"Person",
            None,
            2,
        )
        .unwrap();
    runtime
        .emit_verb_operation(
            "graph",
            Verb::SetProperty,
            "person-1",
            &[],
            "",
            &encode_set_property("name", b"Ada"),
            None,
            3,
        )
        .unwrap();

    // Two content objects: one destroyed, one left alone.
    let keep = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateContent,
            "doc-keep",
            &[],
            "",
            b"",
            Some(b"keep me"),
            4,
        )
        .unwrap()
        .content_id
        .unwrap();
    let destroy = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateContent,
            "doc-destroy",
            &[],
            "",
            b"",
            Some(b"destroy me"),
            5,
        )
        .unwrap()
        .content_id
        .unwrap();

    runtime
        .destroy_content("notes", destroy.clone(), "doc-destroy", 6)
        .unwrap();

    // Drop everything in-memory and rebuild purely from the persisted log.
    let ops = runtime.replay().unwrap();
    let notes_after: airo_mind_core::NotesProjection = rebuild_from_scratch(&ops);
    let graph_after: EntityGraphProjection = rebuild_from_scratch(&ops);
    let ledger_after: ContentLedgerProjection = rebuild_from_scratch(&ops);

    // The note survives identically.
    let n1 = notes_after.get("n1").unwrap();
    assert_eq!(n1.title, "Groceries");
    assert_eq!(n1.body, "milk, eggs");

    // The entity-graph fact survives identically.
    let person = graph_after.get("person-1").unwrap();
    assert_eq!(person.properties.get("name").unwrap(), b"Ada");

    // The kept content is still live and readable.
    assert!(ledger_after.is_live(&keep));
    assert_eq!(runtime.read_content(&keep).unwrap().unwrap(), b"keep me");

    // The destroyed content is gone, and only it.
    assert!(ledger_after.is_destroyed(&destroy));
    assert!(!ledger_after.is_live(&destroy));
    assert!(runtime.read_content(&destroy).unwrap().is_none());
    assert_eq!(ledger_after.live_count(), 1);
    assert_eq!(ledger_after.destroyed_count(), 1);

    cleanup(&path);
}

/// `C4`: *"`DestroyContent` invalidates every projection derived from that
/// content."* [`ContentLedgerProjection`] is that projection at the Content
/// primitive's own level -- destroyed content must be absent from a fresh
/// rebuild, not merely absent from a projection instance that happened to be
/// built before the destroy.
#[test]
fn a_fresh_projection_rebuild_never_shows_destroyed_content_as_live() {
    let path = temp_log_path("projection_never_resurrects");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let content_id = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateContent,
            "doc-1",
            &[],
            "",
            b"",
            Some(b"sensitive"),
            1,
        )
        .unwrap()
        .content_id
        .unwrap();

    let before: ContentLedgerProjection = runtime.query_projection().unwrap();
    assert!(before.is_live(&content_id));
    drop(before);

    runtime
        .destroy_content("notes", content_id.clone(), "doc-1", 2)
        .unwrap();

    // Many independent rebuilds -- not just the first one after the
    // destroy -- must all agree the content is gone. A projection is a pure
    // function of the log (`C4`), so this is deterministic, not a race.
    for _ in 0..5 {
        let after: ContentLedgerProjection = runtime.query_projection().unwrap();
        assert!(!after.is_live(&content_id));
        assert!(after.is_destroyed(&content_id));
    }

    cleanup(&path);
}

/// A `DestroyContent` for a content id that was never created (or already
/// destroyed) is safe -- idempotent, like `ContentStore::remove` itself, not
/// a hard failure a capability has to special-case.
#[test]
fn destroying_the_same_content_twice_is_idempotent() {
    let path = temp_log_path("idempotent_destroy");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let content_id = runtime
        .emit_verb_operation(
            "notes",
            Verb::CreateContent,
            "doc-1",
            &[],
            "",
            b"",
            Some(b"bytes"),
            1,
        )
        .unwrap()
        .content_id
        .unwrap();

    runtime
        .destroy_content("notes", content_id.clone(), "doc-1", 2)
        .unwrap();
    // Destroying again must not error, even though the bytes are already
    // gone.
    runtime
        .destroy_content("notes", content_id.clone(), "doc-1", 3)
        .unwrap();

    let ledger: ContentLedgerProjection = runtime.query_projection().unwrap();
    assert!(ledger.is_destroyed(&content_id));
    assert!(!ledger.is_live(&content_id));

    cleanup(&path);
}

/// The `CapabilityApi` surface: a capability that only ever touches
/// `CapabilityApi` (never `Runtime`, never `ContentStore`) can still destroy
/// content for real, and the destroyed bytes are unreachable through the
/// capability surface too.
#[test]
fn a_capability_can_destroy_content_through_the_capability_api_alone() {
    use airo_mind_core::CreateOperationRequest;

    let path = temp_log_path("capability_api_destroy");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let api = CapabilityApi::new(&runtime, "fake_docs");

    let mut req = CreateOperationRequest::verb(Verb::CreateContent, 1);
    req.entity_id = "doc-1";
    req.content = Some(b"capability-owned bytes");
    let receipt = api.create_operation(req).unwrap();
    let content_id = receipt.content_id.unwrap();

    api.destroy_content(content_id.clone(), "doc-1", 2).unwrap();

    // Runtime-level check: the bytes are really gone (a capability itself
    // has no read path to prove this -- content reading is intentionally
    // not on the five/six-function surface, same as `attach_content`'s
    // sibling read path).
    assert!(runtime.read_content(&content_id).unwrap().is_none());

    let ledger: ContentLedgerProjection = api.query_projection().unwrap();
    assert!(ledger.is_destroyed(&content_id));

    cleanup(&path);
}

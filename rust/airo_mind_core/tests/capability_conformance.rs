//! Capability conformance — contract `C5`, checklist `S3`, `#1295`.
//!
//! Black-box, against `airo_mind_core`'s public API only, the same style as
//! `tests/supervisor_conformance.rs` and
//! `tests/operation_log_and_projection_conformance.rs`. A capability under
//! test here is built the same way a real one is: it holds nothing but a
//! [`CapabilityApi`] handle, the way `#1295`'s module doc describes and the
//! way `NotesCapability` (`#1338`) already does in production.
//!
//! Per the conformance-suite doc's S3 note: *"the strongest form of the S3
//! storage check is negative: a capability denied all filesystem and
//! database access still passes its own suite. If it does not, it was
//! reaching around the runtime."* The filesystem-isolation test below is
//! that negative check, run black-box against the public surface rather than
//! `capability_api`'s own internal unit tests (which exist too, and prove
//! the same properties white-box, from inside the crate that must not leak
//! them).
//!
//! What this file does **not** attempt: the "declares a safety class looser
//! than its ontology lineage" bullet needs a safety-class/ontology system
//! that does not exist on this branch yet (`#1223`'s territory), and
//! "uninstalling it leaves its contexts, entities, and content intact" needs
//! an uninstall path this crate has not built. Both are left as gaps in the
//! conformance-suite report rather than faked here.

use airo_mind_core::{
    encode_relation, encode_set_property, CapabilityApi, CreateOperationRequest,
    EntityGraphProjection, ResourceBudget, Runtime, Verb,
};

fn temp_log_path(name: &str) -> std::path::PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!(
        "airo_mind_capability_conformance_{name}_{unique}.log"
    ))
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

/// A capability built the way `#1295`'s module doc prescribes: nothing but
/// the bound handle. If this struct compiled with a field reaching into
/// `airo_mind_core::runtime`, `airo_mind_core::content`, or
/// `airo_mind_core::signing` directly, that would already be the S3
/// violation — those modules are not `pub use`d, so nothing outside the
/// crate can name their types at all. The type system is the first
/// enforcement layer; the tests below are the runtime-behavior layer on top
/// of it.
struct FakeCrmCapability<'a> {
    api: CapabilityApi<'a>,
}

impl<'a> FakeCrmCapability<'a> {
    const ID: &'static str = "fake_crm";

    fn new(runtime: &'a Runtime) -> Self {
        Self {
            api: CapabilityApi::new(runtime, Self::ID),
        }
    }

    fn create_person(&self, id: &str, name: &str, at_ms: u64) -> String {
        let mut req = CreateOperationRequest::verb(Verb::CreateEntity, at_ms);
        req.entity_id = id;
        req.payload = b"Person";
        let receipt = self.api.create_operation(req).unwrap();

        let mut set_name = CreateOperationRequest::verb(Verb::SetProperty, at_ms + 1);
        set_name.entity_id = id;
        let encoded = encode_set_property("name", name.as_bytes());
        set_name.payload = &encoded;
        self.api.create_operation(set_name).unwrap();

        receipt.operation_id
    }

    fn link(&self, from: &str, relation: &str, to: &str, at_ms: u64) {
        let mut req = CreateOperationRequest::verb(Verb::AddRelation, at_ms);
        req.entity_id = from;
        let encoded = encode_relation(relation, to);
        req.payload = &encoded;
        self.api.create_operation(req).unwrap();
    }

    fn people(&self) -> EntityGraphProjection {
        self.api.query_projection().unwrap()
    }
}

/// S3, bullet 1 and 2: "emits operations only" / "reads projections only".
/// A capability restricted to `CapabilityApi` can still do everything a real
/// capability needs — write structured state and read it back — without
/// ever touching `Runtime`, `OperationLog`, or `ContentStore` directly.
#[test]
fn a_capability_using_only_the_public_capability_api_writes_and_reads_through_a_projection() {
    let path = temp_log_path("write_and_read");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let crm = FakeCrmCapability::new(&runtime);

    crm.create_person("p1", "Ada Lovelace", 1_000);
    crm.create_person("p2", "Alan Turing", 2_000);
    crm.link("p1", "colleague_of", "p2", 3_000);

    let people = crm.people();
    assert_eq!(people.len(), 2);
    let ada = people.get("p1").unwrap();
    assert_eq!(ada.properties.get("name").unwrap(), b"Ada Lovelace");
    assert!(ada
        .relations
        .contains(&("colleague_of".to_string(), "p2".to_string())));

    cleanup(&path);
}

/// S3, bullet 3, stated negatively per the conformance-suite doc: a
/// capability denied all filesystem access beyond the one log path the
/// runtime itself owns still passes. This proves `CapabilityApi` opens no
/// database, writes no file, and touches no preferences of its own —
/// everything durable it produced lives only inside the single log file
/// `Runtime::boot` was given.
#[test]
fn the_capability_writes_nothing_outside_the_runtimes_own_log_path() {
    let dir = std::env::temp_dir().join(format!(
        "airo_mind_capability_conformance_isolation_{}",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    std::fs::create_dir_all(&dir).unwrap();
    let log_path = dir.join("runtime.log");

    let before: std::collections::BTreeSet<_> = std::fs::read_dir(&dir)
        .unwrap()
        .map(|e| e.unwrap().file_name())
        .collect();
    assert!(before.is_empty(), "the directory must start empty");

    let runtime = Runtime::boot(ResourceBudget::new(2048), &log_path).unwrap();
    let crm = FakeCrmCapability::new(&runtime);
    for i in 0..10 {
        crm.create_person(&format!("p{i}"), &format!("Person {i}"), i as u64);
    }
    drop(runtime);

    // Every entry the capability's activity produced must be a file the
    // runtime itself named after `log_path` (the log, its device-id
    // sidecar, its content directory) -- never a path the capability chose.
    let after: std::collections::BTreeSet<_> = std::fs::read_dir(&dir)
        .unwrap()
        .map(|e| e.unwrap().file_name())
        .collect();
    let log_name = log_path.file_name().unwrap().to_os_string();
    for entry in &after {
        let entry_str = entry.to_string_lossy();
        assert!(
            entry_str.starts_with(&*log_name.to_string_lossy()),
            "unexpected filesystem entry {entry_str:?} outside the runtime's own log family \
             -- a capability built only against CapabilityApi must not be able to create this"
        );
    }

    let _ = std::fs::remove_dir_all(&dir);
}

/// S3, bullet: "cannot bypass the Supervisor — it has no route to schedule,
/// spawn, or persist on its own". Every operation a capability emits is
/// stamped with the id bound at construction, never one it can pick per
/// call -- so nothing built against `CapabilityApi` can forge writes under
/// another capability's identity, which is the write-side half of "no route
/// around the runtime's bookkeeping."
#[test]
fn a_capability_cannot_emit_an_operation_under_another_capabilitys_identity() {
    let path = temp_log_path("no_forged_identity");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();
    let crm = FakeCrmCapability::new(&runtime);
    assert_eq!(crm.api.capability_id(), FakeCrmCapability::ID);

    crm.create_person("p1", "Grace Hopper", 1_000);
    let ops = runtime.replay().unwrap();
    assert!(
        ops.iter().all(|op| op.capability == FakeCrmCapability::ID),
        "every operation this capability produced must be stamped with its own bound id"
    );

    cleanup(&path);
}

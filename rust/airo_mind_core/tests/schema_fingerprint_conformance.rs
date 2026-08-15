//! Schema fingerprint + compatibility classes conformance — `#1226`.
//!
//! Black-box, against `airo_mind_core`'s public API only, the same style as
//! `tests/type_system_conformance.rs`. Proves the four things the issue
//! (and the delegation brief) ask for:
//!
//! 1. Two structurally identical [`EntityTypeDef`]s fingerprint identically.
//! 2. Two structurally different ones fingerprint differently.
//! 3. An additive change (new property) classifies as
//!    [`Compatibility::Compatible`].
//! 4. A breaking change (removed/retyped property) classifies as
//!    [`Compatibility::Breaking`] **and** is actually refused at replay
//!    time by [`Runtime::replay_schema_checked`] — not merely detectable by
//!    calling [`classify`] in isolation.

use airo_mind_core::{
    check_replay_compatible, classify, fingerprint, schema_fingerprint_id, Compatibility,
    CoreEntityType, EntityTypeDef, Primitive, ReplayDecision, ResourceBudget, Runtime,
    RuntimeApiError, SchemaRegistry, Verb,
};

fn temp_log_path(name: &str) -> std::path::PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!(
        "airo_mind_schema_fingerprint_conformance_{name}_{unique}.log"
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

fn doctor_v1() -> EntityTypeDef {
    EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_label("Doctor")
        .with_property("speciality", Primitive::String)
}

// ---------------------------------------------------------------------------
// 1 & 2: fingerprint proves structural identity, not incidental identity
// ---------------------------------------------------------------------------

#[test]
fn structurally_identical_schemas_produce_the_same_fingerprint() {
    let a = doctor_v1();
    let b = doctor_v1();
    assert_eq!(fingerprint(&a), fingerprint(&b));

    // Property insertion order must not matter -- two independently
    // authored capability configs that declare the same properties in a
    // different order are the same schema.
    let c = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_label("Doctor")
        .with_property("speciality", Primitive::String);
    assert_eq!(fingerprint(&a), fingerprint(&c));
}

#[test]
fn structurally_different_schemas_produce_different_fingerprints() {
    let a = doctor_v1();
    let retyped = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_property("speciality", Primitive::Text);
    let extra_property = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_property("speciality", Primitive::String)
        .with_property("clinic", Primitive::Reference);
    let different_lineage = EntityTypeDef::new("Doctor", CoreEntityType::Organization)
        .with_property("speciality", Primitive::String);

    assert_ne!(fingerprint(&a), fingerprint(&retyped));
    assert_ne!(fingerprint(&a), fingerprint(&extra_property));
    assert_ne!(fingerprint(&a), fingerprint(&different_lineage));
}

// ---------------------------------------------------------------------------
// 3: additive change classifies as compatible
// ---------------------------------------------------------------------------

#[test]
fn an_additive_change_a_new_optional_property_is_compatible() {
    let v1 = doctor_v1();
    let v2 = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_property("speciality", Primitive::String)
        .with_property("yearsPracticing", Primitive::Number); // new, additive

    assert_eq!(classify(&v1, &v2), Compatibility::Compatible);
}

// ---------------------------------------------------------------------------
// 4: a breaking change classifies as breaking AND is refused at replay
// ---------------------------------------------------------------------------

#[test]
fn a_removed_property_is_breaking() {
    let v1 = doctor_v1();
    let v2 = EntityTypeDef::new("Doctor", CoreEntityType::Person); // speciality removed
    assert_eq!(classify(&v1, &v2), Compatibility::Breaking);
}

#[test]
fn a_retyped_property_is_breaking() {
    let v1 = doctor_v1();
    let v2 = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_property("speciality", Primitive::Number); // String -> Number
    assert_eq!(classify(&v1, &v2), Compatibility::Breaking);
}

/// The end-to-end claim: a capability wrote real operations under `v1`'s
/// schema fingerprint; the running code now only knows about `v2`, a
/// breaking change from `v1`. `Runtime::replay_schema_checked` must refuse
/// the replay outright rather than silently handing back operations whose
/// stored shape no longer matches what the code expects.
#[test]
fn a_breaking_schema_change_is_refused_at_replay_not_merely_detected() {
    let path = temp_log_path("breaking_replay_refused");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let v1 = doctor_v1();
    let v1_stamped = schema_fingerprint_id(&v1);

    runtime
        .emit_verb_operation(
            "clinic",
            Verb::CreateEntity,
            "doctor-1",
            &[],
            &v1_stamped,
            b"Doctor",
            None,
            1,
        )
        .unwrap();

    // The running capability now only knows about a breaking successor to
    // v1 (speciality retyped) -- register v1 as a known-but-not-current
    // version, per the seam `SchemaRegistry::register_known` exists for.
    let mut registry = SchemaRegistry::new();
    registry.register_known(v1);
    let v2 = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_property("speciality", Primitive::Number);
    registry.register_current(v2);

    // Detected...
    let ops = runtime.replay().unwrap();
    let op = ops.iter().find(|op| op.schema_id == v1_stamped).unwrap();
    assert_eq!(
        registry.decide(&op.schema_id),
        ReplayDecision::Breaking,
        "classify() must see this as a breaking change, not merely different"
    );
    assert!(check_replay_compatible(&registry, &ops).is_err());

    // ...and refused, through the real runtime surface a capability would
    // actually call.
    let err = runtime.replay_schema_checked(&registry).unwrap_err();
    match err {
        RuntimeApiError::SchemaIncompatible(violation) => {
            assert_eq!(violation.seq, op.seq);
            assert_eq!(violation.decision, ReplayDecision::Breaking);
        }
        other => panic!("expected SchemaIncompatible, got {other:?}"),
    }

    // Meanwhile, ordinary `replay()` is untouched -- schema enforcement is
    // opt-in through the new method, not a silent behavior change to the
    // six-function surface every other capability already depends on.
    assert_eq!(runtime.replay().unwrap().len(), 1);

    cleanup(&path);
}

/// The additive counterpart: a compatible schema evolution must **not** be
/// refused at replay -- enforcement rejects incompatibility, not mere
/// difference.
#[test]
fn a_compatible_schema_change_is_not_refused_at_replay() {
    let path = temp_log_path("compatible_replay_allowed");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let v1 = doctor_v1();
    let v1_stamped = schema_fingerprint_id(&v1);
    runtime
        .emit_verb_operation(
            "clinic",
            Verb::CreateEntity,
            "doctor-1",
            &[],
            &v1_stamped,
            b"Doctor",
            None,
            1,
        )
        .unwrap();

    let mut registry = SchemaRegistry::new();
    registry.register_known(v1);
    let v2 = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_property("speciality", Primitive::String)
        .with_property("yearsPracticing", Primitive::Number); // additive only
    registry.register_current(v2);

    let ops = runtime.replay_schema_checked(&registry).unwrap();
    assert_eq!(ops.len(), 1);
}

/// Operations that never adopted a typed schema (`schema_id` empty, exactly
/// what every pre-`#1223` capability -- Notes included -- still emits) are
/// never checked at all: `#1226` is additive, not a retrofit that would
/// break every existing capability's replay the moment this method exists.
#[test]
fn untyped_operations_are_never_checked_and_never_refused() {
    let path = temp_log_path("untyped_passthrough");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    runtime
        .emit_operation("notes", "note.create", b"hello", 1)
        .unwrap();

    let registry = SchemaRegistry::new(); // nothing registered at all
    let ops = runtime.replay_schema_checked(&registry).unwrap();
    assert_eq!(ops.len(), 1);

    cleanup(&path);
}

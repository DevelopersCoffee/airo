//! Type system conformance — `#1223`: primitives, archetypes, core ontology.
//!
//! Black-box, against `airo_mind_core`'s public API only, the same style as
//! `tests/operation_log_and_projection_conformance.rs`. Proves the four
//! things the issue asks for, plus the additive claim: a typed [`Value`]
//! integrates with the already-shipped [`Runtime`] / [`EntityGraphProjection`]
//! (`#1194`/`#1195`) through the existing `encode_set_property` seam, with no
//! change to either's wire format.

use airo_mind_core::{
    parse_extends, validate_relation_endpoints, validate_user_facing_label, Archetype,
    CoreEntityType, EntityGraphProjection, EntityTypeDef, OntologyError, Primitive, ResourceBudget,
    Runtime, Value, Verb,
};

fn temp_log_path(name: &str) -> std::path::PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!(
        "airo_mind_type_system_conformance_{name}_{unique}.log"
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

// ---------------------------------------------------------------------------
// Primitives type-check correctly
// ---------------------------------------------------------------------------

#[test]
fn a_doctor_entity_type_rejects_a_wrong_shaped_speciality() {
    let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_label("Doctor")
        .with_label("Clinician")
        .with_property("speciality", Primitive::String);

    assert!(doctor
        .validate_property("speciality", &Value::Str("Cardiology".to_string()))
        .is_ok());
    assert!(doctor
        .validate_property("speciality", &Value::Number(42.0))
        .is_err());
}

// ---------------------------------------------------------------------------
// Archetypes can be composed from primitives
// ---------------------------------------------------------------------------

#[test]
fn a_capability_entity_composes_multiple_primitives_under_one_core_type() {
    let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_property("speciality", Primitive::String)
        .with_property("boardCertified", Primitive::Bool)
        .with_property("yearsPracticing", Primitive::Number)
        .with_property("clinic", Primitive::Reference)
        .with_property("languages", Primitive::List);

    assert_eq!(doctor.extends, CoreEntityType::Person);
    assert_eq!(doctor.extends.extends(), Archetype::Actor);

    assert!(doctor
        .validate_property("speciality", &Value::Str("Cardiology".to_string()))
        .is_ok());
    assert!(doctor
        .validate_property("boardCertified", &Value::Bool(true))
        .is_ok());
    assert!(doctor
        .validate_property("yearsPracticing", &Value::Number(9.0))
        .is_ok());
    assert!(doctor
        .validate_property("clinic", &Value::Reference("clinic-1".to_string()))
        .is_ok());
    assert!(doctor
        .validate_property(
            "languages",
            &Value::List(vec![Value::Str("en".to_string())])
        )
        .is_ok());
}

// ---------------------------------------------------------------------------
// The ontology's relationship rules are enforced, not just declared
// ---------------------------------------------------------------------------

#[test]
fn extending_an_archetype_directly_is_rejected_by_a_real_check() {
    // The design-doc "Rule": capability entities extend the core ontology
    // only, never an archetype directly. `EntityTypeDef::extends` makes this
    // impossible to construct in Rust; `parse_extends` is the boundary that
    // enforces the same rule against a capability's own config data.
    assert_eq!(
        parse_extends("Actor"),
        Err(OntologyError::CannotExtendArchetypeDirectly(
            "Actor".to_string()
        ))
    );
    assert_eq!(parse_extends("Person"), Ok(CoreEntityType::Person));
}

#[test]
fn an_archetype_name_cannot_be_used_as_a_user_facing_label() {
    // "Archetypes... never appear in user data" enforced, not just stated.
    assert!(validate_user_facing_label("Actor").is_err());
    assert!(validate_user_facing_label("Doctor").is_ok());
}

#[test]
fn relation_endpoints_must_both_resolve_through_the_core_ontology() {
    let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person);
    let clinic = EntityTypeDef::new("Clinic", CoreEntityType::Organization);
    assert!(validate_relation_endpoints(&doctor, &clinic).is_ok());
}

// ---------------------------------------------------------------------------
// Round-trip through serialization (the operation-log wire format)
// ---------------------------------------------------------------------------

#[test]
fn every_primitive_value_round_trips_through_encode_decode() {
    let samples = vec![
        Value::Str("Cardiology".to_string()),
        Value::Text("a much longer revisable note body".to_string()),
        Value::Bool(true),
        Value::Number(98.6),
        Value::Datetime(1_723_000_000_000),
        Value::Reference("patient-1".to_string()),
        Value::Blob(vec![1, 2, 3]),
        Value::List(vec![
            Value::Str("en".to_string()),
            Value::Str("hi".to_string()),
        ]),
        Value::Set(vec![Value::Str("cardiology".to_string())]),
    ];
    for value in samples {
        let encoded = value.encode();
        let decoded = Value::decode(&encoded).expect("round-trip must decode");
        assert_eq!(decoded, value);
        assert_eq!(decoded.primitive(), value.primitive());
    }
}

// ---------------------------------------------------------------------------
// Additive integration: typed values ride the existing #1194/#1195 substrate
// ---------------------------------------------------------------------------

/// The additive claim made concrete: a capability encodes a typed [`Value`]
/// and hands its bytes to the same `SetProperty` verb / `EntityGraphProjection`
/// that shipped in `#1194`/`#1195`, unmodified. Nothing about the runtime
/// or projection engine's wire format changed for `#1223` to exist.
#[test]
fn a_typed_value_flows_through_the_existing_runtime_and_projection_unmodified() {
    let path = temp_log_path("typed_value_flow");
    let runtime = Runtime::boot(ResourceBudget::new(2048), &path).unwrap();

    let doctor = EntityTypeDef::new("Doctor", CoreEntityType::Person)
        .with_label("Doctor")
        .with_property("speciality", Primitive::String);

    let speciality = Value::Str("Cardiology".to_string());
    doctor
        .validate_property("speciality", &speciality)
        .expect("well-typed value must validate before it is emitted");

    runtime
        .emit_verb_operation(
            "clinic",
            Verb::CreateEntity,
            "doctor-1",
            &[],
            &doctor.schema_id(),
            b"Doctor",
            None,
            1,
        )
        .unwrap();
    runtime
        .emit_verb_operation(
            "clinic",
            Verb::SetProperty,
            "doctor-1",
            &[],
            &doctor.schema_id(),
            &airo_mind_core::encode_set_property("speciality", &speciality.encode()),
            None,
            2,
        )
        .unwrap();

    let graph: EntityGraphProjection = runtime.query_projection().unwrap();
    let record = graph.get("doctor-1").unwrap();
    assert_eq!(record.label, "Doctor");

    let stored_bytes = record.properties.get("speciality").unwrap();
    let decoded = Value::decode(stored_bytes).unwrap();
    assert_eq!(decoded, Value::Str("Cardiology".to_string()));

    // The operation carries #1223's schema-id seam for #1226 to build on.
    let ops = runtime.replay().unwrap();
    assert!(ops.iter().any(|op| op.schema_id == "capability.Doctor"));

    cleanup(&path);
}

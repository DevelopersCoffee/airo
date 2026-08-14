//! Guards against `schema.rs` and `schema/meeting_ir.v1.schema.json`
//! silently drifting apart. Not a general JSON-Schema validator (adding a
//! `jsonschema` crate dependency for one structural check was not worth it)
//! -- a targeted comparison of the property names on each side, which is
//! exactly the kind of drift a hand-maintained companion file actually
//! suffers from in practice.

use std::collections::BTreeSet;

use airo_mind_extract::{ActionItem, Fact, MeetingIr, MeetingMeta, SCHEMA_VERSION};

fn published_schema() -> serde_json::Value {
    let raw = include_str!("../schema/meeting_ir.v1.schema.json");
    serde_json::from_str(raw).expect("schema/meeting_ir.v1.schema.json is valid JSON")
}

fn top_level_properties(schema: &serde_json::Value) -> BTreeSet<String> {
    schema["properties"]
        .as_object()
        .expect("schema has a top-level properties object")
        .keys()
        .cloned()
        .collect()
}

fn sample_ir() -> MeetingIr {
    MeetingIr {
        schema_version: SCHEMA_VERSION.to_string(),
        meeting: MeetingMeta {
            title: Some("Standup".into()),
            chunk_count: 2,
        },
        topics: vec![],
        observations: vec![],
        decisions: vec![Fact {
            id: "d0".into(),
            text: "ship it".into(),
            evidence: vec!["s0".into()],
        }],
        action_items: vec![ActionItem {
            id: "a0".into(),
            text: "own the rollout".into(),
            owner: Some("Raj".into()),
            evidence: vec!["s1".into()],
        }],
        metrics: vec![],
        risks: vec![],
        questions: vec![],
        next_steps: vec![],
    }
}

#[test]
fn published_json_schema_names_the_same_top_level_categories_as_the_rust_type() {
    let schema = published_schema();
    let schema_props = top_level_properties(&schema);

    let ir = sample_ir();
    let value = serde_json::to_value(&ir).unwrap();
    let rust_props: BTreeSet<String> = value.as_object().unwrap().keys().cloned().collect();

    assert_eq!(
        schema_props, rust_props,
        "schema/meeting_ir.v1.schema.json's top-level properties must match MeetingIr's serialized field names exactly"
    );
}

#[test]
fn published_schema_version_constant_matches_the_document() {
    let schema = published_schema();
    let published_const = schema["properties"]["schema_version"]["const"]
        .as_str()
        .unwrap();
    assert_eq!(published_const, SCHEMA_VERSION);
}

#[test]
fn a_real_meeting_ir_serializes_without_extraneous_fields_the_schema_would_reject() {
    // additionalProperties: false in the schema means every emitted key must
    // be one it names -- a regression here (a stray debug field, an id that
    // should have been dropped) shows up as a mismatch against
    // `top_level_properties`'s companion assertion above for nested objects
    // too, spot-checked on one action item.
    let ir = sample_ir();
    let value = serde_json::to_value(&ir).unwrap();
    let action_item = &value["action_items"][0];
    let allowed: BTreeSet<&str> = ["id", "text", "owner", "evidence"].into_iter().collect();
    let actual: BTreeSet<&str> = action_item
        .as_object()
        .unwrap()
        .keys()
        .map(String::as_str)
        .collect();
    assert_eq!(allowed, actual);
}

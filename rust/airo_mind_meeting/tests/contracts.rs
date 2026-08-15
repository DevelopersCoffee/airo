//! The two contracts this crate publishes to things it cannot compile against:
//! the GBNF grammar (consumed by llama.cpp) and the JSON Schema (consumed by
//! validators and by MIND-LLM-11's eval harness).
//!
//! Both are plain text files. Nothing in the Rust type system stops either one
//! drifting from `ir.rs`, so the checks are here instead.

use std::collections::BTreeSet;

use airo_mind_meeting::ir::{
    ActionItem, ActionStatus, Decision, DecisionStatus, Facts, Meeting, MeetingIr, Metric,
    NextStep, Observation, Question, Risk, Topic,
};
use airo_mind_meeting::{CHUNK_FACTS_GRAMMAR, IR_SCHEMA_VERSION, PROMPT_VERSION};
use serde_json::Value;

// ---------------------------------------------------------------------------
// GBNF
// ---------------------------------------------------------------------------

/// Splits a GBNF file into (rule name, right-hand side), ignoring `#` comments.
///
/// A rule's body continues onto following lines until the next `name ::=`, which
/// is how `root` is written across several lines in the grammar file.
fn rules(grammar: &str) -> Vec<(String, String)> {
    let mut rules: Vec<(String, String)> = Vec::new();
    for line in grammar.lines() {
        let line = match line.split_once('#') {
            Some((before, _)) => before,
            None => line,
        }
        .trim_end();
        if line.trim().is_empty() {
            continue;
        }
        match line.split_once("::=") {
            Some((name, body))
                if !name.trim().is_empty() && !name.starts_with(char::is_whitespace) =>
            {
                rules.push((name.trim().to_string(), body.to_string()));
            }
            _ => {
                if let Some(last) = rules.last_mut() {
                    last.1.push(' ');
                    last.1.push_str(line);
                }
            }
        }
    }
    rules
}

/// Every rule name referenced in a right-hand side.
///
/// Skips quoted literals (`"\"topics\":"` contains no rule references) and
/// character classes (`[a-fA-F]` is not a reference to a rule called `a`).
fn references(body: &str) -> BTreeSet<String> {
    let mut found = BTreeSet::new();
    let chars: Vec<char> = body.chars().collect();
    let mut i = 0;
    while i < chars.len() {
        match chars[i] {
            '"' => {
                i += 1;
                while i < chars.len() && chars[i] != '"' {
                    i += if chars[i] == '\\' { 2 } else { 1 };
                }
                i += 1;
            }
            '[' => {
                i += 1;
                while i < chars.len() && chars[i] != ']' {
                    i += if chars[i] == '\\' { 2 } else { 1 };
                }
                i += 1;
            }
            c if c.is_ascii_alphabetic() => {
                let start = i;
                while i < chars.len() && (chars[i].is_ascii_alphanumeric() || chars[i] == '-') {
                    i += 1;
                }
                found.insert(chars[start..i].iter().collect::<String>());
            }
            _ => i += 1,
        }
    }
    found
}

#[test]
fn the_grammar_defines_the_root_symbol_the_engine_looks_for() {
    // `LlamaGenerationEngine` builds its sampler with the start symbol `root`
    // (`GRAMMAR_ROOT` in `airo_mind_llama/src/llama.rs`). A grammar without one
    // fails at generation time, on device, with a model already loaded.
    let names: BTreeSet<String> = rules(CHUNK_FACTS_GRAMMAR)
        .into_iter()
        .map(|(name, _)| name)
        .collect();
    assert!(names.contains("root"), "defined rules: {names:?}");
}

#[test]
fn every_rule_the_grammar_references_is_defined_and_every_rule_is_reachable() {
    let rules = rules(CHUNK_FACTS_GRAMMAR);
    let defined: BTreeSet<String> = rules.iter().map(|(name, _)| name.clone()).collect();
    let referenced: BTreeSet<String> = rules
        .iter()
        .flat_map(|(_, body)| references(body))
        .collect();

    let undefined: Vec<&String> = referenced.difference(&defined).collect();
    assert!(
        undefined.is_empty(),
        "referenced but never defined: {undefined:?}"
    );

    let unreachable: Vec<&String> = defined
        .iter()
        .filter(|name| name.as_str() != "root" && !referenced.contains(*name))
        .collect();
    assert!(
        unreachable.is_empty(),
        "defined but never used: {unreachable:?}"
    );
}

#[test]
fn the_grammar_names_every_category_the_ir_has() {
    let root = rules(CHUNK_FACTS_GRAMMAR)
        .into_iter()
        .find(|(name, _)| name == "root")
        .expect("root rule")
        .1;
    for category in [
        "topics",
        "observations",
        "decisions",
        "action_items",
        "metrics",
        "risks",
        "questions",
        "next_steps",
    ] {
        assert!(
            root.contains(&format!("\\\"{category}\\\":")),
            "`root` does not emit `{category}`"
        );
    }
}

#[test]
fn the_grammar_makes_an_uncited_item_inexpressible() {
    let evidence = rules(CHUNK_FACTS_GRAMMAR)
        .into_iter()
        .find(|(name, _)| name == "evidence")
        .expect("evidence rule")
        .1;
    // `"[" ws string (…)* ws "]"` — one `string` is mandatory. An optional
    // group (`(string …)?`) here would let the model emit `"evidence": []`,
    // which is the one thing grounding exists to prevent.
    assert!(
        !evidence.contains("(string"),
        "`evidence` must require at least one segment id, got: {evidence}"
    );
    assert!(evidence.contains("ws string"));
}

#[test]
fn the_grammar_offers_no_id_field_for_the_model_to_invent() {
    assert!(
        !CHUNK_FACTS_GRAMMAR.contains("\\\"id\\\":"),
        "item ids are assigned by this crate, never sampled"
    );
}

#[test]
fn the_grammars_statuses_are_exactly_the_ones_serde_accepts() {
    let body = |name: &str| {
        rules(CHUNK_FACTS_GRAMMAR)
            .into_iter()
            .find(|(rule, _)| rule == name)
            .unwrap_or_else(|| panic!("`{name}` rule"))
            .1
    };

    let decision = body("decision-status");
    for status in [
        DecisionStatus::Proposed,
        DecisionStatus::Agreed,
        DecisionStatus::Rejected,
        DecisionStatus::Deferred,
    ] {
        let wire = serde_json::to_string(&status).unwrap();
        assert!(
            decision.contains(&wire.replace('"', "\\\"")),
            "`decision-status` cannot produce {wire}"
        );
    }

    let action = body("action-status");
    for status in [
        ActionStatus::Open,
        ActionStatus::InProgress,
        ActionStatus::Done,
        ActionStatus::Blocked,
    ] {
        let wire = serde_json::to_string(&status).unwrap();
        assert!(
            action.contains(&wire.replace('"', "\\\"")),
            "`action-status` cannot produce {wire}"
        );
    }
}

// ---------------------------------------------------------------------------
// JSON Schema
// ---------------------------------------------------------------------------

const SCHEMA: &str = include_str!("../schemas/meeting_ir.schema.json");

fn schema() -> Value {
    serde_json::from_str(SCHEMA).expect("the published schema is valid JSON")
}

/// One of every item, every optional field populated, so key-set comparison
/// sees the full shape rather than whatever `#[serde(skip)]` might have hidden.
fn fully_populated_ir() -> MeetingIr {
    let evidence = || vec!["s0".to_string()];
    MeetingIr {
        schema_version: IR_SCHEMA_VERSION.to_string(),
        meeting: Meeting {
            id: "meeting-0".into(),
            title: Some("Signaling capacity review".into()),
            started_at_ms: 0,
            ended_at_ms: 59_500,
            chunk_count: 4,
            segment_count: 12,
            model_id: Some("model@1".into()),
            prompt_version: PROMPT_VERSION.into(),
        },
        facts: Facts {
            topics: vec![Topic {
                id: "topic-0".into(),
                title: "signalling".into(),
                evidence: evidence(),
            }],
            observations: vec![Observation {
                id: "observation-0".into(),
                statement: "the workflow is at capacity".into(),
                evidence: evidence(),
            }],
            decisions: vec![Decision {
                id: "decision-0".into(),
                statement: "move signalling onto the queue".into(),
                status: DecisionStatus::Agreed,
                evidence: evidence(),
            }],
            action_items: vec![ActionItem {
                id: "action_item-0".into(),
                task: "update the runbook".into(),
                owner: Some("Dev".into()),
                due: Some("Friday".into()),
                status: ActionStatus::Done,
                evidence: evidence(),
            }],
            metrics: vec![Metric {
                id: "metric-0".into(),
                name: "signals per day".into(),
                value: "about 500,000".into(),
                evidence: evidence(),
            }],
            risks: vec![Risk {
                id: "risk-0".into(),
                statement: "the migration doubles the event volume".into(),
                evidence: evidence(),
            }],
            questions: vec![Question {
                id: "question-0".into(),
                question: "what is the documented limit?".into(),
                answer: Some("nobody knew".into()),
                evidence: evidence(),
            }],
            next_steps: vec![NextStep {
                id: "next_step-0".into(),
                statement: "review the rollout plan".into(),
                evidence: evidence(),
            }],
        },
    }
}

fn keys(value: &Value) -> BTreeSet<String> {
    value.as_object().expect("object").keys().cloned().collect()
}

fn schema_keys(definition: &Value) -> BTreeSet<String> {
    keys(&definition["properties"])
}

fn required(definition: &Value) -> BTreeSet<String> {
    definition["required"]
        .as_array()
        .expect("required")
        .iter()
        .map(|v| v.as_str().expect("string").to_string())
        .collect()
}

#[test]
fn the_published_schema_declares_the_version_the_types_stamp() {
    let schema = schema();
    assert_eq!(
        schema["$id"].as_str().unwrap(),
        format!("https://airo.app/schemas/meeting_ir/{IR_SCHEMA_VERSION}")
    );
    assert_eq!(
        schema["properties"]["schema_version"]["const"]
            .as_str()
            .unwrap(),
        IR_SCHEMA_VERSION
    );
}

#[test]
fn the_schemas_top_level_matches_what_the_types_serialize() {
    let schema = schema();
    let serialized = serde_json::to_value(fully_populated_ir()).unwrap();

    assert_eq!(
        schema_keys(&schema),
        keys(&serialized),
        "schema properties and serialized keys disagree"
    );
    // Everything is required: `Facts`' categories serialize as `[]` rather than
    // being omitted, so a document missing one is a document produced by
    // something other than this crate.
    assert_eq!(required(&schema), keys(&serialized));
}

#[test]
fn every_item_type_matches_its_definition_in_the_schema() {
    let schema = schema();
    let serialized = serde_json::to_value(fully_populated_ir()).unwrap();

    let cases = [
        ("meeting", "meeting"),
        ("topics", "topic"),
        ("observations", "observation"),
        ("decisions", "decision"),
        ("action_items", "action_item"),
        ("metrics", "metric"),
        ("risks", "risk"),
        ("questions", "question"),
        ("next_steps", "next_step"),
    ];

    for (field, definition_name) in cases {
        let definition = &schema["$defs"][definition_name];
        assert!(
            definition.is_object(),
            "the schema has no `$defs/{definition_name}`"
        );
        let value = match &serialized[field] {
            Value::Array(items) => items.first().expect("populated fixture").clone(),
            object => object.clone(),
        };
        assert_eq!(
            schema_keys(definition),
            keys(&value),
            "`{definition_name}` properties disagree with `{field}`"
        );
        assert_eq!(
            required(definition),
            keys(&value),
            "`{definition_name}` required-set disagrees with `{field}`"
        );
    }
}

#[test]
fn the_schema_refuses_fields_it_does_not_describe() {
    let schema = schema();
    assert_eq!(schema["additionalProperties"], Value::Bool(false));
    for (name, definition) in schema["$defs"].as_object().unwrap() {
        if definition.get("properties").is_some() {
            assert_eq!(
                definition["additionalProperties"],
                Value::Bool(false),
                "`$defs/{name}` would accept undescribed fields"
            );
        }
    }
}

#[test]
fn the_schema_requires_evidence_on_every_item() {
    let schema = schema();
    assert_eq!(schema["$defs"]["evidence"]["minItems"], Value::from(1));
    for (name, definition) in schema["$defs"].as_object().unwrap() {
        if name == "evidence" || name == "id" || name == "meeting" {
            continue;
        }
        assert!(
            required(definition).contains("evidence"),
            "`$defs/{name}` does not require evidence"
        );
    }
}

#[test]
fn the_golden_ir_fixture_validates_against_the_shape_the_schema_describes() {
    // Not a full JSON Schema validation -- that would mean a new dependency for
    // one assertion. This checks the part that actually drifts: that every
    // object in the golden document carries exactly the keys the schema names.
    let schema = schema();
    let golden: Value = serde_json::from_str(include_str!("fixtures/golden_ir.json")).unwrap();

    assert_eq!(keys(&golden), schema_keys(&schema));
    assert_eq!(
        keys(&golden["meeting"]),
        schema_keys(&schema["$defs"]["meeting"])
    );

    for (field, definition_name) in [
        ("topics", "topic"),
        ("observations", "observation"),
        ("decisions", "decision"),
        ("action_items", "action_item"),
        ("metrics", "metric"),
        ("risks", "risk"),
        ("questions", "question"),
        ("next_steps", "next_step"),
    ] {
        for item in golden[field].as_array().unwrap() {
            assert_eq!(
                keys(item),
                schema_keys(&schema["$defs"][definition_name]),
                "golden `{field}` item does not match `$defs/{definition_name}`"
            );
            assert!(
                !item["evidence"].as_array().unwrap().is_empty(),
                "golden `{field}` item cites nothing"
            );
        }
    }
}

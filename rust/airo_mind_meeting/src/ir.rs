//! The Meeting IR. `#1633`.
//!
//! One versioned, evidence-grounded structure that every downstream meeting
//! surface — minutes, action-item lists, search — is a *projection* of. The
//! LLM never writes prose here: Pass 1 extracts atomic facts, Pass 2
//! consolidates them, and neither pass produces a summary.
//!
//! # Evidence is segment ids, not snippets
//!
//! The issue allows "optionally short snippets; privacy-aware". This schema
//! carries segment ids only, on purpose. A snippet is a verbatim copy of
//! `secret`-class transcript text, and copying it into the IR means every
//! projection, export and index that touches the IR now carries meeting
//! speech it did not need. A segment id is a pointer: a caller that legitimately
//! wants the words looks them up in the transcript it already holds, under
//! whatever access rules apply there. Grounding is not weakened by this — the
//! id is what makes the claim checkable, the snippet is only a convenience.
//!
//! # Ids are assigned by this crate, never by the model
//!
//! Item `id`s are `#[serde(default)]` and are overwritten after parsing (Pass 1
//! assigns chunk-scoped ids, Pass 2 assigns meeting-scoped ones). A model that
//! invents ids cannot collide with, overwrite or forge another item's identity,
//! and the extraction grammar does not even offer it the field.

use serde::{Deserialize, Serialize};

/// The IR contract version. Bump the major on any change that an existing
/// reader could misinterpret; the minor on additive fields.
///
/// Kept in lockstep with `schemas/meeting_ir.schema.json`'s `$id` — a test
/// asserts the two agree, so the published schema can never silently describe
/// a different version than the types.
pub const IR_SCHEMA_VERSION: &str = "1.0.0";

/// What a decision was, at the last point the transcript mentioned it.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, Default, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum DecisionStatus {
    /// Raised, not settled. The default: silence is not agreement.
    #[default]
    Proposed,
    Agreed,
    Rejected,
    Deferred,
}

/// Where an action item stood at the last point the transcript mentioned it.
#[derive(Serialize, Deserialize, Clone, Copy, Debug, Default, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ActionStatus {
    #[default]
    Open,
    InProgress,
    Done,
    Blocked,
}

/// A subject the meeting spent time on.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct Topic {
    #[serde(default)]
    pub id: String,
    pub title: String,
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// A stated fact that is not a decision, action, metric, risk or question —
/// the catch-all for "someone said this and it matters".
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct Observation {
    #[serde(default)]
    pub id: String,
    pub statement: String,
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// Something the meeting settled (or explicitly did not).
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct Decision {
    #[serde(default)]
    pub id: String,
    pub statement: String,
    #[serde(default)]
    pub status: DecisionStatus,
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// Work someone is expected to do after the meeting.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct ActionItem {
    #[serde(default)]
    pub id: String,
    pub task: String,
    /// `None` when the transcript names nobody. **Never inferred.** Pass 1
    /// drops any owner whose name does not literally appear in the chunk the
    /// item came from — see `pass1::ground_owner`.
    #[serde(default)]
    pub owner: Option<String>,
    /// Whatever the transcript said, as it said it ("Friday", "end of the
    /// quarter"). Not parsed into a date: resolving "Friday" needs a meeting
    /// date and a timezone this crate does not have, and a wrong date is worse
    /// than the words that were actually spoken.
    #[serde(default)]
    pub due: Option<String>,
    #[serde(default)]
    pub status: ActionStatus,
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// A number the meeting quoted. `value` stays a string for the same reason
/// `due` does — "about 500,000", "2x", "under a second" are all real answers
/// and none of them is an `f64`.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct Metric {
    #[serde(default)]
    pub id: String,
    pub name: String,
    pub value: String,
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// Something that could go wrong, as stated.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct Risk {
    #[serde(default)]
    pub id: String,
    pub statement: String,
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// Something asked. `answer` is `None` when the transcript never answered it —
/// an open question is a result, not a gap to fill in.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct Question {
    #[serde(default)]
    pub id: String,
    pub question: String,
    #[serde(default)]
    pub answer: Option<String>,
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// What happens next, where nobody was named and no task was assigned. An
/// action item with an owner belongs in `action_items`.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct NextStep {
    #[serde(default)]
    pub id: String,
    pub statement: String,
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// The eight fact categories, shared by the per-chunk IR (Pass 1) and the
/// consolidated meeting IR (Pass 2). One type, so a category can never exist
/// in one pass and be forgotten in the other.
///
/// Every field is `#[serde(default)]`: a chunk that contains no risks emits
/// `"risks": []`, but a hand-written fixture or an older payload that omits the
/// key entirely is still readable rather than a parse error.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct Facts {
    #[serde(default)]
    pub topics: Vec<Topic>,
    #[serde(default)]
    pub observations: Vec<Observation>,
    #[serde(default)]
    pub decisions: Vec<Decision>,
    #[serde(default)]
    pub action_items: Vec<ActionItem>,
    #[serde(default)]
    pub metrics: Vec<Metric>,
    #[serde(default)]
    pub risks: Vec<Risk>,
    #[serde(default)]
    pub questions: Vec<Question>,
    #[serde(default)]
    pub next_steps: Vec<NextStep>,
}

impl Facts {
    /// Total items across every category. Used by tests and diagnostics; not
    /// a quality signal on its own.
    pub fn len(&self) -> usize {
        self.topics.len()
            + self.observations.len()
            + self.decisions.len()
            + self.action_items.len()
            + self.metrics.len()
            + self.risks.len()
            + self.questions.len()
            + self.next_steps.len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

/// Pass 1's output for one chunk: the facts the model extracted from it, still
/// scoped to that chunk and not yet deduped against any other.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct ChunkIr {
    pub chunk_id: String,
    /// The segment ids this chunk covered. Retained so a consumer can check
    /// grounding without holding the transcript.
    #[serde(default)]
    pub segment_ids: Vec<String>,
    #[serde(flatten)]
    pub facts: Facts,
}

/// What the IR is about and what produced it.
///
/// None of this is extracted by the model — it is either supplied by the
/// caller (id, title) or derived from the transcript (`chunk_count`, span).
/// `ADR-0018 §5`: content records what produced it, so `model_id` and
/// `prompt_version` travel with the IR rather than being reconstructed later.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct Meeting {
    pub id: String,
    #[serde(default)]
    pub title: Option<String>,
    pub started_at_ms: u64,
    pub ended_at_ms: u64,
    pub chunk_count: u32,
    pub segment_count: u32,
    /// The logical model id and version, as `airo_mind_llama` reports it.
    /// `None` when extraction ran against a double (tests) or the caller did
    /// not record one — an absent provenance is stated, never invented.
    #[serde(default)]
    pub model_id: Option<String>,
    /// The extraction prompt template version that produced this IR.
    pub prompt_version: String,
}

/// The consolidated meeting IR: one `Meeting` and one set of deduped,
/// evidence-grounded facts.
#[derive(Serialize, Deserialize, Clone, Debug, Default, PartialEq, Eq)]
pub struct MeetingIr {
    /// Always [`IR_SCHEMA_VERSION`] on write. Present on the wire so a reader
    /// can refuse a payload it does not understand instead of guessing.
    pub schema_version: String,
    pub meeting: Meeting,
    #[serde(flatten)]
    pub facts: Facts,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_action_item_with_no_owner_round_trips_as_null() {
        let item = ActionItem {
            id: "action-0".into(),
            task: "check the Temporal signalling limit".into(),
            owner: None,
            due: None,
            status: ActionStatus::Open,
            evidence: vec!["s3".into()],
        };
        let json = serde_json::to_string(&item).unwrap();
        assert!(json.contains("\"owner\":null"), "{json}");

        let back: ActionItem = serde_json::from_str(&json).unwrap();
        assert_eq!(back, item);
    }

    #[test]
    fn a_missing_category_reads_as_empty_rather_than_failing() {
        let facts: Facts = serde_json::from_str("{\"decisions\":[]}").unwrap();
        assert!(facts.is_empty());
    }

    #[test]
    fn statuses_are_snake_case_on_the_wire() {
        let json = serde_json::to_string(&ActionStatus::InProgress).unwrap();
        assert_eq!(json, "\"in_progress\"");
    }

    #[test]
    fn the_meeting_ir_flattens_its_categories_to_the_top_level() {
        let ir = MeetingIr {
            schema_version: IR_SCHEMA_VERSION.into(),
            meeting: Meeting::default(),
            facts: Facts::default(),
        };
        let value: serde_json::Value = serde_json::to_value(&ir).unwrap();
        for key in [
            "meeting",
            "topics",
            "observations",
            "decisions",
            "action_items",
            "metrics",
            "risks",
            "questions",
            "next_steps",
        ] {
            assert!(value.get(key).is_some(), "missing `{key}`");
        }
    }
}

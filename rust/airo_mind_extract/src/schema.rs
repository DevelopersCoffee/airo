//! Meeting IR: the fixed, versioned schema every extraction pass produces.
//!
//! `#1633`, per the epic's central rule (`#1627`): "the LLM never summarizes
//! the transcript directly. Meeting IR with per-fact evidence is the
//! product; MoM/action-items/search are projections of it." Every item below
//! carries `evidence` — the segment ids (from `#1632`'s chunks, ultimately
//! from `#1629`'s ASR segments) that back it. A fact with no evidence is not
//! a fact this crate will emit.
//!
//! Two shapes live here, not one:
//!
//! - [`ChunkFacts`] is pass 1's output: candidate facts from ONE chunk, no
//!   identity beyond their evidence, because a chunk cannot know whether its
//!   "check the Temporal signalling limit" is the same fact as another
//!   chunk's "confirm Temporal signalling capacity" — only pass 2, looking
//!   at all chunks together, can decide that.
//! - [`MeetingIr`] is pass 2's output: the same categories, deduplicated
//!   across every chunk, each item now carrying a stable `id` a projection
//!   (MoM, action-item list, search index) can reference.
//!
//! JSON Schema for both is published at `schema/meeting_ir.v1.schema.json` in
//! this crate, generated from these types by `tests/schema_matches_json_schema.rs`
//! so the two cannot silently drift apart.

use serde::{Deserialize, Serialize};

/// The schema version every [`MeetingIr`] declares. Bump this — and add a
/// new file under `schema/` — on any breaking change to the categories or
/// item shapes below. `#1636`'s eval harness and `#1657`'s persistence layer
/// both read this field before trusting anything else in the document.
pub const SCHEMA_VERSION: &str = "1.0";

/// One fact with no further structure: a topic, observation, decision,
/// metric, risk, question, or next step. `action_items` is the one category
/// with an extra field (`owner`), so it gets its own type below.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Fact {
    /// Present only on a [`MeetingIr`] item, absent (defaulted to empty) on
    /// a [`ChunkFacts`] candidate — pass 1 does not assign identity, pass 2
    /// does. Kept on one shared type rather than two near-identical structs
    /// because every other field is identical and the alternative is a
    /// `From` impl that just copies five fields.
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub id: String,
    pub text: String,
    /// Segment ids from `#1632`'s chunks. Never empty on a validated
    /// [`ChunkFacts`] (see `extract::validate`) and never invented — a fact
    /// pass 1 could not tie to a segment id is a fact this crate drops, not
    /// one it emits with guessed evidence.
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// An action item: a [`Fact`] plus an owner, which is `None` — never a
/// guessed name — when the transcript does not name one. This is the
/// milestone's single most load-bearing trust rule (`#1634`'s
/// no-invented-owners validator exists because of exactly this field); see
/// `extract::validate_owner_is_grounded`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ActionItem {
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub id: String,
    pub text: String,
    #[serde(default)]
    pub owner: Option<String>,
    #[serde(default)]
    pub evidence: Vec<String>,
}

/// Pass 1's output: what one chunk's extraction produced, before
/// consolidation. No `meeting` metadata, no `schema_version` — those only
/// mean something once every chunk's candidates have been merged.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ChunkFacts {
    #[serde(default)]
    pub topics: Vec<Fact>,
    #[serde(default)]
    pub observations: Vec<Fact>,
    #[serde(default)]
    pub decisions: Vec<Fact>,
    #[serde(default)]
    pub action_items: Vec<ActionItem>,
    #[serde(default)]
    pub metrics: Vec<Fact>,
    #[serde(default)]
    pub risks: Vec<Fact>,
    #[serde(default)]
    pub questions: Vec<Fact>,
    #[serde(default)]
    pub next_steps: Vec<Fact>,
}

impl ChunkFacts {
    /// `true` when every category is empty — a chunk that discussed nothing
    /// extractable (small talk, a pause) is a valid outcome, not an error.
    pub fn is_empty(&self) -> bool {
        self.topics.is_empty()
            && self.observations.is_empty()
            && self.decisions.is_empty()
            && self.action_items.is_empty()
            && self.metrics.is_empty()
            && self.risks.is_empty()
            && self.questions.is_empty()
            && self.next_steps.is_empty()
    }
}

/// Meeting-level metadata. Deliberately thin: this crate extracts from a
/// transcript, it does not know the meeting's calendar title or attendee
/// list — those are `#1657`'s job to attach from outside.
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct MeetingMeta {
    #[serde(default)]
    pub title: Option<String>,
    /// How many chunks pass 2 consolidated. Not evidence for any single
    /// fact — a coverage number, useful for judging whether extraction saw
    /// the whole transcript.
    pub chunk_count: u32,
}

/// Pass 2's output and this crate's product: the whole meeting, deduplicated,
/// every item addressable by a stable `id`. `MoM`, an action-item list, and
/// search results are all projections of this document (`#1627`), never of
/// the raw transcript.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct MeetingIr {
    pub schema_version: String,
    pub meeting: MeetingMeta,
    #[serde(default)]
    pub topics: Vec<Fact>,
    #[serde(default)]
    pub observations: Vec<Fact>,
    #[serde(default)]
    pub decisions: Vec<Fact>,
    #[serde(default)]
    pub action_items: Vec<ActionItem>,
    #[serde(default)]
    pub metrics: Vec<Fact>,
    #[serde(default)]
    pub risks: Vec<Fact>,
    #[serde(default)]
    pub questions: Vec<Fact>,
    #[serde(default)]
    pub next_steps: Vec<Fact>,
}

impl MeetingIr {
    /// Total number of items across every category. Used by the CLI/tests
    /// to report coverage without a caller having to sum eight fields.
    pub fn fact_count(&self) -> usize {
        self.topics.len()
            + self.observations.len()
            + self.decisions.len()
            + self.action_items.len()
            + self.metrics.len()
            + self.risks.len()
            + self.questions.len()
            + self.next_steps.len()
    }

    /// `true` when every item in every category cites at least one evidence
    /// id, and every evidence id is present in `known_segment_ids`. This is
    /// the automated half of "evidence accuracy" (the manual half is
    /// checking the citation is actually relevant, which needs a human or
    /// `#1636`'s eval harness) — a structurally-ungrounded fact fails this
    /// check regardless of how plausible its text reads.
    pub fn all_evidence_is_grounded(
        &self,
        known_segment_ids: &std::collections::HashSet<String>,
    ) -> bool {
        let fact_ok = |f: &Fact| {
            !f.evidence.is_empty() && f.evidence.iter().all(|e| known_segment_ids.contains(e))
        };
        let action_ok = |a: &ActionItem| {
            !a.evidence.is_empty() && a.evidence.iter().all(|e| known_segment_ids.contains(e))
        };

        self.topics.iter().all(fact_ok)
            && self.observations.iter().all(fact_ok)
            && self.decisions.iter().all(fact_ok)
            && self.action_items.iter().all(action_ok)
            && self.metrics.iter().all(fact_ok)
            && self.risks.iter().all(fact_ok)
            && self.questions.iter().all(fact_ok)
            && self.next_steps.iter().all(fact_ok)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn chunk_facts_round_trips_through_json() {
        let facts = ChunkFacts {
            decisions: vec![Fact {
                id: String::new(),
                text: "ship three more pods before Friday".into(),
                evidence: vec!["s12".into(), "s13".into()],
            }],
            action_items: vec![ActionItem {
                id: String::new(),
                text: "own the pod rollout".into(),
                owner: Some("Raj".into()),
                evidence: vec!["s13".into()],
            }],
            ..Default::default()
        };
        let json = serde_json::to_string(&facts).unwrap();
        let back: ChunkFacts = serde_json::from_str(&json).unwrap();
        assert_eq!(facts, back);
    }

    #[test]
    fn a_chunk_facts_with_only_empty_categories_is_empty() {
        assert!(ChunkFacts::default().is_empty());
        let mut f = ChunkFacts::default();
        f.risks.push(Fact {
            id: String::new(),
            text: "x".into(),
            evidence: vec!["s0".into()],
        });
        assert!(!f.is_empty());
    }

    #[test]
    fn missing_categories_deserialize_as_empty_not_an_error() {
        let facts: ChunkFacts = serde_json::from_str("{}").unwrap();
        assert!(facts.is_empty());
    }

    #[test]
    fn evidence_grounding_rejects_an_unknown_segment_id() {
        let known: std::collections::HashSet<String> = ["s0".into(), "s1".into()].into();
        let mut ir = MeetingIr {
            schema_version: SCHEMA_VERSION.into(),
            meeting: MeetingMeta {
                title: None,
                chunk_count: 1,
            },
            decisions: vec![Fact {
                id: "d0".into(),
                text: "x".into(),
                evidence: vec!["s0".into()],
            }],
            ..empty_ir()
        };
        assert!(ir.all_evidence_is_grounded(&known));

        ir.decisions[0].evidence.push("s99".into());
        assert!(!ir.all_evidence_is_grounded(&known));
    }

    #[test]
    fn evidence_grounding_rejects_a_fact_with_no_evidence_at_all() {
        let known: std::collections::HashSet<String> = ["s0".into()].into();
        let ir = MeetingIr {
            schema_version: SCHEMA_VERSION.into(),
            meeting: MeetingMeta {
                title: None,
                chunk_count: 1,
            },
            decisions: vec![Fact {
                id: "d0".into(),
                text: "unsupported claim".into(),
                evidence: vec![],
            }],
            ..empty_ir()
        };
        assert!(!ir.all_evidence_is_grounded(&known));
    }

    fn empty_ir() -> MeetingIr {
        MeetingIr {
            schema_version: SCHEMA_VERSION.into(),
            meeting: MeetingMeta {
                title: None,
                chunk_count: 0,
            },
            topics: vec![],
            observations: vec![],
            decisions: vec![],
            action_items: vec![],
            metrics: vec![],
            risks: vec![],
            questions: vec![],
            next_steps: vec![],
        }
    }
}

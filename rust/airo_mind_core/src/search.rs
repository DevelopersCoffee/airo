//! Find meetings by content. `#1400`.
//!
//! Searches transcript and minutes, returns matching meetings. No ranking
//! engine, no recommendations, no RAG — `search("Kafka")` returning the right
//! meeting is the exit criterion, and a ranker does not move it.
//!
//! # The index is a Projection
//!
//! `C4`: *"every projection is rebuildable, cache-only, and disposable"* and
//! *"no value exists only in a projection."* This index holds nothing the store
//! does not; it is rebuilt from the store on every open and **never synced**.
//!
//! That matters more than it looks. Embeddings are deterministic for a fixed
//! model and quantisation and **not** across versions, so a synced index would
//! hit the same `C2` determinism problem as generated minutes. Rebuilding
//! locally makes a model upgrade a non-event.
//!
//! Lexical rather than semantic, for now. Semantic retrieval needs an Embedding
//! Engine, and the closure rule says an abstraction must move the pipeline this
//! week. When embeddings land they replace `index_of` and nothing else — the
//! index is already disposable, which is what makes that swap cheap.
//!
//! # Crypto-shredding reaches here
//!
//! `C4` requires `DestroyContent` to invalidate *"embeddings, search snippets,
//! and caches"*. A destroyed meeting whose index entry survives is still
//! findable, and with a semantic index would still be semantically
//! recoverable. `remove` exists for that and is tested.

use std::collections::{BTreeMap, BTreeSet};

use crate::store::Meeting;

/// A hit, with enough context to render a result row without reopening.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Hit {
    pub meeting_id: String,
    pub title: String,
    pub recorded_at: u64,
    /// The line the match came from, so a user can see *why* it matched.
    pub snippet: String,
}

/// Rebuildable, disposable, device-local.
#[derive(Default)]
pub struct SearchIndex {
    /// term -> meeting ids
    terms: BTreeMap<String, BTreeSet<String>>,
    /// meeting id -> (title, recorded_at, searchable text)
    meetings: BTreeMap<String, (String, u64, String)>,
}

/// Lowercased alphanumeric runs. Deliberately crude: a stemmer is a dependency
/// and a behaviour, and neither is needed for `search("Kafka")` to work.
fn tokenise(text: &str) -> Vec<String> {
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|t| !t.is_empty())
        .map(|t| t.to_lowercase())
        .collect()
}

impl SearchIndex {
    pub fn new() -> Self {
        Self::default()
    }

    /// Rebuilds from the store. `C4`: the index is derived, so this is the only
    /// way it is ever populated.
    pub fn rebuild(meetings: &[Meeting]) -> Self {
        let mut index = Self::new();
        for m in meetings {
            index.insert(m);
        }
        index
    }

    pub fn insert(&mut self, meeting: &Meeting) {
        self.remove(&meeting.id);
        let mut text = format!(
            "{}\n{}\n{}",
            meeting.title, meeting.transcript, meeting.minutes
        );
        // `ADR-0022 §2`: the IR's decision statements and action-item
        // task/owner text feed the same FTS blob -- same tokeniser, same AND
        // semantics, no second index. Metrics/risks/etc. are not indexed
        // here; the ADR scopes the FTS extension to decisions and action
        // items only.
        for decision in &meeting.decisions {
            text.push('\n');
            text.push_str(&decision.statement);
        }
        for item in &meeting.action_items {
            text.push('\n');
            text.push_str(&item.task);
            if let Some(owner) = &item.owner {
                text.push(' ');
                text.push_str(owner);
            }
        }
        for term in tokenise(&text) {
            self.terms
                .entry(term)
                .or_default()
                .insert(meeting.id.clone());
        }
        self.meetings.insert(
            meeting.id.clone(),
            (meeting.title.clone(), meeting.recorded_at, text),
        );
    }

    /// Drops every trace of a meeting.
    ///
    /// `C4` requires a destroy to invalidate derived state. A meeting whose
    /// index entry outlives its content is still findable, which is the
    /// difference between deleting and appearing to delete.
    pub fn remove(&mut self, meeting_id: &str) {
        self.meetings.remove(meeting_id);
        self.terms.retain(|_, ids| {
            ids.remove(meeting_id);
            !ids.is_empty()
        });
    }

    pub fn len(&self) -> usize {
        self.meetings.len()
    }

    pub fn is_empty(&self) -> bool {
        self.meetings.is_empty()
    }

    /// Meetings matching **every** term in the query, newest first.
    ///
    /// AND rather than OR: a user searching two words wants the meeting with
    /// both, and with no ranker an OR query would bury it.
    pub fn search(&self, query: &str) -> Vec<Hit> {
        let terms = tokenise(query);
        if terms.is_empty() {
            return Vec::new();
        }

        let mut matching: Option<BTreeSet<String>> = None;
        for term in &terms {
            let ids = self.terms.get(term).cloned().unwrap_or_default();
            matching = Some(match matching {
                None => ids,
                Some(acc) => acc.intersection(&ids).cloned().collect(),
            });
            if matching.as_ref().is_some_and(BTreeSet::is_empty) {
                return Vec::new();
            }
        }

        let mut hits: Vec<Hit> = matching
            .unwrap_or_default()
            .into_iter()
            .filter_map(|id| {
                let (title, recorded_at, text) = self.meetings.get(&id)?;
                let snippet = text
                    .lines()
                    .find(|line| {
                        let lower = line.to_lowercase();
                        terms.iter().any(|t| lower.contains(t.as_str()))
                    })
                    .unwrap_or("")
                    .trim()
                    .to_string();
                Some(Hit {
                    meeting_id: id,
                    title: title.clone(),
                    recorded_at: *recorded_at,
                    snippet,
                })
            })
            .collect();

        hits.sort_by(|a, b| {
            b.recorded_at
                .cmp(&a.recorded_at)
                .then(a.meeting_id.cmp(&b.meeting_id))
        });
        hits
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::store::{ActionStatus, DecisionStatus, MeetingActionItem, MeetingDecision};

    fn meeting(id: &str, at: u64, transcript: &str, minutes: &str) -> Meeting {
        Meeting {
            id: id.into(),
            title: format!("Meeting {id}"),
            recorded_at: at,
            transcript: transcript.into(),
            minutes: minutes.into(),
            model: "qwen2.5-0.5b".into(),
            decisions: Vec::new(),
            action_items: Vec::new(),
            metrics: Vec::new(),
        }
    }

    fn corpus() -> Vec<Meeting> {
        vec![
            meeting(
                "platform-standup",
                100,
                "Priya said the Kafka consumer lag is the bottleneck, not the database.",
                "- Add three pods before Friday\n- Raj owns the rollout",
            ),
            meeting(
                "design-review",
                200,
                "We walked through the onboarding flow and the empty states.",
                "- Ship the empty states\n- Revisit copy next week",
            ),
            meeting(
                "budget-call",
                300,
                "Cloud spend is up. The database tier is the largest line item.",
                "- Downgrade the staging tier",
            ),
        ]
    }

    /// **The `#1400` exit criterion.**
    #[test]
    fn search_kafka_returns_the_right_meeting() {
        let index = SearchIndex::rebuild(&corpus());
        let hits = index.search("Kafka");
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].meeting_id, "platform-standup");
        assert!(
            hits[0].snippet.contains("Kafka"),
            "a hit must show why it matched: {}",
            hits[0].snippet
        );
    }

    #[test]
    fn search_is_case_insensitive() {
        let index = SearchIndex::rebuild(&corpus());
        assert_eq!(index.search("KAFKA").len(), 1);
        assert_eq!(index.search("kafka").len(), 1);
    }

    /// Minutes are searchable, not only the transcript. "Friday" appears only
    /// in the generated minutes.
    #[test]
    fn minutes_are_searchable_not_only_the_transcript() {
        let index = SearchIndex::rebuild(&corpus());
        let hits = index.search("Friday");
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].meeting_id, "platform-standup");
    }

    #[test]
    fn a_multi_word_query_requires_every_term() {
        let index = SearchIndex::rebuild(&corpus());
        // "database" is in two meetings, "Kafka" in one. Both -> one.
        assert_eq!(index.search("database").len(), 2);
        assert_eq!(index.search("kafka database").len(), 1);
        assert_eq!(index.search("kafka onboarding").len(), 0);
    }

    #[test]
    fn results_are_newest_first() {
        let index = SearchIndex::rebuild(&corpus());
        let hits = index.search("the");
        assert!(hits.len() > 1);
        assert!(
            hits.windows(2)
                .all(|w| w[0].recorded_at >= w[1].recorded_at),
            "results must be newest first"
        );
    }

    #[test]
    fn an_unknown_term_returns_nothing_rather_than_everything() {
        let index = SearchIndex::rebuild(&corpus());
        assert!(index.search("kubernetes").is_empty());
        assert!(index.search("").is_empty());
    }

    /// `C4`: a destroy must invalidate derived state. A meeting whose index
    /// entry outlives its content is still findable — the difference between
    /// deleting and appearing to delete.
    #[test]
    fn removing_a_meeting_makes_it_unfindable() {
        let mut index = SearchIndex::rebuild(&corpus());
        assert_eq!(index.search("Kafka").len(), 1);

        index.remove("platform-standup");

        assert!(
            index.search("Kafka").is_empty(),
            "a destroyed meeting is still findable -- crypto-shredding did not reach the index"
        );
        assert_eq!(index.len(), 2);
        // The term is gone entirely, not merely orphaned.
        assert!(!index.terms.contains_key("kafka"));
    }

    /// `ADR-0022 §2`: a decision statement is findable through the same FTS
    /// index the transcript/minutes already feed.
    #[test]
    fn a_decision_statement_is_findable() {
        let mut m = meeting(
            "retro",
            400,
            "General retro chat, nothing quotable.",
            "- See decisions",
        );
        m.decisions = vec![MeetingDecision {
            id: "d0".into(),
            statement: "Adopt Rust for the new ingestion pipeline".into(),
            status: DecisionStatus::Agreed,
            evidence_segment_ids: vec!["s9".into()],
        }];
        let index = SearchIndex::rebuild(&[m]);

        let hits = index.search("ingestion");
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].meeting_id, "retro");
    }

    /// `ADR-0022 §2`: an action item's task text and owner name are both
    /// findable -- "who owns the migration" is a real search a person types.
    #[test]
    fn an_action_items_task_and_owner_are_findable() {
        let mut m = meeting(
            "planning",
            500,
            "Discussed the migration timeline.",
            "- See action items",
        );
        m.action_items = vec![MeetingActionItem {
            id: "a0".into(),
            task: "Finish the database migration".into(),
            owner: Some("Priya".into()),
            due: None,
            status: ActionStatus::Open,
            evidence_segment_ids: vec!["s2".into()],
        }];
        let index = SearchIndex::rebuild(&[m]);

        assert_eq!(index.search("Priya").len(), 1, "owner name is indexed");
        assert_eq!(
            index.search("migration Priya").len(),
            1,
            "task text and owner are indexed together"
        );
    }

    /// `C4`'s crypto-shred contract extends to IR text: a destroyed meeting's
    /// decisions and action items must be as unfindable as its transcript.
    #[test]
    fn removing_a_meeting_makes_its_ir_text_unfindable_too() {
        let mut m = meeting("standup", 600, "routine chat", "- see below");
        m.decisions = vec![MeetingDecision {
            id: "d0".into(),
            statement: "Adopt Kubernetes for staging".into(),
            status: DecisionStatus::Agreed,
            evidence_segment_ids: vec!["s1".into()],
        }];
        let mut index = SearchIndex::rebuild(&[m]);
        assert_eq!(index.search("Kubernetes").len(), 1);

        index.remove("standup");

        assert!(
            index.search("Kubernetes").is_empty(),
            "a destroyed meeting's decision text is still findable"
        );
    }

    #[test]
    fn re_inserting_replaces_rather_than_duplicating() {
        let mut index = SearchIndex::rebuild(&corpus());
        let mut edited = corpus()[0].clone();
        edited.transcript = "Nothing about message queues any more.".into();
        edited.minutes = "- Cancelled".into();
        index.insert(&edited);

        assert_eq!(index.len(), 3, "still three meetings");
        assert!(
            index.search("Kafka").is_empty(),
            "stale terms survived a re-index"
        );
        assert_eq!(index.search("queues").len(), 1);
    }
}

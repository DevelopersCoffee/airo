//! Pass 2: consolidation (`#1633`).
//!
//! Merges every chunk's [`ChunkFacts`] (pass 1's output, one per chunk, no
//! stable identity) into one [`MeetingIr`] (stable per-item ids, near-duplicate
//! facts merged, evidence unioned across the chunks that independently found
//! the same fact).
//!
//! # Why this is a heuristic, not a second LLM call
//!
//! The issue's own worked example — "Check Temporal signalling limit" /
//! "Confirm Temporal signalling capacity" / "Ask Temporal team about
//! signalling" collapsing to one action item — reads like it wants semantic
//! judgment, and an LLM consolidation pass was the first design considered.
//! It was set aside for this wave for a concrete reason: pass 1 already
//! spends the model's full attention on one chunk under a tight grammar;
//! pass 2 in production would need a SECOND call, over a growing multi-chunk
//! candidate list, on the same sub-2B model this milestone budgets for —
//! and unlike pass 1's per-chunk output (bounded by one 5-10 minute excerpt),
//! the candidate-list size pass 2 would need to read scales with the whole
//! meeting, which risks exceeding context on a real 60-90 minute recording
//! before this wave has any eval harness (`#1636`, later wave) to even
//! measure whether that second call was net-positive.
//!
//! Token-overlap similarity, by contrast, is deterministic, unit-testable
//! without a model, cheap enough to run over hundreds of candidates, and
//! demonstrably handles the issue's own example (see
//! `dedupes_the_issues_own_worked_example` below) once the transcript
//! processor's (`#1632`) technical-term normalization has already pulled
//! "Temporal"/"signalling" into a consistent spelling — which it does,
//! upstream of this crate, before facts ever reach pass 1.
//!
//! This is a real, documented tradeoff, not an oversight: an LLM-assisted
//! pass 2 for the cases token overlap misses (paraphrases sharing no content
//! words) is a natural strengthening to make once `#1636`'s eval harness can
//! measure whether it is actually worth the extra inference cost.

use std::collections::HashSet;

use crate::schema::{ActionItem, ChunkFacts, Fact, MeetingIr, MeetingMeta, SCHEMA_VERSION};

/// Stopwords stripped before similarity comparison: verbs/connectives that
/// vary between paraphrases of the same fact ("check" vs "confirm" vs "ask")
/// without changing what the fact is about.
const STOPWORDS: &[&str] = &[
    "a", "an", "the", "to", "for", "of", "on", "in", "at", "and", "or", "is", "are", "will",
    "should", "must", "need", "needs", "please", "team", "about", "check", "confirm", "ask",
    "that", "this", "with", "we",
];

fn content_tokens(text: &str) -> HashSet<String> {
    text.to_lowercase()
        .split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty() && !STOPWORDS.contains(w))
        .map(str::to_string)
        .collect()
}

/// Jaccard similarity over content tokens. `0.0` when either side has no
/// content tokens at all (an all-stopword string never "matches" anything by
/// accident).
fn similarity(a: &HashSet<String>, b: &HashSet<String>) -> f64 {
    if a.is_empty() || b.is_empty() {
        return 0.0;
    }
    let intersection = a.intersection(b).count();
    let union = a.union(b).count();
    intersection as f64 / union as f64
}

/// Above this, two facts are treated as the same fact restated. Chosen
/// against the issue's own worked example (~0.5-0.67 overlap between its
/// three phrasings) with headroom below that and above the ~0.2-0.3 overlap
/// two genuinely different facts about the same topic tend to share.
const DEDUPE_THRESHOLD: f64 = 0.4;

/// One cluster of near-duplicate facts collapsing into a single output item:
/// the first (earliest-seen) text as the representative, every contributing
/// fact's evidence unioned.
struct Cluster {
    text: String,
    evidence: Vec<String>,
    tokens: HashSet<String>,
}

fn merge_evidence(evidence: &mut Vec<String>, new: &[String]) {
    for id in new {
        if !evidence.contains(id) {
            evidence.push(id.clone());
        }
    }
}

/// Greedy single-pass clustering: each fact joins the first existing cluster
/// it is similar enough to, else starts a new one. Order-dependent (a
/// property greedy clustering always has) but deterministic — the same input
/// order always produces the same clusters, which is what `#1632`'s
/// determinism contract one layer down already promises this crate's input
/// will have.
fn cluster_facts(facts: Vec<Fact>) -> Vec<Cluster> {
    let mut clusters: Vec<Cluster> = Vec::new();
    for fact in facts {
        let tokens = content_tokens(&fact.text);
        let existing = clusters
            .iter_mut()
            .find(|c| similarity(&c.tokens, &tokens) >= DEDUPE_THRESHOLD);
        match existing {
            Some(cluster) => merge_evidence(&mut cluster.evidence, &fact.evidence),
            None => clusters.push(Cluster {
                text: fact.text,
                evidence: fact.evidence,
                tokens,
            }),
        }
    }
    clusters
}

fn finalize(clusters: Vec<Cluster>, prefix: &str) -> Vec<Fact> {
    clusters
        .into_iter()
        .enumerate()
        .map(|(i, c)| Fact {
            id: format!("{prefix}{i}"),
            text: c.text,
            evidence: c.evidence,
        })
        .collect()
}

struct ActionCluster {
    text: String,
    owner: Option<String>,
    evidence: Vec<String>,
    tokens: HashSet<String>,
}

fn cluster_action_items(items: Vec<ActionItem>) -> Vec<ActionCluster> {
    let mut clusters: Vec<ActionCluster> = Vec::new();
    for item in items {
        let tokens = content_tokens(&item.text);
        let existing = clusters
            .iter_mut()
            .find(|c| similarity(&c.tokens, &tokens) >= DEDUPE_THRESHOLD);
        match existing {
            Some(cluster) => {
                merge_evidence(&mut cluster.evidence, &item.evidence);
                // Prefer keeping a real owner over `None` if either
                // duplicate named one — never overwrite a real owner with a
                // guess, but a later chunk naming the owner a earlier chunk
                // left unstated is real information, not a guess.
                if cluster.owner.is_none() {
                    cluster.owner = item.owner;
                }
            }
            None => clusters.push(ActionCluster {
                text: item.text,
                owner: item.owner,
                evidence: item.evidence,
                tokens,
            }),
        }
    }
    clusters
}

/// Consolidates every chunk's [`ChunkFacts`] into the final [`MeetingIr`].
/// `chunk_count` is recorded as coverage metadata (`MeetingMeta`), not used
/// in the dedup decision itself.
pub fn consolidate(per_chunk: Vec<ChunkFacts>, title: Option<String>) -> MeetingIr {
    let chunk_count = per_chunk.len() as u32;

    let mut topics = Vec::new();
    let mut observations = Vec::new();
    let mut decisions = Vec::new();
    let mut action_items = Vec::new();
    let mut metrics = Vec::new();
    let mut risks = Vec::new();
    let mut questions = Vec::new();
    let mut next_steps = Vec::new();

    for facts in per_chunk {
        topics.extend(facts.topics);
        observations.extend(facts.observations);
        decisions.extend(facts.decisions);
        action_items.extend(facts.action_items);
        metrics.extend(facts.metrics);
        risks.extend(facts.risks);
        questions.extend(facts.questions);
        next_steps.extend(facts.next_steps);
    }

    let action_items = cluster_action_items(action_items)
        .into_iter()
        .enumerate()
        .map(|(i, c)| ActionItem {
            id: format!("a{i}"),
            text: c.text,
            owner: c.owner,
            evidence: c.evidence,
        })
        .collect();

    MeetingIr {
        schema_version: SCHEMA_VERSION.to_string(),
        meeting: MeetingMeta { title, chunk_count },
        topics: finalize(cluster_facts(topics), "t"),
        observations: finalize(cluster_facts(observations), "o"),
        decisions: finalize(cluster_facts(decisions), "d"),
        action_items,
        metrics: finalize(cluster_facts(metrics), "m"),
        risks: finalize(cluster_facts(risks), "r"),
        questions: finalize(cluster_facts(questions), "q"),
        next_steps: finalize(cluster_facts(next_steps), "n"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn fact(text: &str, evidence: &[&str]) -> Fact {
        Fact {
            id: String::new(),
            text: text.to_string(),
            evidence: evidence.iter().map(|s| s.to_string()).collect(),
        }
    }

    /// The issue's own worked example (`#1633`): three chunk-local phrasings
    /// of the same action item collapse into one, with evidence from all
    /// three merged.
    #[test]
    fn dedupes_the_issues_own_worked_example() {
        let per_chunk = vec![
            ChunkFacts {
                action_items: vec![ActionItem {
                    id: String::new(),
                    text: "Check Temporal signalling limit".into(),
                    owner: None,
                    evidence: vec!["s1".into()],
                }],
                ..Default::default()
            },
            ChunkFacts {
                action_items: vec![ActionItem {
                    id: String::new(),
                    text: "Confirm Temporal signalling capacity".into(),
                    owner: None,
                    evidence: vec!["s7".into()],
                }],
                ..Default::default()
            },
            ChunkFacts {
                action_items: vec![ActionItem {
                    id: String::new(),
                    text: "Ask Temporal team about signalling".into(),
                    owner: Some("Raj".into()),
                    evidence: vec!["s12".into()],
                }],
                ..Default::default()
            },
        ];

        let ir = consolidate(per_chunk, None);
        assert_eq!(
            ir.action_items.len(),
            1,
            "expected all three phrasings to merge into one item"
        );
        let item = &ir.action_items[0];
        assert_eq!(item.evidence.len(), 3);
        assert!(item.evidence.contains(&"s1".to_string()));
        assert!(item.evidence.contains(&"s7".to_string()));
        assert!(item.evidence.contains(&"s12".to_string()));
        // The owner named in the third phrasing survives even though the
        // first two never named one.
        assert_eq!(item.owner.as_deref(), Some("Raj"));
    }

    #[test]
    fn genuinely_different_decisions_stay_separate() {
        let per_chunk = vec![ChunkFacts {
            decisions: vec![
                fact("we will add three more pods before Friday", &["s3"]),
                fact("we will migrate the billing database to Postgres", &["s9"]),
            ],
            ..Default::default()
        }];

        let ir = consolidate(per_chunk, None);
        assert_eq!(ir.decisions.len(), 2);
    }

    #[test]
    fn ids_are_assigned_per_category_and_start_at_zero() {
        let per_chunk = vec![ChunkFacts {
            decisions: vec![
                fact("a", &["s0"]),
                fact("b entirely different words here", &["s1"]),
            ],
            risks: vec![fact("some risk", &["s2"])],
            ..Default::default()
        }];
        let ir = consolidate(per_chunk, None);
        assert_eq!(ir.decisions[0].id, "d0");
        assert_eq!(ir.decisions[1].id, "d1");
        assert_eq!(ir.risks[0].id, "r0");
    }

    #[test]
    fn chunk_count_reflects_how_many_chunks_were_consolidated() {
        let ir = consolidate(
            vec![
                ChunkFacts::default(),
                ChunkFacts::default(),
                ChunkFacts::default(),
            ],
            None,
        );
        assert_eq!(ir.meeting.chunk_count, 3);
    }

    #[test]
    fn an_empty_meeting_produces_a_valid_empty_ir() {
        let ir = consolidate(vec![], Some("Standup".into()));
        assert_eq!(ir.fact_count(), 0);
        assert_eq!(ir.schema_version, SCHEMA_VERSION);
        assert_eq!(ir.meeting.title.as_deref(), Some("Standup"));
    }
}

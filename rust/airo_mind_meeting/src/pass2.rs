//! Pass 2 — consolidation.
//!
//! Merges every chunk's facts into one meeting IR: near-duplicates collapse,
//! their evidence unions, and their statuses resolve. No model is involved and
//! nothing is rewritten — a consolidated item's text is text that was extracted
//! verbatim from some chunk, never a phrasing invented to cover several.
//!
//! # Deterministic by construction
//!
//! Chunks are visited in transcript order, items within a chunk in extraction
//! order, and an item joins the **first** existing cluster it matches. The same
//! chunk IRs therefore always produce the same meeting IR, byte for byte —
//! which is what lets the golden test here, and MIND-LLM-11's F1 gates, tell a
//! regression from noise.
//!
//! # Why the earliest phrasing wins
//!
//! When "Check Temporal signalling limit" and "Ask Temporal team about
//! signalling" collapse, the surviving text is the first one. It is the one said
//! closest to where the fact was established; later mentions are usually recaps,
//! and choosing e.g. the longest would let a rambling restatement replace a
//! crisp original.

use crate::dedup::{is_near_duplicate, DedupConfig};
use crate::diagnostics::Diagnostic;
use crate::fact::Fact;
use crate::ir::{ChunkIr, Facts, Meeting, MeetingIr, IR_SCHEMA_VERSION};

/// Merges chunk IRs into one meeting IR.
///
/// `meeting` carries the identity and provenance the model has no part in
/// (`ADR-0018 §5`); the facts come entirely from `chunk_irs`.
pub fn consolidate(
    chunk_irs: &[ChunkIr],
    meeting: Meeting,
    config: &DedupConfig,
) -> (MeetingIr, Vec<Diagnostic>) {
    let mut diagnostics = Vec::new();

    let facts = Facts {
        topics: merge(
            chunk_irs.iter().map(|c| &c.facts.topics),
            config,
            &mut diagnostics,
        ),
        observations: merge(
            chunk_irs.iter().map(|c| &c.facts.observations),
            config,
            &mut diagnostics,
        ),
        decisions: merge(
            chunk_irs.iter().map(|c| &c.facts.decisions),
            config,
            &mut diagnostics,
        ),
        action_items: merge(
            chunk_irs.iter().map(|c| &c.facts.action_items),
            config,
            &mut diagnostics,
        ),
        metrics: merge(
            chunk_irs.iter().map(|c| &c.facts.metrics),
            config,
            &mut diagnostics,
        ),
        risks: merge(
            chunk_irs.iter().map(|c| &c.facts.risks),
            config,
            &mut diagnostics,
        ),
        questions: merge(
            chunk_irs.iter().map(|c| &c.facts.questions),
            config,
            &mut diagnostics,
        ),
        next_steps: merge(
            chunk_irs.iter().map(|c| &c.facts.next_steps),
            config,
            &mut diagnostics,
        ),
    };

    (
        MeetingIr {
            schema_version: IR_SCHEMA_VERSION.to_string(),
            meeting,
            facts,
        },
        diagnostics,
    )
}

/// Greedy first-match clustering over one category, in transcript order.
///
/// Greedy rather than optimal: an optimal clustering would need a global
/// objective nobody has defined, would not be stable under adding one chunk,
/// and is O(n³) territory for a gain no meeting-sized input would notice.
fn merge<'a, F, I>(chunks: I, config: &DedupConfig, diagnostics: &mut Vec<Diagnostic>) -> Vec<F>
where
    F: Fact + Clone + 'a,
    I: Iterator<Item = &'a Vec<F>>,
{
    let mut merged: Vec<F> = Vec::new();
    for items in chunks {
        for item in items {
            match merged
                .iter()
                .position(|existing| is_near_duplicate(existing.text(), item.text(), config))
            {
                Some(index) => {
                    if !merged[index].text().eq_ignore_ascii_case(item.text()) {
                        diagnostics.push(Diagnostic::ItemsMerged {
                            category: F::CATEGORY,
                            kept: merged[index].text().to_string(),
                            merged: item.text().to_string(),
                        });
                    }
                    let absorbed = item.clone();
                    merged[index].absorb(absorbed, diagnostics);
                }
                None => merged.push(item.clone()),
            }
        }
    }

    // Meeting-scoped ids, assigned last so they number the consolidated set
    // rather than whatever chunk each item happened to come from.
    for (index, item) in merged.iter_mut().enumerate() {
        item.set_id(format!("{}-{index}", F::CATEGORY));
    }
    merged
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ir::{ActionItem, ActionStatus, Decision, DecisionStatus};

    fn chunk_ir(id: &str, action_items: Vec<ActionItem>, decisions: Vec<Decision>) -> ChunkIr {
        ChunkIr {
            chunk_id: id.into(),
            segment_ids: Vec::new(),
            facts: Facts {
                action_items,
                decisions,
                ..Facts::default()
            },
        }
    }

    fn action(task: &str, owner: Option<&str>, evidence: &[&str]) -> ActionItem {
        ActionItem {
            id: String::new(),
            task: task.into(),
            owner: owner.map(str::to_string),
            due: None,
            status: ActionStatus::Open,
            evidence: evidence.iter().map(|s| (*s).to_string()).collect(),
        }
    }

    #[test]
    fn three_phrasings_of_one_action_become_one_item_with_all_the_evidence() {
        let chunk_irs = vec![
            chunk_ir(
                "chunk-0",
                vec![action("Check Temporal signalling limit", None, &["s3"])],
                Vec::new(),
            ),
            chunk_ir(
                "chunk-1",
                vec![action(
                    "Confirm Temporal signalling capacity",
                    None,
                    &["s11"],
                )],
                Vec::new(),
            ),
            chunk_ir(
                "chunk-2",
                vec![action("Ask Temporal team about signalling", None, &["s20"])],
                Vec::new(),
            ),
        ];

        let (ir, diagnostics) =
            consolidate(&chunk_irs, Meeting::default(), &DedupConfig::default());

        assert_eq!(ir.facts.action_items.len(), 1);
        let item = &ir.facts.action_items[0];
        assert_eq!(item.task, "Check Temporal signalling limit");
        assert_eq!(item.evidence, vec!["s3", "s11", "s20"]);
        assert_eq!(item.id, "action_item-0");
        assert_eq!(
            diagnostics
                .iter()
                .filter(|d| matches!(d, Diagnostic::ItemsMerged { .. }))
                .count(),
            2
        );
    }

    #[test]
    fn unrelated_actions_stay_separate_and_are_numbered_in_transcript_order() {
        let chunk_irs = vec![chunk_ir(
            "chunk-0",
            vec![
                action("Check the Temporal signalling limit", None, &["s1"]),
                action("Check the Kafka retention limit", None, &["s2"]),
            ],
            Vec::new(),
        )];

        let (ir, _) = consolidate(&chunk_irs, Meeting::default(), &DedupConfig::default());

        assert_eq!(ir.facts.action_items.len(), 2);
        assert_eq!(ir.facts.action_items[0].id, "action_item-0");
        assert_eq!(ir.facts.action_items[1].id, "action_item-1");
    }

    #[test]
    fn an_ownerless_action_stays_ownerless_through_consolidation() {
        let chunk_irs = vec![
            chunk_ir(
                "chunk-0",
                vec![action("Check Temporal signalling limit", None, &["s3"])],
                Vec::new(),
            ),
            chunk_ir(
                "chunk-1",
                vec![action(
                    "Confirm Temporal signalling capacity",
                    None,
                    &["s11"],
                )],
                Vec::new(),
            ),
        ];
        let (ir, _) = consolidate(&chunk_irs, Meeting::default(), &DedupConfig::default());
        assert_eq!(ir.facts.action_items[0].owner, None);
    }

    #[test]
    fn a_decision_proposed_early_and_agreed_late_consolidates_as_agreed() {
        let decision = |statement: &str, status, evidence: &str| Decision {
            id: String::new(),
            statement: statement.into(),
            status,
            evidence: vec![evidence.into()],
        };
        let chunk_irs = vec![
            chunk_ir(
                "chunk-0",
                Vec::new(),
                vec![decision(
                    "move signalling onto the queue",
                    DecisionStatus::Proposed,
                    "s2",
                )],
            ),
            chunk_ir(
                "chunk-1",
                Vec::new(),
                vec![decision(
                    "move signalling onto the queue",
                    DecisionStatus::Agreed,
                    "s30",
                )],
            ),
        ];

        let (ir, _) = consolidate(&chunk_irs, Meeting::default(), &DedupConfig::default());
        assert_eq!(ir.facts.decisions.len(), 1);
        assert_eq!(ir.facts.decisions[0].status, DecisionStatus::Agreed);
        assert_eq!(ir.facts.decisions[0].evidence, vec!["s2", "s30"]);
    }

    #[test]
    fn consolidation_is_deterministic() {
        let chunk_irs = vec![
            chunk_ir(
                "chunk-0",
                vec![action("Check Temporal signalling limit", None, &["s3"])],
                Vec::new(),
            ),
            chunk_ir(
                "chunk-1",
                vec![action("Ask Temporal team about signalling", None, &["s11"])],
                Vec::new(),
            ),
        ];
        let first = consolidate(&chunk_irs, Meeting::default(), &DedupConfig::default());
        let second = consolidate(&chunk_irs, Meeting::default(), &DedupConfig::default());
        assert_eq!(first.0, second.0);
        assert_eq!(first.1, second.1);
    }

    #[test]
    fn the_consolidated_ir_stamps_the_schema_version() {
        let (ir, _) = consolidate(&[], Meeting::default(), &DedupConfig::default());
        assert_eq!(ir.schema_version, IR_SCHEMA_VERSION);
        assert!(ir.facts.is_empty());
    }
}

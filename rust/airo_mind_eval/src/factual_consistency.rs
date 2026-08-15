//! Deterministic factual-consistency checks. `#1636`.
//!
//! The issue names "factual consistency (deterministic checks + local LLM
//! judge scoring 7 axes 0-5; judge never sole evaluator)" and is explicit
//! that the deterministic half is in scope to implement fully. This module is
//! that half: it checks the specific, checkable claims
//! `airo_mind_meeting::mom` already guarantees by construction when its own
//! `generate_mom` produces the document --
//!
//! - every decision/action-item/next-step row renders the IR's field values
//!   verbatim (`airo_mind_meeting::mom`'s own doc comment: "a decision's
//!   statement, an action's owner, a metric's value -- none of it passes
//!   through anything that could paraphrase it"),
//! - no digit reaches a narrative section (`mom::strip_numbers`'s guarantee).
//!
//! An eval run scores a `mom` string that did **not** necessarily come from
//! this crate's own renderer (a real end-to-end run, a different model, a
//! hand-edited fixture) against those same guarantees, which is what makes
//! this a meaningful check rather than a tautology against `generate_mom`'s
//! own tests.

use airo_mind_meeting::ir::{ActionStatus, DecisionStatus, MeetingIr};

/// Mirrors `airo_mind_meeting::mom::escape_cell` (private to that crate): a
/// literal `|` and embedded newlines are escaped/collapsed the same way
/// before a table-cell comparison, so a byte-for-byte `contains` check still
/// finds a row `generate_mom` itself would have produced this way.
fn escape_cell(text: &str) -> String {
    text.trim().replace('|', "\\|").replace(['\n', '\r'], " ")
}

/// Mirrors `airo_mind_meeting::mom::decision_status_label` (private to that
/// crate) -- the label text is part of the wire format the table renders,
/// stable and unlikely to change without the golden MoM fixture changing too.
fn decision_status_label(status: DecisionStatus) -> &'static str {
    match status {
        DecisionStatus::Proposed => "Proposed",
        DecisionStatus::Agreed => "Agreed",
        DecisionStatus::Rejected => "Rejected",
        DecisionStatus::Deferred => "Deferred",
    }
}

/// Mirrors `airo_mind_meeting::mom::action_status_label` (private).
fn action_status_label(status: ActionStatus) -> &'static str {
    match status {
        ActionStatus::Open => "Open",
        ActionStatus::InProgress => "In Progress",
        ActionStatus::Done => "Done",
        ActionStatus::Blocked => "Blocked",
    }
}

const UNSET_CELL: &str = "—";

/// One deterministic check's outcome, kept for the report rather than
/// collapsed straight into a count -- a failing run should say *which* fact
/// the MoM misrepresented, not just that something did.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct ConsistencyCheck {
    pub description: String,
    pub passed: bool,
}

/// Aggregate result.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct FactualConsistencyReport {
    pub checks: Vec<ConsistencyCheck>,
    /// `passed / checks.len()`. `1.0` when there was nothing to check (an
    /// entirely empty IR) -- vacuously consistent.
    pub score: f64,
}

/// The text between the first `## Decisions & Direction` heading and the
/// start of the document -- the narrative sections, which per
/// `mom::strip_numbers`'s contract must carry no digit.
fn narrative_prefix(mom: &str) -> &str {
    match mom.find("## Decisions & Direction") {
        Some(pos) => &mom[..pos],
        None => mom,
    }
}

/// Checks `mom` against `ir` for the specific claims [`generate_mom`]
/// guarantees by construction.
pub fn factual_consistency(ir: &MeetingIr, mom: &str) -> FactualConsistencyReport {
    let mut checks = Vec::new();

    for decision in &ir.facts.decisions {
        let row = format!(
            "| {} | {} |",
            escape_cell(&decision.statement),
            decision_status_label(decision.status)
        );
        checks.push(ConsistencyCheck {
            description: format!("decision row byte-matches the IR: {}", decision.statement),
            passed: mom.contains(&row),
        });
    }

    for item in &ir.facts.action_items {
        let row = format!(
            "| {} | {} | {} | {} |",
            escape_cell(&item.task),
            escape_cell(item.owner.as_deref().unwrap_or(UNSET_CELL)),
            escape_cell(item.due.as_deref().unwrap_or(UNSET_CELL)),
            action_status_label(item.status)
        );
        checks.push(ConsistencyCheck {
            description: format!("action item row byte-matches the IR: {}", item.task),
            passed: mom.contains(&row),
        });
    }

    for step in &ir.facts.next_steps {
        let line = format!("- {}", escape_cell(&step.statement));
        checks.push(ConsistencyCheck {
            description: format!("next step line byte-matches the IR: {}", step.statement),
            passed: mom.contains(&line),
        });
    }

    let narrative = narrative_prefix(mom);
    checks.push(ConsistencyCheck {
        description: "no digit reaches a narrative section".to_string(),
        passed: !narrative.chars().any(|c| c.is_ascii_digit()),
    });

    let passed = checks.iter().filter(|c| c.passed).count();
    let score = if checks.is_empty() {
        1.0
    } else {
        passed as f64 / checks.len() as f64
    };

    FactualConsistencyReport { checks, score }
}

#[cfg(test)]
mod tests {
    use super::*;
    use airo_mind_meeting::ir::{
        ActionItem, Decision, Facts, Meeting, NextStep, IR_SCHEMA_VERSION,
    };

    fn ir_with(facts: Facts) -> MeetingIr {
        MeetingIr {
            schema_version: IR_SCHEMA_VERSION.into(),
            meeting: Meeting {
                id: "meeting-0".into(),
                prompt_version: "chunk_facts.v1".into(),
                ..Meeting::default()
            },
            facts,
        }
    }

    #[test]
    fn a_mom_that_matches_the_ir_exactly_scores_one() {
        let ir = ir_with(Facts {
            decisions: vec![Decision {
                statement: "move signaling onto the queue".into(),
                status: DecisionStatus::Agreed,
                ..Decision::default()
            }],
            action_items: vec![ActionItem {
                task: "check the signaling limit".into(),
                owner: None,
                due: Some("Friday".into()),
                status: ActionStatus::Open,
                ..ActionItem::default()
            }],
            next_steps: vec![NextStep {
                statement: "review the rollout plan".into(),
                ..NextStep::default()
            }],
            ..Facts::default()
        });
        let mom = "## Meeting Objective\n\nReview the plan.\n\n\
                   ## Decisions & Direction\n\n\
                   | Decision | Status |\n| --- | --- |\n\
                   | move signaling onto the queue | Agreed |\n\n\
                   ## Action Items\n\n\
                   | Task | Owner | Due | Status |\n| --- | --- | --- | --- |\n\
                   | check the signaling limit | — | Friday | Open |\n\n\
                   ## Next Steps\n\n- review the rollout plan\n";

        let report = factual_consistency(&ir, mom);
        assert_eq!(report.score, 1.0, "{:#?}", report.checks);
    }

    #[test]
    fn a_decision_status_that_does_not_match_the_ir_fails_that_check() {
        let ir = ir_with(Facts {
            decisions: vec![Decision {
                statement: "move signaling onto the queue".into(),
                status: DecisionStatus::Agreed,
                ..Decision::default()
            }],
            ..Facts::default()
        });
        let mom = "## Decisions & Direction\n\n\
                   | move signaling onto the queue | Proposed |\n";

        let report = factual_consistency(&ir, mom);
        assert!(!report.checks[0].passed);
        assert_eq!(
            report.score, 0.5,
            "the narrative-digit check still passes on its own: {:#?}",
            report.checks
        );
    }

    #[test]
    fn a_digit_that_leaks_into_the_narrative_fails_that_check() {
        let ir = ir_with(Facts::default());
        let mom = "## Meeting Objective\n\nThe team covered 3 topics.\n\n\
                   ## Decisions & Direction\n\n_No decisions recorded._\n";

        let report = factual_consistency(&ir, mom);
        let narrative_check = report
            .checks
            .iter()
            .find(|c| c.description.contains("narrative"))
            .unwrap();
        assert!(!narrative_check.passed);
    }

    #[test]
    fn a_digit_inside_a_table_cell_does_not_fail_the_narrative_check() {
        let ir = ir_with(Facts {
            decisions: vec![Decision {
                statement: "cut the budget by 20 percent".into(),
                status: DecisionStatus::Agreed,
                ..Decision::default()
            }],
            ..Facts::default()
        });
        let mom = "## Meeting Objective\n\nNo figures here.\n\n\
                   ## Decisions & Direction\n\n\
                   | cut the budget by 20 percent | Agreed |\n";

        let report = factual_consistency(&ir, mom);
        let narrative_check = report
            .checks
            .iter()
            .find(|c| c.description.contains("narrative"))
            .unwrap();
        assert!(narrative_check.passed);
    }

    #[test]
    fn an_entirely_empty_ir_is_vacuously_consistent_except_for_the_narrative_check() {
        let ir = ir_with(Facts::default());
        let report = factual_consistency(&ir, "## Meeting Objective\n\nNothing happened.\n");
        assert_eq!(
            report.checks.len(),
            1,
            "only the narrative-digit check applies"
        );
        assert_eq!(report.score, 1.0);
    }
}

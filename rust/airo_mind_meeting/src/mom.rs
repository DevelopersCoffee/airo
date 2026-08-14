//! Minutes of Meeting — a Markdown *projection* of a validated [`MeetingIr`].
//! `#1635`.
//!
//! # Hybrid rendering
//!
//! Five sections, two ways of producing them:
//!
//! - **Decisions & Direction**, **Action Items**, **Next Steps** are tables and
//!   a list rendered directly from IR fields — [`render_decisions_table`],
//!   [`render_action_items_table`] and [`render_next_steps`] are pure
//!   functions, no engine, no model, byte-stable for the same IR. A decision's
//!   statement, an action's owner, a metric's value — none of it passes
//!   through anything that could paraphrase it.
//! - **Meeting Objective** and **Key Discussion Points** are prose: turning
//!   "these are the topics and decisions" into readable sentences genuinely
//!   needs generation, and a template cannot do it. [`generate_mom`] calls the
//!   engine for exactly these two sections and nothing else.
//!
//! # Numbers never reach the model
//!
//! The issue allows either re-running the validator's numeric-grounding check
//! on narrative output, or keeping numbers out of narrative prose entirely.
//! This module takes the second, simpler path: [`strip_numbers`] removes every
//! digit run from the facts handed to the narrative prompts, the prompts
//! themselves forbid writing digits, and [`sanitize_narrative`] strips digits
//! from whatever the model returns anyway. A number in the MoM can therefore
//! only ever come from a table cell copied straight out of the IR, which is
//! what makes AC3 ("numbers byte-match the IR") true by construction rather
//! than by hoping the model behaved. This also structures the two call sites
//! so `#1636`'s factual-consistency gate has exactly one thing left to check —
//! that the prose does not misrepresent a fact, not that it invented a figure.
//!
//! # Validated IR only
//!
//! This module never calls [`crate::validate::validate`] itself. The issue's
//! rule is "MoM from validated IR only", and enforcing that by calling
//! `validate` a second time here would let a caller believe an unvalidated IR
//! is safe to hand in — it is the caller's job to validate first and pass the
//! repaired IR in, the same contract [`crate::pass2::consolidate`] and
//! [`crate::validate::validate`] already use of taking and returning
//! [`MeetingIr`] rather than reaching backward for one.

use airo_mind_core::{CancelToken, EngineError, GenerationEngine, GenerationRequest};

use crate::ir::{ActionItem, ActionStatus, Decision, DecisionStatus, MeetingIr, NextStep};
use crate::mom_prompt;

/// Output-token ceiling for one narrative section. Generous for one to a
/// handful of sentences with room to spare; a section this large overrunning
/// it is not a case this crate has seen in practice.
const NARRATIVE_MAX_OUTPUT_TOKENS: u32 = 320;

/// Why MoM generation could not finish. Mirrors [`crate::ExtractionError`]:
/// the same two things can go wrong, for the same reasons.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MomError {
    /// The caller navigated away. Nothing partial should be treated as a
    /// result.
    Cancelled,
    /// The generation backend failed or has no model.
    Engine(String),
}

impl std::fmt::Display for MomError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Cancelled => write!(f, "cancelled"),
            Self::Engine(message) => write!(f, "generation engine failed: {message}"),
        }
    }
}

impl std::error::Error for MomError {}

/// Renders `ir` (already validated — see the module doc) into Minutes of
/// Meeting Markdown.
///
/// Two calls to `engine`, one per narrative section, in a fixed order —
/// Meeting Objective, then Key Discussion Points — so a caller scripting a
/// test double can key responses by call order the way `pass1`'s tests key
/// them by chunk.
pub fn generate_mom(
    engine: &dyn GenerationEngine,
    ir: &MeetingIr,
    cancel: &CancelToken,
) -> Result<String, MomError> {
    let mut out = String::new();
    out.push_str("# Minutes of Meeting\n\n");

    if let Some(title) = ir.meeting.title.as_deref().filter(|t| !t.trim().is_empty()) {
        out.push_str("**Meeting:** ");
        out.push_str(title.trim());
        out.push_str("\n\n");
    }

    out.push_str("## Meeting Objective\n\n");
    out.push_str(generate_meeting_objective(engine, ir, cancel)?.trim());
    out.push_str("\n\n");

    out.push_str("## Key Discussion Points\n\n");
    out.push_str(generate_key_discussion_points(engine, ir, cancel)?.trim());
    out.push_str("\n\n");

    out.push_str("## Decisions & Direction\n\n");
    out.push_str(&render_decisions_table(&ir.facts.decisions));
    out.push_str("\n\n");

    out.push_str("## Action Items\n\n");
    out.push_str(&render_action_items_table(&ir.facts.action_items));
    out.push_str("\n\n");

    out.push_str("## Next Steps\n\n");
    out.push_str(&render_next_steps(&ir.facts.next_steps));
    out.push('\n');

    Ok(out)
}

// ---------------------------------------------------------------------------
// Deterministic tables — pure, no engine
// ---------------------------------------------------------------------------

/// The Decisions & Direction table. Byte-stable for the same `decisions`: no
/// step here can reorder, reword or drop an item.
pub fn render_decisions_table(decisions: &[Decision]) -> String {
    if decisions.is_empty() {
        return "_No decisions recorded._".to_string();
    }
    let mut out = String::from("| Decision | Status |\n| --- | --- |\n");
    for decision in decisions {
        out.push_str("| ");
        out.push_str(&escape_cell(&decision.statement));
        out.push_str(" | ");
        out.push_str(decision_status_label(decision.status));
        out.push_str(" |\n");
    }
    out.trim_end().to_string()
}

/// The Action Items table. `owner` and `due` render as an em dash when the IR
/// carries `None` — never inferred, never blank, so a reader can tell "no
/// owner was ever named" apart from "this cell is missing".
pub fn render_action_items_table(action_items: &[ActionItem]) -> String {
    if action_items.is_empty() {
        return "_No action items recorded._".to_string();
    }
    let mut out = String::from("| Task | Owner | Due | Status |\n| --- | --- | --- | --- |\n");
    for item in action_items {
        out.push_str("| ");
        out.push_str(&escape_cell(&item.task));
        out.push_str(" | ");
        out.push_str(&escape_cell(item.owner.as_deref().unwrap_or(UNSET_CELL)));
        out.push_str(" | ");
        out.push_str(&escape_cell(item.due.as_deref().unwrap_or(UNSET_CELL)));
        out.push_str(" | ");
        out.push_str(action_status_label(item.status));
        out.push_str(" |\n");
    }
    out.trim_end().to_string()
}

/// The Next Steps list. Not a table: `NextStep` carries one field of prose and
/// nothing tabular to align, so a bullet list is the honest rendering of it.
pub fn render_next_steps(next_steps: &[NextStep]) -> String {
    if next_steps.is_empty() {
        return "_No further steps recorded._".to_string();
    }
    let mut out = String::new();
    for step in next_steps {
        out.push_str("- ");
        out.push_str(&escape_cell(&step.statement));
        out.push('\n');
    }
    out.trim_end().to_string()
}

const UNSET_CELL: &str = "—";

fn decision_status_label(status: DecisionStatus) -> &'static str {
    match status {
        DecisionStatus::Proposed => "Proposed",
        DecisionStatus::Agreed => "Agreed",
        DecisionStatus::Rejected => "Rejected",
        DecisionStatus::Deferred => "Deferred",
    }
}

fn action_status_label(status: ActionStatus) -> &'static str {
    match status {
        ActionStatus::Open => "Open",
        ActionStatus::InProgress => "In Progress",
        ActionStatus::Done => "Done",
        ActionStatus::Blocked => "Blocked",
    }
}

/// Makes `text` safe as one Markdown table cell: a literal `|` would otherwise
/// end the cell early, and an embedded newline would break the row onto a
/// second line the table syntax cannot parse.
fn escape_cell(text: &str) -> String {
    text.trim().replace('|', "\\|").replace(['\n', '\r'], " ")
}

// ---------------------------------------------------------------------------
// Narrative sections — the only two call sites that touch the engine
// ---------------------------------------------------------------------------

fn generate_meeting_objective(
    engine: &dyn GenerationEngine,
    ir: &MeetingIr,
    cancel: &CancelToken,
) -> Result<String, MomError> {
    let facts = objective_facts(ir);
    let prompt = mom_prompt::render_mom_objective(&facts);
    let raw = run_narrative(engine, &prompt, cancel)?;
    Ok(sanitize_narrative(&raw))
}

fn generate_key_discussion_points(
    engine: &dyn GenerationEngine,
    ir: &MeetingIr,
    cancel: &CancelToken,
) -> Result<String, MomError> {
    let facts = discussion_facts(ir);
    let prompt = mom_prompt::render_mom_discussion_points(&facts);
    let raw = run_narrative(engine, &prompt, cancel)?;
    Ok(sanitize_narrative(&raw))
}

/// The facts fed to the Meeting Objective prompt: topics only. A short noun
/// phrase per topic is scope, which is what an objective describes; decisions
/// and observations are what the meeting *concluded*, which belongs in Key
/// Discussion Points instead.
fn objective_facts(ir: &MeetingIr) -> String {
    ir.facts
        .topics
        .iter()
        .map(|topic| format!("- topic: {}", strip_numbers(&topic.title)))
        .collect::<Vec<_>>()
        .join("\n")
}

/// The facts fed to the Key Discussion Points prompt: topics, decisions and
/// observations. Action items, metrics, risks, questions and next steps are
/// deliberately excluded — they already have their own deterministic home
/// (action items and next steps in this document; metrics, risks and
/// questions are out of the issue's five sections entirely) and repeating them
/// in prose would be exactly the duplication the prompt is told to avoid.
fn discussion_facts(ir: &MeetingIr) -> String {
    let mut lines = Vec::new();
    for topic in &ir.facts.topics {
        lines.push(format!("- topic: {}", strip_numbers(&topic.title)));
    }
    for decision in &ir.facts.decisions {
        lines.push(format!(
            "- decision ({}): {}",
            decision_status_label(decision.status).to_lowercase(),
            strip_numbers(&decision.statement)
        ));
    }
    for observation in &ir.facts.observations {
        lines.push(format!(
            "- observation: {}",
            strip_numbers(&observation.statement)
        ));
    }
    lines.join("\n")
}

/// Replaces every maximal run of ASCII digits (with internal `,` or `.`
/// grouping/decimal separators, so "500,000" and "3.5" collapse to one
/// placeholder rather than three) with `[number]`. The model never sees a real
/// figure to copy, restate, or subtly alter.
fn strip_numbers(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut chars = text.chars().peekable();
    while let Some(c) = chars.next() {
        if c.is_ascii_digit() {
            out.push_str("[number]");
            while let Some(&next) = chars.peek() {
                if next.is_ascii_digit() || next == ',' || next == '.' {
                    chars.next();
                } else {
                    break;
                }
            }
        } else {
            out.push(c);
        }
    }
    out
}

/// Trims the model's output and strips any digit it wrote anyway — belt and
/// braces alongside the prompt's own "NO NUMBERS" rule and the pre-stripped
/// facts it was given, so AC3 holds even against a model that ignores an
/// instruction.
fn sanitize_narrative(raw: &str) -> String {
    strip_numbers(raw.trim())
}

fn run_narrative(
    engine: &dyn GenerationEngine,
    prompt: &str,
    cancel: &CancelToken,
) -> Result<String, MomError> {
    if cancel.is_cancelled() {
        return Err(MomError::Cancelled);
    }
    let request = GenerationRequest {
        prompt: prompt.to_string(),
        max_output_tokens: NARRATIVE_MAX_OUTPUT_TOKENS,
        grammar: None,
    };
    let mut raw = String::new();
    engine
        .generate(&request, cancel, &mut |chunk| {
            raw.push_str(&chunk.text);
            Ok(())
        })
        .map_err(|e| match e {
            EngineError::Cancelled => MomError::Cancelled,
            other => MomError::Engine(other.to_string()),
        })?;
    Ok(raw)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ir::{Facts, Meeting, Topic, IR_SCHEMA_VERSION};
    use airo_mind_core::{GenerationChunk, ResourceRequest, RuntimeStats};
    use std::sync::Mutex;

    // -- deterministic tables -------------------------------------------------

    #[test]
    fn an_empty_decisions_list_renders_as_a_stated_absence() {
        assert_eq!(render_decisions_table(&[]), "_No decisions recorded._");
    }

    #[test]
    fn decisions_render_one_row_per_item_in_order() {
        let decisions = vec![
            Decision {
                statement: "move signaling onto the queue".into(),
                status: DecisionStatus::Agreed,
                ..Decision::default()
            },
            Decision {
                statement: "keep the current retry policy".into(),
                status: DecisionStatus::Proposed,
                ..Decision::default()
            },
        ];
        let table = render_decisions_table(&decisions);
        assert_eq!(
            table,
            "| Decision | Status |\n\
             | --- | --- |\n\
             | move signaling onto the queue | Agreed |\n\
             | keep the current retry policy | Proposed |"
        );
    }

    #[test]
    fn an_empty_action_items_list_renders_as_a_stated_absence() {
        assert_eq!(
            render_action_items_table(&[]),
            "_No action items recorded._"
        );
    }

    #[test]
    fn a_missing_owner_and_due_render_as_an_em_dash_not_a_guess() {
        let items = vec![ActionItem {
            task: "check the signaling limit".into(),
            owner: None,
            due: None,
            status: ActionStatus::Open,
            ..ActionItem::default()
        }];
        let table = render_action_items_table(&items);
        assert_eq!(
            table,
            "| Task | Owner | Due | Status |\n\
             | --- | --- | --- | --- |\n\
             | check the signaling limit | — | — | Open |"
        );
    }

    #[test]
    fn a_present_owner_and_due_render_verbatim() {
        let items = vec![ActionItem {
            task: "update the runbook".into(),
            owner: Some("Dev".into()),
            due: Some("Friday".into()),
            status: ActionStatus::Done,
            ..ActionItem::default()
        }];
        let table = render_action_items_table(&items);
        assert!(table.contains("| update the runbook | Dev | Friday | Done |"));
    }

    #[test]
    fn every_action_status_has_a_label() {
        for (status, label) in [
            (ActionStatus::Open, "Open"),
            (ActionStatus::InProgress, "In Progress"),
            (ActionStatus::Done, "Done"),
            (ActionStatus::Blocked, "Blocked"),
        ] {
            assert_eq!(action_status_label(status), label);
        }
    }

    #[test]
    fn every_decision_status_has_a_label() {
        for (status, label) in [
            (DecisionStatus::Proposed, "Proposed"),
            (DecisionStatus::Agreed, "Agreed"),
            (DecisionStatus::Rejected, "Rejected"),
            (DecisionStatus::Deferred, "Deferred"),
        ] {
            assert_eq!(decision_status_label(status), label);
        }
    }

    #[test]
    fn an_empty_next_steps_list_renders_as_a_stated_absence() {
        assert_eq!(render_next_steps(&[]), "_No further steps recorded._");
    }

    #[test]
    fn next_steps_render_one_bullet_per_item_in_order() {
        let steps = vec![
            NextStep {
                statement: "review the rollout plan".into(),
                ..NextStep::default()
            },
            NextStep {
                statement: "circulate the updated runbook".into(),
                ..NextStep::default()
            },
        ];
        assert_eq!(
            render_next_steps(&steps),
            "- review the rollout plan\n- circulate the updated runbook"
        );
    }

    #[test]
    fn a_literal_pipe_in_a_cell_is_escaped_so_the_table_still_parses() {
        let decisions = vec![Decision {
            statement: "use A | B for routing".into(),
            status: DecisionStatus::Agreed,
            ..Decision::default()
        }];
        assert!(render_decisions_table(&decisions).contains("use A \\| B for routing"));
    }

    #[test]
    fn an_embedded_newline_in_a_cell_becomes_a_space() {
        let decisions = vec![Decision {
            statement: "line one\nline two".into(),
            status: DecisionStatus::Agreed,
            ..Decision::default()
        }];
        assert!(render_decisions_table(&decisions).contains("line one line two"));
    }

    #[test]
    fn the_same_ir_renders_the_same_tables_every_time() {
        let decisions = vec![Decision {
            statement: "move signaling onto the queue".into(),
            status: DecisionStatus::Agreed,
            ..Decision::default()
        }];
        assert_eq!(
            render_decisions_table(&decisions),
            render_decisions_table(&decisions)
        );
    }

    // -- number stripping -------------------------------------------------------

    #[test]
    fn a_plain_integer_is_replaced_with_a_placeholder() {
        assert_eq!(
            strip_numbers("about 500000 events"),
            "about [number] events"
        );
    }

    #[test]
    fn a_grouped_and_decimal_number_collapses_to_one_placeholder() {
        assert_eq!(
            strip_numbers("roughly 500,000.5 events"),
            "roughly [number] events"
        );
    }

    #[test]
    fn text_with_no_digits_is_unchanged() {
        assert_eq!(strip_numbers("no figures here"), "no figures here");
    }

    // -- narrative facts blocks --------------------------------------------------

    #[test]
    fn objective_facts_include_topics_and_omit_decisions() {
        let ir = ir_with(Facts {
            topics: vec![Topic {
                title: "Temporal signaling limit".into(),
                ..Topic::default()
            }],
            decisions: vec![Decision {
                statement: "move signaling onto the queue".into(),
                ..Decision::default()
            }],
            ..Facts::default()
        });
        let facts = objective_facts(&ir);
        assert!(facts.contains("Temporal signaling limit"));
        assert!(!facts.contains("move signaling onto the queue"));
    }

    #[test]
    fn discussion_facts_include_topics_decisions_and_observations() {
        let ir = ir_with(Facts {
            topics: vec![Topic {
                title: "Temporal signaling limit".into(),
                ..Topic::default()
            }],
            decisions: vec![Decision {
                statement: "move signaling onto the queue".into(),
                status: DecisionStatus::Agreed,
                ..Decision::default()
            }],
            observations: vec![crate::ir::Observation {
                statement: "the pilot is nearly done".into(),
                ..crate::ir::Observation::default()
            }],
            ..Facts::default()
        });
        let facts = discussion_facts(&ir);
        assert!(facts.contains("Temporal signaling limit"));
        assert!(facts.contains("move signaling onto the queue"));
        assert!(facts.contains("agreed"));
        assert!(facts.contains("the pilot is nearly done"));
    }

    #[test]
    fn narrative_facts_never_carry_a_digit() {
        let ir = ir_with(Facts {
            observations: vec![crate::ir::Observation {
                statement: "the service handles about 500000 events a day".into(),
                ..crate::ir::Observation::default()
            }],
            ..Facts::default()
        });
        assert!(!discussion_facts(&ir).chars().any(|c| c.is_ascii_digit()));
    }

    // -- generate_mom, end to end with a test double -----------------------------

    /// Answers a fixed script in call order, and (deliberately, for the
    /// digit-stripping test below) can be told to smuggle a digit into its
    /// answer despite the prompt telling it not to.
    struct ScriptedNarrativeEngine {
        answers: Vec<&'static str>,
        calls: Mutex<usize>,
        prompts: Mutex<Vec<String>>,
    }

    impl ScriptedNarrativeEngine {
        fn new(answers: Vec<&'static str>) -> Self {
            Self {
                answers,
                calls: Mutex::new(0),
                prompts: Mutex::new(Vec::new()),
            }
        }
    }

    impl GenerationEngine for ScriptedNarrativeEngine {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(0)
        }

        fn generate(
            &self,
            request: &GenerationRequest,
            _cancel: &CancelToken,
            sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            self.prompts.lock().unwrap().push(request.prompt.clone());
            let mut calls = self.calls.lock().unwrap();
            let answer = self
                .answers
                .get(*calls)
                .unwrap_or_else(|| panic!("no scripted answer for call {}", *calls));
            *calls += 1;
            sink(GenerationChunk {
                text: (*answer).to_string(),
            })
        }

        fn stats(&self) -> RuntimeStats {
            RuntimeStats::default()
        }
    }

    struct BrokenEngine;
    impl GenerationEngine for BrokenEngine {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(0)
        }
        fn generate(
            &self,
            _request: &GenerationRequest,
            _cancel: &CancelToken,
            _sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            Err(EngineError::ModelUnavailable)
        }
        fn stats(&self) -> RuntimeStats {
            RuntimeStats::default()
        }
    }

    fn ir_with(facts: Facts) -> MeetingIr {
        MeetingIr {
            schema_version: IR_SCHEMA_VERSION.into(),
            meeting: Meeting {
                id: "meeting-0".into(),
                title: Some("Signaling capacity review".into()),
                prompt_version: "chunk_facts.v1".into(),
                ..Meeting::default()
            },
            facts,
        }
    }

    #[test]
    fn generate_mom_assembles_all_five_sections_in_order() {
        let ir = ir_with(Facts {
            topics: vec![Topic {
                title: "Temporal signaling limit".into(),
                ..Topic::default()
            }],
            decisions: vec![Decision {
                statement: "move signaling onto the queue before the release".into(),
                status: DecisionStatus::Agreed,
                ..Decision::default()
            }],
            action_items: vec![ActionItem {
                task: "check the Temporal signaling limit".into(),
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
        let engine = ScriptedNarrativeEngine::new(vec![
            "Review the Temporal signaling limit ahead of the migration.",
            "The team discussed the Temporal signaling limit and agreed to move signaling onto the queue before the release.",
        ]);

        let mom = generate_mom(&engine, &ir, &CancelToken::new()).unwrap();

        let sections = [
            "# Minutes of Meeting",
            "**Meeting:** Signaling capacity review",
            "## Meeting Objective",
            "Review the Temporal signaling limit ahead of the migration.",
            "## Key Discussion Points",
            "The team discussed the Temporal signaling limit and agreed to move signaling onto the queue before the release.",
            "## Decisions & Direction",
            "| move signaling onto the queue before the release | Agreed |",
            "## Action Items",
            "| check the Temporal signaling limit | — | Friday | Open |",
            "## Next Steps",
            "- review the rollout plan",
        ];
        let mut cursor = 0usize;
        for section in sections {
            let found = mom[cursor..].find(section).unwrap_or_else(|| {
                panic!("missing `{section}` after position {cursor} in:\n{mom}")
            });
            cursor += found + section.len();
        }
    }

    #[test]
    fn a_digit_the_model_writes_anyway_is_stripped_from_the_narrative() {
        let ir = ir_with(Facts::default());
        let engine = ScriptedNarrativeEngine::new(vec![
            "The team covered 3 topics.",
            "Discussion touched on 12 items.",
        ]);

        let mom = generate_mom(&engine, &ir, &CancelToken::new()).unwrap();

        assert!(mom.contains("[number]"));
        let narrative_end = mom.find("## Decisions").unwrap();
        assert!(
            !mom[..narrative_end].chars().any(|c| c.is_ascii_digit()),
            "a digit reached the narrative sections: {mom}"
        );
    }

    #[test]
    fn a_cancelled_run_never_reaches_the_engine() {
        let cancel = CancelToken::new();
        cancel.cancel();
        let ir = ir_with(Facts::default());
        let result = generate_mom(&BrokenEngine, &ir, &cancel);
        assert_eq!(result, Err(MomError::Cancelled));
    }

    #[test]
    fn a_broken_backend_is_an_error_not_a_blank_section() {
        let ir = ir_with(Facts::default());
        let result = generate_mom(&BrokenEngine, &ir, &CancelToken::new());
        assert_eq!(
            result,
            Err(MomError::Engine(EngineError::ModelUnavailable.to_string()))
        );
    }

    #[test]
    fn the_narrative_prompts_are_called_in_a_fixed_order() {
        let ir = ir_with(Facts {
            topics: vec![Topic {
                title: "Temporal signaling limit".into(),
                ..Topic::default()
            }],
            ..Facts::default()
        });
        let engine = ScriptedNarrativeEngine::new(vec!["objective text", "discussion text"]);
        generate_mom(&engine, &ir, &CancelToken::new()).unwrap();

        let prompts = engine.prompts.lock().unwrap();
        assert_eq!(prompts.len(), 2);
        assert!(prompts[0].contains("Meeting Objective"));
        assert!(prompts[1].contains("Key Discussion Points"));
    }

    #[test]
    fn no_narrative_prompt_ever_carries_an_owner_or_a_due_date() {
        let ir = ir_with(Facts {
            action_items: vec![ActionItem {
                task: "update the runbook".into(),
                owner: Some("Dev".into()),
                due: Some("Friday".into()),
                status: ActionStatus::Done,
                ..ActionItem::default()
            }],
            ..Facts::default()
        });
        let engine = ScriptedNarrativeEngine::new(vec!["objective text", "discussion text"]);
        generate_mom(&engine, &ir, &CancelToken::new()).unwrap();

        let prompts = engine.prompts.lock().unwrap();
        for prompt in prompts.iter() {
            assert!(!prompt.contains("Dev"));
            assert!(!prompt.contains("Friday"));
        }
    }
}

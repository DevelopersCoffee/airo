//! Deterministic post-consolidation IR validation. `#1634`.
//!
//! Pass 1 and Pass 2 already ground everything they produce, but grounding
//! there is checked against the *chunk* the model just saw — a single string
//! it was handed a moment ago. This module re-checks the *consolidated* IR
//! against the transcript's actual segment set, with no model in the loop at
//! all. It exists to catch two different classes of thing:
//!
//! - a bug in Pass 1/Pass 2's own grounding (so a regression there is caught
//!   here too, independently), and
//! - anything that arrives at this crate from somewhere other than its own
//!   two passes — a cached IR, a fixture, a future caller — which this module
//!   cannot assume was ever grounded at all.
//!
//! # No guessed speaker attribution
//!
//! Diarization is out of scope for v1: nothing in this pipeline knows who was
//! speaking when. An owner is therefore trusted only if the literal string
//! appears in the text of a segment the fact itself cites — never inferred
//! from proximity, from "who else could it be", or from anything else. Wrong
//! attribution is worse than no attribution: research named it the #1
//! trust-breaker, ahead of a missing owner. [`Violation::UngroundedOwner`]
//! nulls the owner and keeps the task; it never guesses.
//!
//! # Repair, not rejection
//!
//! A single ungrounded owner does not invalidate the fact it sits on, and a
//! single fact does not invalidate the meeting. Only a fact that has nothing
//! left to stand on — no evidence at all, or a number its own text quotes
//! that no cited segment backs up — is dropped. Everything else survives,
//! repaired, with the reason on the report.

use std::collections::{BTreeMap, BTreeSet};

use airo_mind_transcript::Segment;

use crate::dedup::{self, DedupConfig};
use crate::fact::Fact;
use crate::ir::{Facts, MeetingIr, IR_SCHEMA_VERSION};
use crate::pass1::names_appear_in;

/// How serious a [`Violation`] is.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Severity {
    /// The IR could not be trusted as handed in. The validator has already
    /// acted on it — nulled a field or dropped the fact — by the time the
    /// report reaches a caller.
    Fatal,
    /// Flagged, not touched. The fact this refers to is unchanged in the
    /// repaired IR.
    Warn,
}

/// One thing [`validate`] found wrong with the IR, and what it did about it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Violation {
    /// `schema_version` is not [`IR_SCHEMA_VERSION`]. Nothing below this is
    /// repaired away — a reader that does not recognise the version should
    /// not trust the shape of what follows either.
    UnknownSchemaVersion { found: String },
    /// A fact carried no evidence at all. Dropped outright: an unevidenced
    /// fact is not a fact this pipeline can stand behind, no matter what it
    /// says.
    NoEvidence {
        category: &'static str,
        item: String,
    },
    /// A fact cited a segment id that does not exist in the transcript's
    /// segment set. That id is removed from the fact's evidence; the fact
    /// survives if a real id remains.
    DanglingEvidence {
        category: &'static str,
        item: String,
        segment_id: String,
    },
    /// Every segment id a fact cited was dangling. Nothing legitimate backs
    /// it, so it is dropped.
    AllEvidenceDangling {
        category: &'static str,
        item: String,
    },
    /// An action item's owner does not appear, as a whole word, in any
    /// segment the item cites. The owner is nulled; the task itself survives
    /// — see the module doc comment on why a guess is never substituted.
    UngroundedOwner { item: String, owner: String },
    /// A number the fact's own text quotes does not appear in any segment it
    /// cites. Dropped rather than repaired: there is no safe way to excise
    /// one invented figure from an arbitrary sentence and trust what is left.
    UngroundedNumber {
        category: &'static str,
        item: String,
        number: String,
    },
    /// Two items in the same category, after consolidation, still look like
    /// the same fact stated twice. Pass 2's dedup should have merged them and
    /// did not — flagged for review, not merged here: a second, less
    /// informed merge pass is not an improvement on the first one missing it.
    PossibleDuplicate {
        category: &'static str,
        left: String,
        right: String,
    },
}

impl Violation {
    pub fn severity(&self) -> Severity {
        match self {
            Violation::PossibleDuplicate { .. } => Severity::Warn,
            _ => Severity::Fatal,
        }
    }
}

/// Everything [`validate`] found, in the order it found it.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct ValidationReport {
    pub violations: Vec<Violation>,
}

impl ValidationReport {
    pub fn is_clean(&self) -> bool {
        self.violations.is_empty()
    }

    pub fn fatal_count(&self) -> usize {
        self.violations
            .iter()
            .filter(|v| v.severity() == Severity::Fatal)
            .count()
    }

    pub fn warn_count(&self) -> usize {
        self.violations
            .iter()
            .filter(|v| v.severity() == Severity::Warn)
            .count()
    }
}

/// Validates `ir` against `segments`, the transcript it claims to be evidence
/// from.
///
/// Pure and deterministic: no model call, and the same inputs always produce
/// the same repaired IR and the same report. Returns the repaired IR
/// alongside the report — the pattern [`crate::pass2::consolidate`] already
/// uses — rather than mutating in place, so a caller that wants to compare
/// before and after still can.
pub fn validate(ir: &MeetingIr, segments: &[Segment]) -> (MeetingIr, ValidationReport) {
    let mut violations = Vec::new();

    if ir.schema_version != IR_SCHEMA_VERSION {
        violations.push(Violation::UnknownSchemaVersion {
            found: ir.schema_version.clone(),
        });
    }

    let segment_text: BTreeMap<&str, &str> = segments
        .iter()
        .map(|s| (s.id.as_str(), s.text.as_str()))
        .collect();
    let known_ids: BTreeSet<&str> = segment_text.keys().copied().collect();

    let mut facts = Facts {
        topics: ground_and_number_check(
            ir.facts.topics.clone(),
            &known_ids,
            &segment_text,
            &mut violations,
        ),
        observations: ground_and_number_check(
            ir.facts.observations.clone(),
            &known_ids,
            &segment_text,
            &mut violations,
        ),
        decisions: ground_and_number_check(
            ir.facts.decisions.clone(),
            &known_ids,
            &segment_text,
            &mut violations,
        ),
        action_items: ground_and_number_check(
            ir.facts.action_items.clone(),
            &known_ids,
            &segment_text,
            &mut violations,
        ),
        metrics: ground_and_number_check(
            ir.facts.metrics.clone(),
            &known_ids,
            &segment_text,
            &mut violations,
        ),
        risks: ground_and_number_check(
            ir.facts.risks.clone(),
            &known_ids,
            &segment_text,
            &mut violations,
        ),
        questions: ground_and_number_check(
            ir.facts.questions.clone(),
            &known_ids,
            &segment_text,
            &mut violations,
        ),
        next_steps: ground_and_number_check(
            ir.facts.next_steps.clone(),
            &known_ids,
            &segment_text,
            &mut violations,
        ),
    };

    for item in &mut facts.action_items {
        if let Some(owner) = item.owner.take() {
            let cited_text = combined_evidence_text(&item.evidence, &segment_text);
            if names_appear_in(&owner, &cited_text) {
                item.owner = Some(owner);
            } else {
                violations.push(Violation::UngroundedOwner {
                    item: item.task.clone(),
                    owner,
                });
            }
        }
    }

    detect_duplicates(&facts.topics, &mut violations);
    detect_duplicates(&facts.observations, &mut violations);
    detect_duplicates(&facts.decisions, &mut violations);
    detect_duplicates(&facts.action_items, &mut violations);
    detect_duplicates(&facts.metrics, &mut violations);
    detect_duplicates(&facts.risks, &mut violations);
    detect_duplicates(&facts.questions, &mut violations);
    detect_duplicates(&facts.next_steps, &mut violations);

    let repaired = MeetingIr {
        schema_version: ir.schema_version.clone(),
        meeting: ir.meeting.clone(),
        facts,
    };

    (repaired, ValidationReport { violations })
}

/// Evidence grounding, dangling-segment removal, and numeric grounding for
/// one category. Owner grounding is handled separately by [`validate`]: it is
/// specific to `ActionItem` and needs the surviving (post-dangling-removal)
/// evidence this function has already computed.
fn ground_and_number_check<F: Fact>(
    items: Vec<F>,
    known_ids: &BTreeSet<&str>,
    segment_text: &BTreeMap<&str, &str>,
    violations: &mut Vec<Violation>,
) -> Vec<F> {
    let mut kept = Vec::with_capacity(items.len());
    for mut item in items {
        if item.evidence().is_empty() {
            violations.push(Violation::NoEvidence {
                category: F::CATEGORY,
                item: item.text().to_string(),
            });
            continue;
        }

        let mut grounded_evidence = Vec::with_capacity(item.evidence().len());
        for id in item.evidence() {
            if known_ids.contains(id.as_str()) {
                if !grounded_evidence.iter().any(|existing| existing == id) {
                    grounded_evidence.push(id.clone());
                }
            } else {
                violations.push(Violation::DanglingEvidence {
                    category: F::CATEGORY,
                    item: item.text().to_string(),
                    segment_id: id.clone(),
                });
            }
        }

        if grounded_evidence.is_empty() {
            violations.push(Violation::AllEvidenceDangling {
                category: F::CATEGORY,
                item: item.text().to_string(),
            });
            continue;
        }
        *item.evidence_mut() = grounded_evidence;

        let cited_text = combined_evidence_text(item.evidence(), segment_text);
        let mut fields = vec![item.text()];
        fields.extend(item.extra_text());

        let mut numbers: Vec<String> = Vec::new();
        for field in fields {
            numbers.extend(ungrounded_numbers(field, &cited_text));
        }
        if !numbers.is_empty() {
            for number in numbers {
                violations.push(Violation::UngroundedNumber {
                    category: F::CATEGORY,
                    item: item.text().to_string(),
                    number,
                });
            }
            continue;
        }

        kept.push(item);
    }
    kept
}

/// The text of every segment `evidence` cites, joined with a space. Ids that
/// are not in `segment_text` are skipped rather than panicking — by the time
/// this runs, evidence has already been through dangling-id removal, but a
/// caller of the smaller helpers directly should not be able to crash it.
fn combined_evidence_text(evidence: &[String], segment_text: &BTreeMap<&str, &str>) -> String {
    evidence
        .iter()
        .filter_map(|id| segment_text.get(id.as_str()))
        .copied()
        .collect::<Vec<_>>()
        .join(" ")
}

/// Every maximal run of ASCII digits in `text`, split on non-alphanumeric
/// boundaries the same way [`names_appear_in`] splits words — so `"4000/sec"`
/// yields `"4000"` and `"16 cores"` yields `"16"`.
fn digit_tokens(text: &str) -> BTreeSet<String> {
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty() && w.chars().all(|c| c.is_ascii_digit()))
        .map(|w| w.to_string())
        .collect()
}

/// The digit tokens `claimed` quotes that do not appear anywhere in
/// `cited_text`.
fn ungrounded_numbers(claimed: &str, cited_text: &str) -> Vec<String> {
    let wanted = digit_tokens(claimed);
    if wanted.is_empty() {
        return Vec::new();
    }
    let available = digit_tokens(cited_text);
    wanted.difference(&available).cloned().collect()
}

/// Flags every pair in `items` whose text the same near-duplicate heuristic
/// Pass 2 uses would have merged.
fn detect_duplicates<F: Fact>(items: &[F], violations: &mut Vec<Violation>) {
    let config = DedupConfig::default();
    for i in 0..items.len() {
        for j in (i + 1)..items.len() {
            if dedup::is_near_duplicate(items[i].text(), items[j].text(), &config) {
                violations.push(Violation::PossibleDuplicate {
                    category: F::CATEGORY,
                    left: items[i].text().to_string(),
                    right: items[j].text().to_string(),
                });
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ir::{ActionItem, Decision, Meeting, Metric, Observation};

    fn segments() -> Vec<Segment> {
        vec![
            Segment {
                id: "s0".into(),
                start_ms: 0,
                end_ms: 1_000,
                text: "Priya will check the Temporal signalling limit.".into(),
            },
            Segment {
                id: "s1".into(),
                start_ms: 1_000,
                end_ms: 2_000,
                text: "The service handles about 500000 events a day.".into(),
            },
            Segment {
                id: "s2".into(),
                start_ms: 2_000,
                end_ms: 3_000,
                text: "Throughput topped out around 200 TPS in the last test.".into(),
            },
        ]
    }

    fn meeting() -> Meeting {
        Meeting {
            id: "meeting-0".into(),
            prompt_version: "chunk_facts.v1".into(),
            ..Meeting::default()
        }
    }

    fn ir_with(facts: Facts) -> MeetingIr {
        MeetingIr {
            schema_version: IR_SCHEMA_VERSION.into(),
            meeting: meeting(),
            facts,
        }
    }

    // -- seeded hallucination: invented owner -------------------------------

    #[test]
    fn an_owner_not_named_in_any_cited_segment_is_nulled_not_kept() {
        let ir = ir_with(Facts {
            action_items: vec![ActionItem {
                task: "check the signalling limit".into(),
                owner: Some("Rahul".into()),
                evidence: vec!["s0".into()],
                ..ActionItem::default()
            }],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert_eq!(
            repaired.facts.action_items.len(),
            1,
            "the task itself survives"
        );
        assert_eq!(repaired.facts.action_items[0].owner, None);
        assert!(report.violations.contains(&Violation::UngroundedOwner {
            item: "check the signalling limit".into(),
            owner: "Rahul".into(),
        }));
        assert_eq!(report.fatal_count(), 1);
    }

    #[test]
    fn an_owner_the_cited_segment_does_name_survives() {
        let ir = ir_with(Facts {
            action_items: vec![ActionItem {
                task: "check the signalling limit".into(),
                owner: Some("Priya".into()),
                evidence: vec!["s0".into()],
                ..ActionItem::default()
            }],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert_eq!(
            repaired.facts.action_items[0].owner.as_deref(),
            Some("Priya")
        );
        assert!(report.is_clean());
    }

    #[test]
    fn an_owner_named_only_in_a_segment_the_fact_does_not_cite_is_still_nulled() {
        // Diarization is out of scope: the owner must be grounded in a
        // segment *this fact* cites, not merely somewhere in the transcript.
        let ir = ir_with(Facts {
            action_items: vec![ActionItem {
                task: "confirm the daily volume".into(),
                owner: Some("Priya".into()),
                evidence: vec!["s1".into()],
                ..ActionItem::default()
            }],
            ..Facts::default()
        });

        let (repaired, _report) = validate(&ir, &segments());
        assert_eq!(repaired.facts.action_items[0].owner, None);
    }

    // -- seeded hallucination: altered number --------------------------------

    #[test]
    fn a_metric_value_not_present_in_its_cited_segment_is_dropped() {
        let ir = ir_with(Facts {
            metrics: vec![Metric {
                name: "throughput".into(),
                value: "2000 TPS".into(),
                evidence: vec!["s2".into()],
                ..Metric::default()
            }],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert!(repaired.facts.metrics.is_empty());
        assert!(report.violations.iter().any(|v| matches!(
            v,
            Violation::UngroundedNumber { category: "metric", number, .. } if number == "2000"
        )));
        assert_eq!(report.fatal_count(), 1);
    }

    #[test]
    fn a_metric_value_the_cited_segment_does_quote_survives() {
        let ir = ir_with(Facts {
            metrics: vec![Metric {
                name: "throughput".into(),
                value: "200 TPS".into(),
                evidence: vec!["s2".into()],
                ..Metric::default()
            }],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert_eq!(repaired.facts.metrics.len(), 1);
        assert!(report.is_clean());
    }

    #[test]
    fn a_number_in_an_observations_own_statement_is_checked_too() {
        let ir = ir_with(Facts {
            observations: vec![Observation {
                statement: "the service handles 600000 events a day".into(),
                evidence: vec!["s1".into()],
                ..Observation::default()
            }],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert!(repaired.facts.observations.is_empty());
        assert!(report.violations.iter().any(|v| matches!(
            v,
            Violation::UngroundedNumber { number, .. } if number == "600000"
        )));
    }

    // -- seeded hallucination: dangling segment id ---------------------------

    #[test]
    fn a_fact_citing_a_segment_id_that_does_not_exist_has_it_removed() {
        let ir = ir_with(Facts {
            decisions: vec![Decision {
                statement: "move signalling to the queue".into(),
                evidence: vec!["s0".into(), "s99".into()],
                ..Decision::default()
            }],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert_eq!(repaired.facts.decisions.len(), 1, "one real id remains");
        assert_eq!(repaired.facts.decisions[0].evidence, vec!["s0"]);
        assert!(report.violations.contains(&Violation::DanglingEvidence {
            category: "decision",
            item: "move signalling to the queue".into(),
            segment_id: "s99".into(),
        }));
    }

    #[test]
    fn a_fact_whose_only_segment_id_is_dangling_is_dropped() {
        let ir = ir_with(Facts {
            decisions: vec![Decision {
                statement: "move signalling to the queue".into(),
                evidence: vec!["s99".into()],
                ..Decision::default()
            }],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert!(repaired.facts.decisions.is_empty());
        assert!(report.violations.iter().any(|v| matches!(
            v,
            Violation::AllEvidenceDangling {
                category: "decision",
                ..
            }
        )));
        assert!(report.violations.iter().any(|v| matches!(
            v,
            Violation::DanglingEvidence {
                category: "decision",
                ..
            }
        )));
    }

    #[test]
    fn a_fact_with_no_evidence_at_all_is_dropped() {
        let ir = ir_with(Facts {
            decisions: vec![Decision {
                statement: "move signalling to the queue".into(),
                evidence: vec![],
                ..Decision::default()
            }],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert!(repaired.facts.decisions.is_empty());
        assert!(report.violations.iter().any(|v| matches!(
            v,
            Violation::NoEvidence {
                category: "decision",
                ..
            }
        )));
    }

    // -- schema version -------------------------------------------------------

    #[test]
    fn an_unrecognised_schema_version_is_flagged() {
        let mut ir = ir_with(Facts::default());
        ir.schema_version = "0.9.0".into();

        let (_repaired, report) = validate(&ir, &segments());

        assert!(report
            .violations
            .contains(&Violation::UnknownSchemaVersion {
                found: "0.9.0".into(),
            }));
        assert_eq!(report.fatal_count(), 1);
    }

    // -- duplicate detection (warn, not fatal) ---------------------------------

    #[test]
    fn near_duplicate_observations_are_flagged_as_a_warning_not_dropped() {
        let ir = ir_with(Facts {
            decisions: vec![
                Decision {
                    statement: "Check Temporal signalling limit".into(),
                    evidence: vec!["s0".into()],
                    ..Decision::default()
                },
                Decision {
                    statement: "Confirm Temporal signalling capacity".into(),
                    evidence: vec!["s0".into()],
                    ..Decision::default()
                },
            ],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert_eq!(repaired.facts.decisions.len(), 2, "both survive, unmerged");
        assert!(report.violations.iter().any(|v| matches!(
            v,
            Violation::PossibleDuplicate {
                category: "decision",
                ..
            }
        )));
        assert_eq!(report.warn_count(), 1);
        assert_eq!(report.fatal_count(), 0);
    }

    #[test]
    fn dissimilar_decisions_do_not_trigger_a_duplicate_warning() {
        let ir = ir_with(Facts {
            decisions: vec![
                Decision {
                    statement: "move signalling to the queue".into(),
                    evidence: vec!["s0".into()],
                    ..Decision::default()
                },
                Decision {
                    statement: "the daily volume is stable".into(),
                    evidence: vec!["s1".into()],
                    ..Decision::default()
                },
            ],
            ..Facts::default()
        });

        let (_repaired, report) = validate(&ir, &segments());
        assert!(report.is_clean());
    }

    // -- a clean IR reports nothing --------------------------------------------

    #[test]
    fn a_fully_grounded_ir_produces_an_empty_report() {
        let ir = ir_with(Facts {
            action_items: vec![ActionItem {
                task: "check the Temporal signalling limit".into(),
                owner: Some("Priya".into()),
                evidence: vec!["s0".into()],
                ..ActionItem::default()
            }],
            metrics: vec![Metric {
                name: "throughput".into(),
                value: "200 TPS".into(),
                evidence: vec!["s2".into()],
                ..Metric::default()
            }],
            ..Facts::default()
        });

        let (repaired, report) = validate(&ir, &segments());

        assert!(report.is_clean());
        assert_eq!(repaired.facts.action_items.len(), 1);
        assert_eq!(repaired.facts.metrics.len(), 1);
    }
}

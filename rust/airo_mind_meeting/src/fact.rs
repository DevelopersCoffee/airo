//! The one thing all eight IR categories have in common.
//!
//! Grounding, id assignment and consolidation are the same operation for a
//! `Decision` as for a `Risk` — only the field names differ. [`Fact`] is the
//! seam that lets each of those be written once. It is `pub(crate)`: it exists
//! to remove triplicated code, not to become a public extension point.

use crate::diagnostics::Diagnostic;
use crate::ir::{
    ActionItem, ActionStatus, Decision, DecisionStatus, Metric, NextStep, Observation, Question,
    Risk, Topic,
};

pub(crate) trait Fact: Sized {
    /// Singular, snake_case. Used for item ids (`decision-0`) and in
    /// diagnostics.
    const CATEGORY: &'static str;

    fn set_id(&mut self, id: String);
    /// The natural-language content the dedup heuristic compares.
    fn text(&self) -> &str;
    fn evidence(&self) -> &[String];
    fn evidence_mut(&mut self) -> &mut Vec<String>;

    /// Folds a later near-duplicate into this item.
    ///
    /// Evidence is always unioned. Everything else is category-specific and
    /// overridden below; the default handles the categories that carry nothing
    /// but text and evidence.
    fn absorb(&mut self, other: Self, diagnostics: &mut Vec<Diagnostic>) {
        let _ = diagnostics;
        union_evidence(self.evidence_mut(), other.evidence());
    }
}

/// Appends `incoming`'s ids that `into` does not already have, preserving
/// first-seen order.
///
/// First-seen order rather than sorted: segment ids are produced in transcript
/// order, so encounter order *is* chronological order, while sorting them
/// lexicographically would put `s10` before `s2`.
pub(crate) fn union_evidence(into: &mut Vec<String>, incoming: &[String]) {
    for id in incoming {
        if !into.iter().any(|existing| existing == id) {
            into.push(id.clone());
        }
    }
}

/// Keeps the earlier value when two merged items disagree, and says so.
///
/// The earlier one wins because it is the one said closest to where the fact
/// was established; a later mention is usually a recap. A conflict here is also
/// a signal that the dedup threshold may have merged two different things,
/// which is why it is reported rather than resolved quietly.
fn keep_earlier<T: PartialEq + std::fmt::Display>(
    kept: &mut Option<T>,
    incoming: Option<T>,
    category: &'static str,
    item: &str,
    field: &'static str,
    diagnostics: &mut Vec<Diagnostic>,
) {
    match (&*kept, incoming) {
        (None, incoming) => *kept = incoming,
        (Some(_), None) => {}
        (Some(existing), Some(incoming)) => {
            if *existing != incoming {
                diagnostics.push(Diagnostic::ConflictingDetail {
                    category,
                    item: item.to_string(),
                    field,
                    kept: existing.to_string(),
                    discarded: incoming.to_string(),
                });
            }
        }
    }
}

impl Fact for Topic {
    const CATEGORY: &'static str = "topic";
    fn set_id(&mut self, id: String) {
        self.id = id;
    }
    fn text(&self) -> &str {
        &self.title
    }
    fn evidence(&self) -> &[String] {
        &self.evidence
    }
    fn evidence_mut(&mut self) -> &mut Vec<String> {
        &mut self.evidence
    }
}

impl Fact for Observation {
    const CATEGORY: &'static str = "observation";
    fn set_id(&mut self, id: String) {
        self.id = id;
    }
    fn text(&self) -> &str {
        &self.statement
    }
    fn evidence(&self) -> &[String] {
        &self.evidence
    }
    fn evidence_mut(&mut self) -> &mut Vec<String> {
        &mut self.evidence
    }
}

impl Fact for Decision {
    const CATEGORY: &'static str = "decision";
    fn set_id(&mut self, id: String) {
        self.id = id;
    }
    fn text(&self) -> &str {
        &self.statement
    }
    fn evidence(&self) -> &[String] {
        &self.evidence
    }
    fn evidence_mut(&mut self) -> &mut Vec<String> {
        &mut self.evidence
    }

    /// Status resolution across chunks: a **resolved** status beats
    /// `Proposed`, and among resolved statuses the later mention wins.
    ///
    /// Not simply "later wins": a decision agreed in chunk 1 and recapped in
    /// chunk 4 ("so we're doing X?") would be demoted back to `Proposed` by
    /// that rule, which is the wrong answer. `Proposed` is the "not settled
    /// yet" default, so a chunk that carries it adds no information about
    /// resolution.
    fn absorb(&mut self, other: Self, diagnostics: &mut Vec<Diagnostic>) {
        union_evidence(&mut self.evidence, &other.evidence);
        if other.status != DecisionStatus::Proposed {
            self.status = other.status;
        }
        let _ = diagnostics;
    }
}

impl Fact for ActionItem {
    const CATEGORY: &'static str = "action_item";
    fn set_id(&mut self, id: String) {
        self.id = id;
    }
    fn text(&self) -> &str {
        &self.task
    }
    fn evidence(&self) -> &[String] {
        &self.evidence
    }
    fn evidence_mut(&mut self) -> &mut Vec<String> {
        &mut self.evidence
    }

    /// An owner named in *any* chunk fills a `None` — the transcript naming
    /// somebody once is enough, and the chunks that did not name them are not
    /// evidence that nobody was named. What this must never do is invent one:
    /// two items both carrying `None` still merge to `None`.
    fn absorb(&mut self, other: Self, diagnostics: &mut Vec<Diagnostic>) {
        union_evidence(&mut self.evidence, &other.evidence);
        let task = self.task.clone();
        keep_earlier(
            &mut self.owner,
            other.owner,
            Self::CATEGORY,
            &task,
            "owner",
            diagnostics,
        );
        keep_earlier(
            &mut self.due,
            other.due,
            Self::CATEGORY,
            &task,
            "due",
            diagnostics,
        );
        if other.status != ActionStatus::Open {
            self.status = other.status;
        }
    }
}

impl Fact for Metric {
    const CATEGORY: &'static str = "metric";
    fn set_id(&mut self, id: String) {
        self.id = id;
    }
    fn text(&self) -> &str {
        &self.name
    }
    fn evidence(&self) -> &[String] {
        &self.evidence
    }
    fn evidence_mut(&mut self) -> &mut Vec<String> {
        &mut self.evidence
    }
}

impl Fact for Risk {
    const CATEGORY: &'static str = "risk";
    fn set_id(&mut self, id: String) {
        self.id = id;
    }
    fn text(&self) -> &str {
        &self.statement
    }
    fn evidence(&self) -> &[String] {
        &self.evidence
    }
    fn evidence_mut(&mut self) -> &mut Vec<String> {
        &mut self.evidence
    }
}

impl Fact for Question {
    const CATEGORY: &'static str = "question";
    fn set_id(&mut self, id: String) {
        self.id = id;
    }
    fn text(&self) -> &str {
        &self.question
    }
    fn evidence(&self) -> &[String] {
        &self.evidence
    }
    fn evidence_mut(&mut self) -> &mut Vec<String> {
        &mut self.evidence
    }

    /// A question answered in a later chunk is answered, full stop.
    fn absorb(&mut self, other: Self, diagnostics: &mut Vec<Diagnostic>) {
        union_evidence(&mut self.evidence, &other.evidence);
        let question = self.question.clone();
        keep_earlier(
            &mut self.answer,
            other.answer,
            Self::CATEGORY,
            &question,
            "answer",
            diagnostics,
        );
    }
}

impl Fact for NextStep {
    const CATEGORY: &'static str = "next_step";
    fn set_id(&mut self, id: String) {
        self.id = id;
    }
    fn text(&self) -> &str {
        &self.statement
    }
    fn evidence(&self) -> &[String] {
        &self.evidence
    }
    fn evidence_mut(&mut self) -> &mut Vec<String> {
        &mut self.evidence
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn evidence_unions_without_reordering_what_was_already_there() {
        let mut into = vec!["s2".to_string(), "s10".to_string()];
        union_evidence(&mut into, &["s10".to_string(), "s11".to_string()]);
        assert_eq!(into, vec!["s2", "s10", "s11"]);
    }

    #[test]
    fn an_agreed_decision_is_not_demoted_by_a_later_recap() {
        let mut agreed = Decision {
            statement: "move signalling to the queue".into(),
            status: DecisionStatus::Agreed,
            evidence: vec!["s1".into()],
            ..Decision::default()
        };
        let recap = Decision {
            statement: "move signalling to the queue".into(),
            status: DecisionStatus::Proposed,
            evidence: vec!["s9".into()],
            ..Decision::default()
        };
        agreed.absorb(recap, &mut Vec::new());
        assert_eq!(agreed.status, DecisionStatus::Agreed);
        assert_eq!(agreed.evidence, vec!["s1", "s9"]);
    }

    #[test]
    fn a_later_rejection_overrides_an_earlier_proposal() {
        let mut proposed = Decision {
            statement: "add a second region".into(),
            status: DecisionStatus::Proposed,
            ..Decision::default()
        };
        proposed.absorb(
            Decision {
                statement: "add a second region".into(),
                status: DecisionStatus::Rejected,
                ..Decision::default()
            },
            &mut Vec::new(),
        );
        assert_eq!(proposed.status, DecisionStatus::Rejected);
    }

    #[test]
    fn two_ownerless_action_items_merge_to_an_ownerless_action_item() {
        let mut first = ActionItem {
            task: "check the signalling limit".into(),
            owner: None,
            ..ActionItem::default()
        };
        first.absorb(
            ActionItem {
                task: "confirm the signalling limit".into(),
                owner: None,
                ..ActionItem::default()
            },
            &mut Vec::new(),
        );
        assert_eq!(first.owner, None);
    }

    #[test]
    fn an_owner_named_in_a_later_chunk_fills_an_empty_one() {
        let mut first = ActionItem {
            task: "check the signalling limit".into(),
            owner: None,
            ..ActionItem::default()
        };
        first.absorb(
            ActionItem {
                task: "check the signalling limit".into(),
                owner: Some("Priya".into()),
                ..ActionItem::default()
            },
            &mut Vec::new(),
        );
        assert_eq!(first.owner.as_deref(), Some("Priya"));
    }

    #[test]
    fn conflicting_owners_keep_the_earlier_one_and_report_it() {
        let mut first = ActionItem {
            task: "check the signalling limit".into(),
            owner: Some("Priya".into()),
            ..ActionItem::default()
        };
        let mut diagnostics = Vec::new();
        first.absorb(
            ActionItem {
                task: "check the signalling limit".into(),
                owner: Some("Dev".into()),
                ..ActionItem::default()
            },
            &mut diagnostics,
        );
        assert_eq!(first.owner.as_deref(), Some("Priya"));
        assert_eq!(
            diagnostics,
            vec![Diagnostic::ConflictingDetail {
                category: "action_item",
                item: "check the signalling limit".into(),
                field: "owner",
                kept: "Priya".into(),
                discarded: "Dev".into(),
            }]
        );
    }
}

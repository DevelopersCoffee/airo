//! Extraction precision/recall/F1 per IR category. `#1636`.
//!
//! Matches predicted facts against a golden IR by the same semantic-match
//! heuristic `airo_mind_meeting::pass2` uses to dedup near-duplicate facts
//! within one meeting (`airo_mind_meeting::dedup::is_near_duplicate`) --
//! deliberately the *same* function, not a second one, so this harness scores
//! Pass 2's actual notion of "the same fact" rather than a drifting
//! reimplementation of it. Exact text match would fail every correct
//! extraction phrased even slightly differently from the golden fixture;
//! embeddings are the obvious alternative and are the thing `dedup`'s own doc
//! comment already explains this crate family does not have a primitive for.
//!
//! Matching is greedy bipartite: golden items are matched in order, each
//! against the first not-yet-matched predicted item that is a near-duplicate.
//! Not globally optimal (a predicted item might match a *later* golden item
//! better), but deterministic and the golden fixture's items are never
//! textually close enough to each other for that to matter in practice --
//! and a harness whose own matching algorithm was non-deterministic would be
//! a worse foundation for a quality gate than a slightly conservative one.

use airo_mind_meeting::dedup::{self, DedupConfig};
use airo_mind_meeting::ir::Facts;

/// One category's precision/recall/F1.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct CategoryScore {
    pub category: &'static str,
    pub predicted_count: usize,
    pub golden_count: usize,
    pub matched: usize,
    /// `matched / predicted_count`. `1.0` when nothing was predicted --
    /// nothing was invented, even though recall will separately show what
    /// was missed.
    pub precision: f64,
    /// `matched / golden_count`. `1.0` when the golden fixture has nothing in
    /// this category -- nothing to have missed.
    pub recall: f64,
    pub f1: f64,
}

fn f1_of(precision: f64, recall: f64) -> f64 {
    if precision + recall == 0.0 {
        0.0
    } else {
        2.0 * precision * recall / (precision + recall)
    }
}

/// Scores one category: `predicted` and `golden` are the natural-language
/// text of each item (`Decision::statement`, `Topic::title`, ...) -- the
/// caller extracts the field per category, since `Facts`'s per-category types
/// do not share a public trait for it (`airo_mind_meeting::fact::Fact` is
/// crate-private, by design -- see that module's doc comment).
pub fn score_category(
    category: &'static str,
    predicted: &[String],
    golden: &[String],
    config: &DedupConfig,
) -> CategoryScore {
    let mut used = vec![false; predicted.len()];
    let mut matched = 0usize;
    for g in golden {
        if let Some(idx) = predicted
            .iter()
            .enumerate()
            .find(|(i, p)| !used[*i] && dedup::is_near_duplicate(p, g, config))
            .map(|(i, _)| i)
        {
            used[idx] = true;
            matched += 1;
        }
    }

    let precision = if predicted.is_empty() {
        1.0
    } else {
        matched as f64 / predicted.len() as f64
    };
    let recall = if golden.is_empty() {
        1.0
    } else {
        matched as f64 / golden.len() as f64
    };

    CategoryScore {
        category,
        predicted_count: predicted.len(),
        golden_count: golden.len(),
        matched,
        precision,
        recall,
        f1: f1_of(precision, recall),
    }
}

/// One score per IR category, plus a macro-average F1 across the eight.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct ExtractionScores {
    pub topics: CategoryScore,
    pub observations: CategoryScore,
    pub decisions: CategoryScore,
    pub action_items: CategoryScore,
    pub metrics: CategoryScore,
    pub risks: CategoryScore,
    pub questions: CategoryScore,
    pub next_steps: CategoryScore,
    pub macro_f1: f64,
}

impl ExtractionScores {
    #[cfg(test)]
    fn categories(&self) -> [&CategoryScore; 8] {
        [
            &self.topics,
            &self.observations,
            &self.decisions,
            &self.action_items,
            &self.metrics,
            &self.risks,
            &self.questions,
            &self.next_steps,
        ]
    }
}

/// Scores every category of `predicted` against `golden`.
pub fn score_extraction(
    predicted: &Facts,
    golden: &Facts,
    config: &DedupConfig,
) -> ExtractionScores {
    let topics = score_category(
        "topic",
        &texts(predicted.topics.iter().map(|t| t.title.as_str())),
        &texts(golden.topics.iter().map(|t| t.title.as_str())),
        config,
    );
    let observations = score_category(
        "observation",
        &texts(predicted.observations.iter().map(|o| o.statement.as_str())),
        &texts(golden.observations.iter().map(|o| o.statement.as_str())),
        config,
    );
    let decisions = score_category(
        "decision",
        &texts(predicted.decisions.iter().map(|d| d.statement.as_str())),
        &texts(golden.decisions.iter().map(|d| d.statement.as_str())),
        config,
    );
    let action_items = score_category(
        "action_item",
        &texts(predicted.action_items.iter().map(|a| a.task.as_str())),
        &texts(golden.action_items.iter().map(|a| a.task.as_str())),
        config,
    );
    let metrics = score_category(
        "metric",
        &texts(predicted.metrics.iter().map(|m| m.name.as_str())),
        &texts(golden.metrics.iter().map(|m| m.name.as_str())),
        config,
    );
    let risks = score_category(
        "risk",
        &texts(predicted.risks.iter().map(|r| r.statement.as_str())),
        &texts(golden.risks.iter().map(|r| r.statement.as_str())),
        config,
    );
    let questions = score_category(
        "question",
        &texts(predicted.questions.iter().map(|q| q.question.as_str())),
        &texts(golden.questions.iter().map(|q| q.question.as_str())),
        config,
    );
    let next_steps = score_category(
        "next_step",
        &texts(predicted.next_steps.iter().map(|n| n.statement.as_str())),
        &texts(golden.next_steps.iter().map(|n| n.statement.as_str())),
        config,
    );

    let scores = [
        &topics,
        &observations,
        &decisions,
        &action_items,
        &metrics,
        &risks,
        &questions,
        &next_steps,
    ];
    let macro_f1 = scores.iter().map(|s| s.f1).sum::<f64>() / scores.len() as f64;

    ExtractionScores {
        topics,
        observations,
        decisions,
        action_items,
        metrics,
        risks,
        questions,
        next_steps,
        macro_f1,
    }
}

fn texts<'a>(iter: impl Iterator<Item = &'a str>) -> Vec<String> {
    iter.map(|s| s.to_string()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn s(items: &[&str]) -> Vec<String> {
        items.iter().map(|s| s.to_string()).collect()
    }

    #[test]
    fn an_exact_match_scores_perfectly() {
        let predicted = s(&["check the Temporal signaling limit"]);
        let golden = s(&["check the Temporal signaling limit"]);
        let score = score_category("action_item", &predicted, &golden, &DedupConfig::default());
        assert_eq!(score.matched, 1);
        assert_eq!(score.precision, 1.0);
        assert_eq!(score.recall, 1.0);
        assert_eq!(score.f1, 1.0);
    }

    #[test]
    fn a_semantically_equivalent_phrasing_still_matches() {
        // The issue's own worked dedup example -- Jaccard-similar, same
        // domain token, different wording.
        let predicted = s(&["Confirm Temporal signalling capacity"]);
        let golden = s(&["Check Temporal signalling limit"]);
        let score = score_category("action_item", &predicted, &golden, &DedupConfig::default());
        assert_eq!(score.matched, 1);
        assert_eq!(score.f1, 1.0);
    }

    #[test]
    fn an_unrelated_prediction_does_not_match_and_costs_precision() {
        let predicted = s(&["order lunch for the team"]);
        let golden = s(&["check the Temporal signaling limit"]);
        let score = score_category("action_item", &predicted, &golden, &DedupConfig::default());
        assert_eq!(score.matched, 0);
        assert_eq!(score.precision, 0.0);
        assert_eq!(score.recall, 0.0);
        assert_eq!(score.f1, 0.0);
    }

    #[test]
    fn a_missed_golden_item_costs_recall_not_precision() {
        let predicted = s(&["check the Temporal signaling limit"]);
        let golden = s(&[
            "check the Temporal signaling limit",
            "review the rollout plan",
        ]);
        let score = score_category("action_item", &predicted, &golden, &DedupConfig::default());
        assert_eq!(score.matched, 1);
        assert_eq!(score.precision, 1.0);
        assert_eq!(score.recall, 0.5);
    }

    #[test]
    fn an_extra_predicted_item_costs_precision_not_recall() {
        let predicted = s(&[
            "check the Temporal signaling limit",
            "order lunch for the team",
        ]);
        let golden = s(&["check the Temporal signaling limit"]);
        let score = score_category("action_item", &predicted, &golden, &DedupConfig::default());
        assert_eq!(score.matched, 1);
        assert_eq!(score.precision, 0.5);
        assert_eq!(score.recall, 1.0);
    }

    #[test]
    fn an_empty_golden_category_with_no_prediction_is_a_perfect_score() {
        let score = score_category("risk", &[], &[], &DedupConfig::default());
        assert_eq!(score.precision, 1.0);
        assert_eq!(score.recall, 1.0);
        assert_eq!(score.f1, 1.0);
    }

    #[test]
    fn each_predicted_item_matches_at_most_once() {
        // Two identical golden items must not both be satisfied by one
        // predicted item.
        let predicted = s(&["check the Temporal signaling limit"]);
        let golden = s(&[
            "check the Temporal signaling limit",
            "check the Temporal signaling limit",
        ]);
        let score = score_category("action_item", &predicted, &golden, &DedupConfig::default());
        assert_eq!(score.matched, 1);
        assert_eq!(score.recall, 0.5);
    }

    #[test]
    fn score_extraction_covers_all_eight_categories_and_averages_them() {
        let predicted = Facts::default();
        let golden = Facts::default();
        let scores = score_extraction(&predicted, &golden, &DedupConfig::default());
        assert_eq!(
            scores.macro_f1, 1.0,
            "eight empty-vs-empty categories are each a perfect (if vacuous) score"
        );
        assert_eq!(scores.categories().len(), 8);
    }
}

//! Numeric recall/precision. `#1636`.
//!
//! Split out from extraction F1 on purpose: a metric fact with the right
//! shape but the wrong number ("throughput: 2000 TPS" instead of "200 TPS")
//! is exactly the hallucination class `airo_mind_meeting::validate` already
//! polices at the IR level (`Violation::UngroundedNumber`). This module
//! answers the complementary question for the numbers an eval run actually
//! surfaced: of every distinct number the golden fixture cites, how many did
//! the predicted output also cite, and how many extra ones did it invent.
//!
//! Digit-token extraction follows the same word-boundary rule
//! `airo_mind_meeting::validate::digit_tokens` uses internally (split on
//! non-alphanumeric, keep all-digit runs) -- that function is private to its
//! crate, so this is a small, deliberate re-implementation of the same
//! pattern rather than an import.

use std::collections::BTreeSet;

/// Every maximal run of ASCII digits in `text`, split on non-alphanumeric
/// boundaries -- `"4000/sec"` yields `"4000"`, `"about 500,000 events"`
/// yields `{"500", "000"}` (number-grouping is intentionally not
/// reconstructed here; a caller comparing against
/// `airo_mind_transcript::normalize`'s comma-grouped display text gets the
/// same split on both sides, so the comparison is still apples to apples).
pub fn digit_tokens(text: &str) -> BTreeSet<String> {
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty() && w.chars().all(|c| c.is_ascii_digit()))
        .map(|w| w.to_string())
        .collect()
}

/// Precision/recall over the set of distinct digit tokens two texts contain.
#[derive(Clone, Debug, Default, PartialEq, serde::Serialize)]
pub struct NumericResult {
    pub true_positives: usize,
    pub false_positives: usize,
    pub false_negatives: usize,
    /// `true_positives / (true_positives + false_positives)`. `1.0` when the
    /// predicted text cites no numbers at all -- it invented nothing, which
    /// is a true statement even though it is also uninformative on its own.
    pub precision: f64,
    /// `true_positives / (true_positives + false_negatives)`. `1.0` when the
    /// golden text cites no numbers -- nothing to have missed.
    pub recall: f64,
}

impl NumericResult {
    pub fn f1(&self) -> f64 {
        if self.precision + self.recall == 0.0 {
            0.0
        } else {
            2.0 * self.precision * self.recall / (self.precision + self.recall)
        }
    }
}

/// Scores the digit tokens in `predicted` against the digit tokens in
/// `golden`.
pub fn numeric_accuracy(golden: &str, predicted: &str) -> NumericResult {
    let golden_numbers = digit_tokens(golden);
    let predicted_numbers = digit_tokens(predicted);

    let true_positives = golden_numbers.intersection(&predicted_numbers).count();
    let false_negatives = golden_numbers.difference(&predicted_numbers).count();
    let false_positives = predicted_numbers.difference(&golden_numbers).count();

    let precision = if true_positives + false_positives == 0 {
        1.0
    } else {
        true_positives as f64 / (true_positives + false_positives) as f64
    };
    let recall = if true_positives + false_negatives == 0 {
        1.0
    } else {
        true_positives as f64 / (true_positives + false_negatives) as f64
    };

    NumericResult {
        true_positives,
        false_positives,
        false_negatives,
        precision,
        recall,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn digit_tokens_split_on_non_alphanumeric_boundaries() {
        let tokens = digit_tokens("throughput is 4000/sec across 16 cores");
        assert_eq!(
            tokens,
            BTreeSet::from(["4000".to_string(), "16".to_string()])
        );
    }

    #[test]
    fn identical_numbers_score_perfectly() {
        let result = numeric_accuracy(
            "about 500000 events, 200 TPS",
            "about 500000 events, 200 TPS",
        );
        assert_eq!(result.precision, 1.0);
        assert_eq!(result.recall, 1.0);
        assert_eq!(result.true_positives, 2);
    }

    #[test]
    fn a_missed_number_costs_recall_not_precision() {
        let result = numeric_accuracy("500000 events, 200 TPS", "500000 events");
        assert_eq!(result.true_positives, 1);
        assert_eq!(result.false_negatives, 1);
        assert_eq!(result.false_positives, 0);
        assert_eq!(result.precision, 1.0);
        assert_eq!(result.recall, 0.5);
    }

    #[test]
    fn an_invented_number_costs_precision_not_recall() {
        let result = numeric_accuracy("500000 events", "500000 events, 250 TPS");
        assert_eq!(result.true_positives, 1);
        assert_eq!(result.false_positives, 1);
        assert_eq!(result.false_negatives, 0);
        assert_eq!(result.precision, 0.5);
        assert_eq!(result.recall, 1.0);
    }

    #[test]
    fn a_substituted_number_is_both_a_miss_and_an_invention() {
        // 2000 instead of 200: the real number is missing (false negative)
        // and a wrong one was cited instead (false positive).
        let result = numeric_accuracy("throughput: 200 TPS", "throughput: 2000 TPS");
        assert_eq!(result.true_positives, 0);
        assert_eq!(result.false_positives, 1);
        assert_eq!(result.false_negatives, 1);
        assert_eq!(result.precision, 0.0);
        assert_eq!(result.recall, 0.0);
    }

    #[test]
    fn no_numbers_anywhere_is_a_perfect_score() {
        let result = numeric_accuracy("no figures here", "nor here");
        assert_eq!(result.precision, 1.0);
        assert_eq!(result.recall, 1.0);
    }

    #[test]
    fn f1_is_the_harmonic_mean() {
        let result = NumericResult {
            true_positives: 1,
            false_positives: 1,
            false_negatives: 1,
            precision: 0.5,
            recall: 0.5,
        };
        assert!((result.f1() - 0.5).abs() < 1e-9);
    }
}

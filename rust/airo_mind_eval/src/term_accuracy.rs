//! Technical-term accuracy. `#1636`.
//!
//! Scores the raw ASR hypothesis (before `airo_mind_transcript::normalize`
//! runs) against `airo_mind_transcript::normalize::technical_terms` -- the
//! same dictionary the normalizer corrects, reused rather than a second
//! hand-copied list. Scoring the *raw* hypothesis, not the normalized one,
//! is deliberate: normalizing first would ask "did the correction dictionary
//! do its job", which is a different (and already-covered-by-unit-tests)
//! question from "how often did the ASR model get a known term right in the
//! first place".
//!
//! A term "counts" only when the reference transcript actually says it --
//! scoring against every term in the dictionary regardless of whether the
//! meeting mentioned it would credit the hypothesis for silence.

/// Whole-word, case-insensitive occurrence count of `term` in `text`.
fn occurrences(text: &str, term: &str) -> usize {
    let term_lower = term.to_lowercase();
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|word| word.to_lowercase() == term_lower)
        .count()
}

/// One term's outcome: how many times the reference said it, and whether the
/// hypothesis said it at least as often.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct TermOutcome {
    pub term: String,
    pub reference_count: usize,
    pub hypothesis_count: usize,
    /// `hypothesis_count >= reference_count` -- the hypothesis did not lose
    /// an instance of the term. A hypothesis that says the term *more* often
    /// than the reference is not penalized here; over-generation of a
    /// technical term is a different failure mode than dropping/garbling one,
    /// and this metric is scoped to the latter.
    pub correct: bool,
}

/// The full result: per-term outcomes for every term the reference actually
/// used, plus the aggregate rate.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct TermAccuracyResult {
    pub outcomes: Vec<TermOutcome>,
    /// `correct outcomes / outcomes.len()`. `1.0` when the reference used
    /// none of the dictionary's terms -- there is nothing to have gotten
    /// wrong, which is a true statement about this transcript, not evidence
    /// of a perfect ASR run.
    pub accuracy: f64,
}

/// Scores `hypothesis` against `reference` for every term in `terms` that
/// `reference` actually contains.
pub fn term_accuracy(reference: &str, hypothesis: &str, terms: &[&str]) -> TermAccuracyResult {
    let outcomes: Vec<TermOutcome> = terms
        .iter()
        .filter_map(|term| {
            let reference_count = occurrences(reference, term);
            if reference_count == 0 {
                return None;
            }
            let hypothesis_count = occurrences(hypothesis, term);
            Some(TermOutcome {
                term: (*term).to_string(),
                reference_count,
                hypothesis_count,
                correct: hypothesis_count >= reference_count,
            })
        })
        .collect();

    let accuracy = if outcomes.is_empty() {
        1.0
    } else {
        outcomes.iter().filter(|o| o.correct).count() as f64 / outcomes.len() as f64
    };

    TermAccuracyResult { outcomes, accuracy }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_term_the_hypothesis_preserves_is_correct() {
        let result = term_accuracy(
            "we moved the Temporal workspace onto GCP",
            "we moved the Temporal workspace onto GCP",
            &["Temporal", "GCP"],
        );
        assert_eq!(result.accuracy, 1.0);
        assert_eq!(result.outcomes.len(), 2);
        assert!(result.outcomes.iter().all(|o| o.correct));
    }

    #[test]
    fn a_term_the_hypothesis_mishears_is_incorrect() {
        let result = term_accuracy(
            "we moved the Temporal workspace onto GCP",
            "we moved the temple workspace onto GCP",
            &["Temporal", "GCP"],
        );
        assert_eq!(result.accuracy, 0.5);
        let temporal = result
            .outcomes
            .iter()
            .find(|o| o.term == "Temporal")
            .unwrap();
        assert!(!temporal.correct);
        assert_eq!(temporal.reference_count, 1);
        assert_eq!(temporal.hypothesis_count, 0);
    }

    #[test]
    fn a_term_the_reference_never_says_is_not_scored() {
        let result = term_accuracy(
            "we discussed the budget",
            "we discussed the budget",
            &["Kafka"],
        );
        assert!(result.outcomes.is_empty());
        assert_eq!(result.accuracy, 1.0, "nothing to get wrong");
    }

    #[test]
    fn case_differences_do_not_count_against_the_hypothesis() {
        let result = term_accuracy("check the JVM heap", "check the jvm heap", &["JVM"]);
        assert_eq!(result.accuracy, 1.0);
    }

    #[test]
    fn a_term_used_twice_must_survive_both_times() {
        let result = term_accuracy(
            "Kubernetes handles this. Kubernetes also handles that.",
            "Kubernetes handles this. cabinettis also handles that.",
            &["Kubernetes"],
        );
        let outcome = &result.outcomes[0];
        assert_eq!(outcome.reference_count, 2);
        assert_eq!(outcome.hypothesis_count, 1);
        assert!(!outcome.correct);
    }

    #[test]
    fn a_substring_match_inside_another_word_does_not_count() {
        // "namespace" must not be credited by "namespaces".
        let result = term_accuracy(
            "the namespace changed",
            "the namespaces changed",
            &["namespace"],
        );
        let outcome = &result.outcomes[0];
        assert_eq!(outcome.hypothesis_count, 0);
        assert!(!outcome.correct);
    }
}

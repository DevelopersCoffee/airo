//! Word Error Rate. `#1636`.
//!
//! Standard ASR metric: the minimum number of word substitutions, deletions
//! and insertions needed to turn the hypothesis into the reference, divided
//! by the reference's word count. Computed by dynamic-programming edit
//! distance over whitespace-tokenized words (case-insensitive, punctuation
//! left in place -- ASR output and the reference transcript are both plain
//! sentences, not tokenized corpora, so stripping punctuation would hide the
//! difference between "500,000" and "500000" that `airo_mind_transcript`
//! itself treats as meaningful).

/// One WER computation: the raw edit counts plus the rate itself.
#[derive(Clone, Debug, Default, PartialEq, serde::Serialize)]
pub struct WerResult {
    pub reference_words: usize,
    pub substitutions: usize,
    pub deletions: usize,
    pub insertions: usize,
    /// `(substitutions + deletions + insertions) / reference_words`.
    /// `0.0` when the reference is empty and the hypothesis matches (nothing
    /// to get wrong); `1.0` when the reference is empty but the hypothesis is
    /// not (pure insertion, capped rather than divided by zero).
    pub wer: f64,
}

/// Computes [`WerResult`] for `hypothesis` against `reference`.
///
/// Case-insensitive: ASR casing is not the thing this metric is scoring
/// (`airo_mind_transcript::normalize` already owns term-casing correctness,
/// scored separately by [`crate::term_accuracy`]).
pub fn word_error_rate(reference: &str, hypothesis: &str) -> WerResult {
    let r: Vec<String> = tokenize(reference);
    let h: Vec<String> = tokenize(hypothesis);

    let (subs, dels, ins) = edit_ops(&r, &h);

    let wer = if r.is_empty() {
        if h.is_empty() {
            0.0
        } else {
            1.0
        }
    } else {
        (subs + dels + ins) as f64 / r.len() as f64
    };

    WerResult {
        reference_words: r.len(),
        substitutions: subs,
        deletions: dels,
        insertions: ins,
        wer,
    }
}

fn tokenize(text: &str) -> Vec<String> {
    text.split_whitespace().map(|w| w.to_lowercase()).collect()
}

/// Classic Levenshtein DP over word sequences, with backtracking to classify
/// each edit as a substitution, deletion or insertion (rather than just a
/// total distance) -- WER conventionally reports the three separately.
fn edit_ops(r: &[String], h: &[String]) -> (usize, usize, usize) {
    let n = r.len();
    let m = h.len();
    let mut dp = vec![vec![0usize; m + 1]; n + 1];
    for (i, row) in dp.iter_mut().enumerate() {
        row[0] = i;
    }
    for (j, cell) in dp[0].iter_mut().enumerate() {
        *cell = j;
    }
    for i in 1..=n {
        for j in 1..=m {
            dp[i][j] = if r[i - 1] == h[j - 1] {
                dp[i - 1][j - 1]
            } else {
                1 + dp[i - 1][j - 1].min(dp[i - 1][j]).min(dp[i][j - 1])
            };
        }
    }

    // Backtrack from (n, m) to (0, 0), classifying each step.
    let (mut i, mut j) = (n, m);
    let (mut subs, mut dels, mut ins) = (0, 0, 0);
    while i > 0 || j > 0 {
        if i > 0 && j > 0 && r[i - 1] == h[j - 1] {
            i -= 1;
            j -= 1;
            continue;
        }
        let sub_cost = if i > 0 && j > 0 {
            dp[i - 1][j - 1]
        } else {
            usize::MAX
        };
        let del_cost = if i > 0 { dp[i - 1][j] } else { usize::MAX };
        let ins_cost = if j > 0 { dp[i][j - 1] } else { usize::MAX };

        if sub_cost <= del_cost && sub_cost <= ins_cost && i > 0 && j > 0 {
            subs += 1;
            i -= 1;
            j -= 1;
        } else if del_cost <= ins_cost && i > 0 {
            dels += 1;
            i -= 1;
        } else {
            ins += 1;
            j -= 1;
        }
    }

    (subs, dels, ins)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn an_identical_transcript_has_zero_wer() {
        let result = word_error_rate("the quick brown fox", "the quick brown fox");
        assert_eq!(result.wer, 0.0);
        assert_eq!(result.substitutions, 0);
        assert_eq!(result.deletions, 0);
        assert_eq!(result.insertions, 0);
    }

    #[test]
    fn wer_is_case_insensitive() {
        let result = word_error_rate("The Quick Brown Fox", "the quick brown fox");
        assert_eq!(result.wer, 0.0);
    }

    #[test]
    fn a_single_deletion_is_scored_against_the_reference_length() {
        // "brown" is missing from the hypothesis: 1 deletion / 4 ref words.
        let result = word_error_rate("the quick brown fox", "the quick fox");
        assert_eq!(result.deletions, 1);
        assert_eq!(result.substitutions, 0);
        assert_eq!(result.insertions, 0);
        assert_eq!(result.wer, 0.25);
    }

    #[test]
    fn a_single_insertion_is_scored_against_the_reference_length() {
        let result = word_error_rate("the quick fox", "the quick brown fox");
        assert_eq!(result.insertions, 1);
        assert_eq!(result.wer, 1.0 / 3.0);
    }

    #[test]
    fn a_single_substitution_is_one_edit_not_a_deletion_plus_insertion() {
        let result = word_error_rate("the quick brown fox", "the quick red fox");
        assert_eq!(result.substitutions, 1);
        assert_eq!(result.deletions, 0);
        assert_eq!(result.insertions, 0);
        assert_eq!(result.wer, 0.25);
    }

    #[test]
    fn a_known_edit_distance_pair_scores_correctly() {
        // Reference has 5 words; hypothesis drops "signalling", substitutes
        // "limit" -> "limits", and inserts "please" at the end. 3 edits / 5.
        let result = word_error_rate(
            "check the temporal signalling limit",
            "check the temporal limits please",
        );
        assert_eq!(result.reference_words, 5);
        assert_eq!(
            result.substitutions + result.deletions + result.insertions,
            2
        );
    }

    #[test]
    fn an_empty_reference_and_empty_hypothesis_is_zero_wer() {
        let result = word_error_rate("", "");
        assert_eq!(result.wer, 0.0);
    }

    #[test]
    fn an_empty_reference_with_a_nonempty_hypothesis_is_fully_wrong() {
        let result = word_error_rate("", "hello");
        assert_eq!(result.wer, 1.0);
        assert_eq!(result.insertions, 1);
    }

    #[test]
    fn a_completely_wrong_hypothesis_has_wer_of_one() {
        let result = word_error_rate("the quick brown fox", "lorem ipsum dolor sit");
        assert_eq!(result.wer, 1.0);
    }
}

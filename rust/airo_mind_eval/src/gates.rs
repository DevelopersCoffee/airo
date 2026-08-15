//! Quality gates. `#1636`'s hardcoded thresholds, verbatim from the issue.
//!
//! A named constant per gate rather than a config file: the issue states
//! these numbers directly ("term accuracy >=90%; decision F1 >=90%; ..."),
//! and a tunable-by-a-flag threshold would let a run quietly redefine what
//! "passing" means. Changing a gate is a decision this milestone's owner
//! makes in a reviewed diff, not a runtime option.

/// One threshold, and whether `value` clears it.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct GateResult {
    pub name: &'static str,
    pub value: f64,
    pub threshold: f64,
    /// `true` when the gate is a minimum (`value >= threshold` passes);
    /// `false` when it is a maximum (`value <= threshold` passes, used only
    /// by the unsupported-claim-rate gate).
    pub is_minimum: bool,
    pub passed: bool,
}

fn minimum(name: &'static str, value: f64, threshold: f64) -> GateResult {
    GateResult {
        name,
        value,
        threshold,
        is_minimum: true,
        passed: value >= threshold,
    }
}

fn maximum(name: &'static str, value: f64, threshold: f64) -> GateResult {
    GateResult {
        name,
        value,
        threshold,
        is_minimum: false,
        passed: value <= threshold,
    }
}

/// The issue's eight named gates, as constants.
pub struct Gates;

impl Gates {
    pub const TERM_ACCURACY_MIN: f64 = 0.90;
    pub const DECISION_F1_MIN: f64 = 0.90;
    pub const ACTION_F1_MIN: f64 = 0.90;
    pub const NUMERIC_MIN: f64 = 0.95;
    pub const EVIDENCE_MIN: f64 = 0.95;
    pub const UNSUPPORTED_MAX: f64 = 0.02;
    pub const MOM_COVERAGE_MIN: f64 = 0.90;
    pub const FACTUAL_CONSISTENCY_MIN: f64 = 0.95;
}

/// Evaluates every gate against the run's measured values, in the order the
/// issue lists them.
///
/// `numeric` covers both recall and precision -- the issue names one
/// "numeric" gate, so both are checked against the same threshold and both
/// must pass for the pair to count as passing.
#[allow(clippy::too_many_arguments)]
pub fn evaluate(
    term_accuracy: f64,
    decision_f1: f64,
    action_f1: f64,
    numeric_recall: f64,
    numeric_precision: f64,
    evidence_accuracy: f64,
    unsupported_rate: f64,
    mom_coverage: f64,
    factual_consistency: f64,
) -> Vec<GateResult> {
    vec![
        minimum("term_accuracy", term_accuracy, Gates::TERM_ACCURACY_MIN),
        minimum("decision_f1", decision_f1, Gates::DECISION_F1_MIN),
        minimum("action_f1", action_f1, Gates::ACTION_F1_MIN),
        minimum("numeric_recall", numeric_recall, Gates::NUMERIC_MIN),
        minimum("numeric_precision", numeric_precision, Gates::NUMERIC_MIN),
        minimum("evidence_accuracy", evidence_accuracy, Gates::EVIDENCE_MIN),
        maximum("unsupported_rate", unsupported_rate, Gates::UNSUPPORTED_MAX),
        minimum("mom_coverage", mom_coverage, Gates::MOM_COVERAGE_MIN),
        minimum(
            "factual_consistency",
            factual_consistency,
            Gates::FACTUAL_CONSISTENCY_MIN,
        ),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_minimum_gate_passes_at_or_above_threshold() {
        assert!(minimum("x", 0.90, 0.90).passed);
        assert!(minimum("x", 0.95, 0.90).passed);
        assert!(!minimum("x", 0.89, 0.90).passed);
    }

    #[test]
    fn a_maximum_gate_passes_at_or_below_threshold() {
        assert!(maximum("x", 0.02, 0.02).passed);
        assert!(maximum("x", 0.0, 0.02).passed);
        assert!(!maximum("x", 0.03, 0.02).passed);
    }

    #[test]
    fn evaluate_returns_all_nine_checks_in_order() {
        let results = evaluate(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0);
        assert_eq!(results.len(), 9);
        assert!(results.iter().all(|r| r.passed));
        assert_eq!(results[0].name, "term_accuracy");
        assert_eq!(results[6].name, "unsupported_rate");
    }

    #[test]
    fn a_single_failing_gate_is_reported_without_hiding_the_others() {
        let results = evaluate(0.5, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 1.0, 1.0);
        assert!(!results[0].passed);
        assert!(results[1..].iter().all(|r| r.passed));
    }
}

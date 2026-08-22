//! Map meeting-IR validation onto the reliability engine.
//!
//! The validator remains the authority for repair. This module only classifies
//! what already happened so chat/scribe share PM-01 identifiers.

use airo_mind_reliability::{
    Classification, DiagnosticLevel, ExecutionId, ExecutionLog, ExecutionStage, FailureClassifier,
    PersistableDiagnostic, PipelineObservation,
};

use crate::validate::{ValidationReport, Violation};

/// Classify a validation report. `None` means the report is clean.
pub fn classify_validation_report(report: &ValidationReport) -> Option<Classification> {
    if report.is_clean() {
        return None;
    }
    let mut observation = PipelineObservation::healthy();
    observation.checkpoints_recorded = true;
    observation.schema_valid = !report
        .violations
        .iter()
        .any(|v| matches!(v, Violation::UnknownSchemaVersion { .. }));
    observation.grounding_failed = report.violations.iter().any(|v| {
        matches!(
            v,
            Violation::NoEvidence { .. }
                | Violation::DanglingEvidence { .. }
                | Violation::AllEvidenceDangling { .. }
                | Violation::UngroundedOwner { .. }
                | Violation::UngroundedNumber { .. }
        )
    });
    observation.evidence_present = !observation.grounding_failed;
    FailureClassifier::classify(&observation)
}

/// In-process diagnostic for a validation pass. No raw IR or prompts.
pub fn record_validation(
    meeting_id: impl Into<String>,
    report: &ValidationReport,
) -> Vec<PersistableDiagnostic> {
    let mut log = ExecutionLog::new();
    if let Some(classification) = classify_validation_report(report) {
        log.record_classification(
            ExecutionId::new(meeting_id.into()),
            ExecutionStage::Validation,
            &classification,
            0,
        );
    }
    log.persistable(DiagnosticLevel::Standard)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::validate::Violation;
    use airo_mind_reliability::{FailureMode, InvariantId, RecoveryAction};

    #[test]
    fn ungrounded_number_is_pm01() {
        let report = ValidationReport {
            violations: vec![Violation::UngroundedNumber {
                category: "metric",
                item: "q3 revenue".into(),
                number: "12".into(),
            }],
        };
        let classified = classify_validation_report(&report).unwrap();
        assert_eq!(classified.primary, FailureMode::Pm01HallucinationChunkDrift);
        assert_eq!(classified.invariant, InvariantId::ModelResultGrounded);
        assert_eq!(classified.first_repair, RecoveryAction::ReRetrieve);
    }

    #[test]
    fn clean_report_is_not_a_failure() {
        assert!(classify_validation_report(&ValidationReport::default()).is_none());
        assert!(record_validation("m1", &ValidationReport::default()).is_empty());
    }

    #[test]
    fn validation_checkpoint_is_persistable_without_prompt_fields() {
        let report = ValidationReport {
            violations: vec![Violation::UngroundedNumber {
                category: "metric",
                item: "q3 revenue".into(),
                number: "12".into(),
            }],
        };
        let diagnostics = record_validation("meet-9", &report);
        assert_eq!(diagnostics.len(), 1);
        assert_eq!(diagnostics[0].execution_id, "meet-9");
        assert_eq!(diagnostics[0].failure_mode, Some("PM-01"));
        assert_eq!(diagnostics[0].stage, "validation");
        assert_eq!(diagnostics[0].status, "failed");
        let dump = format!("{:?}", diagnostics[0]);
        assert!(!dump.to_ascii_lowercase().contains("prompt"));
        assert!(!dump.contains("q3 revenue"));
    }
}

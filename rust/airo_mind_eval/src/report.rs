//! The run report: `evals/reports/run-NNN.json`. `#1636`.
//!
//! One JSON document per run, covering every section the issue names (ASR,
//! extraction, numeric, grounding, MoM, performance) plus the gate
//! evaluation. `next_run_number` scans the output directory for existing
//! `run-NNN.json` files so consecutive runs do not clobber each other --
//! useful for watching a metric move across iterations, the actual point of
//! a golden-set harness ("do not tune indefinitely against one transcript"
//! needs a trail of what tuning did).

use std::path::{Path, PathBuf};

use serde::Serialize;

use crate::extraction::ExtractionScores;
use crate::factual_consistency::FactualConsistencyReport;
use crate::gates::{self, GateResult};
use crate::grounding::GroundingReport;
use crate::mom_quality::SectionCompleteness;
use crate::numeric::NumericResult;
use crate::performance::PerformanceStats;
use crate::term_accuracy::TermAccuracyResult;
use crate::wer::WerResult;

/// Everything one pipeline run measured, ready to serialize.
#[derive(Debug, Serialize)]
pub struct RunReport {
    pub run_number: u32,
    pub meeting_id: String,
    pub asr: AsrSection,
    pub extraction: ExtractionSection,
    pub numeric: NumericSection,
    pub grounding: GroundingSection,
    pub mom: MomSection,
    pub performance: PerformanceStats,
    pub gates: Vec<GateResultJson>,
    pub passed: bool,
    /// Explains why the run's numbers may not reflect a real model. Empty on
    /// a run that used real engines end to end.
    pub caveats: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct AsrSection {
    pub wer: WerResult,
    pub term_accuracy: TermAccuracyResult,
}

#[derive(Debug, Serialize)]
pub struct ExtractionSection {
    pub scores: ExtractionScores,
}

#[derive(Debug, Serialize)]
pub struct NumericSection {
    pub result: NumericResult,
    pub f1: f64,
}

#[derive(Debug, Serialize)]
pub struct GroundingSection {
    pub report: GroundingReport,
}

#[derive(Debug, Serialize)]
pub struct MomSection {
    pub section_completeness: SectionCompleteness,
    pub factual_consistency: FactualConsistencyReport,
}

#[derive(Debug, Serialize)]
pub struct GateResultJson {
    pub name: &'static str,
    pub value: f64,
    pub threshold: f64,
    pub passed: bool,
}

impl From<GateResult> for GateResultJson {
    fn from(g: GateResult) -> Self {
        Self {
            name: g.name,
            value: g.value,
            threshold: g.threshold,
            passed: g.passed,
        }
    }
}

/// Builds the full report and evaluates every gate.
#[allow(clippy::too_many_arguments)]
pub fn build(
    run_number: u32,
    meeting_id: &str,
    wer: WerResult,
    term_accuracy: TermAccuracyResult,
    extraction: ExtractionScores,
    numeric: NumericResult,
    grounding: GroundingReport,
    section_completeness: SectionCompleteness,
    factual_consistency: FactualConsistencyReport,
    performance: PerformanceStats,
    caveats: Vec<String>,
) -> RunReport {
    let numeric_f1 = numeric.f1();
    let gates = gates::evaluate(
        term_accuracy.accuracy,
        extraction.decisions.f1,
        extraction.action_items.f1,
        numeric.recall,
        numeric.precision,
        grounding.evidence_accuracy,
        grounding.unsupported_rate,
        section_completeness.coverage,
        factual_consistency.score,
    );
    let passed = gates.iter().all(|g| g.passed);
    let gates_json: Vec<GateResultJson> = gates.into_iter().map(GateResultJson::from).collect();

    RunReport {
        run_number,
        meeting_id: meeting_id.to_string(),
        asr: AsrSection { wer, term_accuracy },
        extraction: ExtractionSection { scores: extraction },
        numeric: NumericSection {
            result: numeric,
            f1: numeric_f1,
        },
        grounding: GroundingSection { report: grounding },
        mom: MomSection {
            section_completeness,
            factual_consistency,
        },
        performance,
        gates: gates_json,
        passed,
        caveats,
    }
}

/// The next `run-NNN.json` number for `dir` -- one past the highest existing
/// run number, or `1` if the directory is empty or does not yet exist.
pub fn next_run_number(dir: &Path) -> u32 {
    let Ok(entries) = std::fs::read_dir(dir) else {
        return 1;
    };
    entries
        .filter_map(|e| e.ok())
        .filter_map(|e| e.file_name().into_string().ok())
        .filter_map(|name| {
            name.strip_prefix("run-")
                .and_then(|rest| rest.strip_suffix(".json"))
                .and_then(|n| n.parse::<u32>().ok())
        })
        .max()
        .map(|n| n + 1)
        .unwrap_or(1)
}

/// Writes `report` to `dir/run-{report.run_number:03}.json`, creating `dir`
/// if needed. Returns the path written.
pub fn write(dir: &Path, report: &RunReport) -> Result<PathBuf, String> {
    std::fs::create_dir_all(dir).map_err(|e| format!("creating {}: {e}", dir.display()))?;
    let path = dir.join(format!("run-{:03}.json", report.run_number));
    let json = serde_json::to_string_pretty(report).map_err(|e| e.to_string())?;
    std::fs::write(&path, json).map_err(|e| format!("writing {}: {e}", path.display()))?;
    Ok(path)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_dir(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "airo_mind_eval_report_test_{name}_{}",
            std::process::id()
        ))
    }

    #[test]
    fn next_run_number_is_one_for_a_missing_directory() {
        let dir = temp_dir("missing");
        assert_eq!(next_run_number(&dir), 1);
    }

    #[test]
    fn next_run_number_is_one_past_the_highest_existing_run() {
        let dir = temp_dir("existing");
        std::fs::create_dir_all(&dir).unwrap();
        std::fs::write(dir.join("run-001.json"), "{}").unwrap();
        std::fs::write(dir.join("run-007.json"), "{}").unwrap();
        std::fs::write(dir.join("run-003.json"), "{}").unwrap();
        std::fs::write(dir.join("not-a-run.json"), "{}").unwrap();
        assert_eq!(next_run_number(&dir), 8);
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn write_creates_the_directory_and_a_zero_padded_filename() {
        let dir = temp_dir("write");
        let report = build(
            5,
            "meeting-0",
            WerResult::default(),
            crate::term_accuracy::term_accuracy("", "", &[]),
            crate::extraction::score_extraction(
                &airo_mind_meeting::ir::Facts::default(),
                &airo_mind_meeting::ir::Facts::default(),
                &airo_mind_meeting::dedup::DedupConfig::default(),
            ),
            crate::numeric::numeric_accuracy("", ""),
            crate::grounding::GroundingReport {
                sentences: vec![],
                evidence_accuracy: 1.0,
                unsupported_rate: 0.0,
            },
            crate::mom_quality::section_completeness(""),
            crate::factual_consistency::FactualConsistencyReport {
                checks: vec![],
                score: 1.0,
            },
            PerformanceStats::default(),
            vec!["no real model available in this environment".to_string()],
        );

        let path = write(&dir, &report).expect("writes");
        assert_eq!(path.file_name().unwrap(), "run-005.json");
        assert!(path.exists());

        let raw = std::fs::read_to_string(&path).unwrap();
        let value: serde_json::Value = serde_json::from_str(&raw).unwrap();
        assert_eq!(value["run_number"], 5);
        assert_eq!(value["meeting_id"], "meeting-0");

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn a_report_where_every_metric_is_perfect_passes_every_gate() {
        let report = build(
            1,
            "meeting-0",
            WerResult::default(),
            crate::term_accuracy::term_accuracy("", "", &[]),
            crate::extraction::score_extraction(
                &airo_mind_meeting::ir::Facts::default(),
                &airo_mind_meeting::ir::Facts::default(),
                &airo_mind_meeting::dedup::DedupConfig::default(),
            ),
            crate::numeric::numeric_accuracy("", ""),
            crate::grounding::GroundingReport {
                sentences: vec![],
                evidence_accuracy: 1.0,
                unsupported_rate: 0.0,
            },
            crate::mom_quality::section_completeness(
                "## Meeting Objective\n## Key Discussion Points\n## Decisions & Direction\n## Action Items\n## Next Steps\n",
            ),
            crate::factual_consistency::FactualConsistencyReport {
                checks: vec![],
                score: 1.0,
            },
            PerformanceStats::default(),
            vec![],
        );
        assert!(report.passed, "{:#?}", report.gates);
    }

    #[test]
    fn a_report_with_one_failing_gate_does_not_pass() {
        let report = build(
            1,
            "meeting-0",
            WerResult::default(),
            crate::term_accuracy::term_accuracy(
                "Temporal Temporal Temporal Temporal",
                "temple temple temple temple",
                &["Temporal"],
            ),
            crate::extraction::score_extraction(
                &airo_mind_meeting::ir::Facts::default(),
                &airo_mind_meeting::ir::Facts::default(),
                &airo_mind_meeting::dedup::DedupConfig::default(),
            ),
            crate::numeric::numeric_accuracy("", ""),
            crate::grounding::GroundingReport {
                sentences: vec![],
                evidence_accuracy: 1.0,
                unsupported_rate: 0.0,
            },
            crate::mom_quality::section_completeness(
                "## Meeting Objective\n## Key Discussion Points\n## Decisions & Direction\n## Action Items\n## Next Steps\n",
            ),
            crate::factual_consistency::FactualConsistencyReport {
                checks: vec![],
                score: 1.0,
            },
            PerformanceStats::default(),
            vec![],
        );
        assert!(!report.passed);
        let term_gate = report
            .gates
            .iter()
            .find(|g| g.name == "term_accuracy")
            .unwrap();
        assert!(!term_gate.passed);
    }
}

//! Runs `airo_mind_eval` gates against CLI pipeline outputs.

use std::path::{Path, PathBuf};
use std::time::Instant;

use airo_mind_eval::extraction::score_extraction;
use airo_mind_eval::factual_consistency::factual_consistency;
use airo_mind_eval::golden::{self, GoldenPaths};
use airo_mind_eval::grounding::evaluate_mom_grounding;
use airo_mind_eval::mom_quality::section_completeness;
use airo_mind_eval::numeric::numeric_accuracy;
use airo_mind_eval::performance;
use airo_mind_eval::report;
use airo_mind_eval::term_accuracy::term_accuracy;
use airo_mind_eval::wer::word_error_rate;
use airo_mind_meeting::dedup::DedupConfig;
use airo_mind_meeting::MeetingIr;
use airo_mind_transcript::normalize::technical_terms;

use crate::args::CliArgs;
use crate::pipeline::PipelineOutput;

pub struct EvalResult {
    pub report_path: PathBuf,
    pub passed: bool,
}

pub fn run_eval(args: &CliArgs, out_dir: &Path, output: &PipelineOutput) -> EvalResult {
    let golden_paths = GoldenPaths {
        transcript: args
            .golden_transcript
            .clone()
            .expect("golden transcript path"),
        golden_ir: args.golden_ir.clone().expect("golden ir path"),
        golden_mom: args.golden_mom.clone().expect("golden mom path"),
        audio: args.audio.clone(),
    };

    let golden = golden::load(&golden_paths).expect("golden set loads");

    let predicted_ir: MeetingIr = output.ir.clone();
    let predicted_mom = output.mom.clone();
    let hypothesis_transcript = output.hypothesis_text.clone();

    let start = Instant::now();
    let wer = word_error_rate(&golden.transcript.reference_text(), &hypothesis_transcript);
    let terms = technical_terms();
    let term_result = term_accuracy(
        &golden.transcript.reference_text(),
        &hypothesis_transcript,
        &terms,
    );

    let extraction = score_extraction(
        &predicted_ir.facts,
        &golden.golden_ir.facts,
        &DedupConfig::default(),
    );

    let golden_ir_json = serde_json::to_string(&golden.golden_ir).unwrap_or_default();
    let predicted_ir_json = serde_json::to_string(&predicted_ir).unwrap_or_default();
    let numeric = numeric_accuracy(&golden_ir_json, &predicted_ir_json);

    let segments = golden.transcript.segments();
    let grounding = evaluate_mom_grounding(&predicted_ir, &segments, &predicted_mom);

    let completeness = section_completeness(&predicted_mom);
    let consistency = factual_consistency(&predicted_ir, &predicted_mom);

    let processing = start.elapsed();
    let perf = performance::measure(golden.transcript.duration_ms(), processing, &[]);

    let eval_reports = out_dir.join("eval");
    let run_number = report::next_run_number(&eval_reports);
    let run_report = report::build(
        run_number,
        &golden.golden_ir.meeting.id,
        wer,
        term_result,
        extraction,
        numeric,
        grounding,
        completeness,
        consistency,
        perf,
        vec![],
    );

    let report_path = report::write(&eval_reports, &run_report).expect("eval report written");

    println!("\n-- gates --");
    for gate in &run_report.gates {
        let status = if gate.passed { "PASS" } else { "FAIL" };
        println!(
            "[{status}] {:<20} {:.4} (threshold {:.4})",
            gate.name, gate.value, gate.threshold
        );
    }

    EvalResult {
        report_path,
        passed: run_report.passed,
    }
}

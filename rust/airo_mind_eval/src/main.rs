//! `#1636` CLI: runs the full evaluation pipeline against a golden meeting
//! and writes `evals/reports/run-NNN.json`, exiting non-zero if any gate
//! fails. Local dev tool -- not run in CI (see `Cargo.toml`'s description and
//! this crate's `lib.rs` doc comment).
//!
//! # Default run is a wiring smoke test, not a quality measurement
//!
//! No whisper or llama model is available in the environment this crate was
//! built in (see `golden/reference_meeting/transcript.json`'s `_comment` for
//! the full explanation), so this binary cannot run real ASR or extraction
//! on its own. Its default invocation (`cargo run -p airo_mind_eval`) scores
//! the golden fixtures **against themselves** -- predicted IR = golden IR,
//! predicted MoM = golden MoM, ASR hypothesis = the reference transcript --
//! which proves AC1/AC3 (one command, a report, gates enforced as exit code)
//! end to end, and should pass every gate by construction. It is a smoke
//! test of the *pipeline*, explicitly not evidence about a real model's
//! quality.
//!
//! To score a real run, pass `--predicted-ir`, `--predicted-mom` and/or
//! `--hypothesis-transcript` pointing at that run's actual output.

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
use airo_mind_meeting::ir::MeetingIr;

fn manifest_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
}

/// Parses `--flag value` pairs out of `args`, plain and dependency-free --
/// this CLI takes at most five optional path overrides, which does not
/// justify a new `clap` dependency on a dev-tool crate (Constitution §6
/// applies to every new dependency, including this workspace's own tools).
fn flag(args: &[String], name: &str) -> Option<PathBuf> {
    args.iter()
        .position(|a| a == name)
        .and_then(|i| args.get(i + 1))
        .map(PathBuf::from)
}

fn main() {
    let args: Vec<String> = std::env::args().collect();

    // golden_ir.json / golden_mom.md live in airo_mind_meeting's own fixture
    // directory -- see golden.rs's module doc comment for why this crate
    // reads them by relative path instead of keeping a second copy.
    let meeting_fixtures = manifest_dir().join("../airo_mind_meeting/tests/fixtures");
    let own_golden_dir = manifest_dir().join("golden/reference_meeting");

    let golden_paths = GoldenPaths {
        transcript: flag(&args, "--transcript")
            .unwrap_or_else(|| own_golden_dir.join("transcript.json")),
        golden_ir: flag(&args, "--golden-ir")
            .unwrap_or_else(|| meeting_fixtures.join("golden_ir.json")),
        golden_mom: flag(&args, "--golden-mom")
            .unwrap_or_else(|| meeting_fixtures.join("golden_mom.md")),
        audio: flag(&args, "--audio").unwrap_or_else(|| own_golden_dir.join("audio.m4a")),
    };
    let out_dir = flag(&args, "--out-dir").unwrap_or_else(|| manifest_dir().join("evals/reports"));

    println!("== Airo Mind Eval (#1636) ==");
    println!("transcript:  {}", golden_paths.transcript.display());
    println!("golden IR:   {}", golden_paths.golden_ir.display());
    println!("golden MoM:  {}", golden_paths.golden_mom.display());
    println!("out dir:     {}", out_dir.display());
    println!();

    let golden = match golden::load(&golden_paths) {
        Ok(g) => g,
        Err(e) => {
            eprintln!("failed to load golden set: {e}");
            std::process::exit(2);
        }
    };

    let mut caveats = Vec::new();
    if !golden.audio_path.exists() {
        caveats.push(format!(
            "no audio at {} -- this environment has no matching audio.m4a for the \
             reference meeting; the ASR section below is a wiring smoke test, not a \
             real ASR quality measurement. See golden/reference_meeting/transcript.json.",
            golden.audio_path.display()
        ));
    }

    // Predicted IR/MoM/hypothesis transcript default to the golden fixtures
    // themselves -- see the module doc comment for why.
    let predicted_ir: MeetingIr = match flag(&args, "--predicted-ir") {
        Some(path) => match load_ir(&path) {
            Ok(ir) => ir,
            Err(e) => {
                eprintln!("failed to load --predicted-ir: {e}");
                std::process::exit(2);
            }
        },
        None => {
            caveats.push(
                "no --predicted-ir given: extraction/numeric sections score the golden IR \
                 against itself (perfect by construction), not a real extraction run."
                    .to_string(),
            );
            golden.golden_ir.clone()
        }
    };

    let predicted_mom: String = match flag(&args, "--predicted-mom") {
        Some(path) => match std::fs::read_to_string(&path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("failed to load --predicted-mom ({}): {e}", path.display());
                std::process::exit(2);
            }
        },
        None => {
            caveats.push(
                "no --predicted-mom given: grounding/MoM sections score the golden MoM \
                 against itself, not a real generation run."
                    .to_string(),
            );
            golden.golden_mom.clone()
        }
    };

    let hypothesis_transcript: String = match flag(&args, "--hypothesis-transcript") {
        Some(path) => match std::fs::read_to_string(&path) {
            Ok(s) => s,
            Err(e) => {
                eprintln!(
                    "failed to load --hypothesis-transcript ({}): {e}",
                    path.display()
                );
                std::process::exit(2);
            }
        },
        None => {
            caveats.push(
                "no --hypothesis-transcript given: WER/term accuracy score the reference \
                 transcript against itself (WER 0 by construction), not a real ASR run. \
                 No whisper model is available in this environment to produce one -- see \
                 golden/reference_meeting/transcript.json."
                    .to_string(),
            );
            golden.transcript.reference_text()
        }
    };

    // --- run the pipeline ---------------------------------------------------
    let start = Instant::now();

    let wer = word_error_rate(&golden.transcript.reference_text(), &hypothesis_transcript);
    let terms = airo_mind_transcript::normalize::technical_terms();
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

    let run_number = report::next_run_number(&out_dir);
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
        caveats,
    );

    match report::write(&out_dir, &run_report) {
        Ok(path) => println!("wrote {}", path.display()),
        Err(e) => {
            eprintln!("failed to write report: {e}");
            std::process::exit(2);
        }
    }

    println!("\n-- gates --");
    for gate in &run_report.gates {
        let status = if gate.passed { "PASS" } else { "FAIL" };
        println!(
            "[{status}] {:<20} {:.4} (threshold {:.4})",
            gate.name, gate.value, gate.threshold
        );
    }
    if !run_report.caveats.is_empty() {
        println!("\n-- caveats --");
        for caveat in &run_report.caveats {
            println!("* {caveat}");
        }
    }

    if run_report.passed {
        println!("\nall gates passed");
        std::process::exit(0);
    } else {
        println!("\nGATE FAILURE");
        std::process::exit(1);
    }
}

fn load_ir(path: &Path) -> Result<MeetingIr, String> {
    let raw = std::fs::read_to_string(path).map_err(|e| e.to_string())?;
    serde_json::from_str(&raw).map_err(|e| e.to_string())
}

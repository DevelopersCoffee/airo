//! Benchmark gate conformance — condition 10 (#1311): "every performance
//! contract has benchmark gates in CI." Checklist `S2`, complexity-class
//! bullets ("peak RSS during replay is O(1) in replayed state size", the S1
//! vault-sizing "constant factor" regression guard).
//!
//! # Why this is a scaling assertion, not a `criterion` wall-clock budget
//!
//! `rust/airo_core/benches/m3u_parser.rs` already shows this workspace's
//! pattern for a `criterion` micro-benchmark, and that pattern is right for
//! its purpose: a developer watching absolute throughput on their own
//! machine. It is the wrong tool for a **CI gate**, because a hard
//! wall-clock or ops/sec threshold on a shared GitHub Actions runner is
//! exactly the kind of check that is flaky by construction — the runner's
//! noisy-neighbor variance can be larger than the regression you're trying
//! to catch, which either makes the gate useless (threshold set so loose it
//! never fires) or a source of false-positive PR blocks (threshold set
//! tight enough to matter).
//!
//! What *is* reliable in CI is a **relative** claim: does cost grow linearly
//! with input size, or worse? That question is scale-invariant — it holds
//! whether the runner is fast or slow today — which is exactly the property
//! `AIRO_MIND_ARCHITECTURE_FREEZE_v1`'s existing S1 bullet already measures
//! this way ("a 100k-content vault serializes within a constant factor of a
//! 10k-content vault"). These two tests are that pattern, applied to the
//! operation log and the projection engine, the two runtime surfaces that
//! exist on this branch today.
//!
//! **Judgment call, stated plainly**: #1294 (as filed) does not specify
//! numeric performance targets for the operation log or projection engine —
//! its actual scope is module-persistence-class CI enforcement, not runtime
//! benchmarking. In the absence of stated targets, the threshold below
//! (`MAX_SCALING_RATIO`) is chosen generously: 10x the input should cost at
//! most `MAX_SCALING_RATIO`x the time. Linear cost predicts ~10x; this
//! allows more than 2x that before failing, which still catches a
//! quadratic-or-worse regression (~100x) while tolerating one order of
//! magnitude of CI noise and constant-factor overhead. If a future issue
//! states an exact target, replace this ratio rather than tightening it
//! blind.

use std::time::Instant;

use airo_mind_core::{
    rebuild_from_scratch, NotesCapability, NotesProjection, ResourceBudget, Runtime,
};

/// Linear cost predicts this multiplier for 10x the input; anything
/// meaningfully above it (quadratic would be ~100x) is a real regression,
/// not runner noise.
const MAX_SCALING_RATIO: f64 = 25.0;

/// A run so fast that ratio math is dominated by clock-resolution and
/// process-startup noise rather than the workload -- below this, skip the
/// ratio assertion rather than let noise fail the gate.
const MIN_RELIABLE_MICROS: u128 = 500;

fn temp_log_path(name: &str) -> std::path::PathBuf {
    let unique = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!("airo_mind_benchmark_gate_{name}_{unique}.log"))
}

fn cleanup(path: &std::path::Path) {
    let _ = std::fs::remove_file(path);
    let mut device_id = path.file_name().unwrap().to_string_lossy().into_owned();
    device_id.push_str(".device_id");
    let _ = std::fs::remove_file(path.with_file_name(device_id));
    let mut content = path.file_name().unwrap().to_string_lossy().into_owned();
    content.push_str(".content");
    let _ = std::fs::remove_dir_all(path.with_file_name(content));
}

fn append_notes(runtime: &Runtime, count: usize) {
    let notes = NotesCapability::new(runtime);
    for i in 0..count {
        notes
            .create_note(format!("n{i}"), format!("title {i}"), "body text", i as u64)
            .unwrap();
    }
}

/// Guards against an accidental O(n^2) (or worse) append path -- e.g. a full
/// log rescan on every write, which would pass every correctness test in
/// `operation_log_and_projection_conformance.rs` while making the log
/// unusable past a few thousand operations.
#[test]
fn operation_log_append_scales_linearly_not_worse() {
    const SMALL: usize = 150;
    const LARGE: usize = SMALL * 10;

    let small_path = temp_log_path("append_small");
    let small_runtime = Runtime::boot(ResourceBudget::new(4096), &small_path).unwrap();
    let small_start = Instant::now();
    append_notes(&small_runtime, SMALL);
    let small_elapsed = small_start.elapsed();
    drop(small_runtime);
    cleanup(&small_path);

    let large_path = temp_log_path("append_large");
    let large_runtime = Runtime::boot(ResourceBudget::new(4096), &large_path).unwrap();
    let large_start = Instant::now();
    append_notes(&large_runtime, LARGE);
    let large_elapsed = large_start.elapsed();
    drop(large_runtime);
    cleanup(&large_path);

    if small_elapsed.as_micros() < MIN_RELIABLE_MICROS {
        eprintln!(
            "operation_log_append_scales_linearly_not_worse: small run took only \
             {small_elapsed:?}, below the {MIN_RELIABLE_MICROS}us noise floor -- skipping the \
             ratio assertion rather than gating on clock noise."
        );
        return;
    }

    let ratio = large_elapsed.as_secs_f64() / small_elapsed.as_secs_f64();
    assert!(
        ratio < MAX_SCALING_RATIO,
        "appending {LARGE} operations took {large_elapsed:?} vs {small_elapsed:?} for {SMALL} \
         -- a {ratio:.1}x slowdown for 10x the input exceeds the {MAX_SCALING_RATIO}x linear-cost \
         budget. This looks like a superlinear regression in the append path, not noise."
    );
}

/// Guards against an accidental O(n^2) (or worse) rebuild path -- the
/// projection engine's headline property (condition 5, `#1195`) is that
/// delete-and-rebuild is safe to do routinely, which is false in practice if
/// rebuilding scales worse than linearly with log size.
#[test]
fn projection_rebuild_from_scratch_scales_linearly_not_worse() {
    const SMALL: usize = 150;
    const LARGE: usize = SMALL * 10;

    let small_path = temp_log_path("rebuild_small");
    let small_runtime = Runtime::boot(ResourceBudget::new(4096), &small_path).unwrap();
    append_notes(&small_runtime, SMALL);
    let small_ops = small_runtime.replay().unwrap();
    let small_start = Instant::now();
    let small_projection: NotesProjection = rebuild_from_scratch(&small_ops);
    let small_elapsed = small_start.elapsed();
    assert_eq!(small_projection.len(), SMALL);
    drop(small_runtime);
    cleanup(&small_path);

    let large_path = temp_log_path("rebuild_large");
    let large_runtime = Runtime::boot(ResourceBudget::new(4096), &large_path).unwrap();
    append_notes(&large_runtime, LARGE);
    let large_ops = large_runtime.replay().unwrap();
    let large_start = Instant::now();
    let large_projection: NotesProjection = rebuild_from_scratch(&large_ops);
    let large_elapsed = large_start.elapsed();
    assert_eq!(large_projection.len(), LARGE);
    drop(large_runtime);
    cleanup(&large_path);

    if small_elapsed.as_micros() < MIN_RELIABLE_MICROS {
        eprintln!(
            "projection_rebuild_from_scratch_scales_linearly_not_worse: small run took only \
             {small_elapsed:?}, below the {MIN_RELIABLE_MICROS}us noise floor -- skipping the \
             ratio assertion rather than gating on clock noise."
        );
        return;
    }

    let ratio = large_elapsed.as_secs_f64() / small_elapsed.as_secs_f64();
    assert!(
        ratio < MAX_SCALING_RATIO,
        "rebuilding from {LARGE} operations took {large_elapsed:?} vs {small_elapsed:?} for \
         {SMALL} -- a {ratio:.1}x slowdown for 10x the input exceeds the {MAX_SCALING_RATIO}x \
         linear-cost budget. This looks like a superlinear regression in rebuild_from_scratch, \
         not noise."
    );
}

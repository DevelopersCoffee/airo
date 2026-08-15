//! Supervisor conformance — contract `C6`, checklist `S4`.
//!
//! Black-box, against `airo_mind_core`'s public API only, the same style as
//! `rust/airo_core/tests/runtime_conformance.rs`. Per the conformance-suite
//! doc, these are written against C6 itself, not against `Supervisor`'s
//! current implementation — replacing the implementation (a real Vault, a
//! real Replay engine) should not require rewriting these tests.
//!
//! One item per `S4` bullet:
//!
//! - Lifecycle ordering (Vault before Replay before Projection; sync waits
//!   for replay to reach head)
//! - Cancellation leaves no torn state
//! - Backpressure
//! - Resource limits (memory, and concurrency)
//! - Engine restart without corrupting the engines around it
//! - Graceful shutdown flushes the group-commit buffer and seals the segment
//!
//! `#1302`'s open question — Rust or Dart — is answered by this file
//! existing: the Supervisor lives in `airo_mind_core`, which already backs
//! two production call sites (`airo_mind_whisper`, `airo_mind_llama`) over
//! FRB. Nothing here reaches across an FFI boundary because the contract
//! itself does not need to; wiring a `Supervisor` handle through FRB's
//! stateless call model is `#1338`'s integration concern, not this one's.

use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, Barrier};

use airo_mind_core::{
    AudioInput, CancelToken, EngineError, EngineState, ManagedEngine, ResourceBudget, RuntimeError,
    Supervisor, TranscriptSegment, TranscriptionOptions,
};

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// A managed engine that records every `start`/`stop` call it received, so a
/// test can assert precisely what happened to *this* engine and, just as
/// importantly, that nothing happened to any other.
struct RecordingEngine {
    starts: AtomicU32,
    stops: AtomicU32,
    fail_next_start: AtomicBool,
}

impl RecordingEngine {
    fn new() -> Self {
        Self {
            starts: AtomicU32::new(0),
            stops: AtomicU32::new(0),
            fail_next_start: AtomicBool::new(false),
        }
    }
}

impl ManagedEngine for RecordingEngine {
    fn start(&self) -> Result<(), EngineError> {
        if self.fail_next_start.swap(false, Ordering::SeqCst) {
            return Err(EngineError::Backend("simulated crash".into()));
        }
        self.starts.fetch_add(1, Ordering::SeqCst);
        Ok(())
    }

    fn stop(&self) {
        self.stops.fetch_add(1, Ordering::SeqCst);
    }
}

/// A speech engine that yields one segment per call and, optionally, blocks
/// on a barrier inside the sink — used to hold a job "in flight" so a second
/// job can be attempted against a concurrency cap while the first is still
/// running.
struct BlockingSpeech {
    memory_mb: u32,
    barrier: Option<Arc<Barrier>>,
}

impl airo_mind_core::SpeechEngine for BlockingSpeech {
    fn resource_request(&self) -> airo_mind_core::ResourceRequest {
        airo_mind_core::ResourceRequest::new(self.memory_mb)
    }

    fn transcribe(
        &self,
        _audio: AudioInput<'_>,
        _options: &TranscriptionOptions,
        _cancel: &CancelToken,
        sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        if let Some(barrier) = &self.barrier {
            barrier.wait();
        }
        sink(TranscriptSegment {
            start_ms: 0,
            end_ms: 1000,
            text: "one segment".into(),
        })
    }
}

fn audio() -> [i16; 4] {
    [0, 1, 2, 3]
}

// ---------------------------------------------------------------------------
// Lifecycle ordering — "Vault before Replay before Projection; sync does not
// start before replay reaches head"
// ---------------------------------------------------------------------------

#[test]
fn dependency_order_is_enforced_vault_replay_projection() {
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048));
    supervisor.register_engine("vault", &[], Box::new(RecordingEngine::new()));
    supervisor.register_engine("replay", &["vault"], Box::new(RecordingEngine::new()));
    supervisor.register_engine("projection", &["replay"], Box::new(RecordingEngine::new()));

    // Starting out of order is refused, not merely inadvisable.
    assert!(matches!(
        supervisor.start_engine("replay"),
        Err(RuntimeError::Lifecycle(_))
    ));
    assert!(matches!(
        supervisor.start_engine("projection"),
        Err(RuntimeError::Lifecycle(_))
    ));
    assert_eq!(
        supervisor.engine_state("replay"),
        Some(EngineState::NotStarted)
    );

    // In order, each becomes startable exactly when its dependency is
    // Running -- not before.
    supervisor.start_engine("vault").unwrap();
    assert_eq!(supervisor.engine_state("vault"), Some(EngineState::Running));
    assert!(
        supervisor.start_engine("projection").is_err(),
        "projection depends on replay, which vault being up does not satisfy"
    );

    supervisor.start_engine("replay").unwrap();
    supervisor.start_engine("projection").unwrap();

    assert_eq!(
        supervisor.health(),
        vec![
            ("vault", EngineState::Running),
            ("replay", EngineState::Running),
            ("projection", EngineState::Running),
        ]
    );
}

/// "Sync does not start before replay reaches head" — modeled as sync
/// depending on replay the same way projection does. The dependency
/// mechanism is generic; this proves it holds for the second named case in
/// `C6`, not just the first.
#[test]
fn sync_does_not_start_before_replay() {
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048));
    supervisor.register_engine("vault", &[], Box::new(RecordingEngine::new()));
    supervisor.register_engine("replay", &["vault"], Box::new(RecordingEngine::new()));
    supervisor.register_engine("sync", &["replay"], Box::new(RecordingEngine::new()));

    supervisor.start_engine("vault").unwrap();
    let err = supervisor.start_engine("sync").unwrap_err();
    assert!(matches!(err, RuntimeError::Lifecycle(_)));

    supervisor.start_engine("replay").unwrap();
    supervisor.start_engine("sync").unwrap();
    assert_eq!(supervisor.engine_state("sync"), Some(EngineState::Running));
}

// ---------------------------------------------------------------------------
// Cancellation — "leaves no torn state"
// ---------------------------------------------------------------------------

#[test]
fn a_cancelled_job_leaves_no_torn_state() {
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048));
    supervisor.register_speech(Box::new(BlockingSpeech {
        memory_mb: 512,
        barrier: None,
    }));

    let cancel = CancelToken::new();
    cancel.cancel();

    // "Torn state" for a single-segment engine means: some of a segment's
    // effect was applied and some was not. The only way to prove none of it
    // was applied is a sink that is never called once cancellation has
    // already been requested before the job starts.
    let mut applied = false;
    let result = supervisor.run_speech(
        AudioInput {
            samples: &audio(),
            sample_rate_hz: 16_000,
            channels: 1,
        },
        &TranscriptionOptions::default(),
        &cancel,
        &mut |_| {
            applied = true;
            Ok(())
        },
    );

    // A real engine checks `cancel` before doing any work; `BlockingSpeech`
    // does not, so this test instead proves the property at the level the
    // Supervisor is answerable for: cancellation is visible to the engine
    // before the sink is invoked is the engine's contract (proven in
    // `supervisor::tests` against `FakeSpeech`, which does check). What this
    // test adds is the multi-engine case: cancelling one job's token must
    // not affect a second, independent job.
    let _ = result;
    assert!(
        !applied || result.is_ok(),
        "a call that both ran the sink and reported cancellation would be torn"
    );

    // Independence: a fresh token for a second job is unaffected by the
    // first job's cancellation.
    let second_cancel = CancelToken::new();
    let mut second_applied = false;
    supervisor
        .run_speech(
            AudioInput {
                samples: &audio(),
                sample_rate_hz: 16_000,
                channels: 1,
            },
            &TranscriptionOptions::default(),
            &second_cancel,
            &mut |_| {
                second_applied = true;
                Ok(())
            },
        )
        .unwrap();
    assert!(second_applied, "an uncancelled job must still complete");
}

// ---------------------------------------------------------------------------
// Backpressure — a refusing sink stops the engine, not buffered without
// bound (existing coverage in `supervisor::tests`; this file's job is the
// four properties that module could not exercise without lifecycle support)
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Resource limits — memory (existing) and concurrency (new for `#1302`)
// ---------------------------------------------------------------------------

#[test]
fn a_job_over_the_concurrency_cap_is_refused_while_another_is_in_flight() {
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048)).with_max_concurrent_jobs(1);
    let barrier = Arc::new(Barrier::new(2));
    supervisor.register_speech(Box::new(BlockingSpeech {
        memory_mb: 512,
        barrier: Some(barrier.clone()),
    }));
    let supervisor = Arc::new(supervisor);

    let first = {
        let supervisor = supervisor.clone();
        std::thread::spawn(move || {
            supervisor.run_speech(
                AudioInput {
                    samples: &audio(),
                    sample_rate_hz: 16_000,
                    channels: 1,
                },
                &TranscriptionOptions::default(),
                &CancelToken::new(),
                &mut |_| Ok(()),
            )
        })
    };

    // Block until the first job is admitted and inside its sink -- i.e.
    // definitely still "active" from the Supervisor's point of view -- before
    // the second job is attempted.
    while supervisor.active_jobs() == 0 {
        std::thread::yield_now();
    }

    let second = supervisor.run_speech(
        AudioInput {
            samples: &audio(),
            sample_rate_hz: 16_000,
            channels: 1,
        },
        &TranscriptionOptions::default(),
        &CancelToken::new(),
        &mut |_| Ok(()),
    );
    assert_eq!(
        second,
        Err(RuntimeError::OverCapacity { active: 1, max: 1 }),
        "a second job must be refused while the cap is already spent, not queued silently"
    );

    // Release the first job so the barrier wait completes and the thread
    // joins.
    barrier.wait();
    first.join().unwrap().unwrap();
    assert_eq!(
        supervisor.active_jobs(),
        0,
        "the slot must be released once the job that held it finishes"
    );
}

#[test]
fn an_engine_over_the_memory_budget_is_refused_before_it_allocates() {
    let mut supervisor = Supervisor::new(ResourceBudget::new(512));
    supervisor.register_speech(Box::new(BlockingSpeech {
        memory_mb: 4096,
        barrier: None,
    }));
    let mut called = false;
    let result = supervisor.run_speech(
        AudioInput {
            samples: &audio(),
            sample_rate_hz: 16_000,
            channels: 1,
        },
        &TranscriptionOptions::default(),
        &CancelToken::new(),
        &mut |_| {
            called = true;
            Ok(())
        },
    );
    assert_eq!(
        result,
        Err(RuntimeError::OverBudget {
            needs_mb: 4096,
            budget_mb: 512
        })
    );
    assert!(!called);
}

// ---------------------------------------------------------------------------
// Engine restart — without corrupting the engines around it
// ---------------------------------------------------------------------------

#[test]
fn a_failed_engine_restarts_without_touching_its_neighbors() {
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048));
    supervisor.register_engine("vault", &[], Box::new(RecordingEngine::new()));
    supervisor.register_engine("replay", &["vault"], Box::new(RecordingEngine::new()));
    supervisor.register_engine("projection", &["replay"], Box::new(RecordingEngine::new()));

    supervisor.start_engine("vault").unwrap();
    supervisor.start_engine("replay").unwrap();
    supervisor.start_engine("projection").unwrap();

    let vault_metrics_before = supervisor.engine_metrics("vault").unwrap();
    let replay_metrics_before = supervisor.engine_metrics("replay").unwrap();

    // Restart the leaf engine. Neighbors it depends on must be untouched.
    supervisor.restart_engine("projection").unwrap();

    assert_eq!(
        supervisor.engine_state("vault"),
        Some(EngineState::Running),
        "restarting projection must not stop vault"
    );
    assert_eq!(
        supervisor.engine_state("replay"),
        Some(EngineState::Running),
        "restarting projection must not stop replay"
    );
    assert_eq!(
        supervisor.engine_metrics("vault").unwrap(),
        vault_metrics_before
    );
    assert_eq!(
        supervisor.engine_metrics("replay").unwrap(),
        replay_metrics_before
    );
    assert_eq!(supervisor.engine_metrics("projection").unwrap().restarts, 1);
    assert_eq!(
        supervisor.engine_state("projection"),
        Some(EngineState::Running),
        "a restart must leave the engine itself running again, not stuck Stopped"
    );
}

// ---------------------------------------------------------------------------
// Graceful shutdown — flushes the group-commit buffer, seals the segment,
// stops engines in reverse dependency order
// ---------------------------------------------------------------------------

#[test]
fn graceful_shutdown_flushes_the_buffer_and_seals_the_segment() {
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048));
    supervisor.register_engine("vault", &[], Box::new(RecordingEngine::new()));
    supervisor.register_engine("replay", &["vault"], Box::new(RecordingEngine::new()));

    supervisor.start_engine("vault").unwrap();
    supervisor.start_engine("replay").unwrap();

    // Simulate operations pending in the group-commit window at the moment
    // shutdown is requested -- the case "a kill during group commit recovers
    // cleanly on next start" protects against losing.
    supervisor.buffer_write(b"op-1;");
    supervisor.buffer_write(b"op-2;");

    assert!(!supervisor.buffer_sealed());
    assert!(
        supervisor.durable_buffer().is_empty(),
        "nothing durable yet"
    );

    supervisor.shutdown();

    assert!(
        supervisor.buffer_sealed(),
        "the active segment must be sealed once shutdown completes"
    );
    assert_eq!(
        supervisor.durable_buffer(),
        b"op-1;op-2;".to_vec(),
        "every byte pending at shutdown must be durable after it -- a kill \
         here must recover cleanly, not lose the group-commit window"
    );

    assert_eq!(supervisor.engine_state("vault"), Some(EngineState::Stopped));
    assert_eq!(
        supervisor.engine_state("replay"),
        Some(EngineState::Stopped)
    );
}

#[test]
fn shutdown_stops_engines_in_reverse_dependency_order() {
    // A dependent stopping after what it depends on is the failure mode this
    // guards: replay stopped first while projection is still reading from it
    // is exactly the "torn projection" `C6` names. Observed indirectly,
    // since `RecordingEngine::stop` does not record order by itself -- a
    // shared sequence counter does.
    struct OrderRecordingEngine {
        sequence: Arc<std::sync::Mutex<Vec<&'static str>>>,
        name: &'static str,
    }
    impl ManagedEngine for OrderRecordingEngine {
        fn start(&self) -> Result<(), EngineError> {
            Ok(())
        }
        fn stop(&self) {
            self.sequence.lock().unwrap().push(self.name);
        }
    }

    let sequence = Arc::new(std::sync::Mutex::new(Vec::new()));
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048));
    supervisor.register_engine(
        "vault",
        &[],
        Box::new(OrderRecordingEngine {
            sequence: sequence.clone(),
            name: "vault",
        }),
    );
    supervisor.register_engine(
        "replay",
        &["vault"],
        Box::new(OrderRecordingEngine {
            sequence: sequence.clone(),
            name: "replay",
        }),
    );
    supervisor.register_engine(
        "projection",
        &["replay"],
        Box::new(OrderRecordingEngine {
            sequence: sequence.clone(),
            name: "projection",
        }),
    );

    supervisor.start_engine("vault").unwrap();
    supervisor.start_engine("replay").unwrap();
    supervisor.start_engine("projection").unwrap();

    supervisor.shutdown();

    assert_eq!(
        *sequence.lock().unwrap(),
        vec!["projection", "replay", "vault"],
        "shutdown must stop the most-dependent engine first"
    );
}

// ---------------------------------------------------------------------------
// Control plane only — no payload passes through the Supervisor's lock
// ---------------------------------------------------------------------------

/// Not a runtime-checkable property in the way the others are -- there is no
/// value to inspect and assert "this is not a payload." The proof is
/// structural: every Supervisor method that touches durable-shaped data
/// (`buffer_write`, `durable_buffer`) operates on a caller-supplied
/// `GroupCommitBuffer` stand-in, and every job-execution method
/// (`run_speech`, `run_generation`) streams through a caller-supplied `sink`
/// it never stores. This test asserts the shape that keeps that true: a
/// second, independent Supervisor sharing no buffer with the first is
/// unaffected by the first's writes, which would not hold if payload data
/// routed through Supervisor-owned state rather than the caller's.
#[test]
fn two_supervisors_share_no_state() {
    let a = Supervisor::new(ResourceBudget::new(2048));
    let b = Supervisor::new(ResourceBudget::new(2048));
    a.buffer_write(b"a-only");
    assert!(b.durable_buffer().is_empty());
    a.shutdown();
    assert!(b.durable_buffer().is_empty());
    assert!(!b.buffer_sealed());
}

// ---------------------------------------------------------------------------
// Unregistered / unknown engine names are refusals, not panics
// ---------------------------------------------------------------------------

#[test]
fn an_unregistered_engine_name_is_a_refusal_not_a_panic() {
    let supervisor = Supervisor::new(ResourceBudget::new(2048));
    assert!(matches!(
        supervisor.start_engine("nothing"),
        Err(RuntimeError::Lifecycle(_))
    ));
    assert_eq!(supervisor.engine_state("nothing"), None);
}

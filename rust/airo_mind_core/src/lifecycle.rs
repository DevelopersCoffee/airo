//! Engine lifecycle: state, dependency ordering, and graceful shutdown.
//!
//! `C6`: *"every engine requests resources; the Supervisor grants them,"* and
//! specifically the half of that contract [`supervisor`] did not yet cover --
//! `#1396` scoped the Supervisor to two job slots (speech, generation)
//! executing one pipeline. This module is the generalization `#1302` asks
//! for: an arbitrary number of **stateful** engines -- Vault, Replay, Sync,
//! Projection, and so on, per the diagram in `#1302` -- each with a lifecycle
//! (start, stop, restart), a place in a dependency order, and a health state
//! the Supervisor can report without guessing.
//!
//! # Why this is a separate concern from job execution
//!
//! [`SpeechEngine`](crate::engine::SpeechEngine) and
//! [`GenerationEngine`](crate::engine::GenerationEngine) are **stateless per
//! call**: `transcribe`/`generate` run to completion or cancellation and hold
//! no state between calls. Vault, Replay, Sync, and Projection are the
//! opposite -- they are **started once and run for the life of the process**,
//! and other engines depend on them being up. Modeling both as the same kind
//! of "engine" would force a job-shaped API onto a service-shaped problem, or
//! vice versa. `C6` owns both; this module is the second half.
//!
//! # What this deliberately does not do
//!
//! It does not implement Vault, Replay, Sync, or Projection -- those are
//! `#1338`'s vertical slice, greenfield today. This module is the contract
//! shape they will register into: a real dependency graph, real state
//! transitions, and a real graceful-shutdown path, proven here against fake
//! engines the same way [`supervisor`]'s job tests use `FakeSpeech`.

use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, AtomicU64, Ordering};
use std::sync::Mutex;

use crate::engine::EngineError;

/// A registered engine's name. `&'static str` rather than an enum: the six
/// Phase 1-9 engines (Vault, Replay, Sync, Projection, AI, Capture) are not
/// exhaustive, and a new one should be a registration call, not an enum
/// variant added to this crate.
pub type EngineName = &'static str;

/// Where an engine is in its lifecycle. `C6`: *"health -- which engines are
/// up, which are degraded."*
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EngineState {
    /// Registered, never started.
    NotStarted,
    /// `start()` is running.
    Starting,
    /// Started and healthy. Its dependents may start.
    Running,
    /// `stop()` is running.
    Stopping,
    /// Stopped cleanly. Distinct from `Failed`: a stopped engine chose to
    /// stop, a failed one did not.
    Stopped,
    /// `start()` or `stop()` returned an error. Degraded, per `C6`'s health
    /// vocabulary -- not a panic, not silently `Stopped`.
    Failed,
}

/// A stateful engine the Supervisor starts once and runs for the life of the
/// process. Unlike [`SpeechEngine`](crate::engine::SpeechEngine), there is no
/// per-call input/output -- `start` brings it up, `stop` brings it down, and
/// whatever work it does in between is its own concern.
pub trait ManagedEngine: Send + Sync {
    /// Brings the engine up. Called only after every dependency is
    /// [`EngineState::Running`] -- an engine implementation never has to
    /// check its own dependencies are ready.
    fn start(&self) -> Result<(), EngineError>;

    /// Brings the engine down. Infallible: `C6`'s graceful shutdown must
    /// complete even if a subsystem is unhappy about being stopped, because
    /// the alternative is a shutdown that hangs or a segment that is never
    /// sealed.
    fn stop(&self);
}

/// What the Supervisor knows about one engine beyond its current state.
/// `C6`: *"metrics -- one place that knows operations/sec and memory, rather
/// than six."* `ops` and `elapsed since `started_at`* give a caller
/// operations/sec without this module inventing a policy for how often to
/// sample it; `restarts` is what turns "an engine restarted" from a log line
/// grepped for after the fact into a queryable fact.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct EngineMetrics {
    pub ops: u64,
    pub restarts: u32,
}

struct ManagedSlot {
    depends_on: Vec<EngineName>,
    state: EngineState,
    engine: Box<dyn ManagedEngine>,
    ops: AtomicU64,
    restarts: u32,
}

/// Errors specific to lifecycle management. Folded into
/// [`RuntimeError`](crate::supervisor::RuntimeError) at the Supervisor
/// boundary so callers see one error type.
#[derive(Debug, PartialEq, Eq)]
pub enum LifecycleError {
    /// No engine was registered under this name.
    UnknownEngine(EngineName),
    /// `start` was called before every dependency reached `Running`. `C6`:
    /// *"dependency ordering is enforced: Vault before Replay before
    /// Projection."*
    DependencyNotReady {
        engine: EngineName,
        waiting_on: EngineName,
    },
    /// The engine's own `start` or `stop` returned an error.
    Engine(EngineError),
}

impl std::fmt::Display for LifecycleError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::UnknownEngine(name) => write!(f, "no engine registered as {name:?}"),
            Self::DependencyNotReady { engine, waiting_on } => {
                write!(f, "{engine:?} cannot start: {waiting_on:?} is not Running")
            }
            Self::Engine(e) => write!(f, "{e}"),
        }
    }
}

impl std::error::Error for LifecycleError {}

/// The dependency-ordered registry of stateful engines. Owned by
/// [`Supervisor`](crate::supervisor::Supervisor); kept as its own type
/// because the graph algorithms (dependency checks, reverse-order shutdown)
/// are a self-contained concern that does not need to know about
/// [`ResourceBudget`](crate::budget::ResourceBudget) or job admission.
#[derive(Default)]
pub struct EngineRegistry {
    // `Vec` preserves registration order, which doubles as the deterministic
    // tie-break for shutdown ordering among engines with no dependency
    // relationship to each other.
    slots: Vec<(EngineName, Mutex<ManagedSlot>)>,
}

impl EngineRegistry {
    pub fn new() -> Self {
        Self::default()
    }

    /// Registers an engine with its dependencies. Panics on a duplicate name
    /// or an unregistered dependency -- both are programmer errors caught at
    /// startup, not conditions a caller should be asked to handle at every
    /// call site.
    pub fn register(
        &mut self,
        name: EngineName,
        depends_on: &[EngineName],
        engine: Box<dyn ManagedEngine>,
    ) {
        assert!(
            self.index_of(name).is_none(),
            "engine {name:?} is already registered"
        );
        for dep in depends_on {
            assert!(
                self.index_of(dep).is_some(),
                "engine {name:?} depends on unregistered engine {dep:?} -- register dependencies first"
            );
        }
        self.slots.push((
            name,
            Mutex::new(ManagedSlot {
                depends_on: depends_on.to_vec(),
                state: EngineState::NotStarted,
                engine,
                ops: AtomicU64::new(0),
                restarts: 0,
            }),
        ));
    }

    fn index_of(&self, name: EngineName) -> Option<usize> {
        self.slots.iter().position(|(n, _)| *n == name)
    }

    /// Starts one engine. Refuses if any dependency is not `Running` -- this
    /// is what makes "Vault before Replay before Projection" an enforced
    /// order rather than a comment.
    pub fn start(&self, name: EngineName) -> Result<(), LifecycleError> {
        let idx = self
            .index_of(name)
            .ok_or(LifecycleError::UnknownEngine(name))?;

        // Dependency check reads other slots' state before locking this one,
        // so a dependency that is itself being started concurrently is not
        // deadlocked against.
        {
            let (_, slot) = &self.slots[idx];
            let deps = slot.lock().unwrap().depends_on.clone();
            for dep in &deps {
                let dep_idx = self.index_of(dep).expect("validated at registration");
                let dep_state = self.slots[dep_idx].1.lock().unwrap().state;
                if dep_state != EngineState::Running {
                    return Err(LifecycleError::DependencyNotReady {
                        engine: name,
                        waiting_on: dep,
                    });
                }
            }
        }

        let (_, slot) = &self.slots[idx];
        let mut guard = slot.lock().unwrap();
        guard.state = EngineState::Starting;
        let engine_ref = &guard.engine;
        match engine_ref.start() {
            Ok(()) => {
                guard.state = EngineState::Running;
                Ok(())
            }
            Err(e) => {
                guard.state = EngineState::Failed;
                Err(LifecycleError::Engine(e))
            }
        }
    }

    /// Stops one engine unconditionally. Callers that must respect dependency
    /// order (a running Vault while Replay still depends on it) use
    /// [`Self::shutdown_all`], which computes that order; a targeted `stop`
    /// is for the restart path, where the caller already knows what depends
    /// on what.
    pub fn stop(&self, name: EngineName) -> Result<(), LifecycleError> {
        let idx = self
            .index_of(name)
            .ok_or(LifecycleError::UnknownEngine(name))?;
        let (_, slot) = &self.slots[idx];
        let mut guard = slot.lock().unwrap();
        guard.state = EngineState::Stopping;
        guard.engine.stop();
        guard.state = EngineState::Stopped;
        Ok(())
    }

    /// Stops then starts one engine. `C6` / S4: *"a failed engine restarts
    /// without corrupting the state of the engines around it"* -- this
    /// touches only `name`'s slot; every other slot's state and metrics are
    /// untouched, which is the property the conformance test asserts.
    pub fn restart(&self, name: EngineName) -> Result<(), LifecycleError> {
        let idx = self
            .index_of(name)
            .ok_or(LifecycleError::UnknownEngine(name))?;
        self.stop(name)?;
        let result = self.start(name);
        self.slots[idx].1.lock().unwrap().restarts += 1;
        result
    }

    /// Current state of one engine, or `None` if nothing is registered under
    /// that name.
    pub fn state_of(&self, name: EngineName) -> Option<EngineState> {
        let idx = self.index_of(name)?;
        Some(self.slots[idx].1.lock().unwrap().state)
    }

    /// Every registered engine's health, in registration order. `C6`:
    /// *"health -- which engines are up, which are degraded."*
    pub fn health(&self) -> Vec<(EngineName, EngineState)> {
        self.slots
            .iter()
            .map(|(name, slot)| (*name, slot.lock().unwrap().state))
            .collect()
    }

    /// Records one unit of work against an engine, for the operations/sec
    /// half of `C6`'s metrics guarantee.
    pub fn record_op(&self, name: EngineName) {
        if let Some(idx) = self.index_of(name) {
            self.slots[idx]
                .1
                .lock()
                .unwrap()
                .ops
                .fetch_add(1, Ordering::Relaxed);
        }
    }

    pub fn metrics_of(&self, name: EngineName) -> Option<EngineMetrics> {
        let idx = self.index_of(name)?;
        let guard = self.slots[idx].1.lock().unwrap();
        Some(EngineMetrics {
            ops: guard.ops.load(Ordering::Relaxed),
            restarts: guard.restarts,
        })
    }

    /// Stops every `Running` engine in **reverse dependency order** -- a
    /// dependent stops before what it depends on, so nothing is left
    /// running against a Vault that already went down. `C6`: *"shutdown is
    /// graceful ... no half-applied revocation, no torn projection."*
    ///
    /// Engines that were never started, or already stopped, are left alone.
    pub fn shutdown_all(&self) {
        for name in self.reverse_dependency_order() {
            let idx = self.index_of(name).expect("just enumerated");
            let mut guard = self.slots[idx].1.lock().unwrap();
            if guard.state == EngineState::Running {
                guard.state = EngineState::Stopping;
                guard.engine.stop();
                guard.state = EngineState::Stopped;
            }
        }
    }

    /// Topological order (dependencies before dependents), reversed. A
    /// dependent always appears before what it depends on -- the order
    /// [`Self::shutdown_all`] needs, and the order [`Self::start`] would need
    /// too if a caller wanted "start everything" rather than one engine at a
    /// time.
    fn reverse_dependency_order(&self) -> Vec<EngineName> {
        let mut in_degree: HashMap<EngineName, usize> = HashMap::new();
        let mut dependents: HashMap<EngineName, Vec<EngineName>> = HashMap::new();
        for (name, slot) in &self.slots {
            in_degree.entry(name).or_insert(0);
            for dep in &slot.lock().unwrap().depends_on {
                *in_degree.entry(name).or_insert(0) += 1;
                dependents.entry(*dep).or_default().push(*name);
            }
        }

        // Kahn's algorithm, seeded in registration order so ties are
        // deterministic rather than HashMap-order-dependent (`C2`'s
        // determinism discipline applies here too: this is control-plane
        // ordering, not replay, but a nondeterministic shutdown order is
        // exactly the kind of flake that discipline exists to prevent).
        let mut ready: Vec<EngineName> = self
            .slots
            .iter()
            .map(|(name, _)| *name)
            .filter(|name| in_degree[name] == 0)
            .collect();
        let mut order = Vec::with_capacity(self.slots.len());
        while let Some(name) = ready.first().copied() {
            ready.remove(0);
            order.push(name);
            if let Some(next) = dependents.get(name) {
                for dependent in next {
                    let entry = in_degree.get_mut(dependent).unwrap();
                    *entry -= 1;
                    if *entry == 0 {
                        ready.push(*dependent);
                    }
                }
            }
        }
        order.reverse();
        order
    }
}

/// A stand-in for the operation log's group-commit buffer (`C1`). The real
/// log is `#1338`'s -- Phase 2 in the roadmap -- but `C6`'s graceful-shutdown
/// guarantee ("the group-commit buffer flushes and the active segment
/// seals") is the Supervisor's to coordinate regardless of what backs the
/// buffer, so the coordination is proven here against this minimal stand-in.
/// When the real log lands, this struct is deleted and the Supervisor's
/// shutdown path points at it instead -- the call sites do not change.
pub struct GroupCommitBuffer {
    pending: Mutex<Vec<u8>>,
    flushed: Mutex<Vec<u8>>,
    sealed: std::sync::atomic::AtomicBool,
}

impl Default for GroupCommitBuffer {
    fn default() -> Self {
        Self {
            pending: Mutex::new(Vec::new()),
            flushed: Mutex::new(Vec::new()),
            sealed: std::sync::atomic::AtomicBool::new(false),
        }
    }
}

impl GroupCommitBuffer {
    pub fn new() -> Self {
        Self::default()
    }

    /// Buffers a write the way a group-commit window would, before its
    /// bounded flush interval elapses.
    pub fn write(&self, bytes: &[u8]) {
        self.pending.lock().unwrap().extend_from_slice(bytes);
    }

    /// Moves every pending byte to the durable side atomically -- there is
    /// no window in which some pending bytes are durable and others are not,
    /// which is what "recovers cleanly on next start" requires: a reader
    /// after `flush` sees everything or (before `flush` is called) nothing
    /// pending, never a partial write.
    pub fn flush(&self) {
        let mut pending = self.pending.lock().unwrap();
        let mut flushed = self.flushed.lock().unwrap();
        flushed.extend(pending.drain(..));
    }

    /// Seals the active segment. Called after `flush`, never before -- a
    /// segment sealed with unflushed bytes still pending is exactly the torn
    /// state this exists to prevent.
    pub fn seal(&self) {
        self.sealed.store(true, Ordering::SeqCst);
    }

    pub fn is_sealed(&self) -> bool {
        self.sealed.load(Ordering::SeqCst)
    }

    /// What a fresh reader would see on restart: the durable bytes only.
    pub fn durable(&self) -> Vec<u8> {
        self.flushed.lock().unwrap().clone()
    }

    /// What is buffered but not yet durable. Exposed for the conformance
    /// test to prove `flush` leaves nothing behind, not for production use.
    pub fn pending_len(&self) -> usize {
        self.pending.lock().unwrap().len()
    }
}

/// A per-Supervisor concurrency cap. `C6` / `#1302`: *"resource limits --
/// memory ceilings and concurrency caps, enforced centrally."* The memory
/// half already existed in [`ResourceBudget`](crate::budget::ResourceBudget);
/// this is the concurrency half, admission-checked the same way -- refused
/// before the engine runs, not torn down after it is already using the CPU.
pub struct ConcurrencyLimiter {
    max: u32,
    active: AtomicU32,
}

/// Held for the duration of one admitted job. Dropping it -- including via
/// an early return or a panic unwind -- releases the slot, so a job that
/// errors out cannot leak capacity that starves every job after it.
pub struct ConcurrencySlot<'a>(&'a AtomicU32);

impl Drop for ConcurrencySlot<'_> {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::SeqCst);
    }
}

impl ConcurrencyLimiter {
    pub fn new(max: u32) -> Self {
        Self {
            max,
            active: AtomicU32::new(0),
        }
    }

    pub fn unbounded() -> Self {
        Self::new(u32::MAX)
    }

    /// Admits one job if under the cap, incrementing `active` atomically so
    /// two callers racing to take the last slot cannot both succeed.
    pub fn admit(&self) -> Result<ConcurrencySlot<'_>, (u32, u32)> {
        loop {
            let current = self.active.load(Ordering::SeqCst);
            if current >= self.max {
                return Err((current, self.max));
            }
            if self
                .active
                .compare_exchange(current, current + 1, Ordering::SeqCst, Ordering::SeqCst)
                .is_ok()
            {
                return Ok(ConcurrencySlot(&self.active));
            }
        }
    }

    pub fn active(&self) -> u32 {
        self.active.load(Ordering::SeqCst)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct FakeManaged {
        fail: bool,
    }

    impl ManagedEngine for FakeManaged {
        fn start(&self) -> Result<(), EngineError> {
            if self.fail {
                Err(EngineError::Backend("fake failure".into()))
            } else {
                Ok(())
            }
        }

        fn stop(&self) {}
    }

    fn ok() -> Box<dyn ManagedEngine> {
        Box::new(FakeManaged { fail: false })
    }

    #[test]
    fn a_dependent_refuses_to_start_before_its_dependency_is_running() {
        let mut reg = EngineRegistry::new();
        reg.register("vault", &[], ok());
        reg.register("replay", &["vault"], ok());

        let err = reg.start("replay").unwrap_err();
        assert_eq!(
            err,
            LifecycleError::DependencyNotReady {
                engine: "replay",
                waiting_on: "vault",
            }
        );
        assert_eq!(reg.state_of("replay"), Some(EngineState::NotStarted));
    }

    #[test]
    fn vault_before_replay_before_projection() {
        let mut reg = EngineRegistry::new();
        reg.register("vault", &[], ok());
        reg.register("replay", &["vault"], ok());
        reg.register("projection", &["replay"], ok());

        assert!(reg.start("replay").is_err());
        assert!(reg.start("projection").is_err());

        reg.start("vault").unwrap();
        assert_eq!(reg.state_of("vault"), Some(EngineState::Running));
        assert!(
            reg.start("projection").is_err(),
            "projection depends on replay, not just vault"
        );

        reg.start("replay").unwrap();
        reg.start("projection").unwrap();
        assert_eq!(reg.state_of("projection"), Some(EngineState::Running));
    }

    #[test]
    fn an_unknown_engine_is_a_refusal_not_a_panic() {
        let reg = EngineRegistry::new();
        assert_eq!(
            reg.start("nothing"),
            Err(LifecycleError::UnknownEngine("nothing"))
        );
    }

    #[test]
    fn a_start_failure_reports_failed_health() {
        let mut reg = EngineRegistry::new();
        reg.register("flaky", &[], Box::new(FakeManaged { fail: true }));
        assert!(reg.start("flaky").is_err());
        assert_eq!(reg.state_of("flaky"), Some(EngineState::Failed));
    }
}

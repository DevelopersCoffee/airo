//! Deterministic reference runtime for planner and conformance validation.
//!
//! This module has no platform, planner, or LiteRT dependencies. Time is a
//! virtual clock advanced by configured costs so identical inputs always yield
//! identical traces and telemetry.

use super::runtime_contracts::{
    CapabilityState, InferenceIr, RuntimeApiVersion, RuntimeCapabilities, RuntimeErrorCode,
    RuntimeHealth, RuntimeHealthState, RuntimeId,
};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct MockConfig {
    pub startup_delay_ms: u64,
    pub first_token_delay_ms: u64,
    pub token_delay_ms: u64,
    pub token_rate: u32,
    pub seed: u64,
    pub failure: Option<RuntimeErrorCode>,
    pub fail_after_tokens: Option<u32>,
    pub cancel_after_tokens: Option<u32>,
}

impl Default for MockConfig {
    fn default() -> Self {
        Self {
            startup_delay_ms: 100,
            first_token_delay_ms: 20,
            token_delay_ms: 20,
            token_rate: 50,
            seed: 42,
            failure: None,
            fail_after_tokens: None,
            cancel_after_tokens: None,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct FailureInjection {
    pub error: Option<RuntimeErrorCode>,
    pub after_tokens: Option<u32>,
    pub cancel_after_tokens: Option<u32>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ExecutionTraceEntry {
    pub sequence: u32,
    pub event: String,
    pub elapsed_ms: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ExecutionTrace {
    pub entries: Vec<ExecutionTraceEntry>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TelemetryEvent {
    pub sequence: u32,
    pub event: String,
    pub elapsed_ms: u64,
    pub error: Option<RuntimeErrorCode>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TelemetryStub {
    pub events: Vec<TelemetryEvent>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RuntimeSession {
    pub session_id: String,
    pub state: RuntimeHealthState,
    pub generated_tokens: u32,
}

#[derive(Clone, Debug, Eq, PartialEq)]
#[flutter_rust_bridge::frb(opaque)]
pub struct RuntimeRegistry {
    pub contract_version: RuntimeApiVersion,
    pub runtimes: Vec<RuntimeId>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
#[flutter_rust_bridge::frb(opaque)]
pub struct MockRuntime {
    pub config: MockConfig,
    pub session: RuntimeSession,
    pub trace: ExecutionTrace,
    pub telemetry: TelemetryStub,
    elapsed_ms: u64,
    sequence: u32,
    cancelled: bool,
    last_error: Option<RuntimeErrorCode>,
}

pub fn mock_runtime_new(config: MockConfig) -> MockRuntime {
    MockRuntime {
        config,
        session: RuntimeSession {
            session_id: "mock-session-v1".into(),
            state: RuntimeHealthState::Created,
            generated_tokens: 0,
        },
        trace: ExecutionTrace {
            entries: Vec::new(),
        },
        telemetry: TelemetryStub { events: Vec::new() },
        elapsed_ms: 0,
        sequence: 0,
        cancelled: false,
        last_error: None,
    }
}

pub fn mock_failure_injection_default() -> FailureInjection {
    FailureInjection {
        error: None,
        after_tokens: None,
        cancel_after_tokens: None,
    }
}

pub fn mock_runtime_capabilities() -> RuntimeCapabilities {
    RuntimeCapabilities {
        contract_version: RuntimeApiVersion::V1,
        runtime: RuntimeId::Mock,
        streaming: CapabilityState::Supported,
        cancellation: CapabilityState::Supported,
        vision: CapabilityState::Unsupported,
        tool_calling: CapabilityState::Unknown,
        grammar: CapabilityState::Unknown,
        json_mode: CapabilityState::Unknown,
    }
}

pub fn runtime_registry_new() -> RuntimeRegistry {
    RuntimeRegistry {
        contract_version: RuntimeApiVersion::V1,
        runtimes: Vec::new(),
    }
}

pub fn runtime_registry_register_mock(registry: &mut RuntimeRegistry) {
    if !registry.runtimes.contains(&RuntimeId::Mock) {
        registry.runtimes.push(RuntimeId::Mock);
    }
}

pub fn runtime_registry_contains_mock(registry: &RuntimeRegistry) -> bool {
    registry.runtimes.contains(&RuntimeId::Mock)
}

pub fn mock_runtime_initialize(runtime: &mut MockRuntime) -> RuntimeHealth {
    runtime.session.state = RuntimeHealthState::Initializing;
    runtime.record("Initializing", None);
    runtime.elapsed_ms += runtime.config.startup_delay_ms;

    if let Some(error) = runtime.config.failure {
        return runtime.fail(error);
    }

    runtime.session.state = RuntimeHealthState::Ready;
    runtime.record("Ready", None);
    runtime.telemetry("RuntimeReady", None);
    runtime.health()
}

pub fn mock_runtime_generate(
    runtime: &mut MockRuntime,
    _ir: InferenceIr,
    token_count: u32,
) -> Vec<String> {
    if runtime.session.state != RuntimeHealthState::Ready {
        runtime.fail(RuntimeErrorCode::RuntimeUnavailable);
        return Vec::new();
    }

    let cancelled_before_start = runtime.cancelled;
    runtime.cancelled = false;
    if cancelled_before_start {
        runtime.fail(RuntimeErrorCode::Cancelled);
        return Vec::new();
    }

    runtime.session.state = RuntimeHealthState::Busy;
    runtime.record("GenerationStarted", None);
    runtime.telemetry("GenerationStarted", None);
    runtime.elapsed_ms += runtime.config.first_token_delay_ms;

    let mut tokens = Vec::new();
    for index in 0..token_count {
        if runtime.cancelled {
            runtime.fail(RuntimeErrorCode::Cancelled);
            break;
        }
        if runtime
            .config
            .fail_after_tokens
            .is_some_and(|limit| index >= limit)
        {
            let error = runtime
                .config
                .failure
                .unwrap_or(RuntimeErrorCode::OutOfMemory);
            runtime.fail(error);
            break;
        }
        if runtime
            .config
            .cancel_after_tokens
            .is_some_and(|limit| index >= limit)
        {
            runtime.fail(RuntimeErrorCode::Cancelled);
            break;
        }
        runtime.elapsed_ms += runtime.config.token_delay_ms;
        tokens.push(format!("mock-{}", runtime.next_jitter()));
        runtime.session.generated_tokens += 1;
        if index == 0 {
            runtime.record("FirstToken", None);
            runtime.telemetry("FirstToken", None);
        }
    }

    if runtime.session.state == RuntimeHealthState::Busy {
        runtime.session.state = RuntimeHealthState::Ready;
        runtime.record("GenerationFinished", None);
        runtime.telemetry("GenerationFinished", None);
    }
    tokens
}

pub fn mock_runtime_cancel(runtime: &mut MockRuntime) {
    runtime.cancelled = true;
}

pub fn mock_runtime_shutdown(runtime: &mut MockRuntime) -> RuntimeHealth {
    runtime.session.state = RuntimeHealthState::ShuttingDown;
    runtime.record("ShuttingDown", None);
    runtime.session.state = RuntimeHealthState::Stopped;
    runtime.record("Stopped", None);
    runtime.telemetry("RuntimeStopped", None);
    runtime.health()
}

pub fn mock_runtime_health(runtime: &MockRuntime) -> RuntimeHealth {
    runtime.health()
}

pub fn mock_runtime_trace(runtime: &MockRuntime) -> Vec<ExecutionTraceEntry> {
    runtime.trace.entries.clone()
}

pub fn mock_runtime_telemetry(runtime: &MockRuntime) -> Vec<TelemetryEvent> {
    runtime.telemetry.events.clone()
}

impl MockRuntime {
    fn health(&self) -> RuntimeHealth {
        RuntimeHealth {
            state: self.session.state,
            error: self.last_error,
            detail: None,
        }
    }

    fn fail(&mut self, error: RuntimeErrorCode) -> RuntimeHealth {
        self.last_error = Some(error);
        self.session.state = match error {
            RuntimeErrorCode::OutOfMemory => RuntimeHealthState::LowMemory,
            RuntimeErrorCode::ThermalLimit => RuntimeHealthState::ThermallyLimited,
            RuntimeErrorCode::Cancelled => RuntimeHealthState::Ready,
            _ => RuntimeHealthState::Failed,
        };
        self.record("GenerationFailed", Some(error));
        self.telemetry("GenerationFailed", Some(error));
        RuntimeHealth {
            state: self.session.state,
            error: Some(error),
            detail: Some(format!("mock failure: {error:?}")),
        }
    }

    fn record(&mut self, event: &str, _error: Option<RuntimeErrorCode>) {
        self.sequence += 1;
        self.trace.entries.push(ExecutionTraceEntry {
            sequence: self.sequence,
            event: event.into(),
            elapsed_ms: self.elapsed_ms,
        });
    }

    fn telemetry(&mut self, event: &str, error: Option<RuntimeErrorCode>) {
        self.telemetry.events.push(TelemetryEvent {
            sequence: self.sequence,
            event: event.into(),
            elapsed_ms: self.elapsed_ms,
            error,
        });
    }

    fn next_jitter(&mut self) -> u64 {
        // Deterministic xorshift; no system randomness enters a mock run.
        let mut value = self.config.seed.wrapping_add(self.sequence as u64);
        value ^= value << 13;
        value ^= value >> 7;
        value ^= value << 17;
        value
    }
}

#[cfg(test)]
mod tests {
    use super::super::runtime_contracts::ComputeAccelerator;
    use super::*;

    fn ir() -> InferenceIr {
        InferenceIr {
            runtime: RuntimeId::Mock,
            accelerator: ComputeAccelerator::Cpu,
            model_id: "mock-model".into(),
            context_tokens: 128,
            output_tokens: 8,
            temperature: 0.0,
            top_k: 1,
            top_p: 1.0,
            priority: super::super::runtime_contracts::ExecutionPriority::Interactive,
        }
    }

    #[test]
    fn identical_seed_and_config_produce_identical_runs() {
        let config = MockConfig::default();
        let mut left = mock_runtime_new(config.clone());
        let mut right = mock_runtime_new(config);
        mock_runtime_initialize(&mut left);
        mock_runtime_initialize(&mut right);
        assert_eq!(
            mock_runtime_generate(&mut left, ir(), 3),
            mock_runtime_generate(&mut right, ir(), 3)
        );
        assert_eq!(left.trace, right.trace);
        assert_eq!(left.telemetry, right.telemetry);
    }

    #[test]
    fn failure_injection_is_structured() {
        let mut runtime = mock_runtime_new(MockConfig {
            failure: Some(RuntimeErrorCode::BackendUnavailable),
            ..MockConfig::default()
        });
        let health = mock_runtime_initialize(&mut runtime);
        assert_eq!(health.error, Some(RuntimeErrorCode::BackendUnavailable));
        assert_eq!(health.state, RuntimeHealthState::Failed);
    }

    #[test]
    fn cancellation_is_deterministic_and_structured() {
        let mut runtime = mock_runtime_new(MockConfig {
            cancel_after_tokens: Some(1),
            ..MockConfig::default()
        });
        assert_eq!(
            mock_runtime_initialize(&mut runtime).state,
            RuntimeHealthState::Ready
        );
        let tokens = mock_runtime_generate(&mut runtime, ir(), 3);
        assert_eq!(tokens.len(), 1);
        assert_eq!(
            mock_runtime_health(&runtime).error,
            Some(RuntimeErrorCode::Cancelled)
        );
        assert_eq!(
            mock_runtime_health(&runtime).state,
            RuntimeHealthState::Ready
        );

        mock_runtime_cancel(&mut runtime);
        let cancelled = mock_runtime_generate(&mut runtime, ir(), 1);
        assert!(cancelled.is_empty());
        assert_eq!(
            mock_runtime_health(&runtime).state,
            RuntimeHealthState::Ready
        );
    }

    #[test]
    fn registry_deduplicates_mock_registration() {
        let mut registry = runtime_registry_new();
        runtime_registry_register_mock(&mut registry);
        runtime_registry_register_mock(&mut registry);
        assert_eq!(registry.runtimes, vec![RuntimeId::Mock]);
    }
}

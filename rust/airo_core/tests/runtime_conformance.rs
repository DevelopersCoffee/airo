use airo_core::api::mock_runtime::{
    mock_runtime_cancel, mock_runtime_capabilities, mock_runtime_generate, mock_runtime_health,
    mock_runtime_initialize, mock_runtime_new, mock_runtime_shutdown, MockConfig,
};
use airo_core::api::runtime_contracts::{
    CapabilityState, ComputeAccelerator, ExecutionPriority, ExecutionTraceEvent, InferenceIr,
    RuntimeApiVersion, RuntimeErrorCode, RuntimeHealthState, RuntimeId,
};

fn inference_ir() -> InferenceIr {
    InferenceIr {
        runtime: RuntimeId::Mock,
        accelerator: ComputeAccelerator::Cpu,
        model_id: "mock-chat".into(),
        context_tokens: 256,
        output_tokens: 32,
        temperature: 0.2,
        top_k: 40,
        top_p: 0.9,
        priority: ExecutionPriority::Interactive,
    }
}

#[test]
fn reference_backend_satisfies_lifecycle_and_observability_contract() {
    let capabilities = mock_runtime_capabilities();
    assert_eq!(capabilities.contract_version, RuntimeApiVersion::V1);
    assert_eq!(capabilities.runtime, RuntimeId::Mock);
    assert_eq!(capabilities.streaming, CapabilityState::Supported);

    let mut runtime = mock_runtime_new(MockConfig::default());
    assert_eq!(
        mock_runtime_health(&runtime).state,
        RuntimeHealthState::Created
    );

    assert_eq!(
        mock_runtime_initialize(&mut runtime).state,
        RuntimeHealthState::Ready
    );
    let tokens = mock_runtime_generate(&mut runtime, inference_ir(), 3);
    assert_eq!(tokens.len(), 3);
    assert_eq!(
        mock_runtime_health(&runtime).state,
        RuntimeHealthState::Ready
    );

    let trace = runtime.trace.entries.clone();
    let events: Vec<_> = trace.iter().map(|entry| entry.event).collect();
    assert_eq!(events[0], ExecutionTraceEvent::Initializing);
    assert_eq!(events[1], ExecutionTraceEvent::Ready);
    assert_eq!(events[2], ExecutionTraceEvent::GenerationStarted);
    assert_eq!(events[3], ExecutionTraceEvent::FirstToken);
    assert_eq!(
        events.last(),
        Some(&ExecutionTraceEvent::GenerationFinished)
    );
    assert!(trace
        .windows(2)
        .all(|pair| pair[0].sequence < pair[1].sequence));
    assert!(runtime
        .telemetry
        .events
        .iter()
        .all(|event| event.sequence > 0));

    assert_eq!(
        mock_runtime_shutdown(&mut runtime).state,
        RuntimeHealthState::Stopped
    );
    assert_eq!(
        mock_runtime_health(&runtime).state,
        RuntimeHealthState::Stopped
    );
}

#[test]
fn cancellation_is_recoverable_and_idempotent() {
    let mut runtime = mock_runtime_new(MockConfig::default());
    mock_runtime_initialize(&mut runtime);

    mock_runtime_cancel(&mut runtime);
    mock_runtime_cancel(&mut runtime);
    assert!(mock_runtime_generate(&mut runtime, inference_ir(), 4).is_empty());
    assert_eq!(
        mock_runtime_health(&runtime).state,
        RuntimeHealthState::Ready
    );
    assert_eq!(
        mock_runtime_health(&runtime).error,
        Some(RuntimeErrorCode::Cancelled)
    );

    let tokens = mock_runtime_generate(&mut runtime, inference_ir(), 2);
    assert_eq!(tokens.len(), 2);
    assert_eq!(
        mock_runtime_health(&runtime).state,
        RuntimeHealthState::Ready
    );
}

#[test]
fn injected_failure_has_typed_error_and_failed_health() {
    let mut config = MockConfig::default();
    config.failure = Some(RuntimeErrorCode::OutOfMemory);
    let mut runtime = mock_runtime_new(config);

    let health = mock_runtime_initialize(&mut runtime);
    assert_eq!(health.state, RuntimeHealthState::LowMemory);
    assert_eq!(health.error, Some(RuntimeErrorCode::OutOfMemory));
    assert!(mock_runtime_generate(&mut runtime, inference_ir(), 1).is_empty());
}

//! Versioned, backend-neutral contracts for the Airo Edge Runtime.
//!
//! This module intentionally contains no planner policy or runtime
//! implementation. It is the Rust source of truth for the v1 Flutter bridge.

/// Stable public contract version.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RuntimeApiVersion {
    V1,
}

/// Stable runtime identifiers.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RuntimeId {
    Mock,
    LiteRt,
    LlamaCpp,
    Mlx,
    Onnx,
}

/// Stable capability identifiers used by model selection.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CapabilityId {
    Chat,
    Vision,
    Embedding,
    Speech,
    Reasoning,
    ToolCalling,
}

/// Capability negotiation state.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CapabilityState {
    Supported,
    Unsupported,
    Unknown,
}

/// Platform-neutral compute accelerator identifiers.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ComputeAccelerator {
    Cpu,
    Vulkan,
    Metal,
    CoreMl,
    AppleNeuralEngine,
    Nnapi,
    OpenCl,
    Cuda,
}

/// Runtime lifecycle state shared by every backend.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RuntimeHealthState {
    Created,
    Initializing,
    Ready,
    Busy,
    Recovering,
    LowMemory,
    ThermallyLimited,
    Unavailable,
    ShuttingDown,
    Stopped,
    Failed,
}

/// Stable runtime failure identifiers.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RuntimeErrorCode {
    OutOfMemory,
    ModelMissing,
    RuntimeUnavailable,
    BackendUnavailable,
    InitializationFailed,
    ThermalLimit,
    StorageFailure,
    PermissionDenied,
    ContextTooLarge,
    UnsupportedModel,
    PlannerFailure,
    Timeout,
    Cancelled,
    Unknown,
}

/// Priority used by the inference scheduler.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ExecutionPriority {
    Interactive,
    Foreground,
    Background,
    Maintenance,
}

/// Immutable request entering the planner.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct InferenceRequest {
    pub capability: CapabilityId,
    pub prompt: String,
    pub model_id: Option<String>,
    pub priority: ExecutionPriority,
}

/// Immutable backend-neutral intermediate representation.
#[derive(Clone, Debug, PartialEq)]
pub struct InferenceIr {
    pub runtime: RuntimeId,
    pub accelerator: ComputeAccelerator,
    pub model_id: String,
    pub context_tokens: u32,
    pub output_tokens: u32,
    pub temperature: f64,
    pub top_k: u32,
    pub top_p: f64,
    pub priority: ExecutionPriority,
}

/// Runtime capability declaration and negotiated feature states.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RuntimeCapabilities {
    pub contract_version: RuntimeApiVersion,
    pub runtime: RuntimeId,
    pub streaming: CapabilityState,
    pub cancellation: CapabilityState,
    pub vision: CapabilityState,
    pub tool_calling: CapabilityState,
    pub grammar: CapabilityState,
    pub json_mode: CapabilityState,
}

/// Backend health snapshot.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RuntimeHealth {
    pub state: RuntimeHealthState,
    pub error: Option<RuntimeErrorCode>,
    pub detail: Option<String>,
}

/// Stable entry point used by generated Flutter bindings to verify the v1 API.
pub fn runtime_api_version() -> RuntimeApiVersion {
    RuntimeApiVersion::V1
}

/// Contract-only round trip used by binding and serialization tests.
///
/// This is deliberately policy-free; planner implementations are introduced
/// in a later milestone.
pub fn runtime_contracts_round_trip(request: InferenceRequest) -> InferenceRequest {
    request
}

pub fn runtime_ir_round_trip(ir: InferenceIr) -> InferenceIr {
    ir
}

pub fn runtime_capabilities_round_trip(capabilities: RuntimeCapabilities) -> RuntimeCapabilities {
    capabilities
}

pub fn runtime_health_round_trip(health: RuntimeHealth) -> RuntimeHealth {
    health
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exposes_v1_contract() {
        assert_eq!(runtime_api_version(), RuntimeApiVersion::V1);
    }

    #[test]
    fn contract_values_round_trip_without_policy() {
        let request = InferenceRequest {
            capability: CapabilityId::Chat,
            prompt: "hello".into(),
            model_id: Some("model-v1".into()),
            priority: ExecutionPriority::Interactive,
        };
        assert_eq!(runtime_contracts_round_trip(request.clone()), request);

        let ir = InferenceIr {
            runtime: RuntimeId::Mock,
            accelerator: ComputeAccelerator::Cpu,
            model_id: "model-v1".into(),
            context_tokens: 2048,
            output_tokens: 128,
            temperature: 0.2,
            top_k: 40,
            top_p: 0.9,
            priority: ExecutionPriority::Interactive,
        };
        assert_eq!(runtime_ir_round_trip(ir.clone()), ir);
    }
}

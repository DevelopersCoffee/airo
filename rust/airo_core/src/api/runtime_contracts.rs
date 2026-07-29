//! Versioned, backend-neutral contracts for the Airo Edge Runtime.
//!
//! This module intentionally contains no planner policy or runtime
//! implementation. It is the Rust source of truth for the v1 Flutter bridge.

use serde::{Deserialize, Serialize};

/// Stable public contract version.
#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum RuntimeApiVersion {
    V1 = 1,
}

/// Stable runtime identifiers.
#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum RuntimeId {
    Mock = 0,
    LiteRt = 1,
    LlamaCpp = 2,
    Mlx = 3,
    Onnx = 4,
}

/// Stable capability identifiers used by model selection.
#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum CapabilityId {
    Chat = 0,
    Vision = 1,
    Embedding = 2,
    Speech = 3,
    Reasoning = 4,
    ToolCalling = 5,
}

/// Capability negotiation state.
#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum CapabilityState {
    Supported = 0,
    Unsupported = 1,
    Unknown = 2,
}

/// Platform-neutral compute accelerator identifiers.
#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum ComputeAccelerator {
    Cpu = 0,
    Vulkan = 1,
    Metal = 2,
    CoreMl = 3,
    AppleNeuralEngine = 4,
    Nnapi = 5,
    OpenCl = 6,
    Cuda = 7,
}

/// Runtime lifecycle state shared by every backend.
#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum RuntimeHealthState {
    Created = 0,
    Initializing = 1,
    Ready = 2,
    Busy = 3,
    Recovering = 4,
    LowMemory = 5,
    ThermallyLimited = 6,
    Unavailable = 7,
    ShuttingDown = 8,
    Stopped = 9,
    Failed = 10,
}

/// Stable runtime failure identifiers.
#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum RuntimeErrorCode {
    OutOfMemory = 0,
    ModelMissing = 1,
    RuntimeUnavailable = 2,
    BackendUnavailable = 3,
    InitializationFailed = 4,
    ThermalLimit = 5,
    StorageFailure = 6,
    PermissionDenied = 7,
    ContextTooLarge = 8,
    UnsupportedModel = 9,
    PlannerFailure = 10,
    Timeout = 11,
    Cancelled = 12,
    Unknown = 13,
}

/// Priority used by the inference scheduler.
#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum ExecutionPriority {
    Interactive = 0,
    Foreground = 1,
    Background = 2,
    Maintenance = 3,
}

/// Immutable request entering the planner.
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct InferenceRequest {
    pub capability: CapabilityId,
    pub prompt: String,
    pub model_id: Option<String>,
    pub priority: ExecutionPriority,
}

/// Immutable backend-neutral intermediate representation.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
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
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
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
#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
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

    #[test]
    fn stable_ids_are_append_only() {
        assert_eq!(RuntimeId::Mock as u8, 0);
        assert_eq!(RuntimeId::LiteRt as u8, 1);
        assert_eq!(RuntimeId::LlamaCpp as u8, 2);
        assert_eq!(RuntimeId::Mlx as u8, 3);
        assert_eq!(RuntimeId::Onnx as u8, 4);
    }

    #[test]
    fn v1_request_matches_golden_serialization() {
        let request = InferenceRequest {
            capability: CapabilityId::Chat,
            prompt: "hello".into(),
            model_id: Some("model-v1".into()),
            priority: ExecutionPriority::Interactive,
        };
        let actual = serde_json::to_string(&request).expect("serialize v1 request");
        let expected = include_str!("../../tests/fixtures/runtime_api_v1_request.json").trim();
        assert_eq!(actual, expected);
    }
}

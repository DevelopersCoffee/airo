//! Pure, synchronous planner for Runtime API v1.

use super::runtime_contracts::{
    CapabilityId, ComputeAccelerator, InferenceIr, InferenceRequest, RuntimeId, RuntimeRegistry,
};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct DeviceProfile {
    pub total_memory_mb: u64,
    pub available_memory_mb: u64,
    pub accelerator: ComputeAccelerator,
    pub thermal_limited: bool,
    pub battery_saver: bool,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ModelManifest {
    pub id: String,
    pub capability: CapabilityId,
    pub estimated_peak_memory_mb: u64,
    pub max_context_tokens: u32,
    pub preferred_runtime: Option<RuntimeId>,
    pub preferred_accelerator: Option<ComputeAccelerator>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PlannerConfig {
    pub default_context_tokens: u32,
    pub minimum_context_tokens: u32,
    pub default_output_tokens: u32,
    pub minimum_output_tokens: u32,
    pub batch_size: u32,
    pub temperature: f64,
    pub top_k: u32,
    pub top_p: f64,
}

impl Default for PlannerConfig {
    fn default() -> Self {
        Self {
            default_context_tokens: 2048,
            minimum_context_tokens: 256,
            default_output_tokens: 256,
            minimum_output_tokens: 32,
            batch_size: 1,
            temperature: 0.2,
            top_k: 40,
            top_p: 0.9,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ExecutionPlan {
    pub ir: InferenceIr,
    pub batch_size: u32,
    pub thermal_limited: bool,
    pub battery_saver: bool,
}

#[repr(u8)]
#[derive(Clone, Copy, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum PlannerErrorCode {
    NoCapabilityMatch = 0,
    NoRuntimeAvailable = 1,
    InsufficientMemory = 2,
    UnsupportedAccelerator = 3,
    InvalidConfiguration = 4,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PlannerResult {
    pub plan: Option<ExecutionPlan>,
    pub error: Option<PlannerErrorCode>,
}

/// Pure planner entry point. It performs no I/O, platform calls, or runtime
/// calls; all observations arrive as arguments.
pub fn plan_inference(
    request: InferenceRequest,
    device: DeviceProfile,
    models: Vec<ModelManifest>,
    registry: RuntimeRegistry,
    config: PlannerConfig,
) -> PlannerResult {
    if registry.contract_version != super::runtime_contracts::RuntimeApiVersion::V1
        || config.minimum_context_tokens == 0
        || config.minimum_output_tokens == 0
        || config.minimum_context_tokens > config.default_context_tokens
        || config.minimum_output_tokens > config.default_output_tokens
        || config.batch_size == 0
        || !(0.0..=2.0).contains(&config.temperature)
        || !(0.0..=1.0).contains(&config.top_p)
    {
        return PlannerResult {
            plan: None,
            error: Some(PlannerErrorCode::InvalidConfiguration),
        };
    }

    let mut candidates: Vec<&ModelManifest> = models
        .iter()
        .filter(|model| model.capability == request.capability)
        .collect();
    if let Some(requested_id) = request.model_id.as_deref() {
        candidates.retain(|model| model.id == requested_id);
    }
    candidates.sort_by(|left, right| left.id.cmp(&right.id));

    if candidates.is_empty() {
        return failure(PlannerErrorCode::NoCapabilityMatch);
    }

    if registry.runtimes.is_empty() {
        return failure(PlannerErrorCode::NoRuntimeAvailable);
    }

    // Candidates are ordered deterministically. A model that cannot fit after
    // context/output reduction is skipped, allowing an installed smaller model
    // to satisfy the same capability without hardcoding model names.
    for model in candidates {
        let runtime = model
            .preferred_runtime
            .filter(|runtime| registry.runtimes.contains(runtime))
            .or_else(|| registry.runtimes.first().copied())
            .expect("registry emptiness checked above");
        let accelerator = model.preferred_accelerator.unwrap_or(device.accelerator);
        let mut context_tokens = config.default_context_tokens.min(model.max_context_tokens);
        let mut output_tokens = config.default_output_tokens;

        while device.available_memory_mb < model.estimated_peak_memory_mb
            && context_tokens > config.minimum_context_tokens
        {
            context_tokens = (context_tokens / 2).max(config.minimum_context_tokens);
            output_tokens = (output_tokens / 2).max(config.minimum_output_tokens);
        }
        if device.available_memory_mb < model.estimated_peak_memory_mb {
            continue;
        }

        return PlannerResult {
            plan: Some(ExecutionPlan {
                ir: InferenceIr {
                    runtime,
                    accelerator,
                    model_id: model.id.clone(),
                    context_tokens,
                    output_tokens,
                    temperature: config.temperature,
                    top_k: config.top_k,
                    top_p: config.top_p,
                    priority: request.priority,
                },
                batch_size: if device.thermal_limited || device.battery_saver {
                    1
                } else {
                    config.batch_size
                },
                thermal_limited: device.thermal_limited,
                battery_saver: device.battery_saver,
            }),
            error: None,
        };
    }

    failure(PlannerErrorCode::InsufficientMemory)
}

fn failure(error: PlannerErrorCode) -> PlannerResult {
    PlannerResult {
        plan: None,
        error: Some(error),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::runtime_contracts::ExecutionPriority;

    fn request() -> InferenceRequest {
        InferenceRequest {
            capability: CapabilityId::Chat,
            prompt: "hello".into(),
            model_id: None,
            priority: ExecutionPriority::Interactive,
        }
    }

    fn device(available_memory_mb: u64) -> DeviceProfile {
        DeviceProfile {
            total_memory_mb: 12_000,
            available_memory_mb,
            accelerator: ComputeAccelerator::Cpu,
            thermal_limited: false,
            battery_saver: false,
        }
    }

    fn model(id: &str, memory_mb: u64) -> ModelManifest {
        ModelManifest {
            id: id.into(),
            capability: CapabilityId::Chat,
            estimated_peak_memory_mb: memory_mb,
            max_context_tokens: 4096,
            preferred_runtime: Some(RuntimeId::Mock),
            preferred_accelerator: Some(ComputeAccelerator::Cpu),
        }
    }

    fn registry() -> RuntimeRegistry {
        RuntimeRegistry {
            contract_version: super::super::runtime_contracts::RuntimeApiVersion::V1,
            runtimes: vec![RuntimeId::Mock],
        }
    }

    #[test]
    fn selection_is_deterministic_and_prefers_lexical_tie_breaking() {
        let result = plan_inference(
            request(),
            device(8_000),
            vec![model("z-model", 2_000), model("a-model", 2_000)],
            registry(),
            PlannerConfig::default(),
        );
        assert_eq!(result.plan.unwrap().ir.model_id, "a-model");
    }

    #[test]
    fn reduces_context_before_rejecting_memory() {
        let result = plan_inference(
            request(),
            device(2_000),
            vec![model("small", 2_500)],
            registry(),
            PlannerConfig {
                default_context_tokens: 4096,
                minimum_context_tokens: 512,
                ..PlannerConfig::default()
            },
        );
        assert_eq!(result.error, Some(PlannerErrorCode::InsufficientMemory));
    }

    #[test]
    fn rejects_missing_capability_and_runtime() {
        let mut no_runtime = registry();
        no_runtime.runtimes.clear();
        assert_eq!(
            plan_inference(
                request(),
                device(8_000),
                vec![model("chat", 1_000)],
                no_runtime,
                PlannerConfig::default()
            )
            .error,
            Some(PlannerErrorCode::NoRuntimeAvailable)
        );

        let mut non_chat = model("vision", 1_000);
        non_chat.capability = CapabilityId::Vision;
        assert_eq!(
            plan_inference(
                request(),
                device(8_000),
                vec![non_chat],
                registry(),
                PlannerConfig::default()
            )
            .error,
            Some(PlannerErrorCode::NoCapabilityMatch)
        );
    }

    #[test]
    fn selects_requested_model_and_skips_models_that_do_not_fit() {
        let mut requested = request();
        requested.model_id = Some("small".into());
        let result = plan_inference(
            requested,
            device(2_000),
            vec![model("large", 3_000), model("small", 1_000)],
            registry(),
            PlannerConfig::default(),
        );
        assert_eq!(result.plan.unwrap().ir.model_id, "small");

        let result = plan_inference(
            InferenceRequest {
                model_id: None,
                ..request()
            },
            device(2_000),
            vec![model("large", 3_000), model("small", 1_000)],
            registry(),
            PlannerConfig::default(),
        );
        assert_eq!(result.plan.unwrap().ir.model_id, "small");
    }

    #[test]
    fn rejects_invalid_planner_configuration() {
        let result = plan_inference(
            request(),
            device(8_000),
            vec![model("chat", 1_000)],
            registry(),
            PlannerConfig {
                batch_size: 0,
                ..PlannerConfig::default()
            },
        );
        assert_eq!(result.error, Some(PlannerErrorCode::InvalidConfiguration));
    }

    #[test]
    fn constrains_batch_size_when_thermally_limited_or_on_battery_saver() {
        let result = plan_inference(
            request(),
            DeviceProfile {
                thermal_limited: true,
                battery_saver: false,
                ..device(8_000)
            },
            vec![model("chat", 1_000)],
            registry(),
            PlannerConfig {
                batch_size: 8,
                ..PlannerConfig::default()
            },
        );
        assert_eq!(result.plan.unwrap().batch_size, 1);
    }
}

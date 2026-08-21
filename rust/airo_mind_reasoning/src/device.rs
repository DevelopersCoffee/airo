//! Device constraints injected by the caller. No model names, no OS checks.

use serde::{Deserialize, Serialize};

use crate::level::ReasoningLevel;

/// What this device is willing to spend on one reasoning call.
///
/// Filled from `LlmDeviceTier` / host probes in Dart. The engine never
/// inspects `cfg(target_os)`.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DeviceInferenceProfile {
    pub available_memory_mb: u32,
    pub gpu_available: bool,
    pub npu_available: bool,
    pub thermal_constrained: bool,
    pub battery_constrained: bool,
    /// Hard ceiling after policy. `Deep` on a 1B phone is a caller bug.
    pub max_reasoning_level: ReasoningLevel,
}

impl DeviceInferenceProfile {
    pub fn unconstrained() -> Self {
        Self {
            available_memory_mb: 8192,
            gpu_available: true,
            npu_available: false,
            thermal_constrained: false,
            battery_constrained: false,
            max_reasoning_level: ReasoningLevel::Deep,
        }
    }

    pub fn small_phone() -> Self {
        Self {
            available_memory_mb: 2048,
            gpu_available: false,
            npu_available: false,
            thermal_constrained: false,
            battery_constrained: false,
            max_reasoning_level: ReasoningLevel::Standard,
        }
    }

    pub fn should_downgrade(&self) -> bool {
        self.thermal_constrained || self.battery_constrained
    }
}

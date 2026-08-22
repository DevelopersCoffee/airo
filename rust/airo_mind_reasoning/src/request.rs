use serde::{Deserialize, Serialize};

use crate::context::ReasoningContext;
use crate::device::DeviceInferenceProfile;
use crate::intent::ClassifiedIntent;
use crate::level::ReasoningLevel;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ToolDefinition {
    pub name: String,
    pub description: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ReasoningRequest {
    pub user_query: String,
    pub intent: ClassifiedIntent,
    pub context: ReasoningContext,
    pub available_tools: Vec<ToolDefinition>,
    pub requested_level: Option<ReasoningLevel>,
    pub device: DeviceInferenceProfile,
    /// When true, run a constrained capability extract before the legacy
    /// adapter. Host tests and fixtures keep this off so one scripted
    /// generate is still the answer envelope.
    pub run_analyzer: bool,
}

impl ReasoningRequest {
    pub fn fixture(kind: &str, complexity: f32) -> Self {
        Self {
            user_query: String::new(),
            intent: ClassifiedIntent::new(kind, complexity),
            context: ReasoningContext::default(),
            available_tools: Vec::new(),
            requested_level: None,
            device: DeviceInferenceProfile::unconstrained(),
            run_analyzer: false,
        }
    }
}

//! Versioned ClassifiedIntent. This is the routing contract, not a Dart enum.

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

pub const SCHEMA_VERSION: &str = "1.0";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IntentStatus {
    Classified,
    NeedsClarification,
    Rejected,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum IntentSource {
    Analyzer,
    LegacyFallback,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Confidence {
    pub overall: f32,
    pub intent: f32,
    pub entities: f32,
    pub routing: f32,
    pub requirement: f32,
}

impl Confidence {
    pub fn uniform(value: f32) -> Self {
        let v = value.clamp(0.0, 1.0);
        Self {
            overall: v,
            intent: v,
            entities: v,
            routing: v,
            requirement: v,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ActionReadiness {
    pub ready: bool,
    pub requires_confirmation: bool,
    pub requires_clarification: bool,
}

impl ActionReadiness {
    pub fn execute() -> Self {
        Self {
            ready: true,
            requires_confirmation: false,
            requires_clarification: false,
        }
    }

    pub fn clarify() -> Self {
        Self {
            ready: false,
            requires_confirmation: false,
            requires_clarification: true,
        }
    }
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct Ambiguity {
    pub is_ambiguous: bool,
    pub kind: Option<String>,
    pub candidates: Vec<String>,
    pub reason: Option<String>,
    pub clarification: Option<String>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Requirements {
    pub document: bool,
    pub retrieval: bool,
    pub reasoning: bool,
    pub web: bool,
    pub memory: bool,
    pub tools: bool,
    pub requires_user_input: bool,
    pub missing_information: Vec<String>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct IntentContext {
    pub document_ids: Vec<String>,
    pub conversation_id: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ClassifiedIntent {
    pub schema_version: String,
    pub status: IntentStatus,
    pub domain: String,
    pub intent: String,
    pub action: String,
    pub capability: String,
    pub entities: BTreeMap<String, String>,
    pub constraints: BTreeMap<String, String>,
    pub context: IntentContext,
    pub requirements: Requirements,
    pub confidence: Confidence,
    pub action_readiness: ActionReadiness,
    pub ambiguity: Ambiguity,
    pub model_profile: String,
    /// Compatibility wire for today's FRB `reason()` request.
    pub kind: String,
    pub complexity: f32,
    pub source: IntentSource,
}

impl ClassifiedIntent {
    /// Legacy hydrate. Prefer [`crate::classify`] for the full gate.
    pub fn new(kind: impl Into<String>, complexity: f32) -> Self {
        crate::legacy::from_legacy(&kind.into(), complexity, "")
    }

    pub fn is_direct_lookup(&self) -> bool {
        crate::capability::CapabilityRegistry::builtin()
            .get(&self.capability)
            .map(|cap| cap.direct_lookup)
            .unwrap_or(false)
    }
}

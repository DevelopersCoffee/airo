use serde::{Deserialize, Serialize};

use crate::level::ReasoningLevel;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ToolCall {
    pub name: String,
    pub arguments_json: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ReasoningResult {
    pub answer: String,
    /// Short user-facing basis. Never a private scratchpad.
    pub reasoning_summary: Option<String>,
    pub level: ReasoningLevel,
    pub confidence: Option<f32>,
    pub tool_calls: Vec<ToolCall>,
}

impl ReasoningResult {
    pub fn answer_only(answer: impl Into<String>, level: ReasoningLevel) -> Self {
        Self {
            answer: answer.into(),
            reasoning_summary: None,
            level,
            confidence: None,
            tool_calls: Vec::new(),
        }
    }
}

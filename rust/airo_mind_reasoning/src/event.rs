use serde::{Deserialize, Serialize};

use crate::result::ReasoningResult;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReasoningStage {
    Understanding,
    RetrievingContext,
    UsingTool,
    Analyzing,
    Validating,
    ComposingAnswer,
    Complete,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ReasoningEvent {
    Started,
    StageChanged { stage: ReasoningStage },
    Progress { message: String },
    ToolStarted { tool: String },
    ToolCompleted { tool: String },
    AnswerDelta { text: String },
    Completed { result: ReasoningResult },
    Error { message: String },
}

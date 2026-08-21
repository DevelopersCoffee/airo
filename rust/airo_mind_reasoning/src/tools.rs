//! Tool execution seam. The engine owns the loop; the host owns the verbs.

use crate::error::ReasoningError;
use crate::result::ToolCall;

/// Hard stop for one `reason()` call. Counts executed tools, not LLM rounds.
pub const MAX_TOOL_ITERATIONS: u32 = 5;

pub trait ToolExecutor {
    fn execute(&self, call: &ToolCall) -> Result<String, ReasoningError>;
}

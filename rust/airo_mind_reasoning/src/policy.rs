//! Deterministic first policy. Not keyword matching on the user query.

use crate::level::ReasoningLevel;
use crate::request::ReasoningRequest;

pub trait ReasoningPolicy {
    fn evaluate(&self, request: &ReasoningRequest) -> ReasoningLevel;
}

#[derive(Clone, Copy, Debug, Default)]
pub struct HeuristicReasoningPolicy;

impl ReasoningPolicy for HeuristicReasoningPolicy {
    fn evaluate(&self, request: &ReasoningRequest) -> ReasoningLevel {
        let mut level = if let Some(requested) = request.requested_level {
            requested
        } else {
            score_intent(request)
        };

        if request.device.should_downgrade() {
            level = level.downgrade();
        }
        level.clamp_to(request.device.max_reasoning_level)
    }
}

fn score_intent(request: &ReasoningRequest) -> ReasoningLevel {
    if request.intent.is_direct_lookup() {
        return ReasoningLevel::None;
    }

    let mut level = match request.intent.complexity {
        c if c >= 0.85 => ReasoningLevel::Deep,
        c if c >= 0.55 => ReasoningLevel::Standard,
        c if c >= 0.25 => ReasoningLevel::Light,
        _ => ReasoningLevel::None,
    };

    if (request.context.source_count() >= 3 || request.available_tools.len() >= 3)
        && level < ReasoningLevel::Deep
    {
        level = match level {
            ReasoningLevel::None => ReasoningLevel::Light,
            ReasoningLevel::Light => ReasoningLevel::Standard,
            ReasoningLevel::Standard => ReasoningLevel::Deep,
            ReasoningLevel::Deep => ReasoningLevel::Deep,
        };
    }
    level
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::context::{ContextItem, ReasoningContext};
    use crate::device::DeviceInferenceProfile;
    use crate::request::{ReasoningRequest, ToolDefinition};

    fn item(source: &str) -> ContextItem {
        ContextItem {
            source: source.into(),
            text: "x".into(),
        }
    }

    #[test]
    fn calendar_retrieval_is_none() {
        let req = ReasoningRequest::fixture("calendar_retrieval", 0.1);
        assert_eq!(
            HeuristicReasoningPolicy.evaluate(&req),
            ReasoningLevel::None
        );
    }

    #[test]
    fn planning_high_complexity_is_deep() {
        let req = ReasoningRequest::fixture("planning", 0.88);
        assert_eq!(
            HeuristicReasoningPolicy.evaluate(&req),
            ReasoningLevel::Deep
        );
    }

    #[test]
    fn requested_level_wins_then_device_clamps() {
        let mut req = ReasoningRequest::fixture("planning", 0.88);
        req.requested_level = Some(ReasoningLevel::Deep);
        req.device = DeviceInferenceProfile::small_phone();
        assert_eq!(
            HeuristicReasoningPolicy.evaluate(&req),
            ReasoningLevel::Standard
        );
    }

    #[test]
    fn thermal_constraint_downgrades_deep() {
        let mut req = ReasoningRequest::fixture("planning", 0.88);
        req.device.thermal_constrained = true;
        assert_eq!(
            HeuristicReasoningPolicy.evaluate(&req),
            ReasoningLevel::Standard
        );
    }

    #[test]
    fn many_context_sources_bump_one_level() {
        let mut req = ReasoningRequest::fixture("question", 0.3);
        req.context = ReasoningContext {
            memories: vec![item("m")],
            documents: vec![item("d")],
            tool_results: vec![item("t")],
            history: vec![],
        };
        assert_eq!(
            HeuristicReasoningPolicy.evaluate(&req),
            ReasoningLevel::Standard
        );
    }

    #[test]
    fn tool_count_does_not_inspect_the_query_text() {
        let mut req = ReasoningRequest::fixture("question", 0.1);
        req.user_query = "plan my entire weekend based on meetings".into();
        req.available_tools = vec![
            ToolDefinition {
                name: "calendar".into(),
                description: String::new(),
            },
            ToolDefinition {
                name: "tasks".into(),
                description: String::new(),
            },
            ToolDefinition {
                name: "memory".into(),
                description: String::new(),
            },
        ];
        assert_eq!(
            HeuristicReasoningPolicy.evaluate(&req),
            ReasoningLevel::Light
        );
    }
}

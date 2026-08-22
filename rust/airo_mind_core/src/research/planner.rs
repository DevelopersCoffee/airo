//! Research planner — a DAG of questions, not a prompt.

use crate::research::interpreter::interpret;
use crate::research::request::ResearchRequest;
use crate::research::strategy::strategy_for;

/// Breadth explores a subject; depth follows one subject into a facet.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PlanNodeKind {
    Breadth,
    Depth,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResearchPlanNode {
    pub id: String,
    pub question: String,
    pub kind: PlanNodeKind,
    /// Node ids that must complete first. Empty means the scheduler may start immediately.
    pub depends_on: Vec<String>,
}

/// Deterministic research DAG derived from intent + strategy. No model call.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResearchPlan {
    pub root_question: String,
    pub strategy_id: String,
    pub nodes: Vec<ResearchPlanNode>,
}

impl ResearchPlan {
    pub fn from_request(request: &ResearchRequest) -> Self {
        let goal = interpret(request);
        strategy_for(goal.intent).create_plan(request, &goal)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::request::{ResearchMode, ResearchRequest};

    #[test]
    fn a_compare_question_becomes_per_subject_branches() {
        let mut request =
            ResearchRequest::new("Compare Qwen, Llama and Gemma for offline mobile AI in 2026.");
        request.mode = ResearchMode::Deep;
        let plan = ResearchPlan::from_request(&request);
        let questions: Vec<_> = plan.nodes.iter().map(|n| n.question.as_str()).collect();
        assert!(questions.iter().any(|q| q.contains("Qwen")));
        assert!(questions.iter().any(|q| q.contains("Llama")));
        assert!(questions.iter().any(|q| q.contains("Gemma")));
        assert_eq!(plan.strategy_id, "comparison");
        assert!(
            plan.nodes.iter().any(|n| n.kind == PlanNodeKind::Depth),
            "deep comparison must add dependent depth facets"
        );
        assert!(plan.nodes.iter().any(|n| !n.depends_on.is_empty()));
        assert!(plan.nodes.len() > 3);
        assert!(plan.nodes.len() <= 16);
    }

    #[test]
    fn quick_mode_stays_shallow() {
        let mut request = ResearchRequest::new("Compare Qwen, Llama and Gemma");
        request.mode = ResearchMode::Quick;
        let plan = ResearchPlan::from_request(&request);
        assert!(plan.nodes.len() <= 3);
        assert!(plan.nodes.iter().all(|n| n.kind == PlanNodeKind::Breadth));
    }
}

//! Strategy is selected from intent. There is no universal research algorithm.

use crate::research::interpreter::{
    split_subjects, InterpretedGoal, ResearchIntent,
};
use crate::research::planner::{PlanNodeKind, ResearchPlan, ResearchPlanNode};
use crate::research::request::{ResearchMode, ResearchRequest};

pub trait ResearchStrategy {
    fn id(&self) -> &'static str;
    fn create_plan(&self, request: &ResearchRequest, goal: &InterpretedGoal) -> ResearchPlan;
}

pub fn strategy_for(intent: ResearchIntent) -> &'static dyn ResearchStrategy {
    match intent {
        ResearchIntent::Comparison => &ComparisonStrategy,
        ResearchIntent::DecisionSupport => &DecisionStrategy,
        ResearchIntent::FactFinding => &FactFindingStrategy,
        ResearchIntent::AcademicResearch => &AcademicStrategy,
        ResearchIntent::Investigation => &InvestigationStrategy,
        _ => &TechnicalStrategy,
    }
}

fn cap_for(mode: ResearchMode) -> usize {
    match mode {
        ResearchMode::Quick => 3,
        ResearchMode::Standard => 8,
        ResearchMode::Deep => 16,
        ResearchMode::Exhaustive => 32,
    }
}

fn push(
    nodes: &mut Vec<ResearchPlanNode>,
    id: String,
    question: String,
    kind: PlanNodeKind,
    depends_on: Vec<String>,
) {
    nodes.push(ResearchPlanNode {
        id,
        question,
        kind,
        depends_on,
    });
}

struct ComparisonStrategy;
impl ResearchStrategy for ComparisonStrategy {
    fn id(&self) -> &'static str {
        "comparison"
    }

    fn create_plan(&self, request: &ResearchRequest, goal: &InterpretedGoal) -> ResearchPlan {
        let cap = cap_for(request.mode);
        let subjects = split_subjects(&goal.topic);
        let mut nodes = Vec::new();
        let mut subject_ids = Vec::new();
        for (index, subject) in subjects.iter().enumerate() {
            let id = format!("s{index}");
            push(
                &mut nodes,
                id.clone(),
                subject.clone(),
                PlanNodeKind::Breadth,
                vec![],
            );
            subject_ids.push(id);
            if !matches!(request.mode, ResearchMode::Quick) {
                for (facet_i, facet) in goal.dimensions.iter().take(4).enumerate() {
                    push(
                        &mut nodes,
                        format!("s{index}d{facet_i}"),
                        format!("{subject} {facet}"),
                        PlanNodeKind::Depth,
                        vec![format!("s{index}")],
                    );
                }
            }
        }
        if !matches!(request.mode, ResearchMode::Quick) {
            push(
                &mut nodes,
                "counter".to_string(),
                format!("{} limitations and contradictory evidence", goal.topic),
                PlanNodeKind::Depth,
                subject_ids,
            );
        }
        nodes.truncate(cap);
        ResearchPlan {
            root_question: goal.topic.clone(),
            strategy_id: self.id().to_string(),
            nodes,
        }
    }
}

struct DecisionStrategy;
impl ResearchStrategy for DecisionStrategy {
    fn id(&self) -> &'static str {
        "decision"
    }

    fn create_plan(&self, request: &ResearchRequest, goal: &InterpretedGoal) -> ResearchPlan {
        let cap = cap_for(request.mode);
        let mut nodes = Vec::new();
        push(
            &mut nodes,
            "root".into(),
            goal.topic.clone(),
            PlanNodeKind::Breadth,
            vec![],
        );
        if !matches!(request.mode, ResearchMode::Quick) {
            for (i, dim) in goal.dimensions.iter().enumerate() {
                push(
                    &mut nodes,
                    format!("d{i}"),
                    format!("{} — {dim}", goal.topic),
                    PlanNodeKind::Depth,
                    vec!["root".into()],
                );
            }
            push(
                &mut nodes,
                "counter".into(),
                format!("reasons not to choose: {}", goal.topic),
                PlanNodeKind::Depth,
                vec!["root".into()],
            );
        }
        nodes.truncate(cap);
        ResearchPlan {
            root_question: goal.topic.clone(),
            strategy_id: self.id().to_string(),
            nodes,
        }
    }
}

struct FactFindingStrategy;
impl ResearchStrategy for FactFindingStrategy {
    fn id(&self) -> &'static str {
        "fact_finding"
    }

    fn create_plan(&self, request: &ResearchRequest, goal: &InterpretedGoal) -> ResearchPlan {
        let mut nodes = vec![ResearchPlanNode {
            id: "root".into(),
            question: goal.topic.clone(),
            kind: PlanNodeKind::Breadth,
            depends_on: vec![],
        }];
        if !matches!(request.mode, ResearchMode::Quick) {
            nodes.push(ResearchPlanNode {
                id: "official".into(),
                question: format!("{} official documentation", goal.topic),
                kind: PlanNodeKind::Depth,
                depends_on: vec!["root".into()],
            });
        }
        nodes.truncate(cap_for(request.mode));
        ResearchPlan {
            root_question: goal.topic.clone(),
            strategy_id: self.id().to_string(),
            nodes,
        }
    }
}

struct TechnicalStrategy;
impl ResearchStrategy for TechnicalStrategy {
    fn id(&self) -> &'static str {
        "technical"
    }

    fn create_plan(&self, request: &ResearchRequest, goal: &InterpretedGoal) -> ResearchPlan {
        let mut plan = DecisionStrategy.create_plan(request, goal);
        plan.strategy_id = self.id().to_string();
        plan
    }
}

struct AcademicStrategy;
impl ResearchStrategy for AcademicStrategy {
    fn id(&self) -> &'static str {
        "academic"
    }

    fn create_plan(&self, request: &ResearchRequest, goal: &InterpretedGoal) -> ResearchPlan {
        let mut plan = FactFindingStrategy.create_plan(request, goal);
        plan.strategy_id = self.id().to_string();
        plan
    }
}

struct InvestigationStrategy;
impl ResearchStrategy for InvestigationStrategy {
    fn id(&self) -> &'static str {
        "investigation"
    }

    fn create_plan(&self, request: &ResearchRequest, goal: &InterpretedGoal) -> ResearchPlan {
        let mut plan = DecisionStrategy.create_plan(request, goal);
        plan.strategy_id = self.id().to_string();
        plan
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::interpreter::interpret;
    use crate::research::request::ResearchRequest;

    #[test]
    fn comparison_and_fact_finding_are_different_strategies() {
        let compare = interpret(&ResearchRequest::new("Compare Qwen vs Llama"));
        let fact = interpret(&ResearchRequest::new("What is Qwen?"));
        assert_eq!(strategy_for(compare.intent).id(), "comparison");
        assert_eq!(strategy_for(fact.intent).id(), "fact_finding");
    }
}

//! Deterministic failure classification. No LLM in this path.

use crate::ids::{FailureMode, InvariantId, RecoveryAction, RuntimeFailure};
use crate::observation::PipelineObservation;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Severity {
    Info,
    Degraded,
    Failed,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Classification {
    pub primary: FailureMode,
    pub secondary: Vec<FailureMode>,
    pub runtime_error: Option<RuntimeFailure>,
    pub invariant: InvariantId,
    pub first_repair: RecoveryAction,
    pub misrepair_risks: Vec<&'static str>,
    pub confidence: f32,
    pub severity: Severity,
    pub evidence: Vec<&'static str>,
}

pub struct FailureClassifier;

impl FailureClassifier {
    pub fn classify(observation: &PipelineObservation) -> Option<Classification> {
        let mut hits: Vec<Classification> = Vec::new();
        push_if_some(&mut hits, classify_bootstrap(observation));
        push_if_some(&mut hits, classify_runtime(observation));
        push_if_some(&mut hits, classify_reasoning(observation));
        push_if_some(&mut hits, classify_observability(observation));
        let mut iter = hits.into_iter();
        let mut primary = iter.next()?;
        for extra in iter {
            if extra.primary != primary.primary && !primary.secondary.contains(&extra.primary) {
                primary.secondary.push(extra.primary);
            }
            if primary.runtime_error.is_none() {
                primary.runtime_error = extra.runtime_error;
            }
        }
        Some(primary)
    }
}

fn push_if_some(out: &mut Vec<Classification>, item: Option<Classification>) {
    if let Some(item) = item {
        out.push(item);
    }
}

fn classify_bootstrap(o: &PipelineObservation) -> Option<Classification> {
    if o.circular_dependency {
        return Some(hit(
            FailureMode::Pm15DeploymentDeadlock,
            None,
            InvariantId::StateTransitionValid,
            RecoveryAction::Abort,
            &["circular_dependency"],
            &["retry_without_graph_check"],
            0.99,
            Severity::Failed,
        ));
    }
    if o.bootstrap_order_invalid {
        return Some(hit(
            FailureMode::Pm14BootstrapOrdering,
            None,
            InvariantId::StateTransitionValid,
            RecoveryAction::Abort,
            &["bootstrap_order_invalid"],
            &["start_engines_out_of_order"],
            0.99,
            Severity::Failed,
        ));
    }
    if o.adversarial_eval_failed {
        return Some(hit(
            FailureMode::Pm16PreDeployCollapse,
            None,
            InvariantId::CompletionVerified,
            RecoveryAction::Abort,
            &["adversarial_eval_failed"],
            &["ship_on_unit_tests_only"],
            0.95,
            Severity::Failed,
        ));
    }
    if o.shared_state_write_conflict {
        return Some(hit(
            FailureMode::Pm13MultiAgentChaos,
            None,
            InvariantId::StateTransitionValid,
            RecoveryAction::Abort,
            &["shared_state_write_conflict"],
            &["let_agents_share_writers"],
            0.93,
            Severity::Failed,
        ));
    }
    if o.recursion_depth >= o.recursion_limit {
        return Some(hit(
            FailureMode::Pm12PhilosophicalRecursion,
            None,
            InvariantId::StateTransitionValid,
            RecoveryAction::Abort,
            &["recursion_limit_reached"],
            &["increase_depth"],
            0.97,
            Severity::Failed,
        ));
    }
    None
}

fn classify_runtime(o: &PipelineObservation) -> Option<Classification> {
    if o.timeout {
        return Some(hit(
            FailureMode::Pm06LogicCollapse,
            Some(RuntimeFailure::R08Timeout),
            InvariantId::StateTransitionValid,
            RecoveryAction::Abort,
            &["timeout"],
            &["raise_timeout_blindly"],
            0.98,
            Severity::Failed,
        ));
    }
    if o.resource_pressure {
        return Some(hit(
            FailureMode::Pm09ContextCollapse,
            Some(RuntimeFailure::R09DeviceResourcePressure),
            InvariantId::ContextWithinBudget,
            RecoveryAction::Abort,
            &["device_resource_pressure"],
            &["increase_context_length"],
            0.96,
            Severity::Failed,
        ));
    }
    if o.context_compile_failed {
        return Some(hit(
            FailureMode::Pm09ContextCollapse,
            Some(RuntimeFailure::R01ContextCompiler),
            InvariantId::ContextWithinBudget,
            RecoveryAction::RebuildContext,
            &["context_compiler_failure"],
            &["increase_prompt_size"],
            0.94,
            Severity::Failed,
        ));
    }
    if o.model_adapter_failed {
        return Some(hit(
            FailureMode::Pm08BlackBox,
            Some(RuntimeFailure::R07ModelAdapter),
            InvariantId::StateTransitionValid,
            RecoveryAction::Retry,
            &["model_adapter_failure"],
            &["switch_model"],
            0.9,
            Severity::Failed,
        ));
    }
    if o.tool_claimed && !o.tool_executed {
        return Some(hit(
            FailureMode::Pm04ConfidentNonsense,
            Some(RuntimeFailure::R03ToolAuthorization),
            InvariantId::ToolExecutionAuthority,
            RecoveryAction::Abort,
            &["tool_claimed_without_execution"],
            &["trust_model_tool_claim"],
            0.99,
            Severity::Failed,
        ));
    }
    if !o.schema_valid {
        return Some(hit(
            FailureMode::Pm11SymbolicCollapse,
            Some(RuntimeFailure::R04SchemaViolation),
            InvariantId::OutputSchemaValid,
            RecoveryAction::Retry,
            &["schema_invalid"],
            &["ask_model_to_fix_prose"],
            0.95,
            Severity::Failed,
        ));
    }
    if o.state_skipped_replan {
        return Some(hit(
            FailureMode::Pm06LogicCollapse,
            Some(RuntimeFailure::R05StateMachineViolation),
            InvariantId::StateTransitionValid,
            RecoveryAction::Replan,
            &["silent_plan_rewrite"],
            &["continue_after_failure"],
            0.97,
            Severity::Failed,
        ));
    }
    if o.completion_claimed && !o.completion_criteria_met {
        return Some(hit(
            FailureMode::Pm06LogicCollapse,
            Some(RuntimeFailure::R06VerificationFailure),
            InvariantId::CompletionVerified,
            RecoveryAction::Abort,
            &["unverified_completion_claim"],
            &["trust_model_done"],
            0.98,
            Severity::Failed,
        ));
    }
    None
}

fn classify_reasoning(o: &PipelineObservation) -> Option<Classification> {
    if o.grounding_failed {
        return Some(hit(
            FailureMode::Pm01HallucinationChunkDrift,
            None,
            InvariantId::ModelResultGrounded,
            RecoveryAction::ReRetrieve,
            &["grounding_failed"],
            &["increase_prompt_size"],
            0.92,
            Severity::Failed,
        ));
    }
    if let (Some(retrieval), Some(semantic)) = (o.retrieval_score, o.semantic_score) {
        if retrieval >= 0.8 && semantic < 0.5 {
            return Some(hit(
                FailureMode::Pm05SemanticEmbeddingMismatch,
                None,
                InvariantId::RetrievalSemanticAlignment,
                RecoveryAction::Rerank,
                &["retrieval_score_high", "semantic_score_low"],
                &["increase_prompt_size", "switch_model"],
                0.91,
                Severity::Failed,
            ));
        }
    }
    if o.memory_conflict || o.stale_memory {
        return Some(hit(
            FailureMode::Pm07MemoryFailure,
            Some(RuntimeFailure::R02MemoryConflict),
            InvariantId::MemoryConsistency,
            RecoveryAction::RebuildContext,
            &["memory_conflict"],
            &["inject_all_memory"],
            0.9,
            Severity::Degraded,
        ));
    }
    if o.goal_step_drift {
        return Some(hit(
            FailureMode::Pm03LongChainDrift,
            None,
            InvariantId::GoalStateConsistent,
            RecoveryAction::Replan,
            &["goal_step_drift"],
            &["continue_without_checkpoint"],
            0.88,
            Severity::Failed,
        ));
    }
    if o.intent_confidence.unwrap_or(1.0) < 0.5 {
        let repair = if o.intent_confidence.unwrap_or(0.0) < 0.35 {
            RecoveryAction::AskUser
        } else {
            RecoveryAction::ReinterpretIntent
        };
        return Some(hit(
            FailureMode::Pm02InterpretationCollapse,
            None,
            InvariantId::GoalStateConsistent,
            repair,
            &["low_intent_confidence"],
            &["guess_and_continue"],
            0.86,
            Severity::Degraded,
        ));
    }
    if o.answer_fluent && !o.evidence_present {
        return Some(hit(
            FailureMode::Pm04ConfidentNonsense,
            None,
            InvariantId::ModelResultGrounded,
            RecoveryAction::ValidateWithTool,
            &["fluent_without_evidence"],
            &["treat_fluency_as_confidence"],
            0.84,
            Severity::Failed,
        ));
    }
    if o.context_token_pressure || o.context_redundancy {
        return Some(hit(
            FailureMode::Pm09ContextCollapse,
            None,
            InvariantId::ContextWithinBudget,
            RecoveryAction::RebuildContext,
            &["context_health_low"],
            &["increase_context_length"],
            0.8,
            Severity::Degraded,
        ));
    }
    if o.creative_diversity.unwrap_or(1.0) < 0.15 && o.answer_fluent {
        return Some(hit(
            FailureMode::Pm10CreativeFreeze,
            None,
            InvariantId::GoalStateConsistent,
            RecoveryAction::Retry,
            &["low_diversity"],
            &["expand_prompt_boilerplate"],
            0.7,
            Severity::Degraded,
        ));
    }
    if o.symbolic_task && o.answer_fluent {
        return Some(hit(
            FailureMode::Pm11SymbolicCollapse,
            None,
            InvariantId::OutputSchemaValid,
            RecoveryAction::ValidateWithTool,
            &["llm_used_for_symbolic_work"],
            &["ask_model_to_do_math"],
            0.82,
            Severity::Degraded,
        ));
    }
    None
}

fn classify_observability(o: &PipelineObservation) -> Option<Classification> {
    if !o.checkpoints_recorded {
        return Some(hit(
            FailureMode::Pm08BlackBox,
            None,
            InvariantId::StateTransitionValid,
            RecoveryAction::Abort,
            &["no_execution_trace"],
            &["add_more_logging_of_prompts"],
            0.99,
            Severity::Failed,
        ));
    }
    None
}

#[allow(clippy::too_many_arguments)]
fn hit(
    primary: FailureMode,
    runtime_error: Option<RuntimeFailure>,
    invariant: InvariantId,
    first_repair: RecoveryAction,
    evidence: &'static [&'static str],
    misrepair_risks: &'static [&'static str],
    confidence: f32,
    severity: Severity,
) -> Classification {
    Classification {
        primary,
        secondary: Vec::new(),
        runtime_error,
        invariant,
        first_repair,
        misrepair_risks: misrepair_risks.to_vec(),
        confidence,
        severity,
        evidence: evidence.to_vec(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn healthy_observation_is_not_a_failure() {
        assert!(FailureClassifier::classify(&PipelineObservation::healthy()).is_none());
    }

    #[test]
    fn ungrounded_maps_to_pm01() {
        let mut o = PipelineObservation::healthy();
        o.grounding_failed = true;
        let c = FailureClassifier::classify(&o).unwrap();
        assert_eq!(c.primary, FailureMode::Pm01HallucinationChunkDrift);
        assert_eq!(c.invariant, InvariantId::ModelResultGrounded);
        assert_eq!(c.first_repair, RecoveryAction::ReRetrieve);
    }
}

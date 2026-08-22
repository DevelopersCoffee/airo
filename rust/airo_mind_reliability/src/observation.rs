//! Structured signals the classifier consumes. Callers map domain reports
//! into this shape; this crate never imports meeting or chat types.

/// Healthy defaults: checkpoints on, schema valid, no claims.
#[derive(Clone, Debug)]
pub struct PipelineObservation {
    pub checkpoints_recorded: bool,
    pub intent_confidence: Option<f32>,
    pub grounding_failed: bool,
    pub retrieval_score: Option<f32>,
    pub semantic_score: Option<f32>,
    pub memory_conflict: bool,
    pub stale_memory: bool,
    pub context_token_pressure: bool,
    pub context_redundancy: bool,
    pub context_compile_failed: bool,
    pub schema_valid: bool,
    pub tool_claimed: bool,
    pub tool_executed: bool,
    pub state_skipped_replan: bool,
    pub goal_step_drift: bool,
    pub completion_claimed: bool,
    pub completion_criteria_met: bool,
    pub timeout: bool,
    pub resource_pressure: bool,
    pub recursion_depth: u32,
    pub recursion_limit: u32,
    pub shared_state_write_conflict: bool,
    pub bootstrap_order_invalid: bool,
    pub circular_dependency: bool,
    pub adversarial_eval_failed: bool,
    pub answer_fluent: bool,
    pub evidence_present: bool,
    pub evidence_strength: Option<f32>,
    pub creative_diversity: Option<f32>,
    pub symbolic_task: bool,
    pub model_adapter_failed: bool,
}

impl Default for PipelineObservation {
    fn default() -> Self {
        Self {
            checkpoints_recorded: true,
            intent_confidence: Some(1.0),
            grounding_failed: false,
            retrieval_score: None,
            semantic_score: None,
            memory_conflict: false,
            stale_memory: false,
            context_token_pressure: false,
            context_redundancy: false,
            context_compile_failed: false,
            schema_valid: true,
            tool_claimed: false,
            tool_executed: false,
            state_skipped_replan: false,
            goal_step_drift: false,
            completion_claimed: false,
            completion_criteria_met: false,
            timeout: false,
            resource_pressure: false,
            recursion_depth: 0,
            recursion_limit: 8,
            shared_state_write_conflict: false,
            bootstrap_order_invalid: false,
            circular_dependency: false,
            adversarial_eval_failed: false,
            answer_fluent: false,
            evidence_present: false,
            evidence_strength: None,
            creative_diversity: None,
            symbolic_task: false,
            model_adapter_failed: false,
        }
    }
}

impl PipelineObservation {
    pub fn healthy() -> Self {
        Self {
            evidence_present: true,
            evidence_strength: Some(1.0),
            completion_criteria_met: true,
            ..Self::default()
        }
    }

    /// Chat completion after the model adapter returns. Empty text is an
    /// unverified completion, not a successful turn.
    pub fn chat_completion(text: &str, engine_ok: bool) -> Self {
        let mut observation = Self::healthy();
        observation.checkpoints_recorded = true;
        if !engine_ok {
            observation.model_adapter_failed = true;
            observation.completion_criteria_met = false;
            return observation;
        }
        if text.trim().is_empty() {
            observation.completion_claimed = true;
            observation.completion_criteria_met = false;
            observation.evidence_present = false;
            observation.answer_fluent = false;
        }
        observation
    }
}

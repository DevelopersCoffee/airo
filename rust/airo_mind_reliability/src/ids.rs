//! Stable diagnostic identifiers.
//!
//! PM-01..PM-16 are WFGY Problem Map compatible **classification** IDs, not a
//! runtime dependency and not prompt instructions. AIRO-R01..R09 are Airo's
//! own runtime-implementation failures. Do not invent PM-17.

/// WFGY-compatible reasoning/pipeline failure family.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FailureMode {
    Pm01HallucinationChunkDrift,
    Pm02InterpretationCollapse,
    Pm03LongChainDrift,
    Pm04ConfidentNonsense,
    Pm05SemanticEmbeddingMismatch,
    Pm06LogicCollapse,
    Pm07MemoryFailure,
    Pm08BlackBox,
    Pm09ContextCollapse,
    Pm10CreativeFreeze,
    Pm11SymbolicCollapse,
    Pm12PhilosophicalRecursion,
    Pm13MultiAgentChaos,
    Pm14BootstrapOrdering,
    Pm15DeploymentDeadlock,
    Pm16PreDeployCollapse,
}

impl FailureMode {
    pub const ALL: [FailureMode; 16] = [
        Self::Pm01HallucinationChunkDrift,
        Self::Pm02InterpretationCollapse,
        Self::Pm03LongChainDrift,
        Self::Pm04ConfidentNonsense,
        Self::Pm05SemanticEmbeddingMismatch,
        Self::Pm06LogicCollapse,
        Self::Pm07MemoryFailure,
        Self::Pm08BlackBox,
        Self::Pm09ContextCollapse,
        Self::Pm10CreativeFreeze,
        Self::Pm11SymbolicCollapse,
        Self::Pm12PhilosophicalRecursion,
        Self::Pm13MultiAgentChaos,
        Self::Pm14BootstrapOrdering,
        Self::Pm15DeploymentDeadlock,
        Self::Pm16PreDeployCollapse,
    ];

    pub fn id(self) -> &'static str {
        match self {
            Self::Pm01HallucinationChunkDrift => "PM-01",
            Self::Pm02InterpretationCollapse => "PM-02",
            Self::Pm03LongChainDrift => "PM-03",
            Self::Pm04ConfidentNonsense => "PM-04",
            Self::Pm05SemanticEmbeddingMismatch => "PM-05",
            Self::Pm06LogicCollapse => "PM-06",
            Self::Pm07MemoryFailure => "PM-07",
            Self::Pm08BlackBox => "PM-08",
            Self::Pm09ContextCollapse => "PM-09",
            Self::Pm10CreativeFreeze => "PM-10",
            Self::Pm11SymbolicCollapse => "PM-11",
            Self::Pm12PhilosophicalRecursion => "PM-12",
            Self::Pm13MultiAgentChaos => "PM-13",
            Self::Pm14BootstrapOrdering => "PM-14",
            Self::Pm15DeploymentDeadlock => "PM-15",
            Self::Pm16PreDeployCollapse => "PM-16",
        }
    }

    pub fn from_id(id: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|mode| mode.id() == id)
    }
}

/// Airo runtime-implementation failures. Separate namespace from PM-*.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum RuntimeFailure {
    R01ContextCompiler,
    R02MemoryConflict,
    R03ToolAuthorization,
    R04SchemaViolation,
    R05StateMachineViolation,
    R06VerificationFailure,
    R07ModelAdapter,
    R08Timeout,
    R09DeviceResourcePressure,
}

impl RuntimeFailure {
    pub const ALL: [RuntimeFailure; 9] = [
        Self::R01ContextCompiler,
        Self::R02MemoryConflict,
        Self::R03ToolAuthorization,
        Self::R04SchemaViolation,
        Self::R05StateMachineViolation,
        Self::R06VerificationFailure,
        Self::R07ModelAdapter,
        Self::R08Timeout,
        Self::R09DeviceResourcePressure,
    ];

    pub fn id(self) -> &'static str {
        match self {
            Self::R01ContextCompiler => "AIRO-R01",
            Self::R02MemoryConflict => "AIRO-R02",
            Self::R03ToolAuthorization => "AIRO-R03",
            Self::R04SchemaViolation => "AIRO-R04",
            Self::R05StateMachineViolation => "AIRO-R05",
            Self::R06VerificationFailure => "AIRO-R06",
            Self::R07ModelAdapter => "AIRO-R07",
            Self::R08Timeout => "AIRO-R08",
            Self::R09DeviceResourcePressure => "AIRO-R09",
        }
    }

    pub fn from_id(id: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|mode| mode.id() == id)
    }
}

/// Pipeline invariants. A violation is observable; the model cannot paper over it.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum InvariantId {
    RetrievalSemanticAlignment,
    MemoryConsistency,
    ToolExecutionAuthority,
    OutputSchemaValid,
    GoalStateConsistent,
    CompletionVerified,
    ContextWithinBudget,
    ModelResultGrounded,
    StateTransitionValid,
}

impl InvariantId {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::RetrievalSemanticAlignment => "retrieval_semantic_alignment",
            Self::MemoryConsistency => "memory_consistency",
            Self::ToolExecutionAuthority => "tool_execution_authority",
            Self::OutputSchemaValid => "output_schema_valid",
            Self::GoalStateConsistent => "goal_state_consistent",
            Self::CompletionVerified => "completion_verified",
            Self::ContextWithinBudget => "context_within_budget",
            Self::ModelResultGrounded => "model_result_grounded",
            Self::StateTransitionValid => "state_transition_valid",
        }
    }
}

/// First-repair actions. The model proposes; the runtime selects and verifies.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum RecoveryAction {
    Retry,
    ReRetrieve,
    Rerank,
    RebuildContext,
    ReinterpretIntent,
    Replan,
    ValidateWithTool,
    AskUser,
    Abort,
}

impl RecoveryAction {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Retry => "RETRY",
            Self::ReRetrieve => "RE_RETRIEVE",
            Self::Rerank => "RERANK",
            Self::RebuildContext => "REBUILD_CONTEXT",
            Self::ReinterpretIntent => "REINTERPRET_INTENT",
            Self::Replan => "REPLAN",
            Self::ValidateWithTool => "VALIDATE_WITH_TOOL",
            Self::AskUser => "ASK_USER",
            Self::Abort => "ABORT",
        }
    }
}

/// How much diagnostic metadata may be retained. Never a license to store
/// raw prompts, hidden reasoning, or private tool payloads.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum DiagnosticLevel {
    Off,
    ErrorsOnly,
    #[default]
    Standard,
    Debug,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pm_ids_are_stable_and_complete() {
        for (i, mode) in FailureMode::ALL.iter().enumerate() {
            let expected = format!("PM-{:02}", i + 1);
            assert_eq!(mode.id(), expected);
            assert_eq!(FailureMode::from_id(&expected), Some(*mode));
        }
        assert!(FailureMode::from_id("PM-17").is_none());
    }

    #[test]
    fn runtime_ids_use_airo_namespace() {
        for failure in RuntimeFailure::ALL {
            assert!(failure.id().starts_with("AIRO-R"));
            assert_eq!(RuntimeFailure::from_id(failure.id()), Some(failure));
        }
    }
}

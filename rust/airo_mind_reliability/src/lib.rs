#![deny(unsafe_code)]
//! Airo Reasoning Reliability Engine.
//!
//! Prompt defect prevention (PD-*) runs **before** the model. Reasoning failure
//! detection (PM-01..PM-16, AIRO-Rxx) runs **after**. The two taxonomies are
//! not merged. WFGY Problem Map IDs are diagnostic labels only — this crate
//! does not depend on WFGY and does not put the Problem Map into prompts.
//!
//! Sits *beside* `airo_mind_core`, not inside it: the runtime stays domain-free
//! and this crate stays inference-backend-free. Capabilities map their own
//! reports into [`PipelineObservation`].

pub mod classifier;
pub mod execution;
pub mod ids;
pub mod observation;
pub mod prompt;
pub mod prompt_defect;
pub mod prompt_gate;
pub mod recovery;
pub mod task;

pub use classifier::{Classification, FailureClassifier, Severity};
pub use execution::{
    record_chat_completion, CheckpointMetadata, CheckpointStatus, ExecutionCheckpoint, ExecutionId,
    ExecutionLog, ExecutionStage, PersistableDiagnostic,
};
pub use ids::{DiagnosticLevel, FailureMode, InvariantId, RecoveryAction, RuntimeFailure};
pub use observation::PipelineObservation;
pub use prompt::{
    CompiledPrompt, Instruction, InstructionIssue, InstructionIssueKind, InstructionLayer,
    InstructionSet, PromptDefinition,
};
pub use prompt_defect::{FailureDomain, PromptDefect, PromptDefectCategory};
pub use prompt_gate::{
    context_health, ContextHealthReport, ContextHealthStatus, PrefixCacheCapability, PromptBudget,
    PromptFinding, PromptFindingSeverity, PromptGateDecision, PromptGateReport, PromptInspection,
    PromptQualityGate,
};
pub use recovery::{
    apply_recovery_to_goal, AttemptCounts, RecoveryDecision, RecoveryEngine, RecoveryPolicy,
};
pub use task::{
    compile_context, verify_completion, CompiledContext, CompletionCriterion,
    CompletionVerification, ContextItem, ContextRole, GoalState, GoalStatus, StateMachineError,
    TaskIr, TrustClass,
};

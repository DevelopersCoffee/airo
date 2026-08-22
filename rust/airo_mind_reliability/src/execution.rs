//! Execution identity and checkpoints.
//!
//! Timestamps are caller-supplied so this crate stays deterministic (C2).
//! Metadata is classification/recovery only — never raw prompts.

use crate::ids::{DiagnosticLevel, FailureMode, InvariantId, RecoveryAction, RuntimeFailure};

/// Opaque execution identifier. Callers mint it; this crate does not sample
/// clocks or RNG.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct ExecutionId(String);

impl ExecutionId {
    pub fn new(raw: impl Into<String>) -> Self {
        Self(raw.into())
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum ExecutionStage {
    Intent,
    Goal,
    Context,
    Memory,
    Retrieval,
    Prompt,
    Model,
    Tool,
    Validation,
    Recovery,
    Completion,
    Result,
}

impl ExecutionStage {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Intent => "intent",
            Self::Goal => "goal",
            Self::Context => "context",
            Self::Memory => "memory",
            Self::Retrieval => "retrieval",
            Self::Prompt => "prompt",
            Self::Model => "model",
            Self::Tool => "tool",
            Self::Validation => "validation",
            Self::Recovery => "recovery",
            Self::Completion => "completion",
            Self::Result => "result",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CheckpointStatus {
    Ok,
    Failed,
    Skipped,
    Degraded,
}

/// Privacy-safe checkpoint payload. No prompt, memory, or tool-result bodies.
#[derive(Clone, Debug, Default, PartialEq)]
pub struct CheckpointMetadata {
    pub invariant: Option<InvariantId>,
    pub failure_mode: Option<FailureMode>,
    pub runtime_error: Option<RuntimeFailure>,
    pub recovery: Option<RecoveryAction>,
    pub attempt: u32,
    pub model_id: Option<String>,
    pub runtime_id: Option<String>,
    pub platform: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ExecutionCheckpoint {
    pub execution_id: ExecutionId,
    pub stage: ExecutionStage,
    pub status: CheckpointStatus,
    pub timestamp_ms: u64,
    pub metadata: CheckpointMetadata,
}

/// In-process checkpoint log. Not an operation-log writer (C1 stays elsewhere).
#[derive(Clone, Debug, Default)]
pub struct ExecutionLog {
    checkpoints: Vec<ExecutionCheckpoint>,
}

impl ExecutionLog {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn record(&mut self, checkpoint: ExecutionCheckpoint) {
        self.checkpoints.push(checkpoint);
    }

    /// Record a classifier hit as a privacy-safe checkpoint. Never stores
    /// prompts, IR, or model text.
    pub fn record_classification(
        &mut self,
        execution_id: ExecutionId,
        stage: ExecutionStage,
        classification: &crate::classifier::Classification,
        timestamp_ms: u64,
    ) {
        self.record(ExecutionCheckpoint {
            execution_id,
            stage,
            status: match classification.severity {
                crate::classifier::Severity::Info => CheckpointStatus::Ok,
                crate::classifier::Severity::Degraded => CheckpointStatus::Degraded,
                crate::classifier::Severity::Failed => CheckpointStatus::Failed,
            },
            timestamp_ms,
            metadata: CheckpointMetadata {
                invariant: Some(classification.invariant),
                failure_mode: Some(classification.primary),
                runtime_error: classification.runtime_error,
                recovery: Some(classification.first_repair),
                attempt: 0,
                model_id: None,
                runtime_id: None,
                platform: None,
            },
        });
    }

    pub fn is_empty(&self) -> bool {
        self.checkpoints.is_empty()
    }

    pub fn checkpoints(&self) -> &[ExecutionCheckpoint] {
        &self.checkpoints
    }

    pub fn last_failure(&self) -> Option<&ExecutionCheckpoint> {
        self.checkpoints
            .iter()
            .rev()
            .find(|c| c.status == CheckpointStatus::Failed)
    }

    /// Fields allowed on disk for this diagnostic level. Raw content is never
    /// included, including at Debug.
    pub fn persistable(&self, level: DiagnosticLevel) -> Vec<PersistableDiagnostic> {
        if level == DiagnosticLevel::Off {
            return Vec::new();
        }
        self.checkpoints
            .iter()
            .filter(|c| match level {
                DiagnosticLevel::Off => false,
                DiagnosticLevel::ErrorsOnly => c.status == CheckpointStatus::Failed,
                DiagnosticLevel::Standard | DiagnosticLevel::Debug => true,
            })
            .map(PersistableDiagnostic::from_checkpoint)
            .collect()
    }
}

/// Classify a chat completion without storing the prompt or tokens.
pub fn record_chat_completion(
    execution_id: impl Into<String>,
    text: &str,
    engine_ok: bool,
    level: DiagnosticLevel,
) -> Vec<PersistableDiagnostic> {
    use crate::classifier::FailureClassifier;
    use crate::observation::PipelineObservation;

    let mut log = ExecutionLog::new();
    if let Some(classification) =
        FailureClassifier::classify(&PipelineObservation::chat_completion(text, engine_ok))
    {
        log.record_classification(
            ExecutionId::new(execution_id),
            ExecutionStage::Model,
            &classification,
            0,
        );
    }
    log.persistable(level)
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PersistableDiagnostic {
    pub execution_id: String,
    pub timestamp_ms: u64,
    pub stage: &'static str,
    pub status: &'static str,
    pub failure_mode: Option<&'static str>,
    pub runtime_error: Option<&'static str>,
    pub invariant: Option<&'static str>,
    pub recovery_action: Option<&'static str>,
    pub attempt: u32,
    pub model_id: Option<String>,
    pub runtime_id: Option<String>,
    pub platform: Option<String>,
}

impl PersistableDiagnostic {
    fn from_checkpoint(checkpoint: &ExecutionCheckpoint) -> Self {
        Self {
            execution_id: checkpoint.execution_id.as_str().to_string(),
            timestamp_ms: checkpoint.timestamp_ms,
            stage: checkpoint.stage.as_str(),
            status: match checkpoint.status {
                CheckpointStatus::Ok => "ok",
                CheckpointStatus::Failed => "failed",
                CheckpointStatus::Skipped => "skipped",
                CheckpointStatus::Degraded => "degraded",
            },
            failure_mode: checkpoint.metadata.failure_mode.map(FailureMode::id),
            runtime_error: checkpoint.metadata.runtime_error.map(RuntimeFailure::id),
            invariant: checkpoint.metadata.invariant.map(InvariantId::as_str),
            recovery_action: checkpoint.metadata.recovery.map(RecoveryAction::as_str),
            attempt: checkpoint.metadata.attempt,
            model_id: checkpoint.metadata.model_id.clone(),
            runtime_id: checkpoint.metadata.runtime_id.clone(),
            platform: checkpoint.metadata.platform.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn persistable_diagnostics_omit_prompt_fields() {
        let mut log = ExecutionLog::new();
        log.record(ExecutionCheckpoint {
            execution_id: ExecutionId::new("exec_1"),
            stage: ExecutionStage::Model,
            status: CheckpointStatus::Failed,
            timestamp_ms: 1,
            metadata: CheckpointMetadata {
                failure_mode: Some(FailureMode::Pm01HallucinationChunkDrift),
                ..CheckpointMetadata::default()
            },
        });
        let persisted = log.persistable(DiagnosticLevel::Standard);
        assert_eq!(persisted.len(), 1);
        // Compile-time: PersistableDiagnostic has no prompt/content fields.
        assert_eq!(persisted[0].failure_mode, Some("PM-01"));
        assert_eq!(log.persistable(DiagnosticLevel::Off).len(), 0);
    }

    #[test]
    fn empty_chat_completion_is_unverified_not_success() {
        let diagnostics = record_chat_completion("chat-1", "   ", true, DiagnosticLevel::Standard);
        assert_eq!(diagnostics.len(), 1);
        assert_eq!(diagnostics[0].failure_mode, Some("PM-06"));
        assert_eq!(diagnostics[0].runtime_error, Some("AIRO-R06"));
        let dump = format!("{:?}", diagnostics[0]);
        assert!(!dump.contains("   "));
    }

    #[test]
    fn a_normal_reply_is_not_a_failure() {
        assert!(
            record_chat_completion("chat-2", "2+2 is 4.", true, DiagnosticLevel::Standard,)
                .is_empty()
        );
    }
}

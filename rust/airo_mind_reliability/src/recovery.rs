//! Runtime-owned recovery. The model cannot mark recovery or completion as
//! successful.

use crate::classifier::{Classification, Severity};
use crate::ids::RecoveryAction;
use crate::task::{CompletionVerification, GoalState, GoalStatus, StateMachineError};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RecoveryPolicy {
    pub max_retries: u32,
    pub max_rereads: u32,
    pub max_replans: u32,
    pub max_tool_calls: u32,
}

impl Default for RecoveryPolicy {
    fn default() -> Self {
        Self {
            max_retries: 2,
            max_rereads: 2,
            max_replans: 2,
            max_tool_calls: 8,
        }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct AttemptCounts {
    pub retries: u32,
    pub rereads: u32,
    pub replans: u32,
    pub tool_calls: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RecoveryDecision {
    Execute(RecoveryAction),
    Abort,
}

pub struct RecoveryEngine {
    policy: RecoveryPolicy,
    attempts: AttemptCounts,
}

impl RecoveryEngine {
    pub fn new(policy: RecoveryPolicy) -> Self {
        Self {
            policy,
            attempts: AttemptCounts::default(),
        }
    }

    pub fn attempts(&self) -> AttemptCounts {
        self.attempts
    }

    pub fn select(&self, classification: &Classification) -> RecoveryDecision {
        if classification.first_repair == RecoveryAction::Abort
            || classification.severity == Severity::Failed
                && matches!(classification.first_repair, RecoveryAction::Abort)
        {
            return RecoveryDecision::Abort;
        }
        let action = classification.first_repair;
        if self.exhausted(action) {
            return RecoveryDecision::Abort;
        }
        RecoveryDecision::Execute(action)
    }

    /// Record that the runtime performed `action`. Does not mean it succeeded.
    pub fn note_attempt(&mut self, action: RecoveryAction) {
        match action {
            RecoveryAction::Retry => self.attempts.retries += 1,
            RecoveryAction::ReRetrieve | RecoveryAction::Rerank => self.attempts.rereads += 1,
            RecoveryAction::Replan | RecoveryAction::ReinterpretIntent => {
                self.attempts.replans += 1
            }
            RecoveryAction::ValidateWithTool => self.attempts.tool_calls += 1,
            RecoveryAction::RebuildContext | RecoveryAction::AskUser | RecoveryAction::Abort => {}
        }
    }

    fn exhausted(&self, action: RecoveryAction) -> bool {
        match action {
            RecoveryAction::Retry => self.attempts.retries >= self.policy.max_retries,
            RecoveryAction::ReRetrieve | RecoveryAction::Rerank => {
                self.attempts.rereads >= self.policy.max_rereads
            }
            RecoveryAction::Replan | RecoveryAction::ReinterpretIntent => {
                self.attempts.replans >= self.policy.max_replans
            }
            RecoveryAction::ValidateWithTool => {
                self.attempts.tool_calls >= self.policy.max_tool_calls
            }
            RecoveryAction::RebuildContext | RecoveryAction::AskUser => false,
            RecoveryAction::Abort => true,
        }
    }
}

/// Apply a recovery outcome. Success still requires re-validation; the model
/// does not get to declare that.
pub fn apply_recovery_to_goal(
    goal: &mut GoalState,
    action: RecoveryAction,
    verified: CompletionVerification,
) -> Result<GoalStatus, StateMachineError> {
    match action {
        RecoveryAction::Abort => goal.transition(GoalStatus::Failed),
        RecoveryAction::AskUser => goal.transition(GoalStatus::Blocked),
        RecoveryAction::Replan | RecoveryAction::ReinterpretIntent => {
            goal.transition(GoalStatus::Replanning)?;
            goal.transition(GoalStatus::Executing)
        }
        RecoveryAction::Retry
        | RecoveryAction::ReRetrieve
        | RecoveryAction::Rerank
        | RecoveryAction::RebuildContext
        | RecoveryAction::ValidateWithTool => match verified {
            CompletionVerification::Passed => {
                goal.transition(GoalStatus::Verifying)?;
                goal.transition(GoalStatus::Completed)
            }
            CompletionVerification::Failed | CompletionVerification::Incomplete => {
                if goal.status == GoalStatus::Failed {
                    goal.transition(GoalStatus::Replanning)
                } else {
                    goal.transition(GoalStatus::Failed)
                }
            }
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::classifier::FailureClassifier;
    use crate::ids::FailureMode;
    use crate::observation::PipelineObservation;
    use crate::task::GoalState;

    #[test]
    fn retry_exhaustion_aborts() {
        let mut o = PipelineObservation::healthy();
        o.schema_valid = false;
        let classification = FailureClassifier::classify(&o).unwrap();
        let mut engine = RecoveryEngine::new(RecoveryPolicy {
            max_retries: 1,
            ..RecoveryPolicy::default()
        });
        assert_eq!(
            engine.select(&classification),
            RecoveryDecision::Execute(RecoveryAction::Retry)
        );
        engine.note_attempt(RecoveryAction::Retry);
        assert_eq!(engine.select(&classification), RecoveryDecision::Abort);
    }

    #[test]
    fn model_cannot_skip_failed_to_completed() {
        let mut goal = GoalState::new("find meeting");
        goal.transition(GoalStatus::Planning).unwrap();
        goal.transition(GoalStatus::Executing).unwrap();
        goal.transition(GoalStatus::Failed).unwrap();
        assert!(goal.transition(GoalStatus::Completed).is_err());
        let mut o = PipelineObservation::healthy();
        o.state_skipped_replan = true;
        let c = FailureClassifier::classify(&o).unwrap();
        assert_eq!(c.primary, FailureMode::Pm06LogicCollapse);
    }
}

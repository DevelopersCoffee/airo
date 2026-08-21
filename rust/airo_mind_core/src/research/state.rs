//! Explicit job state. Flutter reconnects to this, not to a model scratchpad.

use super::request::ResearchRequest;

/// Where a research job is. Long-running: the UI must be able to reattach.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ResearchJobState {
    Created,
    Planning,
    Searching,
    Collecting,
    Analyzing,
    Verifying,
    GapAnalysis,
    Synthesizing,
    Validating,
    Completed,
    Paused,
    Cancelled,
    Failed,
}

/// Commands the orchestrator applies. Not LLM tokens.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ResearchCommand {
    StartPlanning,
    PlanReady,
    StartSearch,
    SearchFinished,
    StartCollecting,
    CollectionFinished,
    StartAnalysis,
    AnalysisFinished,
    StartVerification,
    VerificationFinished,
    StartGapAnalysis,
    GapsRemain,
    GapsResolved,
    StartSynthesis,
    SynthesisFinished,
    StartValidation,
    ValidationPassed,
    Pause,
    Resume,
    Cancel,
    Fail,
}

#[derive(Debug, PartialEq, Eq)]
pub enum ResearchStateError {
    IllegalTransition {
        from: ResearchJobState,
        command: ResearchCommand,
    },
}

impl std::fmt::Display for ResearchStateError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::IllegalTransition { from, command } => {
                write!(f, "cannot apply {command:?} from {from:?}")
            }
        }
    }
}

impl std::error::Error for ResearchStateError {}

impl ResearchJobState {
    pub fn apply(self, command: ResearchCommand) -> Result<Self, ResearchStateError> {
        let next = match (self, command) {
            (Self::Created, ResearchCommand::StartPlanning) => Self::Planning,
            (Self::Planning, ResearchCommand::PlanReady) => Self::Searching,
            (Self::Searching, ResearchCommand::SearchFinished) => Self::Collecting,
            (Self::Collecting, ResearchCommand::CollectionFinished) => Self::Analyzing,
            (Self::Analyzing, ResearchCommand::AnalysisFinished) => Self::Verifying,
            (Self::Verifying, ResearchCommand::VerificationFinished) => Self::GapAnalysis,
            (Self::GapAnalysis, ResearchCommand::GapsRemain) => Self::Searching,
            (Self::GapAnalysis, ResearchCommand::GapsResolved) => Self::Synthesizing,
            (Self::Synthesizing, ResearchCommand::SynthesisFinished) => Self::Validating,
            (Self::Validating, ResearchCommand::ValidationPassed) => Self::Completed,
            (Self::Paused, ResearchCommand::Resume) => Self::Searching,
            (_, ResearchCommand::Pause)
                if !matches!(
                    self,
                    Self::Completed | Self::Cancelled | Self::Failed | Self::Paused
                ) =>
            {
                Self::Paused
            }
            (_, ResearchCommand::Cancel)
                if !matches!(self, Self::Completed | Self::Cancelled | Self::Failed) =>
            {
                Self::Cancelled
            }
            (_, ResearchCommand::Fail)
                if !matches!(self, Self::Completed | Self::Cancelled | Self::Failed) =>
            {
                Self::Failed
            }
            _ => {
                return Err(ResearchStateError::IllegalTransition {
                    from: self,
                    command,
                });
            }
        };
        Ok(next)
    }

    pub fn is_terminal(self) -> bool {
        matches!(self, Self::Completed | Self::Cancelled | Self::Failed)
    }
}

/// One admitted research job. Control plane only — no report text lives here.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResearchJob {
    pub request: ResearchRequest,
    pub state: ResearchJobState,
    pub searches_used: u32,
    pub iterations_used: u32,
}

impl ResearchJob {
    pub fn new(request: ResearchRequest) -> Self {
        Self {
            request,
            state: ResearchJobState::Created,
            searches_used: 0,
            iterations_used: 0,
        }
    }

    pub fn apply(&mut self, command: ResearchCommand) -> Result<(), ResearchStateError> {
        self.state = self.state.apply(command)?;
        if command == ResearchCommand::GapsRemain {
            self.iterations_used = self.iterations_used.saturating_add(1);
        }
        Ok(())
    }

    pub fn record_search(&mut self) {
        self.searches_used = self.searches_used.saturating_add(1);
    }

    pub fn budget_exhausted(&self) -> bool {
        let budget = self.request.budget();
        self.searches_used >= budget.max_searches || self.iterations_used >= budget.max_iterations
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::request::ResearchRequest;

    #[test]
    fn the_quality_loop_can_return_to_search_from_gaps() {
        let mut job = ResearchJob::new(ResearchRequest::new("Pixel 9 offline LLM"));
        for command in [
            ResearchCommand::StartPlanning,
            ResearchCommand::PlanReady,
            ResearchCommand::SearchFinished,
            ResearchCommand::CollectionFinished,
            ResearchCommand::AnalysisFinished,
            ResearchCommand::VerificationFinished,
            ResearchCommand::GapsRemain,
        ] {
            job.apply(command).expect("legal transition");
        }
        assert_eq!(job.state, ResearchJobState::Searching);
        assert_eq!(job.iterations_used, 1);
    }

    #[test]
    fn a_completed_job_cannot_search_again() {
        let err = ResearchJobState::Completed
            .apply(ResearchCommand::StartSearch)
            .expect_err("terminal states are closed");
        assert!(matches!(err, ResearchStateError::IllegalTransition { .. }));
    }
}

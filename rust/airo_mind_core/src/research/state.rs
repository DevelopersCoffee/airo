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
    UnknownJob,
    InvalidCheckpoint,
}

impl std::fmt::Display for ResearchStateError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::IllegalTransition { from, command } => {
                write!(f, "cannot apply {command:?} from {from:?}")
            }
            Self::UnknownJob => write!(f, "unknown research job"),
            Self::InvalidCheckpoint => write!(f, "invalid research checkpoint"),
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

    pub fn as_str(self) -> &'static str {
        match self {
            Self::Created => "created",
            Self::Planning => "planning",
            Self::Searching => "searching",
            Self::Collecting => "collecting",
            Self::Analyzing => "analyzing",
            Self::Verifying => "verifying",
            Self::GapAnalysis => "gap_analysis",
            Self::Synthesizing => "synthesizing",
            Self::Validating => "validating",
            Self::Completed => "completed",
            Self::Paused => "paused",
            Self::Cancelled => "cancelled",
            Self::Failed => "failed",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "created" => Some(Self::Created),
            "planning" => Some(Self::Planning),
            "searching" => Some(Self::Searching),
            "collecting" => Some(Self::Collecting),
            "analyzing" => Some(Self::Analyzing),
            "verifying" => Some(Self::Verifying),
            "gap_analysis" => Some(Self::GapAnalysis),
            "synthesizing" => Some(Self::Synthesizing),
            "validating" => Some(Self::Validating),
            "completed" => Some(Self::Completed),
            "paused" => Some(Self::Paused),
            "cancelled" => Some(Self::Cancelled),
            "failed" => Some(Self::Failed),
            _ => None,
        }
    }
}

/// One admitted research job. Control plane only — no report text lives here.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResearchJob {
    pub request: ResearchRequest,
    pub state: ResearchJobState,
    pub paused_from: Option<ResearchJobState>,
    pub searches_used: u32,
    pub iterations_used: u32,
}

impl ResearchJob {
    pub fn new(request: ResearchRequest) -> Self {
        Self {
            request,
            state: ResearchJobState::Created,
            paused_from: None,
            searches_used: 0,
            iterations_used: 0,
        }
    }

    pub fn apply(&mut self, command: ResearchCommand) -> Result<(), ResearchStateError> {
        let next = match command {
            ResearchCommand::Resume if self.state == ResearchJobState::Paused => self
                .paused_from
                .take()
                .unwrap_or(ResearchJobState::Searching),
            ResearchCommand::Pause
                if !self.state.is_terminal() && self.state != ResearchJobState::Paused =>
            {
                self.paused_from = Some(self.state);
                self.state.apply(command)?
            }
            _ => self.state.apply(command)?,
        };
        self.state = next;
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

/// Durable job snapshot. Payload for the operation log — not a sidecar DB.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResearchCheckpoint {
    pub job_id: String,
    pub question: String,
    pub state: ResearchJobState,
    pub paused_from: Option<ResearchJobState>,
    pub searches_used: u32,
    pub iterations_used: u32,
    pub completed_node_ids: Vec<String>,
}

impl ResearchCheckpoint {
    pub fn from_job(
        job_id: impl Into<String>,
        job: &ResearchJob,
        completed_node_ids: Vec<String>,
    ) -> Self {
        Self {
            job_id: job_id.into(),
            question: job.request.question.clone(),
            state: job.state,
            paused_from: job.paused_from,
            searches_used: job.searches_used,
            iterations_used: job.iterations_used,
            completed_node_ids,
        }
    }

    pub fn to_record(&self) -> String {
        format!(
            "v1\u{1f}{}\u{1f}{}\u{1f}{}\u{1f}{}\u{1f}{}\u{1f}{}\u{1f}{}",
            self.job_id,
            self.question.replace('\u{1f}', " "),
            self.state.as_str(),
            self.paused_from.map(ResearchJobState::as_str).unwrap_or(""),
            self.searches_used,
            self.iterations_used,
            self.completed_node_ids.join(","),
        )
    }

    pub fn from_record(record: &str) -> Result<Self, ResearchStateError> {
        let parts: Vec<&str> = record.split('\u{1f}').collect();
        if parts.len() != 8 || parts[0] != "v1" {
            return Err(ResearchStateError::InvalidCheckpoint);
        }
        let state =
            ResearchJobState::parse(parts[3]).ok_or(ResearchStateError::InvalidCheckpoint)?;
        let paused_from = if parts[4].is_empty() {
            None
        } else {
            Some(ResearchJobState::parse(parts[4]).ok_or(ResearchStateError::InvalidCheckpoint)?)
        };
        Ok(Self {
            job_id: parts[1].to_string(),
            question: parts[2].to_string(),
            state,
            paused_from,
            searches_used: parts[5]
                .parse()
                .map_err(|_| ResearchStateError::InvalidCheckpoint)?,
            iterations_used: parts[6]
                .parse()
                .map_err(|_| ResearchStateError::InvalidCheckpoint)?,
            completed_node_ids: if parts[7].is_empty() {
                Vec::new()
            } else {
                parts[7].split(',').map(str::to_string).collect()
            },
        })
    }

    pub fn into_job(self) -> ResearchJob {
        ResearchJob {
            request: ResearchRequest::new(self.question),
            state: self.state,
            paused_from: self.paused_from,
            searches_used: self.searches_used,
            iterations_used: self.iterations_used,
        }
    }
}

/// In-memory control plane. Checkpoints are the durable form (operation log).
#[derive(Default)]
pub struct InMemoryResearchService {
    next_id: u64,
    jobs: std::collections::BTreeMap<String, (ResearchJob, Vec<String>)>,
}

impl InMemoryResearchService {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn start(&mut self, request: ResearchRequest) -> String {
        self.next_id = self.next_id.saturating_add(1);
        let id = format!("job-{}", self.next_id);
        self.jobs
            .insert(id.clone(), (ResearchJob::new(request), Vec::new()));
        id
    }

    pub fn status(&self, job_id: &str) -> Option<ResearchJobState> {
        self.jobs.get(job_id).map(|(job, _)| job.state)
    }

    pub fn apply(
        &mut self,
        job_id: &str,
        command: ResearchCommand,
    ) -> Result<(), ResearchStateError> {
        let (job, _) = self
            .jobs
            .get_mut(job_id)
            .ok_or(ResearchStateError::UnknownJob)?;
        job.apply(command)
    }

    pub fn pause(&mut self, job_id: &str) -> Result<(), ResearchStateError> {
        self.apply(job_id, ResearchCommand::Pause)
    }

    pub fn resume(&mut self, job_id: &str) -> Result<(), ResearchStateError> {
        self.apply(job_id, ResearchCommand::Resume)
    }

    pub fn cancel(&mut self, job_id: &str) -> Result<(), ResearchStateError> {
        self.apply(job_id, ResearchCommand::Cancel)
    }

    pub fn checkpoint(&self, job_id: &str) -> Option<ResearchCheckpoint> {
        let (job, nodes) = self.jobs.get(job_id)?;
        Some(ResearchCheckpoint::from_job(job_id, job, nodes.clone()))
    }

    pub fn restore(&mut self, checkpoint: ResearchCheckpoint) -> Result<(), ResearchStateError> {
        let id = checkpoint.job_id.clone();
        let nodes = checkpoint.completed_node_ids.clone();
        self.jobs.insert(id, (checkpoint.into_job(), nodes));
        Ok(())
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

    #[test]
    fn resume_returns_to_the_phase_that_was_paused() {
        let mut job = ResearchJob::new(ResearchRequest::new("Pixel 9 offline LLM"));
        job.apply(ResearchCommand::StartPlanning).unwrap();
        job.apply(ResearchCommand::PlanReady).unwrap();
        job.apply(ResearchCommand::Pause).unwrap();
        assert_eq!(job.state, ResearchJobState::Paused);
        job.apply(ResearchCommand::Resume).unwrap();
        assert_eq!(
            job.state,
            ResearchJobState::Searching,
            "resume must restore the paused phase, not restart planning"
        );
    }

    #[test]
    fn pause_from_analysis_resumes_into_analysis() {
        let mut job = ResearchJob::new(ResearchRequest::new("Pixel 9 offline LLM"));
        for command in [
            ResearchCommand::StartPlanning,
            ResearchCommand::PlanReady,
            ResearchCommand::SearchFinished,
            ResearchCommand::CollectionFinished,
        ] {
            job.apply(command).unwrap();
        }
        assert_eq!(job.state, ResearchJobState::Analyzing);
        job.apply(ResearchCommand::Pause).unwrap();
        job.apply(ResearchCommand::Resume).unwrap();
        assert_eq!(job.state, ResearchJobState::Analyzing);
    }

    #[test]
    fn checkpoint_roundtrip_preserves_completed_nodes_and_paused_from() {
        let checkpoint = ResearchCheckpoint {
            job_id: "job-1".into(),
            question: "Pixel 9 offline LLM".into(),
            state: ResearchJobState::Paused,
            paused_from: Some(ResearchJobState::Analyzing),
            searches_used: 2,
            iterations_used: 1,
            completed_node_ids: vec!["n1".into(), "n2".into()],
        };
        let restored = ResearchCheckpoint::from_record(&checkpoint.to_record())
            .expect("checkpoint record must roundtrip");
        assert_eq!(restored, checkpoint);
    }

    #[test]
    fn restore_rebuilds_the_job_after_process_death() {
        let mut live = InMemoryResearchService::new();
        let id = live.start(ResearchRequest::new("Pixel 9 offline LLM"));
        live.apply(&id, ResearchCommand::StartPlanning).unwrap();
        live.pause(&id).unwrap();
        let record = live.checkpoint(&id).unwrap().to_record();

        let mut revived = InMemoryResearchService::new();
        revived
            .restore(ResearchCheckpoint::from_record(&record).unwrap())
            .unwrap();
        assert_eq!(revived.status(&id), Some(ResearchJobState::Paused));
        revived.resume(&id).unwrap();
        assert_eq!(revived.status(&id), Some(ResearchJobState::Planning));
    }
}

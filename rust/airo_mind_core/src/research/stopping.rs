//! Stop on evidence sufficiency, not on a magic search count.

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ResearchCompleteness {
    pub coverage: f32,
    pub source_quality: f32,
    pub claim_support: f32,
    pub contradiction_level: f32,
    pub unresolved_questions: usize,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ResearchProgress {
    pub searches_used: u32,
    pub max_searches: u32,
    pub sources: u32,
    pub uncovered_nodes: usize,
    pub iterations_used: u32,
    pub max_iterations: u32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StopDecision {
    Continue,
    Stop(&'static str),
}

pub trait StoppingPolicy {
    fn should_stop(&self, progress: &ResearchProgress) -> StopDecision;
}

/// Budget is a ceiling. Coverage is the reason to stop early.
pub struct EvidenceSufficiencyPolicy;

impl StoppingPolicy for EvidenceSufficiencyPolicy {
    fn should_stop(&self, progress: &ResearchProgress) -> StopDecision {
        if progress.uncovered_nodes == 0 && progress.sources > 0 {
            return StopDecision::Stop("coverage");
        }
        if progress.searches_used >= progress.max_searches {
            return StopDecision::Stop("budget");
        }
        if progress.iterations_used >= progress.max_iterations && progress.sources > 0 {
            return StopDecision::Stop("iteration_cap");
        }
        StopDecision::Continue
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn does_not_stop_just_because_ten_searches_ran() {
        let progress = ResearchProgress {
            searches_used: 10,
            max_searches: 40,
            sources: 0,
            uncovered_nodes: 3,
            iterations_used: 1,
            max_iterations: 8,
        };
        assert_eq!(
            EvidenceSufficiencyPolicy.should_stop(&progress),
            StopDecision::Continue,
            "search count alone is not research"
        );
    }

    #[test]
    fn stops_when_plan_nodes_are_covered_by_sources() {
        let progress = ResearchProgress {
            searches_used: 4,
            max_searches: 40,
            sources: 3,
            uncovered_nodes: 0,
            iterations_used: 1,
            max_iterations: 8,
        };
        assert_eq!(
            EvidenceSufficiencyPolicy.should_stop(&progress),
            StopDecision::Stop("coverage")
        );
    }
}

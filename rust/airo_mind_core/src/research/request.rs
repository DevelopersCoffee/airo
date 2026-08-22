//! Typed research goal and per-mode budget.

/// How far a job is allowed to go. Policy, not a prompt adjective.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ResearchMode {
    Quick,
    Standard,
    Deep,
    Exhaustive,
}

impl ResearchMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Quick => "quick",
            Self::Standard => "standard",
            Self::Deep => "deep",
            Self::Exhaustive => "exhaustive",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "quick" => Some(Self::Quick),
            "standard" => Some(Self::Standard),
            "deep" => Some(Self::Deep),
            "exhaustive" => Some(Self::Exhaustive),
            _ => None,
        }
    }
}

/// Which search providers a job may use. The model does not pick this.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SearchPolicy {
    LocalOnly,
    PrivacyFirst,
    Balanced,
    MaximumQuality,
    Academic,
}

impl SearchPolicy {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::LocalOnly => "local_only",
            Self::PrivacyFirst => "privacy_first",
            Self::Balanced => "balanced",
            Self::MaximumQuality => "maximum_quality",
            Self::Academic => "academic",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "local_only" => Some(Self::LocalOnly),
            "privacy_first" => Some(Self::PrivacyFirst),
            "balanced" => Some(Self::Balanced),
            "maximum_quality" => Some(Self::MaximumQuality),
            "academic" => Some(Self::Academic),
            _ => None,
        }
    }
}

/// Hard caps for one research job. Sufficiency can stop the job earlier.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ResearchBudget {
    pub max_searches: u32,
    pub max_sources: u32,
    pub max_iterations: u32,
    pub max_parallel_tasks: u32,
    pub max_tokens: u64,
    pub max_duration_secs: u64,
    pub max_cost_micros: u64,
}

impl ResearchBudget {
    pub fn for_mode(mode: ResearchMode) -> Self {
        match mode {
            ResearchMode::Quick => Self {
                max_searches: 5,
                max_sources: 8,
                max_iterations: 1,
                max_parallel_tasks: 2,
                max_tokens: 4096,
                max_duration_secs: 30,
                max_cost_micros: 8_000,
            },
            ResearchMode::Standard => Self {
                max_searches: 15,
                max_sources: 20,
                max_iterations: 3,
                max_parallel_tasks: 4,
                max_tokens: 12_288,
                max_duration_secs: 120,
                max_cost_micros: 40_000,
            },
            ResearchMode::Deep => Self {
                max_searches: 40,
                max_sources: 48,
                max_iterations: 8,
                max_parallel_tasks: 6,
                max_tokens: 32_768,
                max_duration_secs: 480,
                max_cost_micros: 150_000,
            },
            ResearchMode::Exhaustive => Self {
                max_searches: 100,
                max_sources: 120,
                max_iterations: 16,
                max_parallel_tasks: 8,
                max_tokens: 65_536,
                max_duration_secs: 1_200,
                max_cost_micros: 500_000,
            },
        }
    }
}

/// A research goal. The engine, not the model, owns the workflow that follows.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ResearchRequest {
    pub question: String,
    pub mode: ResearchMode,
    pub policy: SearchPolicy,
    pub output_format: String,
}

impl ResearchRequest {
    pub fn new(question: impl Into<String>) -> Self {
        Self {
            question: question.into(),
            mode: ResearchMode::Deep,
            policy: SearchPolicy::Balanced,
            output_format: "technical_report".to_string(),
        }
    }

    pub fn budget(&self) -> ResearchBudget {
        ResearchBudget::for_mode(self.mode)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deep_mode_is_the_default_and_is_not_a_fixed_search_count() {
        let request = ResearchRequest::new("Compare Qwen, Llama and Gemma");
        assert_eq!(request.mode, ResearchMode::Deep);
        let budget = request.budget();
        assert_eq!(budget.max_searches, 40);
        assert_eq!(budget.max_iterations, 8);
        assert!(
            budget.max_searches > ResearchBudget::for_mode(ResearchMode::Quick).max_searches,
            "modes must differ by budget, not by a hardcoded 'do 10 searches'"
        );
    }
}

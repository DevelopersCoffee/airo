//! Interpret the user goal before any search. Search is not research.

use crate::research::request::ResearchRequest;

/// What kind of research the user asked for. Strategy is selected from this.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ResearchIntent {
    FactFinding,
    Comparison,
    DecisionSupport,
    TechnicalResearch,
    AcademicResearch,
    MarketResearch,
    ProductResearch,
    NewsResearch,
    Investigation,
    DeepExploration,
}

impl ResearchIntent {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::FactFinding => "fact_finding",
            Self::Comparison => "comparison",
            Self::DecisionSupport => "decision_support",
            Self::TechnicalResearch => "technical_research",
            Self::AcademicResearch => "academic_research",
            Self::MarketResearch => "market_research",
            Self::ProductResearch => "product_research",
            Self::NewsResearch => "news_research",
            Self::Investigation => "investigation",
            Self::DeepExploration => "deep_exploration",
        }
    }
}

/// Structured goal. Prevents wasting searches on the wrong dimensions.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct InterpretedGoal {
    pub topic: String,
    pub intent: ResearchIntent,
    pub dimensions: Vec<String>,
    pub decision_required: bool,
    pub freshness_year: Option<u16>,
}

pub fn interpret(request: &ResearchRequest) -> InterpretedGoal {
    let topic = request.question.trim().to_string();
    let intent = classify(&topic);
    InterpretedGoal {
        dimensions: dimensions_for(intent),
        decision_required: matches!(
            intent,
            ResearchIntent::DecisionSupport | ResearchIntent::Comparison
        ),
        freshness_year: year_in(&topic),
        intent,
        topic,
    }
}

pub fn classify(question: &str) -> ResearchIntent {
    let q = question.to_ascii_lowercase();
    if q.contains(" vs ") || q.contains("versus") || q.contains("compare ") {
        return ResearchIntent::Comparison;
    }
    if q.contains("which should")
        || q.contains("should i")
        || q.contains("should we")
        || q.contains("best ")
        || q.contains("recommend")
    {
        return ResearchIntent::DecisionSupport;
    }
    if q.contains("who invented")
        || q.contains("who created")
        || q.starts_with("what is ")
        || q.starts_with("when was ")
        || q.starts_with("when did ")
    {
        return ResearchIntent::FactFinding;
    }
    if q.contains("arxiv") || q.contains("pubmed") || q.contains("peer-reviewed") {
        return ResearchIntent::AcademicResearch;
    }
    if q.contains("market") || q.contains("pricing") || q.contains("tam ") {
        return ResearchIntent::MarketResearch;
    }
    if q.contains("breaking news") || q.contains("headlines") {
        return ResearchIntent::NewsResearch;
    }
    if q.contains("investigate") || q.contains("what went wrong") {
        return ResearchIntent::Investigation;
    }
    if q.contains("product") && q.contains("review") {
        return ResearchIntent::ProductResearch;
    }
    ResearchIntent::TechnicalResearch
}

pub fn split_subjects(question: &str) -> Vec<String> {
    let lowered = question.to_ascii_lowercase();
    let rest = if let Some(i) = lowered.find("compare ") {
        &question[i + "compare ".len()..]
    } else {
        question
    };
    let cut = rest
        .split(" for ")
        .next()
        .unwrap_or(rest);
    let cut = cut.split(" vs ").next().unwrap_or(cut);
    let normalized = cut.replace(" versus ", ", ").replace(" and ", ", ");
    normalized
        .split(',')
        .map(|part| part.trim().trim_matches(['.', '?']))
        .filter(|part| part.len() >= 2)
        .map(|part| part.to_string())
        .collect()
}

fn dimensions_for(intent: ResearchIntent) -> Vec<String> {
    match intent {
        ResearchIntent::DecisionSupport | ResearchIntent::Comparison => vec![
            "quality".into(),
            "latency".into(),
            "memory".into(),
            "licensing".into(),
            "mobile support".into(),
            "offline support".into(),
            "tooling".into(),
        ],
        ResearchIntent::TechnicalResearch => vec![
            "architecture".into(),
            "constraints".into(),
            "implementation".into(),
        ],
        ResearchIntent::AcademicResearch => {
            vec!["primary literature".into(), "methods".into(), "replication".into()]
        }
        _ => vec!["primary sources".into()],
    }
}

fn year_in(question: &str) -> Option<u16> {
    let mut year = None;
    for token in question.split(|c: char| !c.is_ascii_digit()) {
        if token.len() == 4 {
            if let Ok(value) = token.parse::<u16>() {
                if (1990..=2099).contains(&value) {
                    year = Some(value);
                }
            }
        }
    }
    year
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::research::request::ResearchRequest;

    #[test]
    fn compare_questions_are_comparison_intent() {
        let goal = interpret(&ResearchRequest::new("Compare Qwen, Llama and Gemma"));
        assert_eq!(goal.intent, ResearchIntent::Comparison);
        assert!(goal.decision_required);
        assert!(goal.dimensions.iter().any(|d| d == "licensing"));
    }

    #[test]
    fn best_for_is_decision_support_not_a_search() {
        let goal = interpret(&ResearchRequest::new(
            "Research the best LLM for Airo Mind.",
        ));
        assert_eq!(goal.intent, ResearchIntent::DecisionSupport);
        assert_eq!(goal.freshness_year, None);
    }

    #[test]
    fn what_is_is_fact_finding() {
        assert_eq!(classify("What is Qwen?"), ResearchIntent::FactFinding);
    }

    #[test]
    fn rust_ffi_defaults_to_technical_research() {
        assert_eq!(
            classify("Research Rust FFI for Flutter"),
            ResearchIntent::TechnicalResearch
        );
    }
}

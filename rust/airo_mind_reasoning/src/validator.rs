use crate::error::ReasoningError;
use crate::result::ReasoningResult;

const MAX_SUMMARY_CHARS: usize = 280;

pub fn validate_result(result: &ReasoningResult) -> Result<(), ReasoningError> {
    if result.answer.trim().is_empty() {
        return Err(ReasoningError::InvalidModelOutput);
    }
    if let Some(summary) = &result.reasoning_summary {
        if summary.len() > MAX_SUMMARY_CHARS {
            return Err(ReasoningError::InvalidModelOutput);
        }
        let lowered = summary.to_ascii_lowercase();
        if lowered.contains("<thought") || lowered.contains("chain-of-thought") {
            return Err(ReasoningError::InvalidModelOutput);
        }
    }
    if let Some(confidence) = result.confidence {
        if !(0.0..=1.0).contains(&confidence) {
            return Err(ReasoningError::InvalidModelOutput);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::level::ReasoningLevel;

    #[test]
    fn empty_answer_fails() {
        let result = ReasoningResult::answer_only("   ", ReasoningLevel::None);
        assert!(validate_result(&result).is_err());
    }

    #[test]
    fn thought_tag_in_summary_fails() {
        let mut result = ReasoningResult::answer_only("ok", ReasoningLevel::Light);
        result.reasoning_summary = Some("<thought>secret</thought>".into());
        assert!(validate_result(&result).is_err());
    }
}

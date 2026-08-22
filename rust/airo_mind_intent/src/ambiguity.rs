//! Ambiguity detection. Never selects a capability.

use crate::classified::{ActionReadiness, Ambiguity, ClassifiedIntent, IntentStatus};

const ACTION_VERBS: &[&str] = &[
    "prepare",
    "plan",
    "organize",
    "schedule",
    "arrange",
    "get ready",
];
const TIME_CUES: &[&str] = &[
    "tomorrow",
    "today",
    "tonight",
    "this week",
    "this morning",
    "this afternoon",
];
const QUESTION_CUES: &[&str] = &["?", "why ", "what ", "how ", "when ", "where ", "who "];
const GREETING_CUES: &[&str] = &["hi", "hello", "hey", "thanks", "thank you"];

pub fn apply_legacy_gate(intent: &mut ClassifiedIntent, user_query: &str) {
    if intent.capability != "general.chat" {
        return;
    }
    let lowered = user_query.trim().to_ascii_lowercase();
    if lowered.is_empty() || looks_like_chat(&lowered) {
        intent.status = IntentStatus::Classified;
        intent.action_readiness = ActionReadiness::execute();
        return;
    }
    if looks_underspecified_action(&lowered) {
        intent.status = IntentStatus::NeedsClarification;
        intent.action_readiness = ActionReadiness::clarify();
        intent.requirements.requires_user_input = true;
        intent.requirements.missing_information = vec!["planning_type".into()];
        intent.ambiguity = Ambiguity {
            is_ambiguous: true,
            kind: Some("domain".into()),
            candidates: vec![
                "planning.create".into(),
                "calendar.retrieve".into(),
                "diet.plan".into(),
            ],
            reason: Some("domain_ambiguity".into()),
            clarification: Some(
                "Do you mean planning your day, scheduling something on your calendar, or preparing a diet/meal plan?".into(),
            ),
        };
        return;
    }
    intent.status = IntentStatus::Classified;
    intent.action_readiness = ActionReadiness::execute();
}

fn looks_like_chat(lowered: &str) -> bool {
    QUESTION_CUES.iter().any(|cue| lowered.contains(cue))
        || GREETING_CUES
            .iter()
            .any(|cue| lowered == *cue || lowered.starts_with(&format!("{cue} ")))
}

fn looks_underspecified_action(lowered: &str) -> bool {
    let action = ACTION_VERBS.iter().any(|verb| lowered.contains(verb));
    let when = TIME_CUES.iter().any(|cue| lowered.contains(cue));
    action && when
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::legacy::from_legacy;

    #[test]
    fn prepare_for_tomorrow_asks() {
        let intent = from_legacy("conversation", 0.25, "I need to prepare for tomorrow.");
        assert_eq!(intent.status, IntentStatus::NeedsClarification);
        assert!(!intent.action_readiness.ready);
        assert_eq!(intent.ambiguity.candidates.len(), 3);
        assert!(intent
            .ambiguity
            .clarification
            .as_deref()
            .unwrap()
            .contains("diet/meal plan"));
    }

    #[test]
    fn why_is_the_sky_blue_is_chat() {
        let intent = from_legacy("conversation", 0.3, "Why is the sky blue?");
        assert_eq!(intent.status, IntentStatus::Classified);
        assert!(intent.action_readiness.ready);
        assert_eq!(intent.capability, "general.chat");
    }
}

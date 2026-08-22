//! Action readiness. Inference is not authorization.

use crate::classified::{ActionReadiness, ClassifiedIntent, IntentStatus};

pub const CONFIDENCE_THRESHOLD: f32 = 0.70;
pub const MARGIN_THRESHOLD: f32 = 0.10;

pub fn apply_readiness(intent: &mut ClassifiedIntent) {
    if intent.status == IntentStatus::Rejected {
        intent.action_readiness = ActionReadiness {
            ready: false,
            requires_confirmation: false,
            requires_clarification: false,
        };
        return;
    }
    if intent.status == IntentStatus::NeedsClarification
        || intent.action_readiness.requires_clarification
        || intent.ambiguity.is_ambiguous
    {
        intent.status = IntentStatus::NeedsClarification;
        intent.action_readiness = ActionReadiness::clarify();
        return;
    }
    if !passes_confidence(intent) && intent.capability != "general.chat" {
        intent.status = IntentStatus::NeedsClarification;
        intent.action_readiness = ActionReadiness::clarify();
        if intent.ambiguity.clarification.is_none() {
            intent.ambiguity.is_ambiguous = true;
            intent.ambiguity.reason = Some("low_confidence".into());
            intent.ambiguity.clarification = Some(
                "I am not sure what you want me to do. Could you say it more specifically?".into(),
            );
        }
        return;
    }
    intent.action_readiness = ActionReadiness::execute();
    intent.status = IntentStatus::Classified;
}

fn passes_confidence(intent: &ClassifiedIntent) -> bool {
    if intent.confidence.overall < CONFIDENCE_THRESHOLD {
        return false;
    }
    let margin = (intent.confidence.intent - intent.confidence.entities).abs();
    margin >= MARGIN_THRESHOLD || intent.confidence.intent >= 0.9
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::legacy::from_legacy;

    #[test]
    fn clear_diet_plan_is_ready() {
        let mut intent = from_legacy("diet", 0.85, "Create a 7-day vegetarian meal plan.");
        apply_readiness(&mut intent);
        assert_eq!(intent.status, IntentStatus::Classified);
        assert!(intent.action_readiness.ready);
    }

    #[test]
    fn ambiguous_prepare_is_not_ready() {
        let mut intent = from_legacy("conversation", 0.25, "I need to prepare for tomorrow.");
        apply_readiness(&mut intent);
        assert_eq!(intent.status, IntentStatus::NeedsClarification);
        assert!(!intent.action_readiness.ready);
    }
}

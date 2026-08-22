//! Routes ClassifiedIntent through the registry. Never reads the user string.

use crate::capability::CapabilityRegistry;
use crate::classified::{ClassifiedIntent, IntentStatus};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Route {
    pub capability: String,
    pub orchestrator: String,
    pub model_profile: String,
}

pub fn route(intent: &ClassifiedIntent) -> Option<Route> {
    if intent.status != IntentStatus::Classified || !intent.action_readiness.ready {
        return None;
    }
    let registry = CapabilityRegistry::builtin();
    let cap = registry.get(&intent.capability)?;
    Some(Route {
        capability: cap.id.into(),
        orchestrator: cap.orchestrator.into(),
        model_profile: cap.model_profile.into(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::legacy::from_legacy;
    use crate::readiness::apply_readiness;

    #[test]
    fn router_does_not_inspect_plan_in_the_query() {
        let mut intent = from_legacy("navigation", 0.2, "plan my budget");
        apply_readiness(&mut intent);
        let routed = route(&intent).expect("navigation is ready");
        assert_eq!(routed.capability, "general.navigate");
        assert_eq!(routed.orchestrator, "general");
    }

    #[test]
    fn unclear_intent_does_not_route() {
        let mut intent = from_legacy("conversation", 0.25, "I need to prepare for tomorrow.");
        apply_readiness(&mut intent);
        assert!(route(&intent).is_none());
    }
}

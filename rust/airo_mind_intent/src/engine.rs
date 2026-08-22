//! Classify → validate → readiness → route.
//!
//! A permanent analyzer proposal wins when it validates. Otherwise the
//! legacy kind adapter hydrates the contract. Legacy cannot define routes.

use crate::classified::{ClassifiedIntent, IntentSource, IntentStatus};
use crate::legacy::from_legacy;
use crate::readiness::apply_readiness;
use crate::router::{route, Route};
use crate::validator::validate_intent;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct ClassifyRequest {
    pub user_query: String,
    pub legacy_kind: Option<String>,
    pub legacy_complexity: Option<f32>,
    pub proposal: Option<ClassifiedIntent>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct RouteDecision {
    pub status: IntentStatus,
    pub route: Option<Route>,
    pub intent: ClassifiedIntent,
}

pub fn classify(request: ClassifyRequest) -> RouteDecision {
    let mut intent = match request.proposal {
        Some(proposal) if validate_intent(&proposal).is_ok() => {
            let mut accepted = proposal;
            accepted.source = IntentSource::Analyzer;
            accepted
        }
        _ => from_legacy(
            request.legacy_kind.as_deref().unwrap_or("conversation"),
            request.legacy_complexity.unwrap_or(0.0),
            &request.user_query,
        ),
    };
    if validate_intent(&intent).is_err() {
        intent = from_legacy(
            request.legacy_kind.as_deref().unwrap_or("conversation"),
            request.legacy_complexity.unwrap_or(0.0),
            &request.user_query,
        );
        if validate_intent(&intent).is_err() {
            intent.status = IntentStatus::Rejected;
            intent.action_readiness.ready = false;
            return RouteDecision {
                status: IntentStatus::Rejected,
                route: None,
                intent,
            };
        }
    }
    apply_readiness(&mut intent);
    let routed = route(&intent);
    RouteDecision {
        status: intent.status,
        route: routed,
        intent,
    }
}

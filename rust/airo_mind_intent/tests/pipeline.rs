//! End-to-end contract: analyzer vs legacy, no keyword routing, no invented caps.

use airo_mind_intent::{
    classify, from_legacy, validate_intent, CapabilityRegistry, ClassifyRequest, IntentSource,
    IntentStatus, SCHEMA_VERSION,
};

#[test]
fn diet_plan_routes_to_diet_not_planning() {
    let decision = classify(ClassifyRequest {
        user_query: "Create a 7-day vegetarian meal plan.".into(),
        legacy_kind: Some("diet".into()),
        legacy_complexity: Some(0.85),
        proposal: None,
    });
    assert_eq!(decision.status, IntentStatus::Classified);
    let route = decision.route.expect("ready diet plan");
    assert_eq!(route.capability, "diet.plan");
    assert_eq!(route.orchestrator, "diet");
    assert_eq!(decision.intent.schema_version, SCHEMA_VERSION);
    assert_eq!(decision.intent.source, IntentSource::LegacyFallback);
}

#[test]
fn prepare_for_tomorrow_asks_instead_of_acting() {
    let decision = classify(ClassifyRequest {
        user_query: "I need to prepare for tomorrow.".into(),
        legacy_kind: Some("conversation".into()),
        legacy_complexity: Some(0.25),
        proposal: None,
    });
    assert_eq!(decision.status, IntentStatus::NeedsClarification);
    assert!(decision.route.is_none());
    assert!(decision
        .intent
        .ambiguity
        .candidates
        .contains(&"diet.plan".to_string()));
    assert!(decision
        .intent
        .ambiguity
        .clarification
        .as_deref()
        .unwrap()
        .contains("calendar"));
}

#[test]
fn query_containing_plan_does_not_become_planning() {
    let decision = classify(ClassifyRequest {
        user_query: "plan my budget".into(),
        legacy_kind: Some("navigation".into()),
        legacy_complexity: Some(0.2),
        proposal: None,
    });
    assert_eq!(decision.route.unwrap().capability, "general.navigate");
}

#[test]
fn analyzer_proposal_beats_legacy_when_it_validates() {
    let mut proposal = from_legacy("conversation", 0.2, "hi");
    proposal.capability = "research.deep".into();
    proposal.domain = "research".into();
    proposal.intent = "deep_research".into();
    proposal.action = "investigate".into();
    proposal.source = IntentSource::Analyzer;
    proposal.confidence = airo_mind_intent::Confidence::uniform(0.96);
    let decision = classify(ClassifyRequest {
        user_query: "Investigate local deep research architectures.".into(),
        legacy_kind: Some("conversation".into()),
        legacy_complexity: Some(0.2),
        proposal: Some(proposal),
    });
    assert_eq!(decision.status, IntentStatus::Classified);
    assert_eq!(decision.intent.source, IntentSource::Analyzer);
    assert_eq!(decision.route.unwrap().capability, "research.deep");
}

#[test]
fn analyzer_cannot_invent_a_capability() {
    let mut proposal = from_legacy("conversation", 0.2, "hi");
    proposal.capability = "document.magic_analysis".into();
    proposal.source = IntentSource::Analyzer;
    let decision = classify(ClassifyRequest {
        user_query: "Do magic analysis.".into(),
        legacy_kind: Some("conversation".into()),
        legacy_complexity: Some(0.2),
        proposal: Some(proposal),
    });
    assert_ne!(
        decision.intent.capability, "document.magic_analysis",
        "invented ids must not route"
    );
    assert!(CapabilityRegistry::builtin().contains(&decision.intent.capability));
}

#[test]
fn sky_blue_is_chat_and_ready() {
    let decision = classify(ClassifyRequest {
        user_query: "Why is the sky blue?".into(),
        legacy_kind: Some("conversation".into()),
        legacy_complexity: Some(0.3),
        proposal: None,
    });
    assert_eq!(decision.status, IntentStatus::Classified);
    assert_eq!(decision.route.unwrap().capability, "general.chat");
}

#[test]
fn validate_accepts_legacy_diet() {
    let intent = from_legacy("diet", 0.85, "veg plan");
    assert!(validate_intent(&intent).is_ok());
}

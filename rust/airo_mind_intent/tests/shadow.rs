//! Shadow-mode eval: leftover IntentParser kinds vs ClassifiedIntent.
//!
//! Dual-run only. Compare never routes, never invents capabilities, and never
//! deletes the parser. Product plugins stay `skill.execute`.

use airo_mind_intent::{
    classify, compare_shadow, from_capability, CapabilityRegistry, ClassifyRequest, IntentStatus,
    SHADOW_PROGRESS_PREFIX,
};

struct Case {
    prompt: &'static str,
    parser_kind: &'static str,
    parser_complexity: f32,
    analyzer_capability: Option<&'static str>,
    expect_status: IntentStatus,
    expect_capability: &'static str,
    expect_parser_capability: &'static str,
    expect_capabilities_match: bool,
}

fn cases() -> Vec<Case> {
    vec![
        Case {
            prompt: "I need to prepare for tomorrow.",
            parser_kind: "conversation",
            parser_complexity: 0.25,
            analyzer_capability: None,
            expect_status: IntentStatus::NeedsClarification,
            expect_capability: "general.chat",
            expect_parser_capability: "general.chat",
            expect_capabilities_match: true,
        },
        Case {
            prompt: "Why is the sky blue?",
            parser_kind: "conversation",
            parser_complexity: 0.3,
            analyzer_capability: None,
            expect_status: IntentStatus::Classified,
            expect_capability: "general.chat",
            expect_parser_capability: "general.chat",
            expect_capabilities_match: true,
        },
        Case {
            prompt: "Make me a 7 day vegetarian diet plan",
            parser_kind: "skill",
            parser_complexity: 0.85,
            analyzer_capability: None,
            expect_status: IntentStatus::Classified,
            expect_capability: "skill.execute",
            expect_parser_capability: "skill.execute",
            expect_capabilities_match: true,
        },
        Case {
            prompt: "Create a meal plan",
            parser_kind: "skill",
            parser_complexity: 0.85,
            analyzer_capability: None,
            expect_status: IntentStatus::Classified,
            expect_capability: "skill.execute",
            expect_parser_capability: "skill.execute",
            expect_capabilities_match: true,
        },
        Case {
            prompt: "plan my budget",
            parser_kind: "navigation",
            parser_complexity: 0.2,
            analyzer_capability: None,
            expect_status: IntentStatus::Classified,
            expect_capability: "general.navigate",
            expect_parser_capability: "general.navigate",
            expect_capabilities_match: true,
        },
        Case {
            prompt: "plan my budget",
            parser_kind: "navigation",
            parser_complexity: 0.2,
            analyzer_capability: Some("planning.create"),
            expect_status: IntentStatus::Classified,
            expect_capability: "planning.create",
            expect_parser_capability: "general.navigate",
            expect_capabilities_match: false,
        },
    ]
}

#[test]
fn leftover_parser_kinds_are_compared_not_rerouted() {
    for case in cases() {
        let proposal = case
            .analyzer_capability
            .and_then(|id| from_capability(id, case.prompt, 0.88));
        let decision = classify(ClassifyRequest {
            user_query: case.prompt.into(),
            legacy_kind: Some(case.parser_kind.into()),
            legacy_complexity: Some(case.parser_complexity),
            proposal,
        });
        assert_eq!(
            decision.status, case.expect_status,
            "status for {:?}",
            case.prompt
        );
        assert_eq!(
            decision.intent.capability, case.expect_capability,
            "classified capability for {:?}",
            case.prompt
        );
        assert_ne!(
            decision.intent.capability, "diet.plan",
            "product plugins are not registry domains: {:?}",
            case.prompt
        );
        assert!(!CapabilityRegistry::builtin().contains("diet.plan"));

        let shadow = compare_shadow(case.parser_kind, &decision.intent);
        assert_eq!(shadow.parser_kind, case.parser_kind);
        assert_eq!(shadow.parser_capability, case.expect_parser_capability);
        assert_eq!(shadow.classified_capability, case.expect_capability);
        assert_eq!(shadow.classified_status, case.expect_status);
        assert_eq!(
            shadow.capabilities_match, case.expect_capabilities_match,
            "match for {:?}",
            case.prompt
        );
        assert_eq!(
            decision.intent.capability, case.expect_capability,
            "shadow must not change the classify route for {:?}",
            case.prompt
        );

        let encoded = shadow.encode_progress();
        assert!(encoded.starts_with(SHADOW_PROGRESS_PREFIX), "{encoded}");
        assert!(encoded.contains(case.parser_kind), "{encoded}");
        assert!(encoded.contains(case.expect_capability), "{encoded}");
        assert!(!encoded.contains("diet.plan"), "{encoded}");
        assert!(!encoded.contains("thoughts"), "{encoded}");
    }
}

#[test]
fn leftover_diet_kind_aliases_to_skill_execute_in_shadow() {
    let decision = classify(ClassifyRequest {
        user_query: "veg plan".into(),
        legacy_kind: Some("diet".into()),
        legacy_complexity: Some(0.85),
        proposal: None,
    });
    let shadow = compare_shadow("diet", &decision.intent);
    assert_eq!(shadow.parser_capability, "skill.execute");
    assert_eq!(shadow.classified_capability, "skill.execute");
    assert_eq!(shadow.classified_kind, "skill");
    assert!(shadow.capabilities_match);
    assert!(!shadow.kinds_match);
}

#[test]
fn invented_diet_plan_proposal_does_not_win_shadow_or_route() {
    let decision = classify(ClassifyRequest {
        user_query: "Create a meal plan".into(),
        legacy_kind: Some("skill".into()),
        legacy_complexity: Some(0.85),
        proposal: from_capability("diet.plan", "Create a meal plan", 0.99),
    });
    assert_eq!(decision.intent.capability, "skill.execute");
    let shadow = compare_shadow("skill", &decision.intent);
    assert!(shadow.capabilities_match);
    assert_eq!(shadow.classified_capability, "skill.execute");
}

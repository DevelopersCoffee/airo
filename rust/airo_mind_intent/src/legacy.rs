//! Legacy kind → ClassifiedIntent. Cannot invent capabilities.

use std::collections::BTreeMap;

use crate::capability::CapabilityRegistry;
use crate::classified::{
    ActionReadiness, Ambiguity, ClassifiedIntent, Confidence, IntentContext, IntentSource,
    IntentStatus, Requirements, SCHEMA_VERSION,
};

struct LegacyMap {
    kind: &'static str,
    capability: &'static str,
    complexity: f32,
}

const LEGACY: &[LegacyMap] = &[
    LegacyMap {
        kind: "calendar_retrieval",
        capability: "calendar.retrieve",
        complexity: 0.1,
    },
    LegacyMap {
        kind: "time_query",
        capability: "time.query",
        complexity: 0.05,
    },
    LegacyMap {
        kind: "date_query",
        capability: "time.query",
        complexity: 0.05,
    },
    LegacyMap {
        kind: "play_media",
        capability: "media.play",
        complexity: 0.2,
    },
    LegacyMap {
        kind: "toggle_setting",
        capability: "settings.toggle",
        complexity: 0.2,
    },
    LegacyMap {
        kind: "navigation",
        capability: "general.navigate",
        complexity: 0.2,
    },
    LegacyMap {
        kind: "planning",
        capability: "planning.create",
        complexity: 0.85,
    },
    LegacyMap {
        kind: "skill",
        capability: "skill.execute",
        complexity: 0.85,
    },
    // Temporary kind alias from ADR-0003 Phase 1. Not a framework capability.
    LegacyMap {
        kind: "diet",
        capability: "skill.execute",
        complexity: 0.85,
    },
    LegacyMap {
        kind: "summarization",
        capability: "document.summarize",
        complexity: 0.55,
    },
    LegacyMap {
        kind: "conversation",
        capability: "general.chat",
        complexity: 0.25,
    },
];

pub fn from_legacy(kind: &str, complexity: f32, user_query: &str) -> ClassifiedIntent {
    let registry = CapabilityRegistry::builtin();
    let mapped = LEGACY.iter().find(|row| row.kind == kind);
    let (capability_id, default_complexity) = match mapped {
        Some(row) => (row.capability, row.complexity),
        None => ("general.chat", 0.25),
    };
    let cap = registry
        .get(capability_id)
        .expect("legacy map only names registered capabilities");
    let complexity = if complexity > 0.0 {
        complexity.clamp(0.0, 1.0)
    } else {
        default_complexity
    };
    let known = mapped.is_some() && kind != "conversation";
    let mut intent = ClassifiedIntent {
        schema_version: SCHEMA_VERSION.into(),
        status: IntentStatus::Classified,
        domain: cap.domain.into(),
        intent: cap.intent.into(),
        action: cap.action.into(),
        capability: cap.id.into(),
        entities: BTreeMap::new(),
        constraints: BTreeMap::new(),
        context: IntentContext::default(),
        requirements: Requirements {
            reasoning: cap.reasoning,
            tools: cap.tools,
            retrieval: cap.direct_lookup,
            ..Requirements::default()
        },
        confidence: if known {
            Confidence::uniform(0.92)
        } else {
            Confidence::uniform(0.45)
        },
        action_readiness: ActionReadiness::execute(),
        ambiguity: Ambiguity::default(),
        model_profile: cap.model_profile.into(),
        kind: if kind == "diet" {
            "skill".into()
        } else if mapped.is_some() {
            kind.into()
        } else {
            "conversation".into()
        },
        complexity,
        source: IntentSource::LegacyFallback,
    };
    crate::ambiguity::apply_legacy_gate(&mut intent, user_query);
    if kind == "diet" {
        intent
            .entities
            .insert("skill_id".into(), "diet_plan".into());
    }
    intent
}

/// Analyzer hydrate. Registry only — invented ids return `None`.
pub fn from_capability(id: &str, user_query: &str, confidence: f32) -> Option<ClassifiedIntent> {
    let registry = CapabilityRegistry::builtin();
    let cap = registry.get(id)?;
    let kind = kind_for_capability(id);
    let complexity = default_complexity(cap.id, cap.direct_lookup);
    let conf = confidence.clamp(0.0, 1.0);
    let mut intent = ClassifiedIntent {
        schema_version: SCHEMA_VERSION.into(),
        status: IntentStatus::Classified,
        domain: cap.domain.into(),
        intent: cap.intent.into(),
        action: cap.action.into(),
        capability: cap.id.into(),
        entities: BTreeMap::new(),
        constraints: BTreeMap::new(),
        context: IntentContext::default(),
        requirements: Requirements {
            reasoning: cap.reasoning,
            tools: cap.tools,
            retrieval: cap.direct_lookup,
            ..Requirements::default()
        },
        confidence: Confidence {
            overall: conf,
            intent: 0.92,
            entities: 0.45,
            routing: conf,
            requirement: 0.80,
        },
        action_readiness: ActionReadiness::execute(),
        ambiguity: Ambiguity::default(),
        model_profile: cap.model_profile.into(),
        kind: kind.into(),
        complexity,
        source: IntentSource::Analyzer,
    };
    crate::ambiguity::apply_legacy_gate(&mut intent, user_query);
    Some(intent)
}

fn kind_for_capability(id: &str) -> &'static str {
    LEGACY
        .iter()
        .find(|row| row.capability == id && row.kind != "diet" && row.kind != "date_query")
        .map(|row| row.kind)
        .unwrap_or("conversation")
}

fn default_complexity(capability_id: &str, direct_lookup: bool) -> f32 {
    if direct_lookup {
        return 0.1;
    }
    match capability_id {
        "planning.create" | "research.deep" | "skill.execute" => 0.85,
        "document.summarize" => 0.55,
        _ => 0.25,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn unknown_kind_does_not_invent_a_capability() {
        let intent = from_legacy("document.magic_analysis", 0.9, "do magic");
        assert_eq!(intent.capability, "general.chat");
        assert_eq!(intent.kind, "conversation");
        assert_eq!(intent.source, IntentSource::LegacyFallback);
        assert!(CapabilityRegistry::builtin().contains(&intent.capability));
    }

    #[test]
    fn product_plugin_uses_generic_skill_not_a_diet_capability() {
        let intent = from_legacy("skill", 0.85, "Create a 7-day vegetarian meal plan.");
        assert_eq!(intent.capability, "skill.execute");
        assert_eq!(intent.domain, "skill");
        assert_eq!(intent.kind, "skill");
        assert_eq!(intent.status, IntentStatus::Classified);
        assert!(intent.action_readiness.ready);
        assert!(!CapabilityRegistry::builtin().contains("diet.plan"));
    }

    #[test]
    fn leftover_diet_kind_aliases_to_skill_execute() {
        let intent = from_legacy("diet", 0.85, "veg plan");
        assert_eq!(intent.capability, "skill.execute");
        assert_eq!(intent.kind, "skill");
        assert_eq!(
            intent.entities.get("skill_id").map(String::as_str),
            Some("diet_plan")
        );
    }

    #[test]
    fn analyzer_capability_hydrates_from_the_registry() {
        let intent = from_capability("planning.create", "Plan the week.", 0.88).unwrap();
        assert_eq!(intent.capability, "planning.create");
        assert_eq!(intent.domain, "planning");
        assert_eq!(intent.kind, "planning");
        assert_eq!(intent.source, IntentSource::Analyzer);
        assert_eq!(intent.status, IntentStatus::Classified);
        assert!(intent.action_readiness.ready);
    }

    #[test]
    fn analyzer_cannot_invent_a_diet_capability() {
        assert!(from_capability("diet.plan", "veg plan", 0.99).is_none());
    }

    #[test]
    fn analyzer_chat_on_underspecified_action_still_asks() {
        let intent =
            from_capability("general.chat", "I need to prepare for tomorrow.", 0.80).unwrap();
        assert_eq!(intent.status, IntentStatus::NeedsClarification);
        assert!(!intent.action_readiness.ready);
    }
}

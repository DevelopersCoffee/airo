//! Registry is the source of truth. Analyzers must not invent ids.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Capability {
    pub id: &'static str,
    pub domain: &'static str,
    pub intent: &'static str,
    pub action: &'static str,
    pub orchestrator: &'static str,
    pub model_profile: &'static str,
    pub direct_lookup: bool,
    pub reasoning: bool,
    pub tools: bool,
}

#[derive(Clone, Debug)]
pub struct CapabilityRegistry {
    caps: Vec<Capability>,
}

impl CapabilityRegistry {
    pub fn builtin() -> Self {
        Self {
            caps: vec![
                cap(
                    "calendar.retrieve",
                    "calendar",
                    "event_retrieval",
                    "retrieve",
                    "calendar",
                    "fast",
                    true,
                    false,
                    true,
                ),
                cap(
                    "time.query",
                    "time",
                    "time_query",
                    "retrieve",
                    "calendar",
                    "fast",
                    true,
                    false,
                    false,
                ),
                cap(
                    "media.play",
                    "media",
                    "playback",
                    "play",
                    "media",
                    "fast",
                    true,
                    false,
                    true,
                ),
                cap(
                    "settings.toggle",
                    "settings",
                    "device_toggle",
                    "toggle",
                    "settings",
                    "fast",
                    true,
                    false,
                    true,
                ),
                cap(
                    "general.navigate",
                    "general",
                    "navigate",
                    "open",
                    "general",
                    "fast",
                    true,
                    false,
                    false,
                ),
                cap(
                    "general.chat",
                    "general",
                    "chat",
                    "respond",
                    "general",
                    "fast-structured",
                    false,
                    true,
                    false,
                ),
                cap(
                    "planning.create",
                    "planning",
                    "task_plan",
                    "create",
                    "planning",
                    "reasoning",
                    false,
                    true,
                    false,
                ),
                cap(
                    "diet.plan",
                    "diet",
                    "meal_plan",
                    "create",
                    "diet",
                    "reasoning",
                    false,
                    true,
                    false,
                ),
                cap(
                    "document.summarize",
                    "document",
                    "summarize",
                    "summarize",
                    "document",
                    "long-context",
                    false,
                    true,
                    false,
                ),
                cap(
                    "research.deep",
                    "research",
                    "deep_research",
                    "investigate",
                    "research",
                    "reasoning",
                    false,
                    true,
                    true,
                ),
            ],
        }
    }

    pub fn get(&self, id: &str) -> Option<&Capability> {
        self.caps.iter().find(|c| c.id == id)
    }

    pub fn contains(&self, id: &str) -> bool {
        self.get(id).is_some()
    }

    pub fn ids(&self) -> impl Iterator<Item = &'static str> + '_ {
        self.caps.iter().map(|c| c.id)
    }
}

#[allow(clippy::too_many_arguments)]
fn cap(
    id: &'static str,
    domain: &'static str,
    intent: &'static str,
    action: &'static str,
    orchestrator: &'static str,
    model_profile: &'static str,
    direct_lookup: bool,
    reasoning: bool,
    tools: bool,
) -> Capability {
    Capability {
        id,
        domain,
        intent,
        action,
        orchestrator,
        model_profile,
        direct_lookup,
        reasoning,
        tools,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn registry_ids_are_unique_and_include_diet() {
        let registry = CapabilityRegistry::builtin();
        let mut ids: Vec<_> = registry.ids().collect();
        let before = ids.len();
        ids.sort();
        ids.dedup();
        assert_eq!(ids.len(), before);
        assert!(registry.contains("diet.plan"));
        assert!(registry.contains("planning.create"));
        assert!(registry.contains("research.deep"));
        assert!(!registry.contains("document.magic_analysis"));
    }
}

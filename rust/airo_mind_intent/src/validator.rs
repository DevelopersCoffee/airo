//! Schema + registry + consistency. Does not inspect the user string.

use crate::capability::CapabilityRegistry;
use crate::classified::{ClassifiedIntent, SCHEMA_VERSION};

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ValidationError {
    UnsupportedSchema,
    UnknownCapability,
    TaxonomyMismatch,
    InventedCapability,
}

pub fn validate_intent(intent: &ClassifiedIntent) -> Result<(), ValidationError> {
    if intent.schema_version != SCHEMA_VERSION {
        return Err(ValidationError::UnsupportedSchema);
    }
    let registry = CapabilityRegistry::builtin();
    let Some(cap) = registry.get(&intent.capability) else {
        return Err(ValidationError::UnknownCapability);
    };
    if intent.domain != cap.domain || intent.action != cap.action || intent.intent != cap.intent {
        return Err(ValidationError::TaxonomyMismatch);
    }
    if matches!(
        intent.source,
        crate::classified::IntentSource::LegacyFallback
    ) && !legacy_may_emit(&intent.capability)
    {
        return Err(ValidationError::InventedCapability);
    }
    Ok(())
}

fn legacy_may_emit(capability: &str) -> bool {
    !matches!(capability, "research.deep")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::legacy::from_legacy;

    #[test]
    fn invented_capability_is_rejected() {
        let mut intent = from_legacy("conversation", 0.2, "hi");
        intent.capability = "document.magic_analysis".into();
        assert_eq!(
            validate_intent(&intent),
            Err(ValidationError::UnknownCapability)
        );
    }

    #[test]
    fn diet_plan_is_not_a_framework_capability() {
        let mut intent = from_legacy("skill", 0.85, "veg plan");
        intent.capability = "diet.plan".into();
        intent.domain = "diet".into();
        intent.intent = "meal_plan".into();
        intent.action = "create".into();
        assert_eq!(
            validate_intent(&intent),
            Err(ValidationError::UnknownCapability)
        );
    }

    #[test]
    fn legacy_cannot_emit_research_deep() {
        let mut intent = from_legacy("conversation", 0.2, "hi");
        intent.capability = "research.deep".into();
        intent.domain = "research".into();
        intent.intent = "deep_research".into();
        intent.action = "investigate".into();
        assert_eq!(
            validate_intent(&intent),
            Err(ValidationError::InventedCapability)
        );
    }
}

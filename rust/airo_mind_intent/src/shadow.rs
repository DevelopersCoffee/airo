//! Shadow-mode dual-run: leftover IntentParser kind vs ClassifiedIntent.
//!
//! Compare never routes. The parser stays until evals say otherwise.

use crate::classified::{ClassifiedIntent, IntentStatus};
use crate::legacy::capability_for_legacy_kind;

/// Folded by Flutter into telemetry, never a thinking step.
pub const SHADOW_PROGRESS_PREFIX: &str = "shadow:";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ShadowCompare {
    pub parser_kind: String,
    pub parser_capability: String,
    pub classified_kind: String,
    pub classified_capability: String,
    pub classified_status: IntentStatus,
    pub kinds_match: bool,
    pub capabilities_match: bool,
}

/// Log-only. Inspects the leftover kind and the gated contract — never the
/// user string, and never changes [`crate::classify`].
pub fn compare_shadow(parser_kind: &str, classified: &ClassifiedIntent) -> ShadowCompare {
    let parser_capability = capability_for_legacy_kind(parser_kind);
    ShadowCompare {
        parser_kind: parser_kind.to_string(),
        parser_capability: parser_capability.to_string(),
        classified_kind: classified.kind.clone(),
        classified_capability: classified.capability.clone(),
        classified_status: classified.status,
        kinds_match: parser_kind == classified.kind,
        capabilities_match: parser_capability == classified.capability,
    }
}

impl ShadowCompare {
    pub fn encode_progress(&self) -> String {
        let match_bit = if self.capabilities_match { "1" } else { "0" };
        format!(
            "{SHADOW_PROGRESS_PREFIX}{}|{}|{}|{}|{}|{match_bit}",
            self.parser_kind,
            self.parser_capability,
            self.classified_kind,
            self.classified_capability,
            status_token(self.classified_status),
        )
    }
}

fn status_token(status: IntentStatus) -> &'static str {
    match status {
        IntentStatus::Classified => "classified",
        IntentStatus::NeedsClarification => "needs_clarification",
        IntentStatus::Rejected => "rejected",
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::legacy::from_legacy;

    #[test]
    fn encode_round_trips_the_leftover_without_a_user_string() {
        let classified = from_legacy("conversation", 0.3, "Why is the sky blue?");
        let shadow = compare_shadow("conversation", &classified);
        assert!(shadow.capabilities_match);
        assert_eq!(
            shadow.encode_progress(),
            "shadow:conversation|general.chat|conversation|general.chat|classified|1"
        );
    }
}

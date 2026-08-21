//! How hard this request is allowed to think.
//!
//! Ordered so a device profile can clamp with `min`. `None` is not "no answer"
//! — it is "do not spend a reasoning pass": lookup, one tool, or a direct
//! reply.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReasoningLevel {
    #[default]
    None,
    Light,
    Standard,
    Deep,
}

impl ReasoningLevel {
    /// Drop one step. `None` stays `None`.
    pub fn downgrade(self) -> Self {
        match self {
            Self::Deep => Self::Standard,
            Self::Standard => Self::Light,
            Self::Light => Self::None,
            Self::None => Self::None,
        }
    }

    pub fn clamp_to(self, max: Self) -> Self {
        self.min(max)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ordering_matches_cost() {
        assert!(ReasoningLevel::None < ReasoningLevel::Light);
        assert!(ReasoningLevel::Light < ReasoningLevel::Standard);
        assert!(ReasoningLevel::Standard < ReasoningLevel::Deep);
    }

    #[test]
    fn clamp_never_exceeds_device_max() {
        assert_eq!(
            ReasoningLevel::Deep.clamp_to(ReasoningLevel::Light),
            ReasoningLevel::Light
        );
    }
}

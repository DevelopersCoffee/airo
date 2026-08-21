//! Wire intent for reasoning. Not a copy of Dart `IntentType`.
//!
//! The Flutter keyword map stays a stopgap classifier. This crate only sees
//! a kind string plus a complexity score so policy is not `query.contains`.

use serde::{Deserialize, Serialize};

/// Kinds the first policy treats as direct lookup (`ReasoningLevel::None`).
pub const DIRECT_LOOKUP_KINDS: &[&str] = &[
    "calendar_retrieval",
    "time_query",
    "date_query",
    "play_media",
    "toggle_setting",
    "navigation",
];

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ClassifiedIntent {
    /// Stable kind, e.g. `calendar_retrieval`, `planning`, `summarization`.
    pub kind: String,
    /// 0.0 ..= 1.0. Callers that do not score complexity send 0.0.
    pub complexity: f32,
}

impl ClassifiedIntent {
    pub fn new(kind: impl Into<String>, complexity: f32) -> Self {
        Self {
            kind: kind.into(),
            complexity: complexity.clamp(0.0, 1.0),
        }
    }

    pub fn is_direct_lookup(&self) -> bool {
        DIRECT_LOOKUP_KINDS.iter().any(|k| *k == self.kind)
    }
}

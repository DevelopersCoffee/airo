//! Compatibility re-export. The contract lives in `airo_mind_intent`.

pub use airo_mind_intent::ClassifiedIntent;

/// Kinds the first policy treated as direct lookup. Prefer
/// [`ClassifiedIntent::is_direct_lookup`], which reads the capability registry.
pub const DIRECT_LOOKUP_KINDS: &[&str] = &[
    "calendar_retrieval",
    "time_query",
    "date_query",
    "play_media",
    "toggle_setting",
    "navigation",
];

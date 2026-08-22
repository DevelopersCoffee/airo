//! Airo Mind intent contract.
//!
//! Same layer as `airo_mind_meeting` / `airo_mind_reasoning`: a capability
//! crate above `C5`. The router never inspects the user string. Keyword
//! `IntentParser` may only hydrate [`ClassifiedIntent`] against the registry.

pub mod ambiguity;
pub mod capability;
pub mod classified;
pub mod engine;
pub mod legacy;
pub mod readiness;
pub mod router;
pub mod shadow;
pub mod validator;

pub use capability::{Capability, CapabilityRegistry};
pub use classified::{
    ActionReadiness, Ambiguity, ClassifiedIntent, Confidence, IntentContext, IntentSource,
    IntentStatus, Requirements, SCHEMA_VERSION,
};
pub use engine::{classify, ClassifyRequest, RouteDecision};
pub use legacy::{capability_for_legacy_kind, from_capability, from_legacy};
pub use router::route;
pub use shadow::{compare_shadow, ShadowCompare, SHADOW_PROGRESS_PREFIX};
pub use validator::validate_intent;

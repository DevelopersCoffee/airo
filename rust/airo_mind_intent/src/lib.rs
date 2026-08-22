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
pub mod validator;

pub use capability::{Capability, CapabilityRegistry};
pub use classified::{
    ActionReadiness, Ambiguity, ClassifiedIntent, Confidence, IntentContext, IntentSource,
    IntentStatus, Requirements, SCHEMA_VERSION,
};
pub use engine::{classify, ClassifyRequest, RouteDecision};
pub use legacy::from_legacy;
pub use router::route;
pub use validator::validate_intent;

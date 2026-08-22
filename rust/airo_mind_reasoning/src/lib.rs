#![deny(unsafe_code)]
//! Airo Mind Reasoning capability.
//!
//! Same layer as `airo_mind_meeting`: owns policy, prompt, grammar, parse and
//! validation; drives a `&dyn GenerationEngine` it does not construct. The
//! runtime stays domain-free (`C5`). Flutter never calculates a reasoning
//! level — it consumes [`ReasoningEvent`].
//!
//! Chain-of-thought is not a public field. The result envelope admits
//! `answer`, `reasoning_summary`, `confidence`, and optional `tool_calls`.

pub mod context;
pub mod device;
pub mod engine;
pub mod error;
pub mod event;
pub mod grammar;
pub mod intent;
pub mod level;
pub mod parser;
pub mod policy;
pub mod prompt;
pub mod request;
pub mod result;
pub mod tools;
pub mod validator;

pub use context::{ContextItem, ContextLimits, ReasoningContext};
pub use device::DeviceInferenceProfile;
pub use engine::ReasoningEngine;
pub use error::ReasoningError;
pub use event::{ReasoningEvent, ReasoningStage};
pub use grammar::RESULT_GRAMMAR;
pub use intent::ClassifiedIntent;
pub use level::ReasoningLevel;
pub use policy::{HeuristicReasoningPolicy, ReasoningPolicy};
pub use prompt::MAX_ENVELOPE_SHOTS;
pub use request::{ReasoningRequest, ToolDefinition};
pub use result::{ReasoningResult, ToolCall};
pub use tools::{ToolExecutor, MAX_TOOL_ITERATIONS};

#![forbid(unsafe_code)]
//! Airo Mind runtime — Supervisor and the inference engine boundary.
//!
//! Scope is `#1396`: execute **one** pipeline. Audio through a Speech Engine,
//! transcript through a Generation Engine. No plugin system, no generic engine
//! registry, no OCR/Vision/Translation/Retrieval.
//!
//! # What the frozen contracts already decided
//!
//! This crate implements them; it does not restate or redesign them.
//!
//! - **`C6`** — the Supervisor owns lifecycle, scheduling, cancellation, health
//!   and **memory/CPU/IO budgets**. Control plane only: no operation payload,
//!   no projection data, no key material passes through it.
//! - **`C5`** — a capability never calls an engine. It emits operations and
//!   reads projections. Nothing in this crate is reachable from a capability.
//! - **`I2` / `I4`** — an engine that writes files, emits operations, or
//!   updates projections is a defect. **Inference is pure**: input, output,
//!   resource request, nothing else.
//! - **`I7`** — streaming. An engine yields segments through a sink; it never
//!   returns a whole transcript, because a two-hour meeting does not fit the
//!   assumption that it would.
//! - **The runtime knows no domains.** There is no `Minutes` type here.
//!   `GenerationRequest` carries a prompt the *capability* built.

mod budget;
mod cancel;
mod engine;
mod supervisor;

#[cfg(feature = "llama")]
mod llama;
#[cfg(feature = "whisper")]
mod whisper;

pub use budget::{ResourceBudget, ResourceRequest};
pub use cancel::CancelToken;
pub use engine::{
    AudioInput, EngineError, GenerationChunk, GenerationEngine, GenerationRequest, SpeechEngine,
    TranscriptSegment,
};
pub use supervisor::{RuntimeError, Supervisor};

#[cfg(feature = "llama")]
pub use llama::LlamaGenerationEngine;
#[cfg(feature = "whisper")]
pub use whisper::WhisperSpeechEngine;

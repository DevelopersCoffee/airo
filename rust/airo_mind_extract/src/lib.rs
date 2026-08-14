#![deny(unsafe_code)]
//! Meeting IR schema + two-pass extraction. `#1633`, Milestone 26 Phase 2/Wave 2.
//!
//! The epic's (`#1627`) central architectural rule lives here: **the LLM
//! never summarizes the transcript directly**. What this crate produces —
//! [`schema::MeetingIr`] — is the product. A Minutes-of-Meeting document, an
//! action-item list, and search results are all projections *of the IR*,
//! never of raw transcript text (that work is `#1657`'s, downstream of this
//! crate).
//!
//! # The two passes
//!
//! 1. [`extract::extract_chunk_facts`] — one [`airo_mind_transcript::Chunk`]
//!    in, one [`schema::ChunkFacts`] out, through whatever
//!    [`airo_mind_core::LlmBackend`] the caller wired up, validated and
//!    retried against a JSON-parse + evidence-grounding check before being
//!    accepted. Not grammar-constrained by default — see
//!    [`extract::ExtractionConfig::use_gbnf_grammar`] for a real crash this
//!    discovered in the pinned `llama-cpp-2` version, and
//!    [`grammar::JSON_GRAMMAR`] for the grammar kept ready for when that's
//!    fixed.
//! 2. [`consolidate::consolidate`] — every chunk's [`schema::ChunkFacts`] in,
//!    one [`schema::MeetingIr`] out. Near-duplicate facts across chunks
//!    (the same decision restated in two overlapping chunks, per `#1632`'s
//!    ~1 minute chunk overlap) merge into one item with unioned evidence.
//!
//! # Why this crate does not link an engine
//!
//! It depends on [`airo_mind_core::LlmBackend`] — a trait object — not on
//! `airo_mind_llama` directly. Every call site hands this crate a
//! `&dyn LlmBackend`; which concrete engine that is (in production,
//! `airo_mind_llama::LlamaGenerationEngine`) is the caller's decision, not
//! this crate's. That keeps this crate's own unit tests model-free (see the
//! fake `LlmBackend` in `extract`'s tests) and keeps it from becoming a
//! second place a future backend swap has to touch.
//!
//! `tests/extraction_offline.rs` is the one place this crate DOES pull in a
//! real engine (`airo_mind_llama`, dev-dependency only, gated
//! `#[cfg(feature = "llama")]`) — the end-to-end proof against a real model,
//! same pattern as `airo_mind_llama`'s own `generation_offline.rs`.

pub mod consolidate;
pub mod extract;
pub mod grammar;
pub mod schema;

pub use consolidate::consolidate;
pub use extract::{extract_chunk_facts, ExtractError, ExtractionConfig};
pub use schema::{ActionItem, ChunkFacts, Fact, MeetingIr, MeetingMeta, SCHEMA_VERSION};

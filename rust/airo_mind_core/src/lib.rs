// `deny`, not `forbid`: see the note in each engine crate's root. This crate
// has no FFI boundary at all, so nothing here needs the allowance.
#![deny(unsafe_code)]
//! Airo Mind runtime core — Supervisor and the inference engine boundary.
//!
//! Everything here is backend-free and std-only. That is the property this
//! crate exists to hold, not an accident of what happened to be movable.
//!
//! `whisper.cpp` and `llama.cpp` each statically vendor their own copy of ggml,
//! with the same symbol names and 348 files of difference between the two
//! trees. Linking both into one library is a one-definition-rule conflict
//! between two upstream projects: Android's lld rejects it outright, and
//! Apple's linker "resolves" it by picking a definition per symbol, which is
//! worse — it produced 339 duplicate-symbol warnings and a shipping binary
//! whose ggml is chosen by link order. So each engine gets its own cdylib
//! (`airo_mind_whisper`, `airo_mind_llama`), and this crate is what they are
//! allowed to share, precisely because it links nothing native.
//!
//! Adding a dependency here is therefore not a routine change: anything that
//! pulls in a native library re-creates the conflict this split exists to
//! remove.
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

/// SHA-256 for model verification. Public to the engine crates only in the
/// sense that they are its only callers -- a hash function on a wider surface
/// invites reuse it was not reviewed for.
pub mod digest;

/// The Model Manager (`ADR-0018`). A platform service, not a Dart API: a
/// capability asks it for a task and a budget, and Flutter never sees it. It
/// stays out of any `api` module for the same reason `wav` does -- anything
/// under `api` is generated into Dart.
pub mod models;

pub mod budget;
pub mod cancel;

/// `#1295`'s capability-facing runtime API surface: `create_operation`,
/// `attach_content`, `query_projection`, `instantiate_context`, `emit_event`.
/// The only door a capability built after `#1338`'s [`notes`] should use —
/// see the module doc for what is real and what is honestly stubbed.
pub mod capability_api;

/// Content-addressed storage. `#1194`'s content-store half of `C1`: payload
/// held out of line, addressed by [`content::ContentId`].
pub mod content;
pub mod engine;

/// The in-process, non-durable event bus behind
/// [`capability_api::CapabilityApi::emit_event`]. See the module doc for
/// exactly what "non-durable" means mechanically.
pub mod event;

/// Engine lifecycle: state, dependency ordering, and graceful shutdown.
/// `#1302`'s half of `C6` — see the module docs for why this is split from
/// [`supervisor`], which owns `#1396`'s per-call job execution.
pub mod lifecycle;

/// The Notes capability (`#1338`) — the one capability the runtime skeleton
/// exercises. Emits operations, reads a projection, holds nothing durable of
/// its own.
pub mod notes;

/// The generalized projection engine. `#1195`'s condition-5 machinery:
/// [`projection::EntityGraphProjection`], the multi-capability projection
/// that proves delete-and-rebuild is a property of the engine, not an
/// accident of Notes' own shape.
pub mod projection;

/// The `Operation → Persist → Replay → Projection` substrate, formalized
/// against `C1`/`C2` for `#1194`/`#1195`, wired through
/// [`lifecycle::EngineRegistry`] rather than around it.
pub mod runtime;
pub mod search;

/// Operation signing. `#1194`'s `signature` header field — see the module
/// doc for exactly what this proves today and what it does not.
pub mod signing;
pub mod store;
pub mod supervisor;

/// The fixed, nineteen-verb runtime vocabulary `#1194`'s scope table names.
pub mod verb;

/// WAV decoding for the capability layer. A container format is an input
/// detail, not part of the runtime's surface, so it is reachable only from the
/// crate that decodes audio.
pub mod wav;

pub use budget::{ResourceBudget, ResourceRequest};
pub use cancel::CancelToken;
pub use capability_api::{
    CapabilityApi, CapabilityApiError, ContextId, CreateOperationRequest, OperationKind,
    OperationReceipt,
};
pub use content::{ContentId, ContentStore, ContentStoreError};
pub use digest::file_digest;
pub use engine::{
    AudioInput, EngineError, GenerationChunk, GenerationEngine, GenerationRequest, SpeechEngine,
    TranscriptSegment,
};
pub use event::{CapabilityEvent, EventBus};
pub use lifecycle::{
    EngineMetrics, EngineName, EngineState, GroupCommitBuffer, LifecycleError, ManagedEngine,
};
pub use notes::{Note, NotesCapability, NotesProjection, NOTES_CAPABILITY};
pub use projection::{
    encode_relation, encode_set_property, rebuild_from_scratch, ContentLedgerProjection,
    EntityGraphProjection, EntityRecord,
};
pub use runtime::{
    AppendRequest, Operation, OperationLog, OperationLogError, OperationRequest, Projection,
    ReplayVerifyError, Runtime, RuntimeApiError,
};
pub use search::{Hit, SearchIndex};
pub use signing::{DeviceKeySigner, Signer, SignerVerifier, Verifier};
pub use store::{Meeting, MeetingStore, StoreError};
pub use supervisor::{RuntimeError, Supervisor};
pub use verb::{Verb, VerbPrimitive};

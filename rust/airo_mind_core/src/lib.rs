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

pub mod bench;
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

/// `#1225`'s four capability DSLs — Graph, Workflow, View, Automation. Parse
/// and validate declarative capability data (design doc §5.1 Tier 1); does
/// not execute anything. See the module doc for the shared diagnostic type
/// and why Graph gets the deepest treatment.
pub mod dsl;
pub mod engine;
pub mod engine_log;

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

/// `#1223`'s type system: [`ontology::Primitive`] (the nine leaf value
/// types and their default merge), [`ontology::Archetype`] (the twelve
/// abstract shapes, never in user data), [`ontology::CoreEntityType`] (the
/// twelve concrete types a capability actually extends), and
/// [`ontology::EntityTypeDef`] (what a capability declares). Additive: it
/// encodes into the same `&[u8]` [`projection::encode_set_property`] already
/// accepts, and does not change [`verb::Verb`] or
/// [`projection::EntityGraphProjection`]'s wire shape — see the module doc.
pub mod ontology;

/// The generalized projection engine. `#1195`'s condition-5 machinery:
/// [`projection::EntityGraphProjection`], the multi-capability projection
/// that proves delete-and-rebuild is a property of the engine, not an
/// accident of Notes' own shape.
pub mod projection;

/// The `Operation → Persist → Replay → Projection` substrate, formalized
/// against `C1`/`C2` for `#1194`/`#1195`, wired through
/// [`lifecycle::EngineRegistry`] rather than around it.
pub mod runtime;

/// Schema fingerprint + compatibility classes (`#1226`). Turns an
/// [`ontology::EntityTypeDef`] into a stable [`schema::fingerprint`], and
/// classifies structural drift between two versions of "the same" schema as
/// [`schema::Compatibility::Compatible`] or [`schema::Compatibility::Breaking`]
/// — enforced, not just detected, at [`schema::check_replay_compatible`] /
/// [`runtime::Runtime::replay_schema_checked`].
pub mod schema;
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

/// Deep Research IR and job state. Control plane only: no HTTP, no
/// provider SDKs, no report text. Search engines implement
/// [`research::SearchEngine`] in a later I/O crate.
pub mod research;

pub use bench::{
    aggregate, aggregate_speech, audio_duration_ms, median_f64, median_u64, run_generation_bench,
    run_speech_bench, run_speech_engine_bench, sample_speech_engine, AccelBackend, BenchError,
    BenchMetadata, BenchMode, BenchProtocol, BenchReport, GpuClockControl, SpeechBenchReport,
    SpeechStats,
};
pub use budget::{ResourceBudget, ResourceRequest};
pub use cancel::CancelToken;
pub use capability_api::{
    CapabilityApi, CapabilityApiError, ContextId, CreateOperationRequest, OperationKind,
    OperationReceipt,
};
pub use content::{ContentId, ContentStore, ContentStoreError};
pub use digest::file_digest;
pub use dsl::{
    automation::{
        ActionDef, ActionKind, AutomationDef, AutomationDsl, ConditionDef, ConditionOperator,
        TriggerDef, TriggerKind,
    },
    graph::{Cardinality, GraphDsl, RelationDef},
    view::{ViewDef, ViewDsl, ViewKind},
    workflow::{TransitionDef, WorkflowDsl},
    DslError,
};
pub use engine::{
    AudioInput, EngineError, GenerationChunk, GenerationEngine, GenerationRequest, RuntimeStats,
    SpeechEngine, TranscriptSegment, TranscriptionOptions,
};
pub use engine_log::engine_native_logs_verbose;
pub use event::{CapabilityEvent, EventBus};
pub use lifecycle::{
    EngineMetrics, EngineName, EngineState, GroupCommitBuffer, LifecycleError, ManagedEngine,
};
pub use notes::{Note, NotesCapability, NotesProjection, NOTES_CAPABILITY};
pub use ontology::{
    parse_extends, validate_relation_endpoints, validate_user_facing_label, Archetype,
    CoreEntityType, EntityTypeDef, MergeStrategy, OntologyError, Primitive, Value,
};
pub use projection::{
    encode_relation, encode_set_property, rebuild_from_scratch, ContentLedgerProjection,
    ContextHypergraphProjection, ContextRecord, EntityGraphProjection, EntityRecord,
    SurvivalReport,
};
pub use research::{
    canonicalize_url, classify_url, comparison_matrix, contradiction_reasons, decide, dedupe_hits,
    delta_urls, excerpt_in_source, extract_document, extract_html, extract_markdown, extract_pdf,
    interpret, matrix_markdown, queries_for, strategy_for, topic_key, Claim, ClaimId, ClaimStatus,
    DecisionRow, Evidence, EvidenceGraph, EvidenceId, EvidenceSufficiencyPolicy, ExtractedDocument,
    InMemoryResearchLibrary, InMemoryResearchService, InterpretedGoal, MatrixCell, PlanNodeKind,
    QuerySet, ResearchBudget, ResearchCheckpoint, ResearchCommand, ResearchCompleteness,
    ResearchEngine, ResearchEvent, ResearchEventKind, ResearchIntent, ResearchJob,
    ResearchJobState, ResearchLibraryEntry, ResearchMode, ResearchPlan, ResearchPlanNode,
    ResearchProgress, ResearchRequest, ResearchStateError, ResearchStrategy, SearchEngine,
    SearchError, SearchHit, SearchPolicy, SearchRequest, SearchResponse, Source, SourceClass,
    SourceClassification, SourceContent, SourceFetcher, SourceId, SourceKind, SourceType,
    StopDecision, StoppingPolicy, TrustLevel,
};
pub use runtime::{
    AppendRequest, Operation, OperationLog, OperationLogError, OperationRequest, Projection,
    ReplayVerifyError, Runtime, RuntimeApiError,
};
pub use schema::{
    check_replay_compatible, classify, fingerprint, schema_fingerprint_id,
    split_schema_fingerprint_id, Compatibility, ReplayDecision, SchemaRegistry, SchemaViolation,
};
pub use search::{Hit, SearchIndex};
pub use signing::{DeviceKeySigner, Signer, SignerVerifier, Verifier};
pub use store::{
    ActionStatus, DecisionStatus, Meeting, MeetingActionItem, MeetingDecision, MeetingMetric,
    MeetingStore, StoreError,
};
pub use supervisor::{RuntimeError, Supervisor};
pub use verb::{Verb, VerbPrimitive};

//! Deep Research IR — typed jobs, not a research prompt.
//!
//! # Invariant
//!
//! `SEARCH ≠ RESEARCH`. Search produces candidate information. Research is
//! interpret → plan → acquire → extract → evidence → verify → iterate →
//! synthesize → provenance.

mod compare;
mod document;
mod engine;
mod evidence;
mod interpreter;
mod library;
mod planner;
mod query;
mod request;
mod search;
mod state;
mod stopping;
mod strategy;
mod trust;

pub use compare::{comparison_matrix, decide, matrix_markdown, DecisionRow, MatrixCell};
pub use document::{
    classify_url, extract_document, extract_html, extract_markdown, extract_pdf, ExtractedDocument,
    SourceClass, SourceClassification, SourceKind,
};
pub use engine::{ResearchEngine, ResearchEvent, ResearchEventKind, SourceFetcher};
pub use evidence::{
    contradiction_reasons, excerpt_in_source, Claim, ClaimId, ClaimStatus, Evidence, EvidenceGraph,
    EvidenceId, Source, SourceId, SourceType,
};
pub use interpreter::{interpret, InterpretedGoal, ResearchIntent};
pub use library::{delta_urls, topic_key, InMemoryResearchLibrary, ResearchLibraryEntry};
pub use planner::{PlanNodeKind, ResearchPlan, ResearchPlanNode};
pub use query::{queries_for, QuerySet};
pub use request::{ResearchBudget, ResearchMode, ResearchRequest, SearchPolicy};
pub use search::{
    canonicalize_url, dedupe_hits, SearchEngine, SearchError, SearchHit, SearchRequest,
    SearchResponse,
};
pub use state::{
    InMemoryResearchService, ResearchCheckpoint, ResearchCommand, ResearchJob, ResearchJobState,
    ResearchStateError,
};
pub use stopping::{
    EvidenceSufficiencyPolicy, ResearchCompleteness, ResearchProgress, StopDecision, StoppingPolicy,
};
pub use strategy::{strategy_for, ResearchStrategy};
pub use trust::{SourceContent, TrustLevel};

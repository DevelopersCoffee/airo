//! Deep Research IR — typed jobs, not a research prompt.
//!
//! # Invariant
//!
//! `SEARCH ≠ RESEARCH`. Search produces candidate information. Research is
//! interpret → plan → acquire → extract → evidence → verify → iterate →
//! synthesize → provenance.

mod document;
mod evidence;
mod interpreter;
mod planner;
mod query;
mod request;
mod search;
mod state;
mod stopping;
mod strategy;
mod trust;

pub use document::{
    classify_url, extract_html, ExtractedDocument, SourceClass, SourceClassification, SourceKind,
};
pub use evidence::{
    excerpt_in_source, contradiction_reasons, Claim, ClaimId, ClaimStatus, Evidence, EvidenceGraph, EvidenceId, Source,
    SourceId, SourceType,
};
pub use interpreter::{interpret, InterpretedGoal, ResearchIntent};
pub use planner::{PlanNodeKind, ResearchPlan, ResearchPlanNode};
pub use query::{queries_for, QuerySet};
pub use request::{ResearchBudget, ResearchMode, ResearchRequest, SearchPolicy};
pub use search::{
    canonicalize_url, dedupe_hits, SearchEngine, SearchError, SearchHit, SearchRequest,
    SearchResponse,
};
pub use state::{ResearchCommand, ResearchJob, ResearchJobState, ResearchStateError};
pub use stopping::{
    EvidenceSufficiencyPolicy, ResearchCompleteness, ResearchProgress, StopDecision, StoppingPolicy,
};
pub use strategy::{strategy_for, ResearchStrategy};
pub use trust::{SourceContent, TrustLevel};

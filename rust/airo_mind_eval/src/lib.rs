#![deny(unsafe_code)]
//! Airo Mind golden-dataset evaluation pipeline. `#1636`, epic `#1627`,
//! Milestone 26 Phase 3 -- "gate for everything else".
//!
//! # What this crate is
//!
//! A local dev tool, not shipped product code and not run in CI (the issue is
//! explicit: "local-run only -- respect GH Actions minutes"). It scores one
//! meeting's pipeline output -- ASR transcript, extracted [`MeetingIr`], and
//! rendered Minutes of Meeting -- against a golden fixture, on six axes:
//!
//! - [`wer`] -- word error rate of the ASR hypothesis against the reference
//!   transcript.
//! - [`term_accuracy`] -- whether `airo_mind_transcript`'s own technical-term
//!   dictionary survived ASR.
//! - [`extraction`] -- precision/recall/F1 per IR category, matching
//!   predicted facts to the golden IR with the same semantic-match heuristic
//!   Pass 2 uses to dedup (`airo_mind_meeting::dedup::is_near_duplicate`).
//! - [`numeric`] -- numeric recall/precision, split out from extraction F1
//!   because a fact with the right shape and the wrong number is a worse
//!   failure than a missing fact.
//! - [`grounding`] -- evidence accuracy and unsupported-claim rate for the
//!   MoM's narrative prose, reusing `airo_mind_meeting::validate`'s
//!   evidence-grounding pattern (numbers and content words must appear in the
//!   segments a claim's underlying facts cite).
//! - [`mom_quality`] -- section completeness (reusing the golden-diff pattern
//!   `airo_mind_meeting::tests::mom_golden` already exercises) and
//!   deterministic factual-consistency checks against the IR.
//!
//! Plus [`performance`] (audio minutes / processing seconds / peak memory,
//! reusing `airo_mind_core::RuntimeStats`'s shape) and [`llm_judge`], a
//! call-site for the issue's 7-axis LLM judge -- see that module's doc
//! comment for why it is explicitly unvalidated in this environment.
//!
//! [`report`] aggregates all of the above into one JSON document and checks
//! it against [`gates::Gates`], the issue's hardcoded pass/fail thresholds.
//! [`golden`] loads the fixture set this all runs against.

pub mod extraction;
pub mod factual_consistency;
pub mod gates;
pub mod golden;
pub mod grounding;
pub mod llm_judge;
pub mod mom_quality;
pub mod numeric;
pub mod performance;
pub mod report;
pub mod term_accuracy;
pub mod wer;

pub use airo_mind_meeting::MeetingIr;

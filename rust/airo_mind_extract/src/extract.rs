//! Pass 1: per-chunk fact extraction (`#1633`).
//!
//! One [`airo_mind_transcript::Chunk`] in, one [`ChunkFacts`] out, through
//! whatever [`LlmBackend`] the caller wired up (`airo_mind_llama`'s
//! `LlamaGenerationEngine` in production; a fake in this crate's own unit
//! tests). Grammar-constrained (`grammar::JSON_GRAMMAR`) and retried against
//! a schema+evidence validator, per `#1633`'s "pass 1 output always
//! schema-valid; retry on violation" acceptance criterion.

use std::collections::HashMap;

use airo_mind_core::{CancelToken, EngineError, GenerationRequest, LlmBackend};
use airo_mind_transcript::{Chunk, ProcessedSegment};

use crate::grammar::JSON_GRAMMAR;
use crate::schema::ChunkFacts;

// v1 (no worked example) reliably produced all-empty output against the
// real Qwen2.5-0.5B model on realistic-length excerpts -- see the commit
// history / PR for `#1633` for the before/after. v2 adds a one-shot
// example with deliberately non-conflicting ids (`"ex1"`/`"ex2"`/`"ex3"`)
// to demonstrate the shape without teaching the model to copy those exact
// ids into real output -- kept, versioned, in the same directory as v1 so
// the change in behavior this caused is traceable.
const PASS1_PROMPT_TEMPLATE: &str = include_str!("../prompts/extraction/pass1_v2.txt");

/// Tuning for pass 1. Kept small and explicit rather than reaching into
/// global config — a caller running the eval harness (`#1636`) or a device
/// with a smaller budget can hand this crate a different value without this
/// crate knowing why.
#[derive(Clone, Debug)]
pub struct ExtractionConfig {
    /// How many times to re-prompt after a schema/evidence violation before
    /// giving up and returning an empty [`ChunkFacts`] for the chunk. Never
    /// panics, never blocks the rest of the meeting on one bad chunk.
    pub max_attempts: u32,
    pub max_output_tokens: u32,
    /// Whether to constrain generation with [`crate::grammar::JSON_GRAMMAR`].
    /// **Defaults to `false`** — see the doc comment on this field's use
    /// below for why, and do not flip this default without re-verifying the
    /// upstream bug it works around is actually fixed.
    ///
    /// Discovered live against this crate's own real-model integration test
    /// during `#1633`: `llama-cpp-2` 0.1.153 (the pinned version,
    /// `rust/airo_mind_llama/Cargo.toml`) aborts the process with
    /// `GGML_ASSERT(!stacks.empty())` inside
    /// `llama_grammar_reject_candidates`
    /// (`llama-cpp-sys-2-0.1.153/llama.cpp/src/llama-grammar.cpp:940`)
    /// whenever a GBNF grammar reaches a fully-matched terminal state before
    /// the model emits its own EOG token — which any *finite* grammar,
    /// including [`crate::grammar::JSON_GRAMMAR`], always eventually does.
    /// Verified with the minimal possible repro: `root ::= "{" "}"` against
    /// this same engine crashes identically on the token immediately after
    /// the closing brace. `root ::= [0-9]+` does not crash, because that
    /// grammar has no terminal state (there is always a "one more digit"
    /// continuation) — which is what made this easy to miss in
    /// `airo_mind_llama`'s own `a_gbnf_grammar_constrains_every_generated_character`
    /// test (`#1628`), whose digits-only grammar happens to share that
    /// property.
    ///
    /// Rather than ship a feature proven to crash the process on real
    /// output, pass 1 falls back to unconstrained generation plus the
    /// existing parse/validate/retry loop below, which is a strictly weaker
    /// but non-crashing approximation of `#1633`'s "grammar-constrained;
    /// retry on violation" acceptance criterion. Re-enabling this
    /// (`use_gbnf_grammar: true`) is real, valuable follow-up work once
    /// `llama-cpp-2` is upgraded past whatever `llama.cpp` release fixed
    /// this (or a project-side workaround, e.g. injecting a forced-EOG
    /// check before the grammar sampler runs, is added to
    /// `LlamaGenerationEngine::generate`).
    pub use_gbnf_grammar: bool,
}

impl Default for ExtractionConfig {
    fn default() -> Self {
        Self {
            max_attempts: 3,
            max_output_tokens: 768,
            use_gbnf_grammar: false,
        }
    }
}

/// Why pass 1 gave up on a chunk. Not returned to the caller as a hard
/// error by [`extract_chunk_facts`] — see its own doc comment for why an
/// exhausted retry budget resolves to an empty [`ChunkFacts`] instead.
#[derive(Debug)]
pub enum ExtractError {
    Engine(EngineError),
}

impl std::fmt::Display for ExtractError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Engine(e) => write!(f, "generation failed: {e}"),
        }
    }
}

impl std::error::Error for ExtractError {}

/// Builds the excerpt block (`"[s0] text\n[s1] text"`) pass 1's prompt shows
/// the model, restricted to and ordered by `chunk.segment_ids` — the same
/// ids the model is told evidence must be drawn from, so the prompt and the
/// validator agree on what "in this excerpt" means.
fn render_segments(chunk: &Chunk, segments_by_id: &HashMap<&str, &ProcessedSegment>) -> String {
    chunk
        .segment_ids
        .iter()
        .filter_map(|id| {
            segments_by_id
                .get(id.as_str())
                .map(|s| format!("[{id}] {}", s.normalized))
        })
        .collect::<Vec<_>>()
        .join("\n")
}

fn build_prompt(
    chunk: &Chunk,
    segments_by_id: &HashMap<&str, &ProcessedSegment>,
    retry_note: Option<&str>,
) -> String {
    let note = match retry_note {
        Some(err) => format!(
            "\nYour previous answer was rejected: {err}\nReturn corrected JSON only, following the rules above exactly.\n"
        ),
        None => String::new(),
    };
    PASS1_PROMPT_TEMPLATE
        .replace("{{SEGMENTS}}", &render_segments(chunk, segments_by_id))
        .replace("{{RETRY_NOTE}}", &note)
}

/// Schema+evidence validation, run after every generation attempt. Returns
/// `Err` with a human-readable reason (fed back into the next attempt's
/// prompt) rather than panicking or silently accepting an invalid document —
/// a chunk whose model output never becomes valid ends the retry loop with
/// an empty [`ChunkFacts`], not a crash.
fn parse_and_validate(raw: &str, chunk: &Chunk) -> Result<ChunkFacts, String> {
    let facts: ChunkFacts = serde_json::from_str(raw)
        .map_err(|e| format!("not valid JSON matching the shape above ({e})"))?;

    let known: std::collections::HashSet<&str> =
        chunk.segment_ids.iter().map(String::as_str).collect();
    let evidence_ok =
        |ev: &[String]| !ev.is_empty() && ev.iter().all(|id| known.contains(id.as_str()));

    let all_ok = facts.topics.iter().all(|f| evidence_ok(&f.evidence))
        && facts.observations.iter().all(|f| evidence_ok(&f.evidence))
        && facts.decisions.iter().all(|f| evidence_ok(&f.evidence))
        && facts.action_items.iter().all(|a| evidence_ok(&a.evidence))
        && facts.metrics.iter().all(|f| evidence_ok(&f.evidence))
        && facts.risks.iter().all(|f| evidence_ok(&f.evidence))
        && facts.questions.iter().all(|f| evidence_ok(&f.evidence))
        && facts.next_steps.iter().all(|f| evidence_ok(&f.evidence));

    if !all_ok {
        return Err(
            "every fact must cite at least one evidence segment id, and every id must be one of the ones shown in this excerpt"
                .to_string(),
        );
    }

    // Owner grounding: never trust a guessed name. An owner that does not
    // appear (case-insensitively) anywhere in the excerpt's own text is
    // dropped to `None` rather than failing the whole chunk — the rest of
    // the action item is still a real, evidenced fact.
    let excerpt_lower: String = chunk.text.to_lowercase();
    let mut facts = facts;
    for item in &mut facts.action_items {
        if let Some(owner) = &item.owner {
            if !excerpt_lower.contains(&owner.to_lowercase()) {
                item.owner = None;
            }
        }
    }

    Ok(facts)
}

/// Runs pass 1 for one chunk: prompt, grammar-constrained generation,
/// validate, retry on violation up to `config.max_attempts`. Exhausting the
/// budget resolves to `Ok(ChunkFacts::default())` rather than an error — one
/// stubborn chunk should not stop the rest of the meeting's extraction, and
/// an empty result for a chunk is a legitimate, visible outcome a caller can
/// act on (same reasoning as `ChunkFacts::is_empty`).
pub fn extract_chunk_facts(
    backend: &dyn LlmBackend,
    chunk: &Chunk,
    all_segments: &[ProcessedSegment],
    config: &ExtractionConfig,
    cancel: &CancelToken,
) -> Result<ChunkFacts, ExtractError> {
    let segments_by_id: HashMap<&str, &ProcessedSegment> =
        all_segments.iter().map(|s| (s.id.as_str(), s)).collect();

    let mut retry_note: Option<String> = None;
    for _attempt in 0..config.max_attempts.max(1) {
        if cancel.is_cancelled() {
            return Err(ExtractError::Engine(EngineError::Cancelled));
        }
        let prompt = build_prompt(chunk, &segments_by_id, retry_note.as_deref());
        let mut buf = String::new();
        backend
            .generate(
                &GenerationRequest {
                    prompt,
                    max_output_tokens: config.max_output_tokens,
                    grammar: config.use_gbnf_grammar.then(|| JSON_GRAMMAR.to_string()),
                },
                cancel,
                &mut |chunk| {
                    buf.push_str(&chunk.text);
                    Ok(())
                },
            )
            .map_err(ExtractError::Engine)?;

        match parse_and_validate(&buf, chunk) {
            Ok(facts) => return Ok(facts),
            Err(reason) => retry_note = Some(reason),
        }
    }

    Ok(ChunkFacts::default())
}

#[cfg(test)]
mod tests {
    use super::*;
    use airo_mind_core::GenerationChunk;

    fn seg(id: &str, start_ms: u64, end_ms: u64, normalized: &str) -> ProcessedSegment {
        ProcessedSegment {
            id: id.to_string(),
            start_ms,
            end_ms,
            raw: normalized.to_string(),
            normalized: normalized.to_string(),
            terms_corrected: vec![],
            numbers: vec![],
        }
    }

    fn chunk(segment_ids: &[&str], text: &str) -> Chunk {
        Chunk {
            id: "c0".into(),
            start_ms: 0,
            end_ms: 10_000,
            segment_ids: segment_ids.iter().map(|s| s.to_string()).collect(),
            text: text.to_string(),
        }
    }

    /// A fake `LlmBackend` that always emits a fixed JSON string, so pass 1's
    /// prompt-build/validate/retry logic can be tested without a real model
    /// — the same "second, independent implementation" pattern
    /// `airo_mind_core::engine`'s own tests use for `LlmBackend`.
    struct FixedOutputBackend {
        responses: std::sync::Mutex<Vec<String>>,
    }

    impl LlmBackend for FixedOutputBackend {
        fn resource_request(&self) -> airo_mind_core::ResourceRequest {
            airo_mind_core::ResourceRequest::new(64)
        }

        fn generate(
            &self,
            _request: &GenerationRequest,
            _cancel: &CancelToken,
            sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            let mut responses = self.responses.lock().unwrap();
            let text = if responses.is_empty() {
                String::new()
            } else {
                responses.remove(0)
            };
            sink(GenerationChunk { text })
        }

        fn stats(&self) -> airo_mind_core::RuntimeStats {
            airo_mind_core::RuntimeStats::default()
        }
    }

    #[test]
    fn a_valid_first_attempt_needs_no_retry() {
        let backend = FixedOutputBackend {
            responses: vec![
                r#"{"decisions":[{"text":"ship it","evidence":["s0"]}],"action_items":[],"topics":[],"observations":[],"metrics":[],"risks":[],"questions":[],"next_steps":[]}"#
                    .to_string(),
            ]
            .into(),
        };
        let segments = vec![seg("s0", 0, 1000, "we decided to ship it")];
        let c = chunk(&["s0"], "we decided to ship it");
        let facts = extract_chunk_facts(
            &backend,
            &c,
            &segments,
            &ExtractionConfig::default(),
            &CancelToken::new(),
        )
        .unwrap();
        assert_eq!(facts.decisions.len(), 1);
        assert_eq!(facts.decisions[0].evidence, vec!["s0"]);
    }

    #[test]
    fn an_evidence_id_outside_the_chunk_is_rejected_and_retried() {
        let backend = FixedOutputBackend {
            responses: vec![
                // Attempt 1: cites a segment id not in this chunk.
                r#"{"decisions":[{"text":"bad","evidence":["s99"]}],"action_items":[],"topics":[],"observations":[],"metrics":[],"risks":[],"questions":[],"next_steps":[]}"#
                    .to_string(),
                // Attempt 2: corrected.
                r#"{"decisions":[{"text":"good","evidence":["s0"]}],"action_items":[],"topics":[],"observations":[],"metrics":[],"risks":[],"questions":[],"next_steps":[]}"#
                    .to_string(),
            ]
            .into(),
        };
        let segments = vec![seg("s0", 0, 1000, "text")];
        let c = chunk(&["s0"], "text");
        let facts = extract_chunk_facts(
            &backend,
            &c,
            &segments,
            &ExtractionConfig::default(),
            &CancelToken::new(),
        )
        .unwrap();
        assert_eq!(facts.decisions[0].text, "good");
    }

    #[test]
    fn exhausting_retries_returns_an_empty_result_not_an_error() {
        let backend = FixedOutputBackend {
            responses: vec!["not json at all".to_string(); 5].into(),
        };
        let segments = vec![seg("s0", 0, 1000, "text")];
        let c = chunk(&["s0"], "text");
        let config = ExtractionConfig {
            max_attempts: 2,
            ..ExtractionConfig::default()
        };
        let facts =
            extract_chunk_facts(&backend, &c, &segments, &config, &CancelToken::new()).unwrap();
        assert!(facts.is_empty());
    }

    #[test]
    fn an_owner_not_named_in_the_excerpt_is_dropped_never_guessed() {
        let backend = FixedOutputBackend {
            responses: vec![
                r#"{"action_items":[{"text":"own the rollout","owner":"Raj","evidence":["s0"]}],"decisions":[],"topics":[],"observations":[],"metrics":[],"risks":[],"questions":[],"next_steps":[]}"#
                    .to_string(),
            ]
            .into(),
        };
        // Excerpt never names Raj.
        let segments = vec![seg("s0", 0, 1000, "someone should own the rollout")];
        let c = chunk(&["s0"], "someone should own the rollout");
        let facts = extract_chunk_facts(
            &backend,
            &c,
            &segments,
            &ExtractionConfig::default(),
            &CancelToken::new(),
        )
        .unwrap();
        assert_eq!(facts.action_items[0].owner, None);
    }

    /// A fake `LlmBackend` that records whether the request it received
    /// carried a grammar, so this test can assert on
    /// `ExtractionConfig::use_gbnf_grammar`'s effect without needing a real
    /// model — the crash it works around
    /// (`ExtractionConfig::use_gbnf_grammar`'s doc comment) only reproduces
    /// against real `llama-cpp-2`, but the *wiring* — does this crate ask
    /// for a grammar when told to, and not when told not to — is a plain
    /// unit-testable fact about `extract_chunk_facts` itself.
    struct GrammarRecordingBackend {
        saw_grammar: std::sync::Mutex<Option<bool>>,
    }

    impl LlmBackend for GrammarRecordingBackend {
        fn resource_request(&self) -> airo_mind_core::ResourceRequest {
            airo_mind_core::ResourceRequest::new(64)
        }

        fn generate(
            &self,
            request: &GenerationRequest,
            _cancel: &CancelToken,
            sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            *self.saw_grammar.lock().unwrap() = Some(request.grammar.is_some());
            sink(GenerationChunk {
                text: r#"{"decisions":[{"text":"x","evidence":["s0"]}],"action_items":[],"topics":[],"observations":[],"metrics":[],"risks":[],"questions":[],"next_steps":[]}"#
                    .to_string(),
            })
        }

        fn stats(&self) -> airo_mind_core::RuntimeStats {
            airo_mind_core::RuntimeStats::default()
        }
    }

    #[test]
    fn the_default_config_does_not_request_a_grammar() {
        let backend = GrammarRecordingBackend {
            saw_grammar: std::sync::Mutex::new(None),
        };
        let segments = vec![seg("s0", 0, 1000, "text")];
        let c = chunk(&["s0"], "text");
        extract_chunk_facts(
            &backend,
            &c,
            &segments,
            &ExtractionConfig::default(),
            &CancelToken::new(),
        )
        .unwrap();
        assert_eq!(*backend.saw_grammar.lock().unwrap(), Some(false));
    }

    #[test]
    fn opting_into_use_gbnf_grammar_requests_one() {
        let backend = GrammarRecordingBackend {
            saw_grammar: std::sync::Mutex::new(None),
        };
        let segments = vec![seg("s0", 0, 1000, "text")];
        let c = chunk(&["s0"], "text");
        let config = ExtractionConfig {
            use_gbnf_grammar: true,
            ..ExtractionConfig::default()
        };
        extract_chunk_facts(&backend, &c, &segments, &config, &CancelToken::new()).unwrap();
        assert_eq!(*backend.saw_grammar.lock().unwrap(), Some(true));
    }

    #[test]
    fn an_owner_named_in_the_excerpt_survives() {
        let backend = FixedOutputBackend {
            responses: vec![
                r#"{"action_items":[{"text":"own the rollout","owner":"Raj","evidence":["s0"]}],"decisions":[],"topics":[],"observations":[],"metrics":[],"risks":[],"questions":[],"next_steps":[]}"#
                    .to_string(),
            ]
            .into(),
        };
        let segments = vec![seg("s0", 0, 1000, "Raj will own the rollout")];
        let c = chunk(&["s0"], "Raj will own the rollout");
        let facts = extract_chunk_facts(
            &backend,
            &c,
            &segments,
            &ExtractionConfig::default(),
            &CancelToken::new(),
        )
        .unwrap();
        assert_eq!(facts.action_items[0].owner.as_deref(), Some("Raj"));
    }
}

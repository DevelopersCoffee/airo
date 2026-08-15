//! Pass 1 — per-chunk fact extraction.
//!
//! One grammar-constrained generation per chunk, then a grounding pass that
//! throws away anything the chunk cannot back up. The model proposes; this
//! module is what decides.
//!
//! # Three separate guarantees, in order
//!
//! 1. **Shape** is the grammar's job. `GenerationRequest::grammar` constrains
//!    the sampler to a valid `Facts` object, so "the model returned prose" is
//!    not a state that can occur.
//! 2. **Parse** is bounded-retry's job. The grammar cannot prevent output being
//!    cut off at `max_output_tokens` mid-object, which yields JSON that is valid
//!    right up to where it stops. That retries, a fixed number of times, and
//!    then the chunk is abandoned with a diagnostic — never an unbounded loop.
//! 3. **Grounding** is this module's job, and is not delegated to the model at
//!    all. An item citing a segment outside its own chunk is dropped. An owner
//!    whose name does not appear in the chunk is erased. Both are mechanical
//!    checks against the transcript, which is the only kind of check that
//!    actually holds.

use std::collections::{BTreeMap, BTreeSet};

use airo_mind_core::{CancelToken, EngineError, GenerationEngine, GenerationRequest};
use airo_mind_transcript::Chunk;

use crate::dedup::DedupConfig;
use crate::diagnostics::Diagnostic;
use crate::fact::Fact;
use crate::ir::{ChunkIr, Facts};
use crate::prompt;
use crate::ExtractionError;

/// What Pass 1 and Pass 2 are allowed to spend and how hard they try.
#[derive(Clone, Debug, PartialEq)]
pub struct ExtractionConfig {
    /// Output-token ceiling per chunk.
    ///
    /// `1024` fits the eight categories for a 5–10 minute chunk with room to
    /// spare; a chunk dense enough to overrun it is exactly the case the retry
    /// path exists for.
    pub max_output_tokens: u32,
    /// How many times one chunk may be generated before it is abandoned.
    /// Must be at least 1; `0` is treated as 1 rather than silently extracting
    /// nothing.
    pub max_attempts: u32,
    /// Pass 2's merge behaviour.
    pub dedup: DedupConfig,
}

impl Default for ExtractionConfig {
    fn default() -> Self {
        Self {
            max_output_tokens: 1024,
            max_attempts: 3,
            dedup: DedupConfig::default(),
        }
    }
}

/// Extracts facts from one chunk.
///
/// `segment_text` maps segment id to the normalized text of that segment; it
/// supplies the `[id] text` lines the prompt asks the model to cite from. Ids
/// in `chunk.segment_ids` that are missing from the map are simply not shown to
/// the model.
///
/// Returns the chunk's IR and everything that was dropped getting there. An
/// engine failure is an error (the backend is broken, and the next chunk will
/// fail the same way); an unparseable *chunk* is not — it contributes no facts
/// and the meeting carries on.
pub fn extract_chunk(
    engine: &dyn GenerationEngine,
    chunk: &Chunk,
    segment_text: &BTreeMap<&str, &str>,
    config: &ExtractionConfig,
    cancel: &CancelToken,
) -> Result<(ChunkIr, Vec<Diagnostic>), ExtractionError> {
    let mut diagnostics = Vec::new();

    let lines: Vec<(&str, &str)> = chunk
        .segment_ids
        .iter()
        .filter_map(|id| {
            segment_text
                .get(id.as_str())
                .map(|text| (id.as_str(), *text))
        })
        .collect();

    let request = GenerationRequest {
        prompt: prompt::render_chunk_facts(&lines),
        max_output_tokens: config.max_output_tokens,
        grammar: Some(prompt::CHUNK_FACTS_GRAMMAR.to_string()),
    };

    let attempts = config.max_attempts.max(1);
    let mut facts: Option<Facts> = None;
    for attempt in 1..=attempts {
        if cancel.is_cancelled() {
            return Err(ExtractionError::Cancelled);
        }
        let raw = generate(engine, &request, cancel)?;
        match parse_facts(&raw) {
            Ok(parsed) => {
                facts = Some(parsed);
                break;
            }
            Err(detail) => diagnostics.push(Diagnostic::UnparseableOutput {
                chunk_id: chunk.id.clone(),
                attempt,
                detail,
            }),
        }
    }

    let facts = match facts {
        Some(facts) => facts,
        None => {
            diagnostics.push(Diagnostic::ChunkAbandoned {
                chunk_id: chunk.id.clone(),
                attempts,
            });
            Facts::default()
        }
    };

    let facts = ground(facts, chunk, &mut diagnostics);

    Ok((
        ChunkIr {
            chunk_id: chunk.id.clone(),
            segment_ids: chunk.segment_ids.clone(),
            facts,
        },
        diagnostics,
    ))
}

/// Runs one generation and collects the streamed tokens.
///
/// Streaming is the engine's contract (`I7`), and Pass 1 genuinely needs the
/// whole object before it can parse anything — so this is the one place the
/// stream is joined, deliberately and at chunk scale, not meeting scale.
fn generate(
    engine: &dyn GenerationEngine,
    request: &GenerationRequest,
    cancel: &CancelToken,
) -> Result<String, ExtractionError> {
    let mut raw = String::new();
    engine
        .generate(request, cancel, &mut |chunk| {
            raw.push_str(&chunk.text);
            Ok(())
        })
        .map_err(|e| match e {
            EngineError::Cancelled => ExtractionError::Cancelled,
            other => ExtractionError::Engine(other.to_string()),
        })?;
    Ok(raw)
}

/// Parses the model's output into `Facts`.
///
/// Trims to the outermost `{ … }` first. With the grammar attached there is
/// nothing outside it to trim, but an engine that ignores the grammar (a test
/// double, or a backend without grammar support) commonly wraps the object in a
/// code fence, and recovering from that is free.
fn parse_facts(raw: &str) -> Result<Facts, String> {
    let start = raw.find('{').ok_or("no JSON object in output")?;
    let end = raw.rfind('}').ok_or("unterminated JSON object")?;
    if end < start {
        return Err("unterminated JSON object".to_string());
    }
    serde_json::from_str(&raw[start..=end]).map_err(|e| e.to_string())
}

/// Drops everything the chunk cannot back up, and assigns chunk-scoped ids.
fn ground(facts: Facts, chunk: &Chunk, diagnostics: &mut Vec<Diagnostic>) -> Facts {
    let allowed: BTreeSet<&str> = chunk.segment_ids.iter().map(String::as_str).collect();
    let mut grounded = Facts {
        topics: ground_items(facts.topics, &chunk.id, &allowed, diagnostics),
        observations: ground_items(facts.observations, &chunk.id, &allowed, diagnostics),
        decisions: ground_items(facts.decisions, &chunk.id, &allowed, diagnostics),
        action_items: ground_items(facts.action_items, &chunk.id, &allowed, diagnostics),
        metrics: ground_items(facts.metrics, &chunk.id, &allowed, diagnostics),
        risks: ground_items(facts.risks, &chunk.id, &allowed, diagnostics),
        questions: ground_items(facts.questions, &chunk.id, &allowed, diagnostics),
        next_steps: ground_items(facts.next_steps, &chunk.id, &allowed, diagnostics),
    };

    for item in &mut grounded.action_items {
        if let Some(owner) = item.owner.take() {
            if names_appear_in(&owner, &chunk.text) {
                item.owner = Some(owner);
            } else {
                diagnostics.push(Diagnostic::OwnerNotInTranscript {
                    chunk_id: chunk.id.clone(),
                    task: item.task.clone(),
                    owner,
                });
            }
        }
    }

    grounded
}

fn ground_items<F: Fact>(
    items: Vec<F>,
    chunk_id: &str,
    allowed: &BTreeSet<&str>,
    diagnostics: &mut Vec<Diagnostic>,
) -> Vec<F> {
    let mut kept: Vec<F> = Vec::with_capacity(items.len());
    for mut item in items {
        if item.text().trim().is_empty() {
            diagnostics.push(Diagnostic::UngroundedItemDropped {
                chunk_id: chunk_id.to_string(),
                category: F::CATEGORY,
                text: String::new(),
            });
            continue;
        }

        let mut evidence = Vec::with_capacity(item.evidence().len());
        for id in item.evidence() {
            if !allowed.contains(id.as_str()) {
                diagnostics.push(Diagnostic::UnknownEvidenceDropped {
                    chunk_id: chunk_id.to_string(),
                    category: F::CATEGORY,
                    segment_id: id.clone(),
                });
                continue;
            }
            if !evidence.iter().any(|existing| existing == id) {
                evidence.push(id.clone());
            }
        }

        if evidence.is_empty() {
            diagnostics.push(Diagnostic::UngroundedItemDropped {
                chunk_id: chunk_id.to_string(),
                category: F::CATEGORY,
                text: item.text().to_string(),
            });
            continue;
        }

        *item.evidence_mut() = evidence;
        item.set_id(format!("{chunk_id}:{}-{}", F::CATEGORY, kept.len()));
        kept.push(item);
    }
    kept
}

/// Whether every word of `owner` appears as a whole word in `text`,
/// case-insensitively.
///
/// Word-wise rather than whole-string: the transcript says "Priya said she'd
/// take it", and a model may only write "Priya Nair" if it read "Nair" too.
/// Whole words rather than substrings, so "Dev" cannot be justified by the word
/// "device". It is a containment test, not a name parser — its whole job is to
/// make an invented owner impossible to keep, and an owner it wrongly rejects
/// becomes `None`, which is the safe direction to be wrong in.
pub(crate) fn names_appear_in(owner: &str, text: &str) -> bool {
    let words = |s: &str| -> Vec<String> {
        s.split(|c: char| !c.is_alphanumeric())
            .filter(|w| !w.is_empty())
            .map(str::to_lowercase)
            .collect()
    };
    let spoken: BTreeSet<String> = words(text).into_iter().collect();
    let named = words(owner);
    !named.is_empty() && named.iter().all(|word| spoken.contains(word))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ir::{ActionItem, Decision};

    fn chunk() -> Chunk {
        Chunk {
            id: "chunk-0".into(),
            start_ms: 0,
            end_ms: 1_000,
            segment_ids: vec!["s0".into(), "s1".into()],
            text: "Priya will check the signalling limit.".into(),
        }
    }

    #[test]
    fn an_item_citing_a_segment_outside_its_chunk_is_dropped() {
        let facts = Facts {
            decisions: vec![Decision {
                statement: "we will ship on Friday".into(),
                evidence: vec!["s99".into()],
                ..Decision::default()
            }],
            ..Facts::default()
        };
        let mut diagnostics = Vec::new();
        let grounded = ground(facts, &chunk(), &mut diagnostics);

        assert!(grounded.decisions.is_empty());
        assert!(diagnostics.iter().any(|d| matches!(
            d,
            Diagnostic::UngroundedItemDropped {
                category: "decision",
                ..
            }
        )));
    }

    #[test]
    fn an_item_citing_one_real_and_one_invented_segment_keeps_the_real_one() {
        let facts = Facts {
            decisions: vec![Decision {
                statement: "we will ship on Friday".into(),
                evidence: vec!["s1".into(), "s99".into(), "s1".into()],
                ..Decision::default()
            }],
            ..Facts::default()
        };
        let mut diagnostics = Vec::new();
        let grounded = ground(facts, &chunk(), &mut diagnostics);

        assert_eq!(grounded.decisions.len(), 1);
        assert_eq!(grounded.decisions[0].evidence, vec!["s1"]);
        assert_eq!(grounded.decisions[0].id, "chunk-0:decision-0");
    }

    #[test]
    fn an_owner_the_chunk_never_names_is_erased_not_kept() {
        let facts = Facts {
            action_items: vec![ActionItem {
                task: "check the signalling limit".into(),
                owner: Some("Dev".into()),
                evidence: vec!["s0".into()],
                ..ActionItem::default()
            }],
            ..Facts::default()
        };
        let mut diagnostics = Vec::new();
        let grounded = ground(facts, &chunk(), &mut diagnostics);

        assert_eq!(grounded.action_items[0].owner, None);
        assert!(diagnostics
            .iter()
            .any(|d| matches!(d, Diagnostic::OwnerNotInTranscript { .. })));
    }

    #[test]
    fn an_owner_the_chunk_does_name_survives() {
        let facts = Facts {
            action_items: vec![ActionItem {
                task: "check the signalling limit".into(),
                owner: Some("priya".into()),
                evidence: vec!["s0".into()],
                ..ActionItem::default()
            }],
            ..Facts::default()
        };
        let grounded = ground(facts, &chunk(), &mut Vec::new());
        assert_eq!(grounded.action_items[0].owner.as_deref(), Some("priya"));
    }

    #[test]
    fn output_wrapped_in_prose_or_a_code_fence_still_parses() {
        let raw = "Here you go:\n```json\n{\"decisions\":[]}\n```\n";
        assert_eq!(parse_facts(raw).unwrap(), Facts::default());
    }

    #[test]
    fn truncated_output_is_a_parse_error_rather_than_a_panic() {
        let raw = "{\"decisions\":[{\"statement\":\"we will";
        assert!(parse_facts(raw).is_err());
    }

    #[test]
    fn an_empty_owner_string_does_not_count_as_named() {
        assert!(!names_appear_in("", "Priya will check it."));
        assert!(!names_appear_in("   ", "Priya will check it."));
    }
}

//! The Meeting capability's generation half. `#1401`.
//!
//! # Why the prompt lives here and not below
//!
//! `C5` forbids the runtime from knowing what a meeting is. The word "minutes"
//! and the secretary prompt are in this module; below it, `GenerationEngine`
//! takes a prompt and has never heard of a meeting.
//!
//! It stays in Rust rather than moving to Dart with the sequencing. A prompt is
//! part of what produced a summary, recorded with it under `ADR-0018 §5`, and a
//! prompt the caller supplies is a prompt that can differ from the one the
//! recorded model id claims to describe.
//!
//! # Streaming, because `I7`
//!
//! `generate_minutes` yields a `Stream`. Tokens reach the UI as the model
//! produces them.

use std::sync::Mutex;

use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

use crate::LlamaGenerationEngine;
use airo_mind_core::models;
use airo_mind_core::{CancelToken, GenerationRequest, ResourceBudget, RuntimeStats, Supervisor};

// ---------------------------------------------------------------------------
// Wire types
// ---------------------------------------------------------------------------

/// Where the models live and what the engine may spend.
pub struct GenerationConfig {
    /// Where the Model Manager looks. **Not** a model path — `ADR-0018 §4`.
    pub models_dir: String,
    /// Admission ceiling for the Supervisor (`C6`).
    pub memory_budget_mb: u32,
    /// When true, resolve `ModelQuality::Standard` first (e.g. Sarvam-1 for
    /// Indic meetings). Falls back to `Draft` (Qwen) when
    /// `allow_compact_fallback` is true.
    pub prefer_indic_generation: bool,
    /// When false and Indic resolution fails, return the error instead of
    /// falling back to Qwen (`enhanced_indic` user preference).
    pub allow_compact_fallback: bool,
}

/// Generation progress, as it happens.
pub enum GenerationEvent {
    /// One token, as llama produced it.
    Generating {
        text: String,
    },
    MinutesReady {
        text: String,
    },
    /// The user navigated away. Nothing was saved.
    Cancelled,
}

/// `RuntimeStats`, crossing the FFI boundary. A separate wire type rather
/// than deriving FRB bindings directly on `airo_mind_core::RuntimeStats`:
/// that type lives in the domain-free runtime crate, and this crate's `api`
/// module is the one place a Dart-shaped mirror of a core type is expected to
/// live (same pattern `GenerationEvent` already follows for `GenerationChunk`).
pub struct GenerationStats {
    pub prefill_ms: u64,
    pub prefill_tokens: u32,
    pub generation_ms: u64,
    pub generated_tokens: u32,
    pub tokens_per_second: f64,
    pub peak_rss_bytes: u64,
}

impl From<RuntimeStats> for GenerationStats {
    fn from(s: RuntimeStats) -> Self {
        Self {
            prefill_ms: s.prefill_ms,
            prefill_tokens: s.prefill_tokens,
            generation_ms: s.generation_ms,
            generated_tokens: s.generated_tokens,
            tokens_per_second: s.tokens_per_second,
            peak_rss_bytes: s.peak_rss_bytes,
        }
    }
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

static ENGINE: Mutex<Option<Supervisor>> = Mutex::new(None);
static CANCEL: Mutex<Option<CancelToken>> = Mutex::new(None);

/// The logical identity and version of the loaded model, recorded with the
/// content it produces (`ADR-0018 §5`). The meeting library stores it; this
/// library is the only thing that knows it.
static MODEL_ID: Mutex<Option<String>> = Mutex::new(None);

fn lock<T>(m: &'static Mutex<T>) -> std::sync::MutexGuard<'static, T> {
    m.lock().unwrap_or_else(|e| e.into_inner())
}

/// The Meeting capability's prompt. Above the engine boundary, because
/// `GenerationEngine::summarize(transcript) -> Minutes` would push meeting
/// semantics into the runtime.
fn minutes_prompt(transcript: &str) -> String {
    format!(
        "<|im_start|>system\nYou are a meeting secretary. Extract Decisions and Action Items. \
         Return Markdown only. Do not invent facts.<|im_end|>\n\
         <|im_start|>user\nTranscript:\n{transcript}<|im_end|>\n\
         <|im_start|>assistant\n"
    )
}

// ---------------------------------------------------------------------------
// The capability surface
// ---------------------------------------------------------------------------

/// Loads the generation model. Called on first use, not at startup: this
/// library is large and only minutes need it.
///
/// Safe to call again — a Flutter hot restart runs it a second time.
pub fn initialize(config: GenerationConfig) -> Result<(), String> {
    let models_dir = std::path::Path::new(&config.models_dir);

    // `ADR-0018 §1`: ask for a CAPABILITY and a budget, never for a file.
    let requirement = models::ModelRequirement {
        task: models::ModelTask::Generation,
        memory_budget_mb: config.memory_budget_mb,
        minimum_quality: if config.prefer_indic_generation {
            models::ModelQuality::Standard
        } else {
            models::ModelQuality::Draft
        },
        language: models::ModelLanguage::default(),
    };

    let generation_model = match models::resolve(&requirement, models_dir, &[], false) {
        Ok(model) => model,
        Err(err) if config.prefer_indic_generation && config.allow_compact_fallback => {
            // Auto mode: Standard Indic model missing or too large — stay
            // responsive with the compact default rather than failing the job.
            models::resolve(
                &models::ModelRequirement {
                    minimum_quality: models::ModelQuality::Draft,
                    ..requirement
                },
                models_dir,
                &[],
                false,
            )
            .map_err(|fallback| format!("{err}; compact fallback also failed: {fallback}"))?
        }
        Err(err) => return Err(err.to_string()),
    };

    let generation = LlamaGenerationEngine::load(
        std::path::Path::new(&generation_model.path),
        generation_model.memory_mb,
        2048,
    )
    .map_err(|e| format!("{}: {e}", generation_model.logical_id))?;

    let mut supervisor = Supervisor::new(ResourceBudget::new(config.memory_budget_mb));
    supervisor.register_generation(Box::new(generation));

    *lock(&ENGINE) = Some(supervisor);
    // A file name would not survive a model update that changes quantisation,
    // and replay must reproduce the reference.
    *lock(&MODEL_ID) = Some(format!(
        "{}@{}",
        generation_model.logical_id, generation_model.version
    ));
    Ok(())
}

/// True once `initialize` has succeeded.
#[frb(sync)]
pub fn is_ready() -> bool {
    lock(&ENGINE).is_some()
}

/// What produced the minutes, for the meeting library to record.
///
/// Empty before `initialize`, which is a state the caller can act on rather
/// than an error: it means nothing has been generated yet.
#[frb(sync)]
pub fn generation_model_id() -> String {
    lock(&MODEL_ID).clone().unwrap_or_default()
}

/// Transcript → minutes, streaming throughout.
///
/// `grammar` is a GBNF grammar (start symbol `root`) constraining the token
/// stream to a caller-chosen shape, or `None` for the model's normal
/// unconstrained Markdown output. It is plumbing, not policy: this function
/// does not know or care what the grammar encodes -- turning "Meeting IR as
/// JSON" into a concrete GBNF string is a capability decision for whichever
/// caller passes one in, not something minutes.rs decides.
pub fn generate_minutes(
    transcript: String,
    grammar: Option<String>,
    sink: StreamSink<GenerationEvent>,
) -> Result<(), String> {
    let emit = |event: GenerationEvent| -> Result<(), String> {
        sink.add(event).map_err(|e| e.to_string())
    };

    let cancel = CancelToken::new();
    *lock(&CANCEL) = Some(cancel.clone());

    let mut minutes = String::new();
    {
        let mut engine = lock(&ENGINE);
        let supervisor = engine.as_mut().ok_or("Airo Mind is not initialised")?;

        let generation = supervisor.run_generation(
            &GenerationRequest {
                prompt: minutes_prompt(&transcript),
                max_output_tokens: 320,
                grammar,
            },
            &cancel,
            &mut |chunk| {
                minutes.push_str(&chunk.text);
                let _ = sink.add(GenerationEvent::Generating {
                    text: chunk.text.clone(),
                });
                Ok(())
            },
        );
        if cancel.is_cancelled() {
            emit(GenerationEvent::Cancelled)?;
            return Ok(());
        }
        generation.map_err(|e| e.to_string())?;
    }

    emit(GenerationEvent::MinutesReady { text: minutes })
}

/// Stops the in-flight generation at the next token.
#[frb(sync)]
pub fn cancel_generation() {
    if let Some(token) = lock(&CANCEL).as_ref() {
        token.cancel();
    }
}

/// Timing and memory from the most recently completed `generate_minutes`
/// call. All zero before anything has generated, or if `initialize` was
/// never called — a state the caller can act on rather than an error.
#[frb(sync)]
pub fn generation_stats() -> GenerationStats {
    lock(&ENGINE)
        .as_ref()
        .and_then(Supervisor::generation_stats)
        .unwrap_or_default()
        .into()
}

/// Releases the loaded generation model. Safe to call when nothing is
/// loaded, and safe to call again after `initialize` reloads a model — this
/// only clears the Supervisor's generation slot, not the speech one (there
/// is none here) or the recorded `MODEL_ID`, so `generation_model_id`
/// continues to describe whatever was last generated until something new is.
#[frb(sync)]
pub fn unload_generation() {
    if let Some(supervisor) = lock(&ENGINE).as_mut() {
        supervisor.unregister_generation();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_surface_reports_uninitialised_rather_than_panicking() {
        if lock(&ENGINE).is_some() {
            return;
        }
        assert!(!is_ready());
        assert!(generation_model_id().is_empty());
        // Cancelling with nothing in flight is a no-op, not a crash.
        cancel_generation();
    }

    #[test]
    fn the_prompt_carries_the_transcript_and_forbids_invention() {
        let p = minutes_prompt("Priya said the lag is the bottleneck.");
        assert!(p.contains("Priya said the lag is the bottleneck."));
        assert!(p.contains("Do not invent facts"));
    }

    /// `ADR-0018 §4`: nothing above the Model Manager names a file.
    #[test]
    fn the_capability_never_names_a_model_file() {
        let source = include_str!("minutes.rs");
        for forbidden in [".gguf", ".bin", "q4_k_m"] {
            let occurrences = source.matches(forbidden).count();
            assert_eq!(
                occurrences, 1,
                "`{forbidden}` appears {occurrences} times -- the capability is naming model files again"
            );
        }
    }
}

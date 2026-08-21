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

use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

use crate::LlamaGenerationEngine;
use airo_mind_core::models;
use airo_mind_core::{GenerationRequest, ResourceBudget, RuntimeStats, Supervisor};
use airo_mind_reliability::{record_chat_completion, DiagnosticLevel};

use super::generation_state::{begin_job, lock, CANCEL, ENGINE, MODEL_ID};

// ---------------------------------------------------------------------------
// Wire types
// ---------------------------------------------------------------------------

/// Where the models live and what the engine may spend.
pub struct GenerationConfig {
    /// Directory for capability resolve, or a weight file the Dart Model
    /// Manager already chose. Minutes still pass a directory (`ADR-0018 §4`).
    /// Chat selection is a file, so the engine must load that file rather than
    /// asking resolve for Draft quality in the same folder.
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
// State — shared with `meeting_intelligence` via `generation_state`.
// ---------------------------------------------------------------------------

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

/// True when `models_dir` is already a weight file the Model Manager chose.
fn chosen_weight_path(models_dir: &std::path::Path) -> Option<&std::path::Path> {
    models_dir.is_file().then_some(models_dir)
}

fn install_generation(
    model_path: &std::path::Path,
    engine_memory_mb: u32,
    supervisor_budget_mb: u32,
    logical_id: String,
    version: &str,
) -> Result<(), String> {
    let generation = LlamaGenerationEngine::load(model_path, engine_memory_mb, 2048)
        .map_err(|e| format!("{logical_id}: {e}"))?;
    let mut supervisor = Supervisor::new(ResourceBudget::new(supervisor_budget_mb));
    supervisor.register_generation(Box::new(generation));
    *lock(&ENGINE) = Some(supervisor);
    // A file name would not survive a model update that changes quantisation,
    // and replay must reproduce the reference.
    *lock(&MODEL_ID) = Some(format!("{logical_id}@{version}"));
    // Metal device globals are C++ function-local statics. Register after
    // load so this handler runs *before* ggml's unique_ptr destructor.
    register_generation_exit_guard();
    Ok(())
}

/// Loads the generation model. Called on first use, not at startup: this
/// library is large and only minutes need it.
///
/// Safe to call again — a Flutter hot restart runs it a second time.
pub fn initialize(config: GenerationConfig) -> Result<(), String> {
    let models_dir = std::path::Path::new(&config.models_dir);

    if let Some(path) = chosen_weight_path(models_dir) {
        let logical_id = path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("chat")
            .to_string();
        return install_generation(
            path,
            config.memory_budget_mb,
            config.memory_budget_mb,
            logical_id,
            "selected",
        );
    }

    // `ADR-0018 §1`: ask for a CAPABILITY and a budget, never for a file.
    let requirement = models::ModelRequirement {
        task: models::ModelTask::Generation,
        memory_budget_mb: config.memory_budget_mb,
        minimum_quality: if config.prefer_indic_generation {
            models::ModelQuality::Standard
        } else {
            models::ModelQuality::Draft
        },
        maximum_quality: None,
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
                    maximum_quality: Some(models::ModelQuality::Draft),
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

    install_generation(
        std::path::Path::new(&generation_model.path),
        generation_model.memory_mb,
        config.memory_budget_mb,
        generation_model.logical_id,
        &generation_model.version,
    )
}

/// True once `initialize` has loaded a generation engine.
#[frb(sync)]
pub fn is_ready() -> bool {
    lock(&ENGINE)
        .as_ref()
        .is_some_and(Supervisor::has_generation_engine)
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

    let cancel = begin_job();

    let mut minutes = String::new();
    {
        let engine = lock(&ENGINE);
        let supervisor = engine.as_ref().ok_or("Airo Mind is not initialised")?;

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
        if let Err(error) = generation {
            let _ = record_chat_completion(
                "meeting.minutes.v1",
                "",
                false,
                DiagnosticLevel::ErrorsOnly,
            );
            return Err(error.to_string());
        }
    }

    let _ = record_chat_completion(
        "meeting.minutes.v1",
        &minutes,
        true,
        DiagnosticLevel::Standard,
    );
    emit(GenerationEvent::MinutesReady { text: minutes })
}

/// General text completion for assistant chat — prompt is used as-is (no
/// meeting-secretary wrapper). Shares the same generation engine as
/// [`generate_minutes`].
pub fn generate_completion(
    prompt: String,
    max_output_tokens: u32,
    sink: StreamSink<GenerationEvent>,
) -> Result<(), String> {
    let emit = |event: GenerationEvent| -> Result<(), String> {
        sink.add(event).map_err(|e| e.to_string())
    };

    let cancel = begin_job();

    let mut completion = String::new();
    {
        let engine = lock(&ENGINE);
        let supervisor = engine.as_ref().ok_or("Airo Mind is not initialised")?;

        let generation = supervisor.run_generation(
            &GenerationRequest {
                prompt,
                max_output_tokens,
                grammar: None,
            },
            &cancel,
            &mut |chunk| {
                completion.push_str(&chunk.text);
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
        if let Err(error) = generation {
            let _ =
                record_chat_completion("chat.assistant.v1", "", false, DiagnosticLevel::ErrorsOnly);
            return Err(error.to_string());
        }
    }

    let _ = record_chat_completion(
        "chat.assistant.v1",
        &completion,
        true,
        DiagnosticLevel::Standard,
    );
    emit(GenerationEvent::MinutesReady { text: completion })
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
///
/// Also the Metal-exit guard: Rust statics are never dropped, so without an
/// explicit unload the llama.cpp `ggml_metal_device` unique_ptr vector
/// destructor runs at `NSApplication terminate` while residency sets still
/// hold model buffers and `GGML_ASSERT([rsets->data count] == 0)` aborts.
#[frb(sync)]
pub fn unload_generation() {
    release_generation_resources();
}

/// Drops the generation Supervisor so llama.cpp can `rsets_rm` every Metal
/// buffer before ggml's process-exit device destructor runs.
fn release_generation_resources() {
    cancel_generation();
    *lock(&ENGINE) = None;
}

/// Runs [unload_generation] at process exit, before C++ static destructors
/// that were registered earlier (the Metal device vector is created during
/// model load, which happens before this `atexit` registration).
fn register_generation_exit_guard() {
    use std::sync::Once;
    static REGISTER: Once = Once::new();
    REGISTER.call_once(|| {
        #[allow(unsafe_code)]
        {
            // SAFETY: the handler only takes process-local mutexes and drops
            // `ENGINE`. It must not panic: atexit callbacks that unwind abort.
            let rc = unsafe { libc::atexit(release_generation_on_process_exit) };
            debug_assert_eq!(rc, 0);
        }
    });
}

extern "C" fn release_generation_on_process_exit() {
    let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(release_generation_resources));
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
        // Cancelling / unloading with nothing in flight is a no-op, not a crash.
        cancel_generation();
        unload_generation();
        unload_generation();
        register_generation_exit_guard();
        register_generation_exit_guard();
        assert!(!is_ready());
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

    #[test]
    fn a_regular_file_is_the_model_managers_choice() {
        let path =
            std::env::temp_dir().join(format!("airo-mind-chosen-weight-{}", std::process::id()));
        std::fs::write(&path, b"x").expect("probe file");
        assert!(chosen_weight_path(&path).is_some());
        std::fs::remove_file(&path).ok();
        assert!(chosen_weight_path(&std::env::temp_dir()).is_none());
    }
}

//! The Meeting capability, and the only thing Flutter can see. `#1401`.
//!
//! # Why the domain lives here and not below
//!
//! `C5` limits a capability to six functions and forbids the runtime from
//! knowing what a meeting is. Everything meeting-shaped — the word "minutes",
//! the secretary prompt, the WAV container, the id scheme — is in this module
//! or `crate::wav`. Below it, `SpeechEngine` takes PCM and `GenerationEngine`
//! takes a prompt, and neither has heard of a meeting.
//!
//! That is not tidiness. It is what lets a second capability reuse both engines
//! without inheriting the first one's vocabulary.
//!
//! # Streaming, because `I7`
//!
//! `process_recording` yields a `Stream`, not a future. Segments and tokens
//! reach the UI as the models produce them, so "watch processing" is the
//! pipeline being honest rather than a spinner over a black box. Nothing here
//! accumulates on behalf of the caller — the strings this module joins are the
//! ones it must persist anyway.
//!
//! # Clocks
//!
//! `recorded_at_ms` comes from Dart. `C2` forbids reading a wall clock on a
//! path that replay must reproduce, and this is that path.

use std::sync::Mutex;

use flutter_rust_bridge::frb;

// `StreamSink` is re-exported by the generated module rather than the crate
// root in flutter_rust_bridge 2.x. Importing it from anywhere else does not
// compile.
use crate::frb_generated::StreamSink;

use crate::models;
use crate::{
    AudioInput, CancelToken, GenerationRequest, LlamaGenerationEngine, Meeting, MeetingStore,
    ResourceBudget, SearchIndex, Supervisor, WhisperSpeechEngine,
};

// ---------------------------------------------------------------------------
// Wire types
// ---------------------------------------------------------------------------

/// Where the models and the store live. Supplied by Dart, which owns the
/// platform's notion of an application directory.
pub struct MindConfig {
    /// Where the Model Manager looks. **Not** a model path — `ADR-0018 §4`
    /// says nothing above the Manager names a file, a quantisation or a
    /// runtime, and this type is above the Manager.
    pub models_dir: String,
    pub store_path: String,
    /// Admission ceiling for the Supervisor (`C6`). A device that cannot afford
    /// the model is told so before anything allocates.
    pub memory_budget_mb: u32,
}

/// A stored meeting, flattened for the bridge.
///
/// Deliberately not `crate::Meeting` re-exported: the wire contract and the
/// storage record are allowed to diverge, and coupling them means a storage
/// change becomes a Dart change.
pub struct MeetingRecord {
    pub id: String,
    pub title: String,
    pub recorded_at: u64,
    pub transcript: String,
    pub minutes: String,
    pub model: String,
}

impl From<Meeting> for MeetingRecord {
    fn from(m: Meeting) -> Self {
        Self {
            id: m.id,
            title: m.title,
            recorded_at: m.recorded_at,
            transcript: m.transcript,
            minutes: m.minutes,
            model: m.model,
        }
    }
}

/// A search result, with the line that matched.
pub struct SearchHit {
    pub meeting_id: String,
    pub title: String,
    pub recorded_at: u64,
    pub snippet: String,
}

/// Progress, as it happens.
pub enum ProcessingEvent {
    /// One transcript segment, as whisper produced it.
    Transcribing {
        text: String,
    },
    /// The joined transcript. The UI can stop appending and start displaying.
    TranscriptReady {
        text: String,
    },
    /// One token, as llama produced it.
    Generating {
        text: String,
    },
    MinutesReady {
        text: String,
    },
    /// Durable. Only after this is the meeting reopenable.
    Saved {
        meeting_id: String,
    },
    /// The user navigated away. Nothing was saved.
    Cancelled,
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Loaded models. Held apart from `LIBRARY` on purpose: transcription holds
/// this lock for the length of a recording, and search must not queue behind it.
static ENGINES: Mutex<Option<Supervisor>> = Mutex::new(None);

/// The store and its projection.
static LIBRARY: Mutex<Option<Library>> = Mutex::new(None);

/// The in-flight job's token, so the UI can stop it.
static CANCEL: Mutex<Option<CancelToken>> = Mutex::new(None);

struct Library {
    store: MeetingStore,
    /// `C4`: rebuilt from the store, never persisted, disposable.
    index: SearchIndex,
    /// Which generation model produced the minutes in this session. Recorded
    /// with each meeting per `ADR-0018` — an LLM is not deterministic across
    /// versions, so what produced a summary is stored, not inferred later.
    generation_model: String,
}

/// A poisoned lock means a panic inside inference. The Supervisor keeps no
/// mutable state between runs, so the contents are still sound and recovering
/// beats bricking the app until it is reinstalled.
fn lock<T>(m: &'static Mutex<T>) -> std::sync::MutexGuard<'static, T> {
    m.lock().unwrap_or_else(|e| e.into_inner())
}

/// The Meeting capability's prompt. It lives here, above the engine boundary,
/// because `GenerationEngine::summarize(transcript) -> Minutes` would push
/// meeting semantics into the runtime.
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

/// Loads both models and opens the store. Safe to call again — a Flutter hot
/// restart runs it a second time, and refusing would make development require a
/// full relaunch.
///
/// A missing model is an ordinary error carrying the path, because on a real
/// device it is the most likely failure and the user can act on it.
pub fn initialize(config: MindConfig) -> Result<(), String> {
    let models_dir = std::path::Path::new(&config.models_dir);

    // `ADR-0018 §1`: ask for a CAPABILITY and a budget, never for a file. The
    // capability does not know which model it got, only that one resolved.
    let speech_model = models::resolve(
        &models::ModelRequirement {
            task: models::ModelTask::Speech,
            memory_budget_mb: config.memory_budget_mb,
            minimum_quality: models::ModelQuality::Draft,
        },
        models_dir,
        &[],
        false,
    )
    .map_err(|e| e.to_string())?;

    let generation_model = models::resolve(
        &models::ModelRequirement {
            task: models::ModelTask::Generation,
            memory_budget_mb: config.memory_budget_mb,
            minimum_quality: models::ModelQuality::Draft,
        },
        models_dir,
        &[],
        false,
    )
    .map_err(|e| e.to_string())?;

    let speech = WhisperSpeechEngine::load(
        std::path::Path::new(&speech_model.path),
        speech_model.memory_mb,
    )
    .map_err(|e| format!("{}: {e}", speech_model.logical_id))?;
    let generation = LlamaGenerationEngine::load(
        std::path::Path::new(&generation_model.path),
        generation_model.memory_mb,
        2048,
    )
    .map_err(|e| format!("{}: {e}", generation_model.logical_id))?;

    let mut supervisor = Supervisor::new(ResourceBudget::new(config.memory_budget_mb));
    supervisor.register_speech(Box::new(speech));
    supervisor.register_generation(Box::new(generation));

    let store = MeetingStore::open(&config.store_path);
    let index = SearchIndex::rebuild(&store.all().map_err(|e| e.to_string())?);

    *lock(&ENGINES) = Some(supervisor);
    *lock(&LIBRARY) = Some(Library {
        store,
        index,
        // `ADR-0018 §5`: the LOGICAL identity and version, recorded with the
        // content it produces. A file name would not survive a model update
        // that changes quantisation, and replay must reproduce the reference.
        generation_model: format!(
            "{}@{}",
            generation_model.logical_id, generation_model.version
        ),
    });
    Ok(())
}

/// True once `initialize` has succeeded. Lets the UI show why it cannot record
/// instead of failing at the moment the user presses the button.
#[frb(sync)]
pub fn is_ready() -> bool {
    lock(&ENGINES).is_some()
}

/// Recording → transcript → minutes → saved, streaming throughout.
///
/// The whole of steps 2–5 of the milestone journey. Runs on a
/// `flutter_rust_bridge` worker thread, never the Dart main isolate.
pub fn process_recording(
    wav_path: String,
    title: String,
    recorded_at_ms: u64,
    sink: StreamSink<ProcessingEvent>,
) -> Result<(), String> {
    let emit = |event: ProcessingEvent| -> Result<(), String> {
        sink.add(event).map_err(|e| e.to_string())
    };

    let bytes = std::fs::read(&wav_path).map_err(|e| format!("reading {wav_path}: {e}"))?;
    let pcm = crate::wav::decode(&bytes)?;

    let cancel = CancelToken::new();
    *lock(&CANCEL) = Some(cancel.clone());

    // Scoped so the engine lock is released before the library lock is taken.
    // Holding both is how two locks become one deadlock.
    let (transcript, minutes) = {
        let mut engines = lock(&ENGINES);
        let supervisor = engines.as_mut().ok_or("Airo Mind is not initialised")?;

        let mut transcript = String::new();
        let speech = supervisor.run_speech(
            AudioInput {
                samples: &pcm.samples,
                sample_rate_hz: pcm.sample_rate_hz,
                channels: pcm.channels,
            },
            &cancel,
            &mut |segment| {
                if !transcript.is_empty() {
                    transcript.push(' ');
                }
                transcript.push_str(segment.text.trim());
                // Emitting per segment is the point: a ten-minute recording
                // shows text within seconds instead of after the whole file.
                let _ = sink.add(ProcessingEvent::Transcribing {
                    text: segment.text.clone(),
                });
                Ok(())
            },
        );
        if cancel.is_cancelled() {
            emit(ProcessingEvent::Cancelled)?;
            return Ok(());
        }
        speech.map_err(|e| e.to_string())?;

        if transcript.trim().is_empty() {
            return Err("No speech was found in the recording.".into());
        }
        emit(ProcessingEvent::TranscriptReady {
            text: transcript.clone(),
        })?;

        let mut minutes = String::new();
        let generation = supervisor.run_generation(
            &GenerationRequest {
                prompt: minutes_prompt(&transcript),
                max_output_tokens: 320,
            },
            &cancel,
            &mut |chunk| {
                minutes.push_str(&chunk.text);
                let _ = sink.add(ProcessingEvent::Generating {
                    text: chunk.text.clone(),
                });
                Ok(())
            },
        );
        if cancel.is_cancelled() {
            emit(ProcessingEvent::Cancelled)?;
            return Ok(());
        }
        generation.map_err(|e| e.to_string())?;

        (transcript, minutes)
    };

    emit(ProcessingEvent::MinutesReady {
        text: minutes.clone(),
    })?;

    let meeting = Meeting {
        id: format!("m{recorded_at_ms}"),
        title,
        recorded_at: recorded_at_ms / 1000,
        transcript,
        minutes,
        model: lock(&LIBRARY)
            .as_ref()
            .map(|l| l.generation_model.clone())
            .unwrap_or_default(),
    };

    let mut library = lock(&LIBRARY);
    let library = library.as_mut().ok_or("Airo Mind is not initialised")?;
    // Durable before the projection: an index entry for a meeting the store
    // does not hold is a search result that opens nothing.
    library.store.save(&meeting).map_err(|e| e.to_string())?;
    library.index.insert(&meeting);

    emit(ProcessingEvent::Saved {
        meeting_id: meeting.id,
    })
}

/// Stops the in-flight job at the next segment or token.
#[frb(sync)]
pub fn cancel_processing() {
    if let Some(token) = lock(&CANCEL).as_ref() {
        token.cancel();
    }
}

/// Every meeting, newest first.
pub fn list_meetings() -> Result<Vec<MeetingRecord>, String> {
    let library = lock(&LIBRARY);
    let library = library.as_ref().ok_or("Airo Mind is not initialised")?;
    Ok(library
        .store
        .all()
        .map_err(|e| e.to_string())?
        .into_iter()
        .map(MeetingRecord::from)
        .collect())
}

/// Step 7 of the journey. Searches transcripts and minutes.
pub fn search_meetings(query: String) -> Result<Vec<SearchHit>, String> {
    let library = lock(&LIBRARY);
    let library = library.as_ref().ok_or("Airo Mind is not initialised")?;
    Ok(library
        .index
        .search(&query)
        .into_iter()
        .map(|h| SearchHit {
            meeting_id: h.meeting_id,
            title: h.title,
            recorded_at: h.recorded_at,
            snippet: h.snippet,
        })
        .collect())
}

/// Step 8. Opens one meeting.
pub fn get_meeting(id: String) -> Result<Option<MeetingRecord>, String> {
    let library = lock(&LIBRARY);
    let library = library.as_ref().ok_or("Airo Mind is not initialised")?;
    Ok(library
        .store
        .get(&id)
        .map_err(|e| e.to_string())?
        .map(MeetingRecord::from))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Every call must say what is wrong rather than panicking on `None`, since
    /// on a device "the model did not load" is the common state, not the
    /// exceptional one.
    #[test]
    fn the_surface_reports_uninitialised_rather_than_panicking() {
        // Guarded: another test in this process may have initialised state.
        if lock(&ENGINES).is_some() {
            return;
        }
        assert!(!is_ready());
        assert!(list_meetings().is_err());
        assert!(search_meetings("anything".into()).is_err());
        assert!(get_meeting("nope".into()).is_err());
        // Cancelling with nothing in flight is a no-op, not a crash: the user
        // can press Stop on a screen whose job already finished.
        cancel_processing();
    }

    #[test]
    fn the_prompt_carries_the_transcript_and_forbids_invention() {
        let p = minutes_prompt("Priya said the lag is the bottleneck.");
        assert!(p.contains("Priya said the lag is the bottleneck."));
        assert!(p.contains("Do not invent facts"));
    }

    /// `ADR-0018 §4`: nothing above the Model Manager names a file. If a
    /// quantisation or an extension appears in this module again, the file
    /// coupling the ADR removed has come back.
    #[test]
    fn the_capability_never_names_a_model_file() {
        let source = include_str!("mind.rs");
        for forbidden in [".gguf", ".bin", "q4_k_m"] {
            // The literal in this test is the only permitted occurrence.
            let occurrences = source.matches(forbidden).count();
            assert_eq!(
                occurrences, 1,
                "`{forbidden}` appears {occurrences} times -- the capability is naming model files again"
            );
        }
    }
}

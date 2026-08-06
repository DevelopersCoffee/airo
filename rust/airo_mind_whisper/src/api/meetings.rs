//! The Meeting capability's speech half, and the meeting library. `#1401`.
//!
//! # Why the domain lives here and not below
//!
//! `C5` limits a capability to six functions and forbids the runtime from
//! knowing what a meeting is. Everything meeting-shaped — the WAV container,
//! the id scheme — is in this module or `airo_mind_core::wav`. Below it,
//! `SpeechEngine` takes PCM and has never heard of a meeting.
//!
//! That is not tidiness. It is what lets a second capability reuse the engine
//! without inheriting the first one's vocabulary.
//!
//! # Why transcription and generation are separate calls
//!
//! They used to be one `process_recording` that ran the whole pipeline inside
//! Rust. They cannot be any more: the two engines live in two libraries,
//! because their vendored ggml copies cannot share a linked image. Dart holds
//! both and composes them.
//!
//! What that moves is *sequencing*, and only sequencing. Each library still
//! owns its own admission, budget and cancellation (`C6`), and the durability
//! rule below is still enforced here rather than trusted to the caller.
//!
//! # Streaming, because `I7`
//!
//! `transcribe_recording` yields a `Stream`, not a future. Segments reach the
//! UI as the model produces them, so "watch processing" is the pipeline being
//! honest rather than a spinner over a black box.
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

use crate::WhisperSpeechEngine;
use airo_mind_core::models;
use airo_mind_core::{
    AudioInput, CancelToken, Meeting, MeetingStore, ResourceBudget, SearchIndex, Supervisor,
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
/// Deliberately not `Meeting` re-exported: the wire contract and the storage
/// record are allowed to diverge, and coupling them means a storage change
/// becomes a Dart change.
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

/// Transcription progress, as it happens.
pub enum TranscriptEvent {
    /// One transcript segment, as whisper produced it.
    Transcribing { text: String },
    /// The joined transcript. The UI can stop appending and start displaying.
    TranscriptReady { text: String },
    /// The user navigated away. Nothing was saved.
    Cancelled,
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// The loaded speech model. Held apart from `LIBRARY` on purpose:
/// transcription holds this lock for the length of a recording, and search must
/// not queue behind it.
static ENGINES: Mutex<Option<Supervisor>> = Mutex::new(None);

/// The store and its projection.
static LIBRARY: Mutex<Option<Library>> = Mutex::new(None);

/// The in-flight job's token, so the UI can stop it.
static CANCEL: Mutex<Option<CancelToken>> = Mutex::new(None);

struct Library {
    store: MeetingStore,
    /// `C4`: rebuilt from the store, never persisted, disposable.
    index: SearchIndex,
}

/// A poisoned lock means a panic inside inference. The Supervisor keeps no
/// mutable state between runs, so the contents are still sound and recovering
/// beats bricking the app until it is reinstalled.
fn lock<T>(m: &'static Mutex<T>) -> std::sync::MutexGuard<'static, T> {
    m.lock().unwrap_or_else(|e| e.into_inner())
}

// ---------------------------------------------------------------------------
// The capability surface
// ---------------------------------------------------------------------------

/// Loads the speech model and opens the store. Safe to call again — a Flutter
/// hot restart runs it a second time, and refusing would make development
/// require a full relaunch.
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

    let speech = WhisperSpeechEngine::load(
        std::path::Path::new(&speech_model.path),
        speech_model.memory_mb,
    )
    .map_err(|e| format!("{}: {e}", speech_model.logical_id))?;

    let mut supervisor = Supervisor::new(ResourceBudget::new(config.memory_budget_mb));
    supervisor.register_speech(Box::new(speech));

    let store = MeetingStore::open(&config.store_path);
    let index = SearchIndex::rebuild(&store.all().map_err(|e| e.to_string())?);

    *lock(&ENGINES) = Some(supervisor);
    *lock(&LIBRARY) = Some(Library { store, index });
    Ok(())
}

/// True once `initialize` has succeeded. Lets the UI show why it cannot record
/// instead of failing at the moment the user presses the button.
#[frb(sync)]
pub fn is_ready() -> bool {
    lock(&ENGINES).is_some()
}

/// Recording → transcript, streaming throughout.
///
/// Runs on a `flutter_rust_bridge` worker thread, never the Dart main isolate.
/// The caller takes the transcript on to generation, which lives in the other
/// library.
pub fn transcribe_recording(
    wav_path: String,
    sink: StreamSink<TranscriptEvent>,
) -> Result<(), String> {
    let emit = |event: TranscriptEvent| -> Result<(), String> {
        sink.add(event).map_err(|e| e.to_string())
    };

    let bytes = std::fs::read(&wav_path).map_err(|e| format!("reading {wav_path}: {e}"))?;
    let pcm = airo_mind_core::wav::decode(&bytes)?;

    let cancel = CancelToken::new();
    *lock(&CANCEL) = Some(cancel.clone());

    let mut transcript = String::new();
    {
        let mut engines = lock(&ENGINES);
        let supervisor = engines.as_mut().ok_or("Airo Mind is not initialised")?;

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
                let _ = sink.add(TranscriptEvent::Transcribing {
                    text: segment.text.clone(),
                });
                Ok(())
            },
        );
        if cancel.is_cancelled() {
            emit(TranscriptEvent::Cancelled)?;
            return Ok(());
        }
        speech.map_err(|e| e.to_string())?;
    }

    if transcript.trim().is_empty() {
        return Err("No speech was found in the recording.".into());
    }
    emit(TranscriptEvent::TranscriptReady { text: transcript })
}

/// Makes a meeting durable and searchable. Returns its id.
///
/// Separate from transcription because the minutes come from the other library.
/// The ordering below is a contract, not an implementation detail: an index
/// entry for a meeting the store does not hold is a search result that opens
/// nothing. Keeping it here rather than in Dart is deliberate — the caller
/// sequences the pipeline, but it does not get to sequence durability.
///
/// `model` is the logical identity and version of whatever produced `minutes`
/// (`ADR-0018 §5`), supplied by the generation library. An LLM is not
/// deterministic across versions, so what produced a summary is stored, not
/// inferred later.
pub fn save_meeting(
    title: String,
    recorded_at_ms: u64,
    transcript: String,
    minutes: String,
    model: String,
) -> Result<String, String> {
    let meeting = Meeting {
        id: format!("m{recorded_at_ms}"),
        title,
        recorded_at: recorded_at_ms / 1000,
        transcript,
        minutes,
        model,
    };

    let mut library = lock(&LIBRARY);
    let library = library.as_mut().ok_or("Airo Mind is not initialised")?;
    // Durable before the projection.
    library.store.save(&meeting).map_err(|e| e.to_string())?;
    library.index.insert(&meeting);
    Ok(meeting.id)
}

/// Stops the in-flight transcription at the next segment.
///
/// Only this library's job. Dart cancels generation through the other library —
/// two engines, two admission controls, two cancellations.
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
        assert!(save_meeting("t".into(), 0, "x".into(), "y".into(), "m".into()).is_err());
        // Cancelling with nothing in flight is a no-op, not a crash: the user
        // can press Stop on a screen whose job already finished.
        cancel_processing();
    }

    /// `ADR-0018 §4`: nothing above the Model Manager names a file. If a
    /// quantisation or an extension appears in this module again, the file
    /// coupling the ADR removed has come back.
    #[test]
    fn the_capability_never_names_a_model_file() {
        let source = include_str!("meetings.rs");
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

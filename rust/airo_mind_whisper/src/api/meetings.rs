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

use crate::transcript_store;
use crate::WhisperSpeechEngine;
use airo_mind_core::models;
use airo_mind_core::wav::Pcm;
use airo_mind_core::{
    ActionStatus, AudioInput, CancelToken, DecisionStatus, Meeting, MeetingActionItem,
    MeetingDecision, MeetingMetric, MeetingStore, ResourceBudget, SearchIndex, Supervisor,
    TranscriptSegment, TranscriptionOptions,
};
use airo_mind_diarize::{diarize_segments, DiarizationStrategy};
use airo_mind_transcript::Segment;

// ---------------------------------------------------------------------------
// Wire types
// ---------------------------------------------------------------------------

/// Which speech model to resolve. Mirrors `airo_mind_core::models::
/// ModelLanguage` rather than re-exporting it: that type lives below the
/// Model Manager boundary (`ADR-0018 §4`), and the wire contract is allowed to
/// diverge from the storage/resolution type the same way `MeetingRecord`
/// already diverges from `Meeting`.
///
/// `#1629`: Hindi+English code-switching needs the multilingual weights: the
/// bundled `.en` model is architecturally incapable of any language but
/// English. Choosing `Multilingual` here only resolves a different registry
/// row — it does not download anything by itself, and `initialize` reports
/// `NotInstalled` naming the missing multilingual weight file the same way it
/// would for any other unresolved model (`ADR-0018 §4`: that name is the
/// Model Manager's to know, not this capability's).
///
/// Not to be confused with `TranscriptionOptions::language` (`#1664`), which
/// this field feeds but does not replace: `SpeechLanguage` picks *which
/// model* loads (English-only weights, or multilingual weights capable of
/// more than English); `TranscriptionOptions::language`, supplied per call to
/// `transcribe_recording`, pins *which language the loaded model decodes as*
/// for that one recording, or leaves it on auto-detect. A `Multilingual`
/// model with no language hint still auto-detects — this field alone does
/// not pin anything.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum SpeechLanguage {
    #[default]
    EnglishOnly,
    Multilingual,
}

impl From<SpeechLanguage> for models::ModelLanguage {
    fn from(language: SpeechLanguage) -> Self {
        match language {
            SpeechLanguage::EnglishOnly => Self::EnglishOnly,
            SpeechLanguage::Multilingual => Self::Multilingual,
        }
    }
}

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
    /// `#1629`. Defaults to `EnglishOnly` on the Dart side, so every existing
    /// caller keeps today's behaviour unchanged.
    pub speech_language: SpeechLanguage,
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
    /// `ADR-0022 §1`: the Meeting IR's decisions, action items and metrics,
    /// flattened onto the meeting record the same way every other field on
    /// this struct already is -- IR is not a sibling record with its own
    /// lifecycle, it rides `Meeting`'s.
    pub decisions: Vec<MeetingDecisionRecord>,
    pub action_items: Vec<MeetingActionItemRecord>,
    pub metrics: Vec<MeetingMetricRecord>,
}

/// Wire mirror of `airo_mind_core::DecisionStatus`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MeetingDecisionStatus {
    Proposed,
    Agreed,
    Rejected,
    Deferred,
}

impl From<DecisionStatus> for MeetingDecisionStatus {
    fn from(status: DecisionStatus) -> Self {
        match status {
            DecisionStatus::Proposed => Self::Proposed,
            DecisionStatus::Agreed => Self::Agreed,
            DecisionStatus::Rejected => Self::Rejected,
            DecisionStatus::Deferred => Self::Deferred,
        }
    }
}

impl From<MeetingDecisionStatus> for DecisionStatus {
    fn from(status: MeetingDecisionStatus) -> Self {
        match status {
            MeetingDecisionStatus::Proposed => Self::Proposed,
            MeetingDecisionStatus::Agreed => Self::Agreed,
            MeetingDecisionStatus::Rejected => Self::Rejected,
            MeetingDecisionStatus::Deferred => Self::Deferred,
        }
    }
}

/// Wire mirror of `airo_mind_core::ActionStatus`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MeetingActionStatus {
    Open,
    InProgress,
    Done,
    Blocked,
}

impl From<ActionStatus> for MeetingActionStatus {
    fn from(status: ActionStatus) -> Self {
        match status {
            ActionStatus::Open => Self::Open,
            ActionStatus::InProgress => Self::InProgress,
            ActionStatus::Done => Self::Done,
            ActionStatus::Blocked => Self::Blocked,
        }
    }
}

impl From<MeetingActionStatus> for ActionStatus {
    fn from(status: MeetingActionStatus) -> Self {
        match status {
            MeetingActionStatus::Open => Self::Open,
            MeetingActionStatus::InProgress => Self::InProgress,
            MeetingActionStatus::Done => Self::Done,
            MeetingActionStatus::Blocked => Self::Blocked,
        }
    }
}

/// Wire mirror of `airo_mind_core::MeetingDecision`. `evidence_segment_ids`
/// resolves against `transcript.json` per `ADR-0022 §4` -- this record
/// carries only the ids, never the words, matching the IR's own privacy
/// discipline (`rust/airo_mind_meeting/src/ir.rs`'s "evidence is segment ids,
/// not snippets").
pub struct MeetingDecisionRecord {
    pub id: String,
    pub statement: String,
    pub status: MeetingDecisionStatus,
    pub evidence_segment_ids: Vec<String>,
}

impl From<MeetingDecision> for MeetingDecisionRecord {
    fn from(d: MeetingDecision) -> Self {
        Self {
            id: d.id,
            statement: d.statement,
            status: d.status.into(),
            evidence_segment_ids: d.evidence_segment_ids,
        }
    }
}

impl From<MeetingDecisionRecord> for MeetingDecision {
    fn from(d: MeetingDecisionRecord) -> Self {
        Self {
            id: d.id,
            statement: d.statement,
            status: d.status.into(),
            evidence_segment_ids: d.evidence_segment_ids,
        }
    }
}

/// Wire mirror of `airo_mind_core::MeetingActionItem`.
pub struct MeetingActionItemRecord {
    pub id: String,
    pub task: String,
    /// `None` when the transcript named nobody -- never inferred, mirrored
    /// unchanged from `airo_mind_meeting::ir::ActionItem::owner`.
    pub owner: Option<String>,
    pub due: Option<String>,
    pub status: MeetingActionStatus,
    pub evidence_segment_ids: Vec<String>,
}

impl From<MeetingActionItem> for MeetingActionItemRecord {
    fn from(a: MeetingActionItem) -> Self {
        Self {
            id: a.id,
            task: a.task,
            owner: a.owner,
            due: a.due,
            status: a.status.into(),
            evidence_segment_ids: a.evidence_segment_ids,
        }
    }
}

impl From<MeetingActionItemRecord> for MeetingActionItem {
    fn from(a: MeetingActionItemRecord) -> Self {
        Self {
            id: a.id,
            task: a.task,
            owner: a.owner,
            due: a.due,
            status: a.status.into(),
            evidence_segment_ids: a.evidence_segment_ids,
        }
    }
}

/// Wire mirror of `airo_mind_core::MeetingMetric`.
pub struct MeetingMetricRecord {
    pub id: String,
    pub name: String,
    pub value: String,
    pub evidence_segment_ids: Vec<String>,
}

impl From<MeetingMetric> for MeetingMetricRecord {
    fn from(m: MeetingMetric) -> Self {
        Self {
            id: m.id,
            name: m.name,
            value: m.value,
            evidence_segment_ids: m.evidence_segment_ids,
        }
    }
}

impl From<MeetingMetricRecord> for MeetingMetric {
    fn from(m: MeetingMetricRecord) -> Self {
        Self {
            id: m.id,
            name: m.name,
            value: m.value,
            evidence_segment_ids: m.evidence_segment_ids,
        }
    }
}

/// Builds the `index`th [TranscriptSegmentRecord] for a recording from the
/// engine's raw [TranscriptSegment].
///
/// Pulled out of `transcribe_recording` so the id scheme (`"s{index}"`) and
/// the fact that `start_ms`/`end_ms`/`text` pass through unchanged can be
/// tested without a loaded model or a live `StreamSink` — `#1629`'s gap was
/// exactly this step silently dropping the timestamps, so it gets its own
/// name and its own tests.
fn transcript_segment_record(index: usize, segment: &TranscriptSegment) -> TranscriptSegmentRecord {
    TranscriptSegmentRecord {
        id: format!("s{index}"),
        start_ms: segment.start_ms,
        end_ms: segment.end_ms,
        text: segment.text.trim().to_string(),
        speaker_label: None,
    }
}

/// Assigns `speaker_label` on wire segments after ASR, using the PCM whisper
/// already preprocessed for transcription.
fn apply_diarization_labels(
    records: &mut [TranscriptSegmentRecord],
    pcm: &Pcm,
    strategy: DiarizationStrategy,
) -> Result<(), String> {
    if records.is_empty() {
        return Ok(());
    }
    let segments: Vec<Segment> = records
        .iter()
        .map(|record| Segment {
            id: record.id.clone(),
            start_ms: record.start_ms,
            end_ms: record.end_ms,
            text: record.text.clone(),
        })
        .collect();
    let result = diarize_segments(&segments, Some(pcm), strategy).map_err(|e| e.to_string())?;
    for (record, diarized) in records.iter_mut().zip(result.segments.iter()) {
        record.speaker_label = Some(diarized.speaker.label());
    }
    Ok(())
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
            decisions: m.decisions.into_iter().map(Into::into).collect(),
            action_items: m.action_items.into_iter().map(Into::into).collect(),
            metrics: m.metrics.into_iter().map(Into::into).collect(),
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

/// One transcript segment, with the evidence-grounding fields `#1657` needs:
/// a stable id and the audio timestamps whisper produced.
///
/// `id` is a sequence number scoped to this recording (`"s0"`, `"s1"`, …)
/// rather than a UUID — it is stable across the one transcription run that
/// produced it (segment 3 is always segment 3 for this recording) and free to
/// compute, which is all an evidence link back to an audio timestamp needs.
/// `start_ms`/`end_ms` are whisper's own segment timestamps
/// (`WhisperSpeechEngine`, `rust/airo_mind_whisper/src/whisper.rs`), carried
/// through rather than recomputed here.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TranscriptSegmentRecord {
    pub id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
    /// Diarization label (`sp0`, `sp1`, …). None for legacy segments.
    pub speaker_label: Option<String>,
}

/// Transcription progress, as it happens.
pub enum TranscriptEvent {
    /// One transcript segment, as whisper produced it.
    Transcribing { segment: TranscriptSegmentRecord },
    /// The joined transcript, plus every segment that produced it, in order.
    /// The flat `text` stays for callers that only want to display it; the UI
    /// case that needs a fact to point back at an audio timestamp reads
    /// `segments` instead of re-deriving them.
    TranscriptReady {
        text: String,
        segments: Vec<TranscriptSegmentRecord>,
    },
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

/// `logical_id@version` of whichever speech model `initialize` resolved.
/// `#1629` Gap D: `transcript.json` records which model produced a transcript
/// for reproducibility, and this is the only place that identity is known —
/// `WhisperSpeechEngine` itself is handed a path, never a logical id.
static SPEECH_MODEL_VERSION: Mutex<Option<String>> = Mutex::new(None);

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
            language: config.speech_language.into(),
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
    *lock(&SPEECH_MODEL_VERSION) = Some(format!(
        "{}@{}",
        speech_model.logical_id, speech_model.version
    ));
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
///
/// `language` is `#1664`'s per-recording language pin: a whisper.cpp
/// language code (`"en"`, `"hi"`, ...), or `None` to leave the engine on
/// auto-detect. Settings' "pin one or two expected languages" maps to Dart
/// always supplying the user's chosen primary language here — this call
/// accepts exactly one, because whisper.cpp itself has no "try either of
/// these" mode (see `TranscriptionOptions` in `airo_mind_core::engine`). A
/// "globally pinned" language is the same value passed on every call; there
/// is no separate global switch to keep in sync on the Rust side.
pub fn transcribe_recording(
    wav_path: String,
    language: Option<String>,
    sink: StreamSink<TranscriptEvent>,
) -> Result<(), String> {
    let emit = |event: TranscriptEvent| -> Result<(), String> {
        sink.add(event).map_err(|e| e.to_string())
    };

    let pcm = airo_mind_audio::preprocess_path(std::path::Path::new(&wav_path))?;

    let cancel = CancelToken::new();
    *lock(&CANCEL) = Some(cancel.clone());
    let options = TranscriptionOptions { language };

    let mut transcript = String::new();
    let mut segments: Vec<TranscriptSegmentRecord> = Vec::new();
    {
        let mut engines = lock(&ENGINES);
        let supervisor = engines.as_mut().ok_or("Airo Mind is not initialised")?;

        let speech = supervisor.run_speech(
            AudioInput {
                samples: &pcm.samples,
                sample_rate_hz: pcm.sample_rate_hz,
                channels: pcm.channels,
            },
            &options,
            &cancel,
            &mut |segment| {
                if !transcript.is_empty() {
                    transcript.push(' ');
                }
                transcript.push_str(segment.text.trim());
                // The id is the segment's position in *this* recording, so it
                // stays stable across the run that produced it without this
                // capability inventing an id scheme the store does not have.
                let record = transcript_segment_record(segments.len(), &segment);
                segments.push(record.clone());
                // Emitting per segment is the point: a ten-minute recording
                // shows text within seconds instead of after the whole file.
                let _ = sink.add(TranscriptEvent::Transcribing { segment: record });
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

    apply_diarization_labels(&mut segments, &pcm, DiarizationStrategy::Solo)?;

    emit(TranscriptEvent::TranscriptReady {
        text: transcript,
        segments,
    })
}

/// A meeting's transcript, in the reproducible shape `#1629` Gap D asks for:
/// the segments that produced the flat transcript string, which speech model
/// produced them, and which audio file they came from.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TranscriptDocumentRecord {
    pub meeting_id: String,
    pub audio_path: String,
    pub model_version: String,
    pub segments: Vec<TranscriptSegmentRecord>,
}

impl From<transcript_store::TranscriptDocument> for TranscriptDocumentRecord {
    fn from(doc: transcript_store::TranscriptDocument) -> Self {
        Self {
            meeting_id: doc.meeting_id,
            audio_path: doc.audio_path,
            model_version: doc.model_version,
            segments: doc
                .segments
                .into_iter()
                .map(|s| TranscriptSegmentRecord {
                    id: s.id,
                    start_ms: s.start_ms,
                    end_ms: s.end_ms,
                    text: s.text,
                    speaker_label: s.speaker_label,
                })
                .collect(),
        }
    }
}

/// Makes a meeting durable and searchable, and persists its structured
/// transcript document. Returns the meeting's id.
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
///
/// `segments` and `audio_path` are `#1629` Gap D: written to a per-meeting
/// `transcript.json` (`transcript_store`) after the flat `Meeting` record is
/// durable, so the ASR step is reproducible — which model produced these
/// segments, from which recording — independent of the append-only log's flat
/// string.
// `ADR-0022 §1` adds the three IR parameters to what was already a
// wide bridge signature. A params struct would need its own frb wire type
// with no reuse anywhere else, trading one clippy lint for a layer of
// indirection with a single call site -- `runtime.rs` accepts the same
// trade at this crate's other wide boundary functions.
#[allow(clippy::too_many_arguments)]
pub fn save_meeting(
    title: String,
    recorded_at_ms: u64,
    transcript: String,
    minutes: String,
    model: String,
    segments: Vec<TranscriptSegmentRecord>,
    audio_path: String,
    decisions: Vec<MeetingDecisionRecord>,
    action_items: Vec<MeetingActionItemRecord>,
    metrics: Vec<MeetingMetricRecord>,
) -> Result<String, String> {
    let meeting = Meeting {
        id: format!("m{recorded_at_ms}"),
        title,
        recorded_at: recorded_at_ms / 1000,
        transcript,
        minutes,
        model,
        decisions: decisions.into_iter().map(Into::into).collect(),
        action_items: action_items.into_iter().map(Into::into).collect(),
        metrics: metrics.into_iter().map(Into::into).collect(),
    };

    let mut library = lock(&LIBRARY);
    let library = library.as_mut().ok_or("Airo Mind is not initialised")?;
    // Durable before the projection.
    library.store.save(&meeting).map_err(|e| e.to_string())?;
    library.index.insert(&meeting);

    let model_version = lock(&SPEECH_MODEL_VERSION)
        .clone()
        .unwrap_or_else(|| "unknown".to_string());
    let doc = transcript_store::TranscriptDocument {
        meeting_id: meeting.id.clone(),
        audio_path,
        model_version,
        segments: segments
            .into_iter()
            .map(|s| transcript_store::StoredSegment {
                id: s.id,
                start_ms: s.start_ms,
                end_ms: s.end_ms,
                text: s.text,
                speaker_label: s.speaker_label,
            })
            .collect(),
    };
    transcript_store::write(library.store.path(), &doc)?;

    Ok(meeting.id)
}

/// Reopens a meeting's structured transcript document — the segments, model
/// version and audio reference `save_meeting` persisted. `Ok(None)` for a
/// meeting saved before this feature shipped, or one with no matching id.
pub fn get_transcript(meeting_id: String) -> Result<Option<TranscriptDocumentRecord>, String> {
    let library = lock(&LIBRARY);
    let library = library.as_ref().ok_or("Airo Mind is not initialised")?;
    Ok(transcript_store::read(library.store.path(), &meeting_id)?.map(Into::into))
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

    /// `#1629`: `transcribe_recording` computed `start_ms`/`end_ms` correctly
    /// at the engine layer (`WhisperSpeechEngine`) but discarded them before
    /// they reached `TranscriptEvent`. This test pins the fix at the smallest
    /// unit that can prove it without a loaded model: given raw engine
    /// segments in the order whisper would produce them, the ids are
    /// sequential and stable, and the timestamps/text survive unchanged.
    #[test]
    fn transcript_segment_record_preserves_timestamps_text_and_order() {
        let raw = [
            TranscriptSegment {
                start_ms: 0,
                end_ms: 1_200,
                text: "  the deploy is blocked  ".into(),
            },
            TranscriptSegment {
                start_ms: 1_200,
                end_ms: 3_450,
                text: "on the migration".into(),
            },
            TranscriptSegment {
                start_ms: 3_450,
                end_ms: 5_000,
                text: "Raj is looking at it".into(),
            },
        ];

        let records: Vec<TranscriptSegmentRecord> = raw
            .iter()
            .enumerate()
            .map(|(i, s)| transcript_segment_record(i, s))
            .collect();

        assert_eq!(
            records.iter().map(|r| r.id.as_str()).collect::<Vec<_>>(),
            ["s0", "s1", "s2"],
            "ids are sequential and stable within one recording"
        );
        assert_eq!(
            records.iter().map(|r| r.start_ms).collect::<Vec<_>>(),
            [0, 1_200, 3_450],
            "start_ms is not the field that goes missing any more"
        );
        assert_eq!(
            records.iter().map(|r| r.end_ms).collect::<Vec<_>>(),
            [1_200, 3_450, 5_000],
            "end_ms is not the field that goes missing any more"
        );
        // Segment boundaries are contiguous and non-decreasing: this is the
        // shape #1657's evidence links need to be trustworthy at all.
        for pair in records.windows(2) {
            assert!(
                pair[0].end_ms <= pair[1].start_ms,
                "segments must not overlap or reorder: {:?} then {:?}",
                pair[0],
                pair[1]
            );
        }
        assert_eq!(records[0].text, "the deploy is blocked", "text is trimmed");
        assert_eq!(records[1].text, "on the migration");
        assert_eq!(records[2].text, "Raj is looking at it");
    }

    #[test]
    fn transcript_segment_record_handles_a_single_segment_recording() {
        let record = transcript_segment_record(
            0,
            &TranscriptSegment {
                start_ms: 0,
                end_ms: 900,
                text: "hello".into(),
            },
        );
        assert_eq!(record.id, "s0");
        assert_eq!(record.start_ms, 0);
        assert_eq!(record.end_ms, 900);
        assert_eq!(record.text, "hello");
    }

    #[test]
    fn apply_diarization_labels_assigns_solo_speaker_on_segments() {
        let pcm = Pcm {
            samples: vec![0, 1, 2, 3],
            sample_rate_hz: 16_000,
            channels: 1,
        };
        let mut records = vec![
            TranscriptSegmentRecord {
                id: "s0".into(),
                start_ms: 0,
                end_ms: 500,
                text: "hello".into(),
                speaker_label: None,
            },
            TranscriptSegmentRecord {
                id: "s1".into(),
                start_ms: 500,
                end_ms: 900,
                text: "world".into(),
                speaker_label: None,
            },
        ];
        apply_diarization_labels(&mut records, &pcm, DiarizationStrategy::Solo)
            .expect("solo labels apply");
        assert_eq!(records[0].speaker_label.as_deref(), Some("sp0"));
        assert_eq!(records[1].speaker_label.as_deref(), Some("sp0"));
    }

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
        assert!(save_meeting(
            "t".into(),
            0,
            "x".into(),
            "y".into(),
            "m".into(),
            Vec::new(),
            "rec.wav".into(),
            Vec::new(),
            Vec::new(),
            Vec::new(),
        )
        .is_err());
        assert!(get_transcript("nope".into()).is_err());
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

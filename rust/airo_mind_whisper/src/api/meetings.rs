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

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::mpsc::{self, Receiver, SyncSender};
use std::sync::{LazyLock, Mutex};
use std::thread::JoinHandle;

use flutter_rust_bridge::frb;

// `StreamSink` is re-exported by the generated module rather than the crate
// root in flutter_rust_bridge 2.x. Importing it from anywhere else does not
// compile.
use crate::frb_generated::StreamSink;

use crate::transcript_store;
use crate::WhisperSpeechEngine;
use airo_mind_audio::{
    rms_energy, CaptureFanout, LiveSpeechConfig, LiveSpeechPipeline, SpeakerActivityTracker,
};
use airo_mind_core::engine::TranscriptSegmentState;
use airo_mind_core::models;
use airo_mind_core::wav::Pcm;
use airo_mind_core::{
    ActionStatus, AudioInput, CancelToken, DecisionStatus, EngineError, Meeting, MeetingActionItem,
    MeetingDecision, MeetingMetric, MeetingStore, ResourceBudget, SearchIndex, Supervisor,
    TranscriptSegment, TranscriptionOptions,
};
use airo_mind_diarize::{
    diarize_segments, product_diarization_strategy, resolve_embedder, DiarizationStrategy,
    SpeakerEmbedder, SpeakerEnrollmentStore,
};
use airo_mind_transcript::Segment;
use airo_mind_transcript::VocabularyIntelligence;

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
    models_dir: Option<&Path>,
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
    let enrollment = lock(&*SPEAKER_ENROLLMENT);
    let result = match diarize_segments(
        &segments,
        Some(pcm),
        strategy,
        models_dir,
        Some(&*enrollment),
    ) {
        Ok(result) => result,
        Err(error) if !matches!(strategy, DiarizationStrategy::Solo) => {
            diarize_segments(&segments, None, DiarizationStrategy::Solo, None, None)
                .map_err(|e| format!("diarization failed ({error}); solo fallback failed: {e}"))?
        }
        Err(error) => return Err(error.to_string()),
    };
    for (record, diarized) in records.iter_mut().zip(result.segments.iter()) {
        record.speaker_label = Some(diarized.wire_label());
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

/// Live transcript state for a segment (`PARTIAL` / `STABLE` / `FINAL`).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TranscriptSegmentStateWire {
    Partial,
    Stable,
    Final,
}

impl From<TranscriptSegmentState> for TranscriptSegmentStateWire {
    fn from(state: TranscriptSegmentState) -> Self {
        match state {
            TranscriptSegmentState::Partial => Self::Partial,
            TranscriptSegmentState::Stable => Self::Stable,
            TranscriptSegmentState::Final => Self::Final,
        }
    }
}

/// One live transcript update during an active session (`ADR-0025` §6.3).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TranscriptDeltaRecord {
    pub session_id: String,
    pub segment_id: String,
    pub speaker_label: Option<String>,
    pub text: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub state: TranscriptSegmentStateWire,
}

/// Transcription progress, as it happens.
pub enum TranscriptEvent {
    /// One transcript segment, as whisper produced it.
    Transcribing { segment: TranscriptSegmentRecord },
    /// Live session hypothesis or commit (`PARTIAL` / `STABLE` / `FINAL`).
    Delta { delta: TranscriptDeltaRecord },
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
    /// Ring overflow, thermal backoff, or another recoverable live degradation.
    Degraded { message: String },
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

/// Models directory from the last successful `initialize` — used to pick
/// diarization strategy (ECAPA optional weights).
static MODELS_DIR: Mutex<Option<PathBuf>> = Mutex::new(None);

/// Parent of `MindConfig.store_path` — live fan-out WAVs live in
/// `{parent}/mind_recordings/{meeting_id}.wav`, matching Dart's app-support
/// layout (`mind_service` store + `nextMeetingRecordingPath`).
static STORE_PARENT_DIR: Mutex<Option<PathBuf>> = Mutex::new(None);

static SPEECH_MEMORY_BUDGET_MB: Mutex<Option<u32>> = Mutex::new(None);

static INITIALIZED_SPEECH_LANGUAGE: Mutex<Option<SpeechLanguage>> = Mutex::new(None);

/// Path of the whisper weights currently registered on the Supervisor.
static LOADED_SPEECH_PATH: Mutex<Option<String>> = Mutex::new(None);

/// The in-flight job's token, so the UI can stop it.
static CANCEL: Mutex<Option<CancelToken>> = Mutex::new(None);

struct LiveSessionState {
    meeting_id: String,
    pipeline: LiveSpeechPipeline,
    cancel: CancelToken,
    options: TranscriptionOptions,
    paused: bool,
    segment_index: usize,
    segments: Vec<TranscriptSegmentRecord>,
    transcript: String,
    sink: StreamSink<TranscriptEvent>,
    /// One degradation notice per session — ring overflow can drop many frames.
    degraded_notified: bool,
    /// Provisional live speaker lanes (`P1`); reconciled after recording.
    speaker_activity: SpeakerActivityTracker,
    last_window_energy: f32,
    /// Authoritative file writer. Live STT consumes a bounded channel, not this handle.
    fanout: Option<CaptureFanout>,
    live_tx: Option<SyncSender<Vec<i16>>>,
}

static LIVE_SESSIONS: LazyLock<Mutex<HashMap<String, LiveSessionState>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

static LIVE_WORKERS: LazyLock<Mutex<HashMap<String, JoinHandle<()>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

static LIVE_VOCABULARY: LazyLock<VocabularyIntelligence> =
    LazyLock::new(VocabularyIntelligence::with_defaults);

/// Cross-meeting speaker enrollment profiles synced from Dart (#504).
static SPEAKER_ENROLLMENT: LazyLock<Mutex<SpeakerEnrollmentStore>> =
    LazyLock::new(|| Mutex::new(SpeakerEnrollmentStore::new()));

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

fn stored_speech_requirement_inputs() -> Result<(u32, models::ModelLanguage), String> {
    let budget = lock(&SPEECH_MEMORY_BUDGET_MB)
        .as_ref()
        .copied()
        .ok_or_else(|| "Airo Mind is not initialised".to_string())?;
    let speech_language = lock(&INITIALIZED_SPEECH_LANGUAGE)
        .as_ref()
        .copied()
        .ok_or_else(|| "Airo Mind is not initialised".to_string())?;
    Ok((budget, speech_language.into()))
}

/// Loads or swaps the registered speech engine when the resolved model path
/// differs from what is already registered (`ADR-0025` §6.7).
fn ensure_speech_engine_for_requirement(
    requirement: models::ModelRequirement,
) -> Result<(), String> {
    let models_dir = lock(&MODELS_DIR)
        .clone()
        .ok_or_else(|| "Airo Mind is not initialised".to_string())?;

    let speech_model =
        models::resolve(&requirement, &models_dir, &[], false).map_err(|e| e.to_string())?;

    if lock(&LOADED_SPEECH_PATH).as_deref() == Some(&speech_model.path) {
        return Ok(());
    }

    let speech = WhisperSpeechEngine::load(
        std::path::Path::new(&speech_model.path),
        speech_model.memory_mb,
    )
    .map_err(|e| format!("{}: {e}", speech_model.logical_id))?;

    let mut engines = lock(&ENGINES);
    let supervisor = engines
        .as_mut()
        .ok_or_else(|| "Airo Mind is not initialised".to_string())?;
    supervisor.register_speech(Box::new(speech));

    *lock(&SPEECH_MODEL_VERSION) = Some(format!(
        "{}@{}",
        speech_model.logical_id, speech_model.version
    ));
    *lock(&LOADED_SPEECH_PATH) = Some(speech_model.path.clone());
    Ok(())
}

fn ensure_speech_engine_for_live() -> Result<(), String> {
    let (budget, language) = stored_speech_requirement_inputs()?;
    ensure_speech_engine_for_requirement(models::speech_live_requirement(budget, language))
}

fn maybe_emit_live_degraded(session: &mut LiveSessionState, message: &str) -> Result<(), String> {
    if session.degraded_notified {
        return Ok(());
    }
    session.degraded_notified = true;
    session
        .sink
        .add(TranscriptEvent::Degraded {
            message: message.to_string(),
        })
        .map_err(|e| e.to_string())
}

fn sanitize_meeting_id(meeting_id: &str) -> String {
    let safe: String = meeting_id
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' || c == '_' || c == '.' {
                c
            } else {
                '_'
            }
        })
        .collect();
    if safe.is_empty() {
        "meeting".into()
    } else {
        safe
    }
}

fn live_fanout_path(meeting_id: &str) -> Option<PathBuf> {
    let parent = lock(&STORE_PARENT_DIR).clone()?;
    Some(
        parent
            .join("mind_recordings")
            .join(format!("{}.wav", sanitize_meeting_id(meeting_id))),
    )
}

fn spawn_live_worker(session_id: String, rx: Receiver<Vec<i16>>) {
    let worker_id = session_id.clone();
    let spawned = std::thread::Builder::new()
        .name(format!("airo-live-{session_id}"))
        .spawn(move || loop {
            let chunk = match rx.recv() {
                Ok(samples) => samples,
                Err(_) => break,
            };
            let panicked = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                {
                    let mut sessions = lock(&LIVE_SESSIONS);
                    let Some(session) = sessions.get_mut(&worker_id) else {
                        return;
                    };
                    if session.paused {
                        return;
                    }
                    session.pipeline.push_pcm(&chunk);
                    session.last_window_energy = rms_energy(&chunk);
                }
                let _ = run_live_pipeline_step(&worker_id);
            }));
            if panicked.is_err() {
                let mut sessions = lock(&LIVE_SESSIONS);
                if let Some(session) = sessions.get_mut(&worker_id) {
                    let _ = maybe_emit_live_degraded(
                        session,
                        "Live intelligence degraded — native worker recovered. Recording continues.",
                    );
                }
            }
        });
    if let Ok(handle) = spawned {
        lock(&LIVE_WORKERS).insert(session_id, handle);
    }
}

fn stop_live_worker(session_id: &str) {
    if let Some(handle) = lock(&LIVE_WORKERS).remove(session_id) {
        let _ = handle.join();
    }
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
    // `ADR-0018 §1`: ask for a CAPABILITY and a budget, never for a file. The
    // capability does not know which model it got, only that one resolved.
    let store = MeetingStore::open(&config.store_path);
    let index = SearchIndex::rebuild(&store.all().map_err(|e| e.to_string())?);

    let supervisor = Supervisor::new(ResourceBudget::new(config.memory_budget_mb));
    *lock(&ENGINES) = Some(supervisor);
    *lock(&MODELS_DIR) = Some(PathBuf::from(config.models_dir.clone()));
    *lock(&SPEECH_MEMORY_BUDGET_MB) = Some(config.memory_budget_mb);
    *lock(&INITIALIZED_SPEECH_LANGUAGE) = Some(config.speech_language);
    *lock(&LIBRARY) = Some(Library { store, index });
    *lock(&STORE_PARENT_DIR) = PathBuf::from(&config.store_path)
        .parent()
        .map(|p| p.to_path_buf())
        .or_else(|| Some(PathBuf::from(".")));

    ensure_speech_engine_for_requirement(models::speech_file_requirement(
        config.memory_budget_mb,
        config.speech_language.into(),
    ))?;
    crate::mind_runtime_state::open_mind_runtime(&config.models_dir)?;
    // Metal device globals are C++ function-local statics. Register after
    // load so this handler runs *before* ggml's unique_ptr destructor.
    register_speech_exit_guard();
    Ok(())
}

/// True once `initialize` has succeeded. Lets the UI show why it cannot record
/// instead of failing at the moment the user presses the button.
#[frb(sync)]
pub fn is_ready() -> bool {
    lock(&ENGINES).is_some()
}

/// Sarvam Edge on-device ASR — true when public weights are installed (`#1664`).
///
/// Flip is automatic once `sarvam_edge_speech.onnx` is in the models directory
/// (future HF pin). Dev override: `AIRO_SARVAM_EDGE_SPEECH=1`.
#[frb(sync)]
pub fn sarvam_edge_speech_available() -> bool {
    if std::env::var("AIRO_SARVAM_EDGE_SPEECH").as_deref() == Ok("1") {
        return true;
    }
    let models_dir = lock(&MODELS_DIR);
    match models_dir.as_deref() {
        Some(dir) => sarvam_edge_speech_model_path(dir).is_some(),
        None => false,
    }
}

/// Expected on-disk name for Sarvam Edge ASR when public weights ship.
pub const SARVAM_EDGE_SPEECH_FILE: &str = "sarvam_edge_speech.onnx";

fn sarvam_edge_speech_model_path(models_dir: &Path) -> Option<PathBuf> {
    let path = models_dir.join(SARVAM_EDGE_SPEECH_FILE);
    if path.is_file() {
        Some(path)
    } else {
        None
    }
}

/// Wire profile for cross-meeting speaker enrollment (#504).
#[derive(Clone, Debug, serde::Deserialize)]
pub struct EnrolledSpeakerRecord {
    pub id: String,
    pub display_name: String,
    pub embedding: Vec<f32>,
}

/// Replaces the in-memory enrollment store used during diarization.
pub fn sync_speaker_enrollment_json(raw: String) {
    let profiles: Vec<EnrolledSpeakerRecord> = serde_json::from_str(&raw).unwrap_or_default();
    let mut store = SpeakerEnrollmentStore::new();
    for profile in profiles {
        store.replace_or_insert(profile.id, profile.display_name, profile.embedding);
    }
    *lock(&*SPEAKER_ENROLLMENT) = store;
}

pub(crate) fn replace_speaker_enrollment_store(store: SpeakerEnrollmentStore) {
    *lock(&*SPEAKER_ENROLLMENT) = store;
}

/// Speaker embedding for one transcript time range (#504).
///
/// Uses ECAPA when the optional ONNX file is installed; stub embedder otherwise.
#[frb(sync)]
pub fn embed_speaker_segment(
    wav_path: String,
    start_ms: u64,
    end_ms: u64,
) -> Result<Vec<f32>, String> {
    let pcm = airo_mind_audio::preprocess_path(Path::new(&wav_path)).map_err(|e| e.to_string())?;
    let core_pcm = Pcm {
        samples: pcm.samples,
        sample_rate_hz: pcm.sample_rate_hz,
        channels: pcm.channels,
    };
    let models_dir = lock(&MODELS_DIR).clone();
    let embedder = resolve_embedder(models_dir.as_deref());
    embedder
        .embed_segment(&core_pcm, start_ms, end_ms)
        .map_err(|e| e.to_string())
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

    let models_dir_guard = lock(&MODELS_DIR);
    let models_dir = models_dir_guard.as_deref();
    let strategy = models_dir
        .map(product_diarization_strategy)
        .unwrap_or(DiarizationStrategy::Solo);
    apply_diarization_labels(&mut segments, &pcm, strategy, models_dir)?;

    emit(TranscriptEvent::TranscriptReady {
        text: transcript,
        segments,
    })
}

fn vocabulary_correct_stable(text: &str) -> String {
    LIVE_VOCABULARY.correct(text).corrected_text
}

fn provisional_speaker_label(index: u8) -> String {
    format!("sp{index}")
}

fn emit_live_delta(
    session: &mut LiveSessionState,
    session_id: &str,
    segment: TranscriptSegment,
) -> Result<(), String> {
    let raw_text = segment.text.trim().to_string();
    let display_text = match segment.state {
        TranscriptSegmentState::Partial => raw_text.clone(),
        TranscriptSegmentState::Stable | TranscriptSegmentState::Final => {
            vocabulary_correct_stable(&raw_text)
        }
    };

    let speaker_label = match segment.state {
        TranscriptSegmentState::Partial => Some(provisional_speaker_label(
            session.speaker_activity.active_speaker_index(),
        )),
        TranscriptSegmentState::Stable => {
            let index = session.speaker_activity.on_utterance(
                segment.start_ms,
                segment.end_ms,
                session.last_window_energy,
            );
            Some(provisional_speaker_label(index))
        }
        TranscriptSegmentState::Final => session
            .segments
            .last()
            .and_then(|record| record.speaker_label.clone()),
    };

    let segment_id = match segment.state {
        TranscriptSegmentState::Partial => format!("s{}", session.segment_index),
        TranscriptSegmentState::Stable => {
            let id = format!("s{}", session.segment_index);
            let mut corrected_segment = TranscriptSegment::new(
                segment.start_ms,
                segment.end_ms,
                display_text.clone(),
                segment.state,
            );
            let record = transcript_segment_record(session.segments.len(), &corrected_segment);
            let record = TranscriptSegmentRecord {
                id: id.clone(),
                start_ms: record.start_ms,
                end_ms: record.end_ms,
                text: record.text,
                speaker_label: speaker_label.clone(),
            };
            if !session.transcript.is_empty() {
                session.transcript.push(' ');
            }
            session.transcript.push_str(record.text.trim());
            session.segments.push(record);
            session.segment_index += 1;
            id
        }
        TranscriptSegmentState::Final => {
            if let Some(record) = session.segments.last_mut() {
                record.text = display_text.clone();
                record.end_ms = segment.end_ms;
                record.start_ms = segment.start_ms;
                record.id.clone()
            } else {
                let mut corrected_segment = TranscriptSegment::new(
                    segment.start_ms,
                    segment.end_ms,
                    display_text.clone(),
                    segment.state,
                );
                let record = transcript_segment_record(session.segments.len(), &corrected_segment);
                session.segments.push(record.clone());
                record.id
            }
        }
    };

    let delta = TranscriptDeltaRecord {
        session_id: session_id.to_string(),
        segment_id,
        speaker_label,
        text: display_text,
        start_ms: segment.start_ms,
        end_ms: segment.end_ms,
        state: TranscriptSegmentStateWire::from(segment.state),
    };
    session
        .sink
        .add(TranscriptEvent::Delta { delta })
        .map_err(|e| e.to_string())
}

fn run_live_pipeline_step(session_id: &str) -> Result<(), String> {
    let mut engines = lock(&ENGINES);
    let supervisor = engines
        .as_mut()
        .ok_or_else(|| "Airo Mind is not initialised".to_string())?;

    let mut sessions = lock(&LIVE_SESSIONS);
    let session = sessions
        .get_mut(session_id)
        .ok_or_else(|| format!("unknown live session {session_id}"))?;
    if session.paused {
        return Ok(());
    }

    let cancel = session.cancel.clone();
    let options = session.options.clone();
    let mut produced = Vec::new();

    let report = session
        .pipeline
        .step_with_transcribe(
            |audio, opts, token, sink| {
                supervisor
                    .run_speech(audio, opts, token, sink)
                    .map_err(|e| EngineError::Backend(e.to_string()))
            },
            &options,
            &cancel,
            &mut |segment| {
                produced.push(segment);
                Ok(())
            },
        )
        .map_err(|e| e.to_string())?;

    if report.degraded {
        maybe_emit_live_degraded(
            session,
            "Live transcript quality reduced — audio ring overflow.",
        )?;
    }
    if report.live_failed {
        maybe_emit_live_degraded(
            session,
            "Live intelligence degraded — inference failed. Recording continues.",
        )?;
    }
    session.last_window_energy = report.window_energy;

    for segment in produced {
        emit_live_delta(session, session_id, segment)?;
    }

    Ok(())
}

/// Opens a live transcription session. Refuses before the mic opens when the
/// speech model cannot be admitted (`ADR-0025` §6.6).
pub fn start_live_session(
    meeting_id: String,
    language: Option<String>,
    sink: StreamSink<TranscriptEvent>,
) -> Result<(), String> {
    ensure_speech_engine_for_live()?;

    let engines = lock(&ENGINES);
    let supervisor = engines
        .as_ref()
        .ok_or_else(|| "Airo Mind is not initialised".to_string())?;
    supervisor
        .check_speech_admission()
        .map_err(|e| e.to_string())?;

    let session_id = meeting_id.clone();
    let cancel = CancelToken::new();
    *lock(&CANCEL) = Some(cancel.clone());

    let (tx, rx) = mpsc::sync_channel::<Vec<i16>>(8);
    spawn_live_worker(session_id.clone(), rx);
    let fanout =
        live_fanout_path(&meeting_id).and_then(|path| CaptureFanout::create_file(path).ok());

    let session = LiveSessionState {
        meeting_id,
        pipeline: LiveSpeechPipeline::new(LiveSpeechConfig::default()),
        cancel,
        options: TranscriptionOptions { language },
        paused: false,
        segment_index: 0,
        segments: Vec::new(),
        transcript: String::new(),
        sink,
        degraded_notified: false,
        speaker_activity: SpeakerActivityTracker::new(1200),
        last_window_energy: 0.0,
        fanout,
        live_tx: Some(tx),
    };

    lock(&LIVE_SESSIONS).insert(session_id, session);
    Ok(())
}

/// Interim platform shim: pushes PCM into the native ring. Not the public
/// contract — documented in `LIVE_CAPTURE_FAN_OUT.md` §Interim shim.
#[frb(sync)]
pub fn push_live_pcm(session_id: String, samples: Vec<i16>) -> Result<(), String> {
    let mut sessions = lock(&LIVE_SESSIONS);
    let session = sessions
        .get_mut(&session_id)
        .ok_or_else(|| format!("unknown live session {session_id}"))?;
    if session.paused {
        return Ok(());
    }
    if let Some(fanout) = session.fanout.as_mut() {
        if let Err(error) = fanout.ingest(&samples) {
            maybe_emit_live_degraded(
                session,
                &format!("Live transcript quality reduced — recording write failed ({error})."),
            )?;
        }
    }
    session.last_window_energy = rms_energy(&samples);
    let live_busy = session
        .live_tx
        .as_ref()
        .map(|tx| tx.try_send(samples).is_err())
        .unwrap_or(true);
    if live_busy {
        maybe_emit_live_degraded(
            session,
            "Live transcript quality reduced — live worker backpressure.",
        )?;
    }
    Ok(())
}

#[frb(sync)]
pub fn pause_live_session(session_id: String) -> Result<(), String> {
    let mut sessions = lock(&LIVE_SESSIONS);
    let session = sessions
        .get_mut(&session_id)
        .ok_or_else(|| format!("unknown live session {session_id}"))?;
    session.paused = true;
    Ok(())
}

#[frb(sync)]
pub fn resume_live_session(session_id: String) -> Result<(), String> {
    let mut sessions = lock(&LIVE_SESSIONS);
    let session = sessions
        .get_mut(&session_id)
        .ok_or_else(|| format!("unknown live session {session_id}"))?;
    session.paused = false;
    Ok(())
}

/// Flushes stable hypotheses to `FINAL` and emits [`TranscriptEvent::TranscriptReady`].
///
/// When `audio_path` is supplied (the recorded file after stop), ECAPA/solo
/// diarization reconciles provisional live speaker lanes — same pass as
/// [`transcribe_recording`], without re-running ASR.
pub fn stop_live_session(session_id: String, audio_path: Option<String>) -> Result<(), String> {
    let mut session = lock(&LIVE_SESSIONS)
        .remove(&session_id)
        .ok_or_else(|| format!("unknown live session {session_id}"))?;
    session.live_tx = None;
    session.fanout = None;
    stop_live_worker(&session_id);

    let mut finals = Vec::new();
    session
        .pipeline
        .finish(&mut |segment| {
            finals.push(segment);
            Ok(())
        })
        .map_err(|e| e.to_string())?;

    let mut segments = session.segments;
    let mut transcript = session.transcript;
    for segment in finals {
        if segment.state == TranscriptSegmentState::Stable {
            let record = transcript_segment_record(segments.len(), &segment);
            if !transcript.is_empty() {
                transcript.push(' ');
            }
            transcript.push_str(record.text.trim());
            segments.push(record);
        } else if segment.state == TranscriptSegmentState::Final {
            if let Some(record) = segments.last_mut() {
                record.text = segment.text.trim().to_string();
                record.end_ms = segment.end_ms;
                record.start_ms = segment.start_ms;
            }
        }
    }

    if transcript.trim().is_empty() {
        return Err("No speech was found in the live session.".into());
    }

    if let Some(path) = audio_path {
        let pcm = airo_mind_audio::preprocess_path(std::path::Path::new(&path))?;
        let models_dir_guard = lock(&MODELS_DIR);
        let models_dir = models_dir_guard.as_deref();
        let strategy = models_dir
            .map(product_diarization_strategy)
            .unwrap_or(DiarizationStrategy::Solo);
        apply_diarization_labels(&mut segments, &pcm, strategy, models_dir)?;
    }

    session
        .sink
        .add(TranscriptEvent::TranscriptReady {
            text: transcript,
            segments,
        })
        .map_err(|e| e.to_string())?;
    *lock(&CANCEL) = None;
    Ok(())
}

/// Aborts a live session without persisting transcript output.
#[frb(sync)]
pub fn cancel_live_session(session_id: String) -> Result<(), String> {
    let mut session = lock(&LIVE_SESSIONS)
        .remove(&session_id)
        .ok_or_else(|| format!("unknown live session {session_id}"))?;
    session.live_tx = None;
    session.fanout = None;
    stop_live_worker(&session_id);
    session.cancel.cancel();
    session
        .sink
        .add(TranscriptEvent::Cancelled)
        .map_err(|e| e.to_string())?;
    *lock(&CANCEL) = None;
    Ok(())
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

/// Drops the speech Supervisor so whisper.cpp can release Metal buffers
/// before ggml's process-exit `ggml_metal_device` destructor runs.
///
/// Rust statics are never dropped, so without this `NSApplication terminate`
/// hits `GGML_ASSERT([rsets->data count] == 0)` in `ggml_metal_rsets_free`.
/// Safe to call when nothing is loaded. Dart reaches this through the
/// exported C symbol — a new FRB method would require regenerating the
/// bridge, and quit must work on the already-linked dylib.
pub fn unload_speech() {
    release_speech_resources();
}

/// Exported so Dart can drop the speech engine on Cmd-Q / SIGTERM while
/// AppKit Metal is still valid. Hidden ggml symbols stay unexported; this
/// is a `#[no_mangle]` cdylib entry like the FRB wire functions.
#[allow(unsafe_code)]
#[no_mangle]
pub extern "C" fn airo_mind_whisper_unload_speech() {
    release_speech_resources();
}

fn release_speech_resources() {
    cancel_processing();
    *lock(&ENGINES) = None;
}

fn register_speech_exit_guard() {
    use std::sync::Once;
    static REGISTER: Once = Once::new();
    REGISTER.call_once(|| {
        #[allow(unsafe_code)]
        {
            extern "C" {
                fn atexit(cb: extern "C" fn()) -> i32;
            }
            // SAFETY: the handler only takes process-local mutexes and drops
            // `ENGINES`. It must not panic: atexit callbacks that unwind abort.
            let rc = unsafe { atexit(release_speech_on_process_exit) };
            debug_assert_eq!(rc, 0);
        }
    });
}

extern "C" fn release_speech_on_process_exit() {
    let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(release_speech_resources));
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

/// Drops a meeting from the append-only store and search index.
pub fn delete_meeting(id: String) -> Result<bool, String> {
    let mut library = lock(&LIBRARY);
    let library = library.as_mut().ok_or("Airo Mind is not initialised")?;
    let deleted = library.store.delete(&id).map_err(|e| e.to_string())?;
    if deleted {
        library.index.remove(&id);
    }
    Ok(deleted)
}

/// Dart reaches this without regenerating the FRB bridge.
#[allow(unsafe_code)]
#[no_mangle]
pub extern "C" fn airo_mind_whisper_delete_meeting(id: *const std::ffi::c_char) -> i32 {
    if id.is_null() {
        return -1;
    }
    // SAFETY: caller passes a NUL-terminated UTF-8 C string.
    let c_str = unsafe { std::ffi::CStr::from_ptr(id) };
    let Ok(id) = c_str.to_str() else {
        return -1;
    };
    match delete_meeting(id.to_string()) {
        Ok(true) => 0,
        Ok(false) => 1,
        Err(_) => -1,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sarvam_edge_speech_available_when_model_file_present() {
        let dir =
            std::env::temp_dir().join(format!("airo_sarvam_edge_test_{}", std::process::id()));
        std::fs::create_dir_all(&dir).expect("tempdir");
        let model_path = dir.join(SARVAM_EDGE_SPEECH_FILE);
        std::fs::write(&model_path, b"stub").expect("write stub onnx");

        assert!(sarvam_edge_speech_model_path(&dir).is_some());
        assert_eq!(
            sarvam_edge_speech_model_path(&dir).as_ref(),
            Some(&model_path)
        );
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn sarvam_edge_speech_unavailable_without_model_file() {
        let dir =
            std::env::temp_dir().join(format!("airo_sarvam_edge_empty_{}", std::process::id()));
        std::fs::create_dir_all(&dir).expect("tempdir");
        assert!(sarvam_edge_speech_model_path(&dir).is_none());
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn embed_speaker_segment_returns_stub_vector_without_ecapa() {
        let dir =
            std::env::temp_dir().join(format!("airo_embed_segment_test_{}", std::process::id()));
        std::fs::create_dir_all(&dir).expect("tempdir");
        let wav_path = dir.join("tone.wav");
        write_test_wav_i16(
            &wav_path,
            &(0..16_000)
                .map(|i| ((i % 200) as i16) - 100)
                .collect::<Vec<_>>(),
            16_000,
        );

        let embedding = embed_speaker_segment(wav_path.to_string_lossy().into_owned(), 0, 1_000)
            .expect("embed segment");
        assert!(!embedding.is_empty());
        let _ = std::fs::remove_dir_all(&dir);
    }

    fn write_test_wav_i16(path: &Path, samples: &[i16], sample_rate_hz: u32) {
        let num_samples = samples.len();
        let data_bytes = num_samples * 2;
        let byte_rate = sample_rate_hz * 2;
        let mut bytes = Vec::with_capacity(44 + data_bytes);
        bytes.extend_from_slice(b"RIFF");
        bytes.extend_from_slice(&(36 + data_bytes as u32).to_le_bytes());
        bytes.extend_from_slice(b"WAVEfmt ");
        bytes.extend_from_slice(&16u32.to_le_bytes());
        bytes.extend_from_slice(&1u16.to_le_bytes());
        bytes.extend_from_slice(&1u16.to_le_bytes());
        bytes.extend_from_slice(&sample_rate_hz.to_le_bytes());
        bytes.extend_from_slice(&byte_rate.to_le_bytes());
        bytes.extend_from_slice(&2u16.to_le_bytes());
        bytes.extend_from_slice(&16u16.to_le_bytes());
        bytes.extend_from_slice(b"data");
        bytes.extend_from_slice(&(data_bytes as u32).to_le_bytes());
        for sample in samples {
            bytes.extend_from_slice(&sample.to_le_bytes());
        }
        std::fs::write(path, bytes).expect("write wav");
    }

    /// `#1629`: `transcribe_recording` computed `start_ms`/`end_ms` correctly
    /// at the engine layer (`WhisperSpeechEngine`) but discarded them before
    /// they reached `TranscriptEvent`. This test pins the fix at the smallest
    /// unit that can prove it without a loaded model: given raw engine
    /// segments in the order whisper would produce them, the ids are
    /// sequential and stable, and the timestamps/text survive unchanged.
    #[test]
    fn transcript_segment_record_preserves_timestamps_text_and_order() {
        let raw = [
            TranscriptSegment::final_text(0, 1_200, "  the deploy is blocked  ".into()),
            TranscriptSegment::final_text(1_200, 3_450, "on the migration".into()),
            TranscriptSegment::final_text(3_450, 5_000, "Raj is looking at it".into()),
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
        let record =
            transcript_segment_record(0, &TranscriptSegment::final_text(0, 900, "hello".into()));
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
        apply_diarization_labels(&mut records, &pcm, DiarizationStrategy::Solo, None)
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
        // Cancelling / releasing with nothing in flight is a no-op, not a crash:
        // the user can press Stop on a screen whose job already finished.
        cancel_processing();
        release_speech_resources();
        release_speech_resources();
        register_speech_exit_guard();
        register_speech_exit_guard();
        assert!(!is_ready());
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

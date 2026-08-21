//! Meeting-intelligence pipeline: transcript preprocess → extract → validate → MoM.
//! `#1785`.
//!
//! Replaces the prose-only `generate_minutes` path for product orchestration.
//! Dart still owns sequencing across the two cdylibs; this module is everything
//! that must run in the generation library after ASR has produced segments.

use std::sync::Mutex;

use airo_mind_core::{
    CancelToken, EngineError, GenerationChunk, GenerationEngine, GenerationRequest,
    ResourceRequest, RuntimeError, RuntimeStats, Supervisor,
};
use airo_mind_diarize::diarize_single_speaker;
use airo_mind_meeting::{
    extract, generate_mom, record_validation, validate, ExtractionConfig, MeetingInput, MomError,
};
use airo_mind_transcript::{process, ChunkConfig, Segment};
use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

use super::generation_state::{begin_job, lock, with_supervisor, CANCEL, MODEL_ID};

// ---------------------------------------------------------------------------
// Wire types — field shapes match `airo_mind_whisper::api::meetings` so Dart
// can thread IR into `saveMeeting` without a second conversion layer.
// ---------------------------------------------------------------------------

pub struct MeetingIntelligenceSegment {
    pub id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MeetingDecisionStatus {
    Proposed,
    Agreed,
    Rejected,
    Deferred,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MeetingActionStatus {
    Open,
    InProgress,
    Done,
    Blocked,
}

pub struct MeetingDecisionRecord {
    pub id: String,
    pub statement: String,
    pub status: MeetingDecisionStatus,
    pub evidence_segment_ids: Vec<String>,
}

pub struct MeetingActionItemRecord {
    pub id: String,
    pub task: String,
    pub owner: Option<String>,
    pub due: Option<String>,
    pub status: MeetingActionStatus,
    pub evidence_segment_ids: Vec<String>,
}

pub struct MeetingMetricRecord {
    pub id: String,
    pub name: String,
    pub value: String,
    pub evidence_segment_ids: Vec<String>,
}

pub enum MeetingIntelligenceEvent {
    Extracting,
    Generating {
        text: String,
    },
    MinutesReady {
        text: String,
    },
    IrReady {
        decisions: Vec<MeetingDecisionRecord>,
        action_items: Vec<MeetingActionItemRecord>,
        metrics: Vec<MeetingMetricRecord>,
    },
    Cancelled,
}

// ---------------------------------------------------------------------------
// IR → wire
// ---------------------------------------------------------------------------

impl From<airo_mind_meeting::DecisionStatus> for MeetingDecisionStatus {
    fn from(status: airo_mind_meeting::DecisionStatus) -> Self {
        use airo_mind_meeting::DecisionStatus as S;
        match status {
            S::Proposed => Self::Proposed,
            S::Agreed => Self::Agreed,
            S::Rejected => Self::Rejected,
            S::Deferred => Self::Deferred,
        }
    }
}

impl From<airo_mind_meeting::ActionStatus> for MeetingActionStatus {
    fn from(status: airo_mind_meeting::ActionStatus) -> Self {
        use airo_mind_meeting::ActionStatus as S;
        match status {
            S::Open => Self::Open,
            S::InProgress => Self::InProgress,
            S::Done => Self::Done,
            S::Blocked => Self::Blocked,
        }
    }
}

fn decisions_from_ir(ir: &airo_mind_meeting::MeetingIr) -> Vec<MeetingDecisionRecord> {
    ir.facts
        .decisions
        .iter()
        .map(|d| MeetingDecisionRecord {
            id: d.id.clone(),
            statement: d.statement.clone(),
            status: d.status.into(),
            evidence_segment_ids: d.evidence.clone(),
        })
        .collect()
}

fn action_items_from_ir(ir: &airo_mind_meeting::MeetingIr) -> Vec<MeetingActionItemRecord> {
    ir.facts
        .action_items
        .iter()
        .map(|a| MeetingActionItemRecord {
            id: a.id.clone(),
            task: a.task.clone(),
            owner: a.owner.clone(),
            due: a.due.clone(),
            status: a.status.into(),
            evidence_segment_ids: a.evidence.clone(),
        })
        .collect()
}

fn metrics_from_ir(ir: &airo_mind_meeting::MeetingIr) -> Vec<MeetingMetricRecord> {
    ir.facts
        .metrics
        .iter()
        .map(|m| MeetingMetricRecord {
            id: m.id.clone(),
            name: m.name.clone(),
            value: m.value.clone(),
            evidence_segment_ids: m.evidence.clone(),
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Supervisor adapter — `airo_mind_meeting` drives a `&dyn GenerationEngine`;
// the real engine lives behind the shared `Supervisor`.
// ---------------------------------------------------------------------------

struct SupervisorGenerationEngine<'a> {
    supervisor: &'a Supervisor,
    sink: Option<&'a StreamSink<MeetingIntelligenceEvent>>,
    emit_error: &'a Mutex<Option<String>>,
}

impl GenerationEngine for SupervisorGenerationEngine<'_> {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(0)
    }

    fn stats(&self) -> RuntimeStats {
        self.supervisor.generation_stats().unwrap_or_default()
    }

    fn generate(
        &self,
        request: &GenerationRequest,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        self.supervisor
            .run_generation(request, cancel, &mut |chunk| {
                if let Some(event_sink) = self.sink {
                    if let Err(error) = event_sink.add(MeetingIntelligenceEvent::Generating {
                        text: chunk.text.clone(),
                    }) {
                        *self.emit_error.lock().unwrap() = Some(error.to_string());
                        return Err(EngineError::Backend(error.to_string()));
                    }
                }
                sink(chunk)
            })
            .map_err(runtime_to_engine)
    }
}

fn runtime_to_engine(error: RuntimeError) -> EngineError {
    match error {
        RuntimeError::Engine(e) => e,
        other => EngineError::Backend(other.to_string()),
    }
}

fn mom_to_engine(error: MomError) -> String {
    match error {
        MomError::Cancelled => "cancelled".into(),
        MomError::Engine(message) => message,
    }
}

// ---------------------------------------------------------------------------
// Capability surface
// ---------------------------------------------------------------------------

/// Segments → validated Meeting IR → streaming MoM.
///
/// Requires `initialize` from `minutes` to have succeeded — this module shares
/// the same `Supervisor` slot.
pub fn process_meeting_intelligence(
    meeting_id: String,
    title: String,
    segments: Vec<MeetingIntelligenceSegment>,
    sink: StreamSink<MeetingIntelligenceEvent>,
) -> Result<(), String> {
    let emit = |event: MeetingIntelligenceEvent| -> Result<(), String> {
        sink.add(event).map_err(|e| e.to_string())
    };

    let cancel = begin_job();

    let transcript_segments: Vec<Segment> = segments
        .iter()
        .map(|s| Segment {
            id: s.id.clone(),
            start_ms: s.start_ms,
            end_ms: s.end_ms,
            text: s.text.clone(),
        })
        .collect();

    // Wave 3: validate diarization seam before transcript preprocessing.
    // v0 assigns one speaker; multi-speaker embedders plug in here later.
    diarize_single_speaker(&transcript_segments).map_err(|e| e.to_string())?;

    let validate_segments = transcript_segments.clone();

    let processed = process(&transcript_segments, &ChunkConfig::default());

    emit(MeetingIntelligenceEvent::Extracting)?;

    let model_id = lock(&MODEL_ID).clone();

    let extraction = with_supervisor(|supervisor| {
        let emit_error = Mutex::new(None);
        let engine = SupervisorGenerationEngine {
            supervisor,
            sink: None,
            emit_error: &emit_error,
        };
        let result = extract(
            &engine,
            &processed,
            &MeetingInput {
                id: meeting_id.clone(),
                title: Some(title),
                model_id,
            },
            &ExtractionConfig::default(),
            &cancel,
        )
        .map_err(|e| e.to_string());
        if let Some(message) = emit_error.into_inner().unwrap() {
            return Err(message);
        }
        result
    })?;

    if cancel.is_cancelled() {
        emit(MeetingIntelligenceEvent::Cancelled)?;
        return Ok(());
    }

    let (validated_ir, report) = validate(&extraction.ir, &validate_segments);
    // Classification is in-process only: no new MindOpKind, no raw IR in the
    // diagnostic, and the FFI surface stays IrReady + MoM. Repair already
    // happened in `validate`; the classifier names the failure family and the
    // execution log keeps persistable metadata only.
    let _diagnostics = record_validation(&meeting_id, &report);

    emit(MeetingIntelligenceEvent::IrReady {
        decisions: decisions_from_ir(&validated_ir),
        action_items: action_items_from_ir(&validated_ir),
        metrics: metrics_from_ir(&validated_ir),
    })?;

    let minutes = with_supervisor(|supervisor| {
        let emit_error = Mutex::new(None);
        let engine = SupervisorGenerationEngine {
            supervisor,
            sink: Some(&sink),
            emit_error: &emit_error,
        };
        let result = generate_mom(&engine, &validated_ir, &cancel).map_err(mom_to_engine);
        if let Some(message) = emit_error.into_inner().unwrap() {
            return Err(message);
        }
        result
    })?;

    if cancel.is_cancelled() {
        emit(MeetingIntelligenceEvent::Cancelled)?;
        return Ok(());
    }

    emit(MeetingIntelligenceEvent::MinutesReady { text: minutes })
}

/// Stops the in-flight meeting-intelligence job at the next engine checkpoint.
#[frb(sync)]
pub fn cancel_meeting_intelligence() {
    if let Some(token) = lock(&CANCEL).as_ref() {
        token.cancel();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use airo_mind_meeting::ir::{ActionItem, Decision, Facts, Meeting, MeetingIr, Metric};

    #[test]
    fn ir_maps_to_wire_records_field_for_field() {
        let ir = MeetingIr {
            schema_version: airo_mind_meeting::IR_SCHEMA_VERSION.to_string(),
            meeting: Meeting {
                id: "m1".into(),
                title: Some("Standup".into()),
                ..Meeting::default()
            },
            facts: Facts {
                decisions: vec![Decision {
                    id: "d1".into(),
                    statement: "ship it".into(),
                    status: airo_mind_meeting::DecisionStatus::Agreed,
                    evidence: vec!["s0".into()],
                }],
                action_items: vec![ActionItem {
                    id: "a1".into(),
                    task: "write tests".into(),
                    owner: Some("Priya".into()),
                    due: Some("Friday".into()),
                    status: airo_mind_meeting::ActionStatus::Open,
                    evidence: vec!["s1".into()],
                }],
                metrics: vec![Metric {
                    id: "m1".into(),
                    name: "latency".into(),
                    value: "200ms".into(),
                    evidence: vec!["s2".into()],
                }],
                ..Facts::default()
            },
        };

        let decisions = decisions_from_ir(&ir);
        assert_eq!(decisions.len(), 1);
        assert_eq!(decisions[0].id, "d1");
        assert_eq!(decisions[0].status, MeetingDecisionStatus::Agreed);

        let actions = action_items_from_ir(&ir);
        assert_eq!(actions[0].owner.as_deref(), Some("Priya"));

        let metrics = metrics_from_ir(&ir);
        assert_eq!(metrics[0].value, "200ms");
    }
}

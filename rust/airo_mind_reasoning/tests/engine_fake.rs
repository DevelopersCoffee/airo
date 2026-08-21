//! Fake GenerationEngine coverage: no GGUF, no FFI.

use airo_mind_core::{
    CancelToken, EngineError, GenerationChunk, GenerationEngine, GenerationRequest,
    ResourceRequest, RuntimeStats,
};
use airo_mind_reasoning::{
    DeviceInferenceProfile, ReasoningEngine, ReasoningError, ReasoningEvent, ReasoningLevel,
    ReasoningRequest, ReasoningStage,
};

struct ScriptedEngine {
    body: String,
    fail: Option<EngineError>,
}

impl GenerationEngine for ScriptedEngine {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(0)
    }

    fn generate(
        &self,
        request: &GenerationRequest,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        if cancel.is_cancelled() {
            return Err(EngineError::Cancelled);
        }
        if let Some(err) = &self.fail {
            return Err(match err {
                EngineError::Cancelled => EngineError::Cancelled,
                EngineError::ModelUnavailable => EngineError::ModelUnavailable,
                EngineError::InvalidInput(m) => EngineError::InvalidInput(m.clone()),
                EngineError::Backend(m) => EngineError::Backend(m.clone()),
            });
        }
        assert!(
            request
                .grammar
                .as_deref()
                .is_some_and(|g| g.contains("root")),
            "reasoning must attach the result grammar"
        );
        for piece in self.body.as_bytes().chunks(5) {
            if cancel.is_cancelled() {
                return Err(EngineError::Cancelled);
            }
            sink(GenerationChunk {
                text: String::from_utf8_lossy(piece).into_owned(),
            })?;
        }
        Ok(())
    }

    fn stats(&self) -> RuntimeStats {
        RuntimeStats::default()
    }
}

fn envelope(answer: &str, summary: &str, confidence: &str) -> String {
    format!(r#"{{"answer":"{answer}","reasoning_summary":"{summary}","confidence":{confidence}}}"#)
}

fn collect(
    engine: &ScriptedEngine,
    request: ReasoningRequest,
    cancel: &CancelToken,
) -> Result<Vec<ReasoningEvent>, ReasoningError> {
    let mut events = Vec::new();
    ReasoningEngine::default().reason(engine, &request, cancel, &mut |event| {
        events.push(event);
        Ok(())
    })?;
    Ok(events)
}

fn completed_answer(events: &[ReasoningEvent]) -> String {
    events
        .iter()
        .find_map(|e| match e {
            ReasoningEvent::Completed { result } => Some(result.answer.clone()),
            _ => None,
        })
        .expect("Completed event")
}

#[test]
fn direct_question_streams_answer_deltas_and_summary() {
    let gen = ScriptedEngine {
        body: envelope("It is Tuesday.", "Answered from the clock.", "0.90"),
        fail: None,
    };
    let req = ReasoningRequest::fixture("time_query", 0.05);
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    assert!(matches!(events[0], ReasoningEvent::Started));
    assert!(events.iter().any(|e| matches!(
        e,
        ReasoningEvent::StageChanged {
            stage: ReasoningStage::Understanding
        }
    )));
    let deltas: String = events
        .iter()
        .filter_map(|e| match e {
            ReasoningEvent::AnswerDelta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();
    assert_eq!(deltas, "It is Tuesday.");
    assert_eq!(completed_answer(&events), "It is Tuesday.");
}

#[test]
fn calendar_lookup_stays_none() {
    let gen = ScriptedEngine {
        body: envelope("Three meetings tomorrow.", "Checked the calendar.", "0.96"),
        fail: None,
    };
    let req = ReasoningRequest::fixture("calendar_retrieval", 0.1);
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    match events.last() {
        Some(ReasoningEvent::Completed { result }) => {
            assert_eq!(result.level, ReasoningLevel::None);
            assert_eq!(
                result.reasoning_summary.as_deref(),
                Some("Checked the calendar.")
            );
        }
        other => panic!("expected Completed, got {other:?}"),
    }
}

#[test]
fn malformed_output_is_typed_error() {
    let gen = ScriptedEngine {
        body: "not json at all".into(),
        fail: None,
    };
    let req = ReasoningRequest::fixture("summarization", 0.4);
    let err = collect(&gen, req, &CancelToken::new()).unwrap_err();
    assert_eq!(err, ReasoningError::InvalidModelOutput);
}

#[test]
fn cancellation_before_generate_does_not_call_the_model() {
    let gen = ScriptedEngine {
        body: envelope("nope", "n", "0.1"),
        fail: None,
    };
    let cancel = CancelToken::new();
    cancel.cancel();
    let err = collect(&gen, ReasoningRequest::fixture("planning", 0.9), &cancel).unwrap_err();
    assert_eq!(err, ReasoningError::Cancelled);
}

#[test]
fn model_unavailable_maps_to_typed_error() {
    let gen = ScriptedEngine {
        body: String::new(),
        fail: Some(EngineError::ModelUnavailable),
    };
    let err = collect(
        &gen,
        ReasoningRequest::fixture("comparison", 0.6),
        &CancelToken::new(),
    )
    .unwrap_err();
    assert_eq!(err, ReasoningError::ModelNotLoaded);
}

#[test]
fn low_memory_device_clamps_deep_planning() {
    let gen = ScriptedEngine {
        body: envelope("A shorter plan.", "Clamped.", "0.80"),
        fail: None,
    };
    let mut req = ReasoningRequest::fixture("planning", 0.9);
    req.device = DeviceInferenceProfile::small_phone();
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    match events.last() {
        Some(ReasoningEvent::Completed { result }) => {
            assert_eq!(result.level, ReasoningLevel::Standard);
        }
        other => panic!("{other:?}"),
    }
}

#[test]
fn thoughts_in_model_output_are_rejected() {
    let gen = ScriptedEngine {
        body: r#"{"thoughts":"secret","answer":"x","reasoning_summary":"s","confidence":0.1}"#
            .into(),
        fail: None,
    };
    let err = collect(
        &gen,
        ReasoningRequest::fixture("summarization", 0.4),
        &CancelToken::new(),
    )
    .unwrap_err();
    assert_eq!(err, ReasoningError::InvalidModelOutput);
}

//! Fake GenerationEngine coverage: no GGUF, no FFI.

use std::collections::{HashMap, VecDeque};
use std::sync::Mutex;

use airo_mind_core::{
    CancelToken, EngineError, GenerationChunk, GenerationEngine, GenerationRequest,
    ResourceRequest, RuntimeStats,
};
use airo_mind_reasoning::{
    DeviceInferenceProfile, ReasoningEngine, ReasoningError, ReasoningEvent, ReasoningLevel,
    ReasoningRequest, ReasoningStage, ToolCall, ToolDefinition, ToolExecutor, MAX_TOOL_ITERATIONS,
};

struct ScriptedEngine {
    bodies: Mutex<VecDeque<String>>,
    generate_count: Mutex<u32>,
    fail: Option<EngineError>,
}

impl ScriptedEngine {
    fn once(body: impl Into<String>) -> Self {
        Self::sequence([body.into()])
    }

    fn sequence(bodies: impl IntoIterator<Item = String>) -> Self {
        Self {
            bodies: Mutex::new(bodies.into_iter().collect()),
            generate_count: Mutex::new(0),
            fail: None,
        }
    }

    fn always(body: impl Into<String>) -> Self {
        Self::once(body)
    }

    fn failing(err: EngineError) -> Self {
        Self {
            bodies: Mutex::new(VecDeque::new()),
            generate_count: Mutex::new(0),
            fail: Some(err),
        }
    }

    fn calls(&self) -> u32 {
        *self.generate_count.lock().unwrap()
    }
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
        *self.generate_count.lock().unwrap() += 1;
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
                .is_some_and(|g| g.contains("root") && g.contains("tool_calls")),
            "reasoning must attach the result grammar"
        );
        let body = {
            let mut queue = self.bodies.lock().unwrap();
            let next = queue.pop_front().expect("scripted generation body");
            if queue.is_empty() {
                queue.push_back(next.clone());
            }
            next
        };
        for piece in body.as_bytes().chunks(5) {
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

struct MapExecutor {
    outputs: HashMap<String, String>,
    names: Mutex<Vec<String>>,
}

impl MapExecutor {
    fn new(outputs: HashMap<String, String>) -> Self {
        Self {
            outputs,
            names: Mutex::new(Vec::new()),
        }
    }
}

impl ToolExecutor for MapExecutor {
    fn execute(&self, call: &ToolCall) -> Result<String, ReasoningError> {
        self.names.lock().unwrap().push(call.name.clone());
        Ok(self
            .outputs
            .get(&call.name)
            .cloned()
            .unwrap_or_else(|| "missing".into()))
    }
}

fn envelope(answer: &str, summary: &str, confidence: &str) -> String {
    format!(r#"{{"answer":"{answer}","reasoning_summary":"{summary}","confidence":{confidence}}}"#)
}

fn tool_envelope(name: &str) -> String {
    format!(
        r#"{{"answer":"","reasoning_summary":"Need {name}.","confidence":0.80,"tool_calls":[{{"name":"{name}","arguments_json":"{{}}" }}]}}"#
    )
}

fn calendar_tool() -> ToolDefinition {
    ToolDefinition {
        name: "read_calendar_events".into(),
        description: "List events for a day.".into(),
    }
}

fn collect(
    engine: &ScriptedEngine,
    request: ReasoningRequest,
    cancel: &CancelToken,
) -> Result<Vec<ReasoningEvent>, ReasoningError> {
    collect_with_tools(engine, request, cancel, None)
}

fn collect_with_tools(
    engine: &ScriptedEngine,
    request: ReasoningRequest,
    cancel: &CancelToken,
    tools: Option<&dyn ToolExecutor>,
) -> Result<Vec<ReasoningEvent>, ReasoningError> {
    let mut events = Vec::new();
    ReasoningEngine::default().reason_with_tools(
        engine,
        &request,
        cancel,
        &mut |event| {
            events.push(event);
            Ok(())
        },
        tools,
    )?;
    Ok(events)
}

fn completed(events: &[ReasoningEvent]) -> &airo_mind_reasoning::ReasoningResult {
    events
        .iter()
        .find_map(|e| match e {
            ReasoningEvent::Completed { result } => Some(result),
            _ => None,
        })
        .expect("Completed event")
}

#[test]
fn direct_question_streams_answer_deltas_and_summary() {
    let gen = ScriptedEngine::once(envelope(
        "It is Tuesday.",
        "Answered from the clock.",
        "0.90",
    ));
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
    assert_eq!(completed(&events).answer, "It is Tuesday.");
}

#[test]
fn calendar_lookup_stays_none() {
    let gen = ScriptedEngine::once(envelope(
        "Three meetings tomorrow.",
        "Checked the calendar.",
        "0.96",
    ));
    let req = ReasoningRequest::fixture("calendar_retrieval", 0.1);
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    let result = completed(&events);
    assert_eq!(result.level, ReasoningLevel::None);
    assert_eq!(
        result.reasoning_summary.as_deref(),
        Some("Checked the calendar.")
    );
}

#[test]
fn malformed_output_is_typed_error() {
    let gen = ScriptedEngine::once("not json at all");
    let req = ReasoningRequest::fixture("summarization", 0.4);
    let err = collect(&gen, req, &CancelToken::new()).unwrap_err();
    assert_eq!(err, ReasoningError::InvalidModelOutput);
}

#[test]
fn cancellation_before_generate_does_not_call_the_model() {
    let gen = ScriptedEngine::once(envelope("nope", "n", "0.1"));
    let cancel = CancelToken::new();
    cancel.cancel();
    let err = collect(&gen, ReasoningRequest::fixture("planning", 0.9), &cancel).unwrap_err();
    assert_eq!(err, ReasoningError::Cancelled);
    assert_eq!(gen.calls(), 0);
}

#[test]
fn model_unavailable_maps_to_typed_error() {
    let gen = ScriptedEngine::failing(EngineError::ModelUnavailable);
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
    let gen = ScriptedEngine::once(envelope("A shorter plan.", "Clamped.", "0.80"));
    let mut req = ReasoningRequest::fixture("planning", 0.9);
    req.device = DeviceInferenceProfile::small_phone();
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    assert_eq!(completed(&events).level, ReasoningLevel::Standard);
}

#[test]
fn thinking_channel_is_discarded_and_the_answer_survives() {
    let gen = ScriptedEngine::once(format!(
        "<think>do not persist this</think>{}",
        envelope("Ice is less dense than water.", "Density.", "0.88")
    ));
    let events = collect(
        &gen,
        ReasoningRequest::fixture("planning", 0.6),
        &CancelToken::new(),
    )
    .unwrap();
    let result = completed(&events);
    assert_eq!(result.answer, "Ice is less dense than water.");
    assert!(!result.answer.contains("persist"));
    let streamed: String = events
        .iter()
        .filter_map(|e| match e {
            ReasoningEvent::AnswerDelta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();
    assert!(!streamed.contains("persist"));
}

#[test]
fn thoughts_in_model_output_are_rejected() {
    let gen = ScriptedEngine::once(
        r#"{"thoughts":"secret","answer":"x","reasoning_summary":"s","confidence":0.1}"#,
    );
    let err = collect(
        &gen,
        ReasoningRequest::fixture("summarization", 0.4),
        &CancelToken::new(),
    )
    .unwrap_err();
    assert_eq!(err, ReasoningError::InvalidModelOutput);
}

#[test]
fn tool_calls_without_executor_are_handed_to_the_host() {
    let gen = ScriptedEngine::once(tool_envelope("read_calendar_events"));
    let mut req = ReasoningRequest::fixture("calendar_retrieval", 0.1);
    req.available_tools = vec![calendar_tool()];
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    let result = completed(&events);
    assert!(result.answer.is_empty());
    assert_eq!(result.tool_calls.len(), 1);
    assert_eq!(result.tool_calls[0].name, "read_calendar_events");
    assert_eq!(gen.calls(), 1);
}

#[test]
fn none_level_runs_one_tool_and_skips_a_second_model_call() {
    let gen = ScriptedEngine::once(tool_envelope("read_calendar_events"));
    let mut req = ReasoningRequest::fixture("calendar_retrieval", 0.1);
    req.available_tools = vec![calendar_tool()];
    let exec = MapExecutor::new(HashMap::from([(
        "read_calendar_events".into(),
        "Three meetings tomorrow.".into(),
    )]));
    let events = collect_with_tools(&gen, req, &CancelToken::new(), Some(&exec)).unwrap();
    let result = completed(&events);
    assert_eq!(result.answer, "Three meetings tomorrow.");
    assert_eq!(result.level, ReasoningLevel::None);
    assert_eq!(result.tool_calls.len(), 1);
    assert!(events.iter().any(|e| matches!(
        e,
        ReasoningEvent::ToolStarted {
            tool
        } if tool == "read_calendar_events"
    )));
    assert!(events.iter().any(|e| matches!(
        e,
        ReasoningEvent::ToolCompleted {
            tool
        } if tool == "read_calendar_events"
    )));
    assert_eq!(gen.calls(), 1);
    assert_eq!(*exec.names.lock().unwrap(), ["read_calendar_events"]);
}

#[test]
fn light_level_feeds_tool_output_into_a_second_generation() {
    let gen = ScriptedEngine::sequence([
        tool_envelope("read_calendar_events"),
        envelope("You have three meetings.", "Used the calendar.", "0.91"),
    ]);
    let mut req = ReasoningRequest::fixture("summarization", 0.4);
    req.available_tools = vec![calendar_tool()];
    let exec = MapExecutor::new(HashMap::from([(
        "read_calendar_events".into(),
        "a, b, c".into(),
    )]));
    let events = collect_with_tools(&gen, req, &CancelToken::new(), Some(&exec)).unwrap();
    let result = completed(&events);
    assert_eq!(result.answer, "You have three meetings.");
    assert_eq!(result.tool_calls.len(), 1);
    assert_eq!(gen.calls(), 2);
}

#[test]
fn tool_loop_stops_at_five() {
    let gen = ScriptedEngine::always(tool_envelope("read_calendar_events"));
    let mut req = ReasoningRequest::fixture("summarization", 0.4);
    req.available_tools = vec![calendar_tool()];
    let exec = MapExecutor::new(HashMap::from([(
        "read_calendar_events".into(),
        "ok".into(),
    )]));
    let err = collect_with_tools(&gen, req, &CancelToken::new(), Some(&exec)).unwrap_err();
    assert_eq!(err, ReasoningError::ToolBudgetExceeded);
    assert_eq!(exec.names.lock().unwrap().len() as u32, MAX_TOOL_ITERATIONS);
}

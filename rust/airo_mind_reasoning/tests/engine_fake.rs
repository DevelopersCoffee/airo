//! Fake GenerationEngine coverage: no GGUF, no FFI.

use std::collections::{HashMap, VecDeque};
use std::sync::Mutex;

use airo_mind_core::{
    CancelToken, EngineError, GenerationChunk, GenerationEngine, GenerationRequest,
    ResourceRequest, RuntimeStats,
};
use airo_mind_reasoning::{
    DeviceInferenceProfile, ReasoningEngine, ReasoningError, ReasoningEvent, ReasoningLevel,
    ReasoningRequest, ReasoningStage, ToolCall, ToolDefinition, ToolExecutor,
    CLARIFY_PROGRESS_PREFIX, MAX_TOOL_ITERATIONS, SHADOW_PROGRESS_PREFIX,
};

struct ScriptedEngine {
    bodies: Mutex<VecDeque<String>>,
    generate_count: Mutex<u32>,
    prompts: Mutex<Vec<String>>,
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
            prompts: Mutex::new(Vec::new()),
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
            prompts: Mutex::new(Vec::new()),
            fail: Some(err),
        }
    }

    fn calls(&self) -> u32 {
        *self.generate_count.lock().unwrap()
    }

    fn prompts(&self) -> Vec<String> {
        self.prompts.lock().unwrap().clone()
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
        self.prompts.lock().unwrap().push(request.prompt.clone());
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
        let grammar = request
            .grammar
            .as_deref()
            .expect("reasoning must attach the result grammar");
        let analyzer = request.prompt.contains("Pick exactly one capability");
        if analyzer {
            assert!(
                grammar.contains("root") && grammar.contains("capability"),
                "analyzer must attach the capability grammar"
            );
            assert!(!grammar.contains("diet.plan"));
            assert!(
                !grammar.contains(r#"root ::= "{""#),
                "opening brace is teacher-forced; grammar must start at \"capability\""
            );
        } else {
            assert!(
                grammar.contains("root") && grammar.contains("tool_calls"),
                "reasoning must attach the result grammar"
            );
            let lookup = grammar.contains("lookup-tail");
            let none_or_light = request
                .prompt
                .contains("Do not perform unnecessary analysis")
                || request
                    .prompt
                    .contains("Return a concise answer and a one-sentence basis");
            assert_eq!(
                lookup, none_or_light,
                "none/light attach lookup grammar; standard/deep keep the full envelope"
            );
            assert!(
                !grammar.contains(r#"root ::= "{""#),
                "opening brace is teacher-forced; grammar must start at \"answer\""
            );
        }
        assert!(
            request.prompt.ends_with('{'),
            "prompt must teacher-force '{{' so greedy GGUF does not EOG before JSON"
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

fn analyzer_envelope(capability: &str) -> String {
    format!(r#"{{"capability":"{capability}","confidence":0.88}}"#)
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

fn shadow_progress(events: &[ReasoningEvent]) -> Option<&str> {
    events.iter().find_map(|event| match event {
        ReasoningEvent::Progress { message } if message.starts_with(SHADOW_PROGRESS_PREFIX) => {
            Some(message.as_str())
        }
        _ => None,
    })
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
fn none_accepts_an_answer_only_envelope() {
    let gen = ScriptedEngine::once(r#""answer":"It is Tuesday."}"#);
    let req = ReasoningRequest::fixture("time_query", 0.05);
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    let result = completed(&events);
    assert_eq!(result.level, ReasoningLevel::None);
    assert_eq!(result.answer, "It is Tuesday.");
    assert!(result.reasoning_summary.is_none());
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

#[test]
fn underspecified_action_asks_instead_of_generating() {
    let gen = ScriptedEngine::once(envelope("A plan.", "Guessed.", "0.80"));
    let mut req = ReasoningRequest::fixture("conversation", 0.25);
    req.user_query = "I need to prepare for tomorrow.".into();
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    assert_eq!(gen.calls(), 0);
    assert!(events.iter().any(|e| matches!(
        e,
        ReasoningEvent::Error { message } if message.contains("calendar")
    )));
    assert!(events.iter().any(|e| matches!(
        e,
        ReasoningEvent::Progress { message } if message.starts_with(CLARIFY_PROGRESS_PREFIX)
            && message.contains("skill.execute")
    )));
    let shadow = shadow_progress(&events).expect("shadow compare on reason()");
    assert!(
        shadow.contains("conversation") && shadow.contains("general.chat"),
        "{shadow}"
    );
    assert!(
        shadow.contains("needs_clarification"),
        "underspecified leftover must still ask: {shadow}"
    );
    assert!(events
        .iter()
        .all(|e| !matches!(e, ReasoningEvent::Completed { .. })));
}

#[test]
fn deep_revises_the_draft_on_a_second_generation() {
    let gen = ScriptedEngine::sequence([
        envelope("Draft plan.", "First pass.", "0.70"),
        envelope("Revised plan.", "Checked constraints.", "0.92"),
    ]);
    let mut req = ReasoningRequest::fixture("planning", 0.9);
    req.user_query = "Plan the week around the launch.".into();
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    let result = completed(&events);
    assert_eq!(result.level, ReasoningLevel::Deep);
    assert_eq!(result.answer, "Revised plan.");
    assert_eq!(
        result.reasoning_summary.as_deref(),
        Some("Checked constraints.")
    );
    assert_eq!(gen.calls(), 2);
    let prompts = gen.prompts();
    assert_eq!(prompts.len(), 2);
    assert!(
        prompts[1].contains("Draft plan."),
        "validate pass must see the draft: {}",
        prompts[1]
    );
    assert!(
        prompts[1].contains("Check this draft") || prompts[1].contains("draft"),
        "validate pass must ask for a check: {}",
        prompts[1]
    );
    assert!(!prompts[1].contains("\"thoughts\""));
    let streamed: String = events
        .iter()
        .filter_map(|e| match e {
            ReasoningEvent::AnswerDelta { text } => Some(text.as_str()),
            _ => None,
        })
        .collect();
    assert_eq!(
        streamed, "Revised plan.",
        "draft tokens must not stream; only the validated answer"
    );
}

#[test]
fn standard_stays_one_generation() {
    let gen = ScriptedEngine::once(envelope("A shorter plan.", "One pass.", "0.80"));
    let req = ReasoningRequest::fixture("planning", 0.6);
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    assert_eq!(completed(&events).level, ReasoningLevel::Standard);
    assert_eq!(completed(&events).answer, "A shorter plan.");
    assert_eq!(gen.calls(), 1);
}

#[test]
fn deep_does_not_validate_a_tool_call_draft() {
    let gen = ScriptedEngine::once(tool_envelope("read_calendar_events"));
    let mut req = ReasoningRequest::fixture("planning", 0.9);
    req.available_tools = vec![calendar_tool()];
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    assert_eq!(completed(&events).tool_calls.len(), 1);
    assert_eq!(gen.calls(), 1);
}

#[test]
fn deep_keeps_the_draft_when_validate_output_is_malformed() {
    let gen = ScriptedEngine::sequence([
        envelope("Draft plan.", "First pass.", "0.70"),
        "not json at all".into(),
    ]);
    let events = collect(
        &gen,
        ReasoningRequest::fixture("planning", 0.9),
        &CancelToken::new(),
    )
    .unwrap();
    assert_eq!(completed(&events).answer, "Draft plan.");
    assert_eq!(gen.calls(), 2);
}

#[test]
fn analyzer_proposal_beats_a_wrong_legacy_kind() {
    let gen = ScriptedEngine::sequence([
        analyzer_envelope("planning.create"),
        envelope("A budget plan.", "Split income and bills.", "0.88"),
    ]);
    let mut req = ReasoningRequest::fixture("navigation", 0.2);
    req.user_query = "plan my budget".into();
    req.run_analyzer = true;
    req.requested_level = Some(ReasoningLevel::Standard);
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    assert_eq!(completed(&events).answer, "A budget plan.");
    assert_eq!(gen.calls(), 2);
    let shadow = shadow_progress(&events).expect("shadow compare on reason()");
    assert!(
        shadow.contains("navigation") && shadow.contains("planning.create"),
        "leftover parser kind must be compared, not discarded: {shadow}"
    );
    assert!(
        shadow.ends_with("|0"),
        "analyzer vs navigation leftover is a mismatch: {shadow}"
    );
    let prompts = gen.prompts();
    assert!(
        prompts[0].contains("Pick exactly one capability"),
        "first generate is the analyzer: {}",
        prompts[0]
    );
    assert!(
        prompts[1].contains("Make a study plan for the week."),
        "classified planning must condition the few-shots: {}",
        prompts[1]
    );
}

#[test]
fn analyzer_invented_id_falls_back_to_legacy() {
    let gen = ScriptedEngine::sequence([
        analyzer_envelope("diet.plan"),
        envelope("Opened Budget.", "Navigated.", "0.80"),
    ]);
    let mut req = ReasoningRequest::fixture("navigation", 0.2);
    req.user_query = "plan my budget".into();
    req.run_analyzer = true;
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    assert_eq!(completed(&events).answer, "Opened Budget.");
    assert_eq!(gen.calls(), 2);
    assert!(
        !gen.prompts()[1].contains("Make a study plan for the week."),
        "legacy navigation must not take the planning shot: {}",
        gen.prompts()[1]
    );
}

#[test]
fn analyzer_malformed_output_falls_back_to_legacy() {
    let gen = ScriptedEngine::sequence([
        "not json".into(),
        envelope(
            "Sky is blue because of scattering.",
            "Used density of air.",
            "0.80",
        ),
    ]);
    let mut req = ReasoningRequest::fixture("conversation", 0.3);
    req.user_query = "Why is the sky blue?".into();
    req.run_analyzer = true;
    let events = collect(&gen, req, &CancelToken::new()).unwrap();
    assert_eq!(
        completed(&events).answer,
        "Sky is blue because of scattering."
    );
    assert_eq!(gen.calls(), 2);
}

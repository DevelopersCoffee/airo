//! Reasoning capability surface. Drives `airo_mind_reasoning` over the
//! shared `Supervisor` generation slot — same engine as `generate_completion`.
//!
//! Flutter never sees a model name, a GBNF grammar, or a thought trace.

use std::sync::Mutex;

use airo_mind_core::{
    CancelToken, EngineError, GenerationChunk, GenerationEngine, GenerationRequest,
    ResourceRequest, RuntimeError, RuntimeStats, Supervisor,
};
use airo_mind_reasoning::{
    ClassifiedIntent, ContextItem, DeviceInferenceProfile, ReasoningContext, ReasoningEngine,
    ReasoningError, ReasoningEvent as DomainEvent, ReasoningLevel as DomainLevel,
    ReasoningRequest as DomainRequest, ReasoningStage as DomainStage, ToolDefinition,
};
use flutter_rust_bridge::frb;

use crate::frb_generated::StreamSink;

use super::generation_state::{begin_job, lock, with_supervisor, CANCEL};

pub struct ReasoningContextItem {
    pub source: String,
    pub text: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ReasoningLevel {
    None,
    Light,
    Standard,
    Deep,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ReasoningStage {
    Understanding,
    RetrievingContext,
    UsingTool,
    Analyzing,
    Validating,
    ComposingAnswer,
    Complete,
}

pub struct ReasoningRequest {
    pub user_query: String,
    pub intent_kind: String,
    pub intent_complexity: f32,
    pub requested_level: Option<ReasoningLevel>,
    pub max_reasoning_level: ReasoningLevel,
    pub available_memory_mb: u32,
    pub gpu_available: bool,
    pub npu_available: bool,
    pub thermal_constrained: bool,
    pub battery_constrained: bool,
    pub memories: Vec<ReasoningContextItem>,
    pub documents: Vec<ReasoningContextItem>,
    pub tool_results: Vec<ReasoningContextItem>,
    pub history: Vec<ReasoningContextItem>,
    pub tool_names: Vec<String>,
}

pub enum ReasoningEvent {
    Started,
    StageChanged {
        stage: ReasoningStage,
    },
    Progress {
        message: String,
    },
    ToolStarted {
        tool: String,
    },
    ToolCompleted {
        tool: String,
    },
    AnswerDelta {
        text: String,
    },
    Completed {
        answer: String,
        reasoning_summary: Option<String>,
        level: ReasoningLevel,
        confidence: Option<f32>,
    },
    Error {
        message: String,
    },
    Cancelled,
}

impl From<ReasoningLevel> for DomainLevel {
    fn from(value: ReasoningLevel) -> Self {
        match value {
            ReasoningLevel::None => Self::None,
            ReasoningLevel::Light => Self::Light,
            ReasoningLevel::Standard => Self::Standard,
            ReasoningLevel::Deep => Self::Deep,
        }
    }
}

impl From<DomainLevel> for ReasoningLevel {
    fn from(value: DomainLevel) -> Self {
        match value {
            DomainLevel::None => Self::None,
            DomainLevel::Light => Self::Light,
            DomainLevel::Standard => Self::Standard,
            DomainLevel::Deep => Self::Deep,
        }
    }
}

impl From<DomainStage> for ReasoningStage {
    fn from(value: DomainStage) -> Self {
        match value {
            DomainStage::Understanding => Self::Understanding,
            DomainStage::RetrievingContext => Self::RetrievingContext,
            DomainStage::UsingTool => Self::UsingTool,
            DomainStage::Analyzing => Self::Analyzing,
            DomainStage::Validating => Self::Validating,
            DomainStage::ComposingAnswer => Self::ComposingAnswer,
            DomainStage::Complete => Self::Complete,
        }
    }
}

impl ReasoningRequest {
    fn into_domain(self) -> DomainRequest {
        let items = |list: Vec<ReasoningContextItem>| {
            list.into_iter()
                .map(|i| ContextItem {
                    source: i.source,
                    text: i.text,
                })
                .collect()
        };
        DomainRequest {
            user_query: self.user_query,
            intent: ClassifiedIntent::new(self.intent_kind, self.intent_complexity),
            context: ReasoningContext {
                memories: items(self.memories),
                documents: items(self.documents),
                tool_results: items(self.tool_results),
                history: items(self.history),
            },
            available_tools: self
                .tool_names
                .into_iter()
                .map(|name| ToolDefinition {
                    name,
                    description: String::new(),
                })
                .collect(),
            requested_level: self.requested_level.map(Into::into),
            device: DeviceInferenceProfile {
                available_memory_mb: self.available_memory_mb,
                gpu_available: self.gpu_available,
                npu_available: self.npu_available,
                thermal_constrained: self.thermal_constrained,
                battery_constrained: self.battery_constrained,
                max_reasoning_level: self.max_reasoning_level.into(),
            },
        }
    }
}

fn wire_event(event: DomainEvent) -> ReasoningEvent {
    match event {
        DomainEvent::Started => ReasoningEvent::Started,
        DomainEvent::StageChanged { stage } => ReasoningEvent::StageChanged {
            stage: stage.into(),
        },
        DomainEvent::Progress { message } => ReasoningEvent::Progress { message },
        DomainEvent::ToolStarted { tool } => ReasoningEvent::ToolStarted { tool },
        DomainEvent::ToolCompleted { tool } => ReasoningEvent::ToolCompleted { tool },
        DomainEvent::AnswerDelta { text } => ReasoningEvent::AnswerDelta { text },
        DomainEvent::Completed { result } => ReasoningEvent::Completed {
            answer: result.answer,
            reasoning_summary: result.reasoning_summary,
            level: result.level.into(),
            confidence: result.confidence,
        },
        DomainEvent::Error { message } => ReasoningEvent::Error { message },
    }
}

/// Adapter: capability sees `&dyn GenerationEngine`; the real engine sits
/// behind `Supervisor`. Unlike meeting-intelligence, this does **not** forward
/// raw tokens to Flutter — those would be the envelope, including anything
/// the model tried to hide as a trace.
struct SupervisorGenerationAdapter<'a> {
    supervisor: &'a Supervisor,
}

impl GenerationEngine for SupervisorGenerationAdapter<'_> {
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
            .run_generation(request, cancel, sink)
            .map_err(|error| match error {
                RuntimeError::Engine(e) => e,
                other => EngineError::Backend(other.to_string()),
            })
    }
}

/// Intent + context → streamed reasoning events over the loaded generation
/// engine. Requires `initialize` from `minutes`.
///
/// Cancellation is [`super::minutes::cancel_generation`] — the same token
/// slot as completion, so Stop in the UI already covers this job.
pub fn reason(request: ReasoningRequest, sink: StreamSink<ReasoningEvent>) -> Result<(), String> {
    let emit = |event: ReasoningEvent| -> Result<(), String> {
        sink.add(event).map_err(|e| e.to_string())
    };
    let cancel = begin_job();
    let domain = request.into_domain();
    let sink_error = Mutex::new(None::<String>);

    let outcome = with_supervisor(|supervisor| {
        let adapter = SupervisorGenerationAdapter { supervisor };
        ReasoningEngine::default()
            .reason(&adapter, &domain, &cancel, &mut |event| {
                emit(wire_event(event)).map_err(|message| {
                    *sink_error.lock().unwrap() = Some(message);
                    ReasoningError::Cancelled
                })
            })
            .map_err(|e| e.user_message().to_string())
    });

    if cancel.is_cancelled() {
        let _ = emit(ReasoningEvent::Cancelled);
        return Ok(());
    }
    match outcome {
        Ok(()) => Ok(()),
        Err(message) => {
            if let Some(sink_message) = sink_error.lock().unwrap().as_ref() {
                return Err(sink_message.clone());
            }
            let _ = emit(ReasoningEvent::Error {
                message: if message.contains("not initialised") {
                    ReasoningError::InferenceUnavailable
                        .user_message()
                        .to_string()
                } else {
                    message
                },
            });
            Ok(())
        }
    }
}

/// Same token as [`super::minutes::cancel_generation`]. Exposed so Dart can
/// name the intent without knowing the slot is shared.
#[frb(sync)]
pub fn cancel_reasoning() {
    if let Some(token) = lock(&CANCEL).as_ref() {
        token.cancel();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wire_level_round_trips() {
        for level in [
            ReasoningLevel::None,
            ReasoningLevel::Light,
            ReasoningLevel::Standard,
            ReasoningLevel::Deep,
        ] {
            let domain: DomainLevel = level.into();
            let back = ReasoningLevel::from(domain);
            assert_eq!(back, level);
        }
    }

    #[test]
    fn calendar_request_maps_to_direct_lookup_intent() {
        let req = ReasoningRequest {
            user_query: "Show me tomorrow's calendar".into(),
            intent_kind: "calendar_retrieval".into(),
            intent_complexity: 0.1,
            requested_level: None,
            max_reasoning_level: ReasoningLevel::Deep,
            available_memory_mb: 8192,
            gpu_available: true,
            npu_available: false,
            thermal_constrained: false,
            battery_constrained: false,
            memories: vec![],
            documents: vec![],
            tool_results: vec![],
            history: vec![],
            tool_names: vec!["calendar".into()],
        };
        let domain = req.into_domain();
        assert!(domain.intent.is_direct_lookup());
        assert_eq!(domain.available_tools.len(), 1);
    }
}

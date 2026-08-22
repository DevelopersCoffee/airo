//! Drive `GenerationEngine`. No llama.cpp types here.

use std::time::Instant;

use airo_mind_core::{CancelToken, GenerationChunk, GenerationEngine, GenerationRequest};

use crate::context::{ContextItem, ContextLimits};
use crate::error::ReasoningError;
use crate::event::{ReasoningEvent, ReasoningStage};
use crate::grammar::grammar_for;
use crate::level::ReasoningLevel;
use crate::parser::{
    extract_tool_calls, reject_unknown_trace_keys, ResultStreamParser, ThinkingChannelStripper,
};
use crate::policy::{HeuristicReasoningPolicy, ReasoningPolicy};
use crate::prompt::{build_prompt, build_validate_prompt};
use crate::request::ReasoningRequest;
use crate::result::ReasoningResult;
use crate::tools::{ToolExecutor, MAX_TOOL_ITERATIONS};
use crate::validator::validate_result;
use airo_mind_intent::{classify, ClassifyRequest, IntentStatus};

pub struct ReasoningTimings {
    pub policy_ms: u128,
    pub prompt_ms: u128,
    pub generation_ms: u128,
    pub total_ms: u128,
}

pub struct ReasoningEngine<P> {
    pub policy: P,
    pub limits: ContextLimits,
    pub max_output_tokens: u32,
}

impl Default for ReasoningEngine<HeuristicReasoningPolicy> {
    fn default() -> Self {
        Self {
            policy: HeuristicReasoningPolicy,
            limits: ContextLimits::default(),
            max_output_tokens: 512,
        }
    }
}

impl<P: ReasoningPolicy> ReasoningEngine<P> {
    pub fn reason(
        &self,
        generation: &dyn GenerationEngine,
        request: &ReasoningRequest,
        cancel: &CancelToken,
        emit: &mut dyn FnMut(ReasoningEvent) -> Result<(), ReasoningError>,
    ) -> Result<(), ReasoningError> {
        self.reason_with_tools(generation, request, cancel, emit, None)
    }

    /// Same as [`Self::reason`], executing parsed tool calls through `tools`
    /// until the model answers or [`MAX_TOOL_ITERATIONS`] is hit.
    ///
    /// When `tools` is `None`, a tool-call envelope is returned on
    /// `Completed` so the host can run verbs and call `reason` again.
    pub fn reason_with_tools(
        &self,
        generation: &dyn GenerationEngine,
        request: &ReasoningRequest,
        cancel: &CancelToken,
        emit: &mut dyn FnMut(ReasoningEvent) -> Result<(), ReasoningError>,
        tools: Option<&dyn ToolExecutor>,
    ) -> Result<(), ReasoningError> {
        let started = Instant::now();
        emit(ReasoningEvent::Started)?;
        check(cancel)?;

        emit(ReasoningEvent::StageChanged {
            stage: ReasoningStage::Understanding,
        })?;
        let proposal = if request.run_analyzer {
            match crate::analyzer::analyze(generation, &request.user_query, cancel) {
                Ok(proposal) => proposal,
                Err(ReasoningError::Cancelled) => return Err(ReasoningError::Cancelled),
                Err(_) => None,
            }
        } else {
            None
        };
        let decision = classify(ClassifyRequest {
            user_query: request.user_query.clone(),
            legacy_kind: Some(request.intent.kind.clone()),
            legacy_complexity: Some(request.intent.complexity),
            proposal,
        });
        if decision.status == IntentStatus::NeedsClarification {
            let message = decision
                .intent
                .ambiguity
                .clarification
                .unwrap_or_else(|| "Could you clarify what you want me to do?".into());
            if !decision.intent.ambiguity.candidates.is_empty() {
                emit(ReasoningEvent::Progress {
                    message: format!(
                        "{}{}",
                        crate::analyzer::CLARIFY_PROGRESS_PREFIX,
                        decision.intent.ambiguity.candidates.join("|")
                    ),
                })?;
            }
            emit(ReasoningEvent::Error { message })?;
            return Ok(());
        }
        if decision.status == IntentStatus::Rejected {
            emit(ReasoningEvent::Error {
                message: "This request cannot be routed.".into(),
            })?;
            return Err(ReasoningError::UnsupportedCapability);
        }
        let mut gated = request.clone();
        gated.intent = decision.intent;

        let policy_started = Instant::now();
        let level = self.policy.evaluate(&gated);
        let policy_ms = policy_started.elapsed().as_millis();
        emit(ReasoningEvent::Progress {
            message: format!("level={level:?}"),
        })?;

        if gated.context.total_chars() > self.limits.max_chars.saturating_mul(4) {
            return Err(ReasoningError::ContextLimitExceeded);
        }

        emit(ReasoningEvent::StageChanged {
            stage: ReasoningStage::RetrievingContext,
        })?;
        check(cancel)?;

        let mut working = gated;
        let mut executed = Vec::new();
        let mut generation_ms = 0_u128;
        let mut prompt_ms = 0_u128;

        loop {
            check(cancel)?;
            let prompt_started = Instant::now();
            let prompt = build_prompt(&working, level, self.limits);
            prompt_ms += prompt_started.elapsed().as_millis();

            emit(ReasoningEvent::StageChanged {
                stage: ReasoningStage::Analyzing,
            })?;

            let gen_started = Instant::now();
            let mut result = self.generate_envelope(
                generation,
                &prompt,
                level,
                cancel,
                emit,
                level != ReasoningLevel::Deep,
            )?;
            if level == ReasoningLevel::Deep && result.tool_calls.is_empty() {
                emit(ReasoningEvent::StageChanged {
                    stage: ReasoningStage::Validating,
                })?;
                emit(ReasoningEvent::Progress {
                    message: "checking draft".into(),
                })?;
                let validate_prompt = build_validate_prompt(&working, level, self.limits, &result);
                match self.generate_envelope(
                    generation,
                    &validate_prompt,
                    level,
                    cancel,
                    emit,
                    true,
                ) {
                    Ok(revised)
                        if revised.tool_calls.is_empty() && validate_result(&revised).is_ok() =>
                    {
                        result = revised;
                    }
                    Ok(_) | Err(ReasoningError::InvalidModelOutput) => {}
                    Err(err) => return Err(err),
                }
            }
            generation_ms += gen_started.elapsed().as_millis();

            emit(ReasoningEvent::StageChanged {
                stage: ReasoningStage::Validating,
            })?;
            validate_result(&result)?;

            if result.tool_calls.is_empty() {
                let mut finished = result;
                finished.tool_calls = executed;
                let _timings = ReasoningTimings {
                    policy_ms,
                    prompt_ms,
                    generation_ms,
                    total_ms: started.elapsed().as_millis(),
                };
                emit(ReasoningEvent::StageChanged {
                    stage: ReasoningStage::Complete,
                })?;
                emit(ReasoningEvent::Completed { result: finished })?;
                return Ok(());
            }

            let Some(executor) = tools else {
                let _timings = ReasoningTimings {
                    policy_ms,
                    prompt_ms,
                    generation_ms,
                    total_ms: started.elapsed().as_millis(),
                };
                emit(ReasoningEvent::StageChanged {
                    stage: ReasoningStage::Complete,
                })?;
                emit(ReasoningEvent::Completed { result })?;
                return Ok(());
            };

            if executed.len() as u32 >= MAX_TOOL_ITERATIONS {
                emit(ReasoningEvent::Error {
                    message: ReasoningError::ToolBudgetExceeded.user_message().into(),
                })?;
                return Err(ReasoningError::ToolBudgetExceeded);
            }

            let remaining = MAX_TOOL_ITERATIONS.saturating_sub(executed.len() as u32);
            let take = if level == ReasoningLevel::None {
                remaining.min(1)
            } else {
                remaining
            };
            let batch: Vec<_> = result.tool_calls.into_iter().take(take as usize).collect();
            if batch.is_empty() {
                emit(ReasoningEvent::Error {
                    message: ReasoningError::ToolBudgetExceeded.user_message().into(),
                })?;
                return Err(ReasoningError::ToolBudgetExceeded);
            }

            for call in batch {
                if executed.len() as u32 >= MAX_TOOL_ITERATIONS {
                    emit(ReasoningEvent::Error {
                        message: ReasoningError::ToolBudgetExceeded.user_message().into(),
                    })?;
                    return Err(ReasoningError::ToolBudgetExceeded);
                }
                emit(ReasoningEvent::StageChanged {
                    stage: ReasoningStage::UsingTool,
                })?;
                emit(ReasoningEvent::ToolStarted {
                    tool: call.name.clone(),
                })?;
                let output = if working
                    .available_tools
                    .iter()
                    .any(|tool| tool.name == call.name)
                {
                    executor.execute(&call)?
                } else {
                    "Tool is not available.".into()
                };
                emit(ReasoningEvent::ToolCompleted {
                    tool: call.name.clone(),
                })?;
                working.context.tool_results.push(ContextItem {
                    source: call.name.clone(),
                    text: output.clone(),
                });
                executed.push(call.clone());

                if level == ReasoningLevel::None {
                    let finished = ReasoningResult {
                        answer: output,
                        reasoning_summary: Some(format!("Used {}.", call.name)),
                        level,
                        confidence: result.confidence,
                        tool_calls: executed,
                    };
                    validate_result(&finished)?;
                    emit(ReasoningEvent::StageChanged {
                        stage: ReasoningStage::Complete,
                    })?;
                    emit(ReasoningEvent::Completed { result: finished })?;
                    return Ok(());
                }
            }
        }
    }

    fn generate_envelope(
        &self,
        generation: &dyn GenerationEngine,
        prompt: &str,
        level: ReasoningLevel,
        cancel: &CancelToken,
        emit: &mut dyn FnMut(ReasoningEvent) -> Result<(), ReasoningError>,
        stream_answer: bool,
    ) -> Result<ReasoningResult, ReasoningError> {
        let mut parser = ResultStreamParser::new();
        let mut stripper = ThinkingChannelStripper::new();
        let mut raw = String::new();
        const MAX_RAW: usize = 32_768;
        let request_gen = GenerationRequest {
            prompt: prompt.to_string(),
            max_output_tokens: tokens_for(level, self.max_output_tokens),
            grammar: Some(grammar_for(level).trim().to_string()),
        };

        emit(ReasoningEvent::StageChanged {
            stage: ReasoningStage::ComposingAnswer,
        })?;

        generation.generate(&request_gen, cancel, &mut |chunk: GenerationChunk| {
            if cancel.is_cancelled() {
                return Err(airo_mind_core::EngineError::Cancelled);
            }
            let visible = stripper.push(&chunk.text);
            if visible.is_empty() {
                return Ok(());
            }
            if raw.len() + visible.len() > MAX_RAW {
                return Err(airo_mind_core::EngineError::InvalidInput(
                    "reasoning envelope exceeded the parse window".into(),
                ));
            }
            raw.push_str(&visible);
            match parser.push(&visible) {
                Ok(delta) if stream_answer && !delta.is_empty() => {
                    emit(ReasoningEvent::AnswerDelta { text: delta })
                        .map_err(|_| airo_mind_core::EngineError::Cancelled)
                }
                Ok(_) => Ok(()),
                Err(_) => Err(airo_mind_core::EngineError::InvalidInput(
                    "malformed reasoning envelope".into(),
                )),
            }
        })?;

        let tail = stripper.finish();
        if !tail.is_empty() {
            if raw.len() + tail.len() > MAX_RAW {
                return Err(ReasoningError::InvalidModelOutput);
            }
            raw.push_str(&tail);
            let _ = parser.push(&tail)?;
        }

        reject_unknown_trace_keys(&raw)?;
        let mut result = parser.finish(level)?;
        result.tool_calls = extract_tool_calls(&raw);
        Ok(result)
    }
}

fn tokens_for(level: ReasoningLevel, cap: u32) -> u32 {
    let want = match level {
        ReasoningLevel::None => 128,
        ReasoningLevel::Light => 256,
        ReasoningLevel::Standard => 384,
        ReasoningLevel::Deep => cap,
    };
    want.min(cap)
}

fn check(cancel: &CancelToken) -> Result<(), ReasoningError> {
    if cancel.is_cancelled() {
        Err(ReasoningError::Cancelled)
    } else {
        Ok(())
    }
}

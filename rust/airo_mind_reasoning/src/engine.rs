//! Drive `GenerationEngine`. No llama.cpp types here.

use std::time::Instant;

use airo_mind_core::{CancelToken, GenerationChunk, GenerationEngine, GenerationRequest};

use crate::context::ContextLimits;
use crate::error::ReasoningError;
use crate::event::{ReasoningEvent, ReasoningStage};
use crate::grammar::RESULT_GRAMMAR;
use crate::level::ReasoningLevel;
use crate::parser::{reject_unknown_trace_keys, ResultStreamParser};
use crate::policy::{HeuristicReasoningPolicy, ReasoningPolicy};
use crate::prompt::build_prompt;
use crate::request::ReasoningRequest;
use crate::validator::validate_result;

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
        let started = Instant::now();
        emit(ReasoningEvent::Started)?;
        check(cancel)?;

        emit(ReasoningEvent::StageChanged {
            stage: ReasoningStage::Understanding,
        })?;
        let policy_started = Instant::now();
        let level = self.policy.evaluate(request);
        let policy_ms = policy_started.elapsed().as_millis();
        emit(ReasoningEvent::Progress {
            message: format!("level={level:?}"),
        })?;

        if request.context.total_chars() > self.limits.max_chars.saturating_mul(4) {
            return Err(ReasoningError::ContextLimitExceeded);
        }

        emit(ReasoningEvent::StageChanged {
            stage: ReasoningStage::RetrievingContext,
        })?;
        check(cancel)?;

        let prompt_started = Instant::now();
        let prompt = build_prompt(request, level, self.limits);
        let prompt_ms = prompt_started.elapsed().as_millis();

        emit(ReasoningEvent::StageChanged {
            stage: ReasoningStage::Analyzing,
        })?;

        let gen_started = Instant::now();
        let mut parser = ResultStreamParser::new();
        let mut raw = String::new();
        const MAX_RAW: usize = 32_768;
        let grammar = Some(RESULT_GRAMMAR.trim().to_string());
        let request_gen = GenerationRequest {
            prompt,
            max_output_tokens: tokens_for(level, self.max_output_tokens),
            grammar,
        };

        emit(ReasoningEvent::StageChanged {
            stage: ReasoningStage::ComposingAnswer,
        })?;

        generation.generate(&request_gen, cancel, &mut |chunk: GenerationChunk| {
            if cancel.is_cancelled() {
                return Err(airo_mind_core::EngineError::Cancelled);
            }
            if raw.len() + chunk.text.len() > MAX_RAW {
                return Err(airo_mind_core::EngineError::InvalidInput(
                    "reasoning envelope exceeded the parse window".into(),
                ));
            }
            raw.push_str(&chunk.text);
            match parser.push(&chunk.text) {
                Ok(delta) if !delta.is_empty() => emit(ReasoningEvent::AnswerDelta { text: delta })
                    .map_err(|_| airo_mind_core::EngineError::Cancelled),
                Ok(_) => Ok(()),
                Err(_) => Err(airo_mind_core::EngineError::InvalidInput(
                    "malformed reasoning envelope".into(),
                )),
            }
        })?;
        let generation_ms = gen_started.elapsed().as_millis();

        emit(ReasoningEvent::StageChanged {
            stage: ReasoningStage::Validating,
        })?;
        reject_unknown_trace_keys(&raw)?;
        let result = parser.finish(level)?;
        validate_result(&result)?;

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
        Ok(())
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

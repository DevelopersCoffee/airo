//! The LLM-judge axis. `#1636`.
//!
//! # This is explicitly a thin, unvalidated wrapper
//!
//! The issue names "a local LLM judge scoring 7 axes 0-5" and, in the same
//! breath, "judge never sole evaluator" -- it is deliberately not one of the
//! eight hardcoded gates in [`crate::gates::Gates`], and [`crate::report`]
//! never blocks a run on it. What this module builds is the call-site: a
//! prompt, a `&dyn GenerationEngine` the same way the rest of this crate
//! family takes one (`airo_mind_meeting::mom::generate_mom`'s own pattern),
//! and a strict parser for the 7-axis JSON response.
//!
//! **What it does not do**: validate that a real local model actually
//! produces useful judgments. No whisper or llama model is available in the
//! environment this crate was built in (`rust/airo_mind_whisper/models/` and
//! `rust/airo_mind_llama/models/` are both absent, and downloading one is out
//! of scope for a dev-tool crate) -- the unit tests below prove the parsing
//! and error-handling contract against a scripted engine, the same technique
//! `airo_mind_meeting`'s own tests use for the narrative sections, but they
//! cannot and do not prove a real model's judgment is any good. Treat
//! [`JudgeScores`] in a real report as informational until someone runs this
//! against an installed model and looks at the numbers.

use airo_mind_core::{CancelToken, EngineError, GenerationEngine, GenerationRequest};
use airo_mind_meeting::ir::MeetingIr;
use serde::Deserialize;

const JUDGE_MAX_OUTPUT_TOKENS: u32 = 256;

/// The seven axes the issue names, each scored 0-5 by the model. Field names
/// match the JSON keys the prompt asks for.
#[derive(Clone, Copy, Debug, Default, PartialEq, Deserialize)]
pub struct JudgeScores {
    pub coherence: f32,
    pub completeness: f32,
    pub accuracy: f32,
    pub conciseness: f32,
    pub actionability: f32,
    pub tone: f32,
    pub structure: f32,
}

impl JudgeScores {
    /// Mean of the seven axes, `0.0`-`5.0`.
    pub fn mean(&self) -> f32 {
        (self.coherence
            + self.completeness
            + self.accuracy
            + self.conciseness
            + self.actionability
            + self.tone
            + self.structure)
            / 7.0
    }
}

#[derive(Debug, PartialEq)]
pub enum JudgeError {
    Cancelled,
    Engine(String),
    /// The model's response was not the 7-axis JSON object the prompt asked
    /// for. Reported, not repaired or defaulted to zero -- a judge score this
    /// harness invented on the model's behalf would be worse than admitting
    /// the axis was not evaluated on this run.
    UnparseableResponse(String),
}

impl std::fmt::Display for JudgeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Cancelled => write!(f, "cancelled"),
            Self::Engine(m) => write!(f, "generation engine failed: {m}"),
            Self::UnparseableResponse(raw) => {
                write!(f, "judge response was not valid 7-axis JSON: {raw}")
            }
        }
    }
}

impl std::error::Error for JudgeError {}

fn judge_prompt(ir: &MeetingIr, mom: &str) -> String {
    format!(
        "You are scoring Minutes of Meeting against the facts it was generated \
         from. Score each axis 0-5 (integers or one decimal place). Respond with \
         ONLY a JSON object with exactly these keys: coherence, completeness, \
         accuracy, conciseness, actionability, tone, structure.\n\n\
         Meeting: {}\n\n\
         Minutes of Meeting:\n{}\n\n\
         JSON:",
        ir.meeting.title.as_deref().unwrap_or("(untitled)"),
        mom
    )
}

/// Scores `mom` on the issue's 7 axes by asking `engine`. See the module doc
/// comment for what this is and is not validated against.
pub fn judge_mom(
    engine: &dyn GenerationEngine,
    ir: &MeetingIr,
    mom: &str,
    cancel: &CancelToken,
) -> Result<JudgeScores, JudgeError> {
    if cancel.is_cancelled() {
        return Err(JudgeError::Cancelled);
    }
    let request = GenerationRequest {
        prompt: judge_prompt(ir, mom),
        max_output_tokens: JUDGE_MAX_OUTPUT_TOKENS,
        grammar: None,
    };
    let mut raw = String::new();
    engine
        .generate(&request, cancel, &mut |chunk| {
            raw.push_str(&chunk.text);
            Ok(())
        })
        .map_err(|e| match e {
            EngineError::Cancelled => JudgeError::Cancelled,
            other => JudgeError::Engine(other.to_string()),
        })?;

    parse_judge_response(&raw)
}

/// Extracts and parses the JSON object from `raw`. Tolerant of leading/
/// trailing prose around the object (a model that ignores "respond with
/// ONLY..." is the realistic case, not the exception), but not tolerant of a
/// missing or malformed object -- that is [`JudgeError::UnparseableResponse`],
/// never a guessed score.
fn parse_judge_response(raw: &str) -> Result<JudgeScores, JudgeError> {
    let start = raw
        .find('{')
        .ok_or_else(|| JudgeError::UnparseableResponse(raw.to_string()))?;
    let end = raw
        .rfind('}')
        .ok_or_else(|| JudgeError::UnparseableResponse(raw.to_string()))?;
    if end < start {
        return Err(JudgeError::UnparseableResponse(raw.to_string()));
    }
    serde_json::from_str(&raw[start..=end])
        .map_err(|_| JudgeError::UnparseableResponse(raw.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use airo_mind_core::{GenerationChunk, ResourceRequest, RuntimeStats};
    use airo_mind_meeting::ir::{Facts, Meeting, IR_SCHEMA_VERSION};
    use std::sync::Mutex;

    fn ir() -> MeetingIr {
        MeetingIr {
            schema_version: IR_SCHEMA_VERSION.into(),
            meeting: Meeting {
                id: "meeting-0".into(),
                title: Some("Signaling capacity review".into()),
                prompt_version: "chunk_facts.v1".into(),
                ..Meeting::default()
            },
            facts: Facts::default(),
        }
    }

    struct ScriptedEngine {
        answer: &'static str,
        prompts: Mutex<Vec<String>>,
    }

    impl GenerationEngine for ScriptedEngine {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(0)
        }
        fn generate(
            &self,
            request: &GenerationRequest,
            _cancel: &CancelToken,
            sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            self.prompts.lock().unwrap().push(request.prompt.clone());
            sink(GenerationChunk {
                text: self.answer.to_string(),
            })
        }
        fn stats(&self) -> RuntimeStats {
            RuntimeStats::default()
        }
    }

    struct BrokenEngine;
    impl GenerationEngine for BrokenEngine {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(0)
        }
        fn generate(
            &self,
            _request: &GenerationRequest,
            _cancel: &CancelToken,
            _sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            Err(EngineError::ModelUnavailable)
        }
        fn stats(&self) -> RuntimeStats {
            RuntimeStats::default()
        }
    }

    #[test]
    fn a_clean_json_response_parses_into_all_seven_axes() {
        let engine = ScriptedEngine {
            answer: r#"{"coherence":5,"completeness":4,"accuracy":5,"conciseness":3,"actionability":4,"tone":5,"structure":4}"#,
            prompts: Mutex::new(Vec::new()),
        };
        let scores = judge_mom(
            &engine,
            &ir(),
            "## Meeting Objective\n\ntext\n",
            &CancelToken::new(),
        )
        .expect("valid JSON parses");
        assert_eq!(scores.coherence, 5.0);
        assert_eq!(scores.conciseness, 3.0);
        assert!((scores.mean() - 30.0 / 7.0).abs() < 1e-6);
    }

    #[test]
    fn json_wrapped_in_prose_still_parses() {
        let engine = ScriptedEngine {
            answer: "Here is my assessment:\n{\"coherence\":4,\"completeness\":4,\"accuracy\":4,\"conciseness\":4,\"actionability\":4,\"tone\":4,\"structure\":4}\nHope that helps!",
            prompts: Mutex::new(Vec::new()),
        };
        let scores = judge_mom(&engine, &ir(), "mom text", &CancelToken::new()).expect("parses");
        assert_eq!(scores.coherence, 4.0);
    }

    #[test]
    fn a_response_with_no_json_object_is_an_error_not_a_guessed_score() {
        let engine = ScriptedEngine {
            answer: "I think the minutes look pretty good overall.",
            prompts: Mutex::new(Vec::new()),
        };
        let result = judge_mom(&engine, &ir(), "mom text", &CancelToken::new());
        assert!(matches!(result, Err(JudgeError::UnparseableResponse(_))));
    }

    #[test]
    fn a_json_object_missing_an_axis_is_an_error() {
        let engine = ScriptedEngine {
            answer: r#"{"coherence":5,"completeness":4}"#,
            prompts: Mutex::new(Vec::new()),
        };
        let result = judge_mom(&engine, &ir(), "mom text", &CancelToken::new());
        assert!(matches!(result, Err(JudgeError::UnparseableResponse(_))));
    }

    #[test]
    fn a_broken_backend_is_an_engine_error() {
        let result = judge_mom(&BrokenEngine, &ir(), "mom text", &CancelToken::new());
        assert!(matches!(result, Err(JudgeError::Engine(_))));
    }

    #[test]
    fn a_cancelled_run_never_reaches_the_engine() {
        let cancel = CancelToken::new();
        cancel.cancel();
        let result = judge_mom(&BrokenEngine, &ir(), "mom text", &cancel);
        assert_eq!(result, Err(JudgeError::Cancelled));
    }

    #[test]
    fn the_prompt_asks_for_all_seven_axis_names() {
        let engine = ScriptedEngine {
            answer: r#"{"coherence":5,"completeness":4,"accuracy":5,"conciseness":3,"actionability":4,"tone":5,"structure":4}"#,
            prompts: Mutex::new(Vec::new()),
        };
        judge_mom(&engine, &ir(), "mom text", &CancelToken::new()).unwrap();
        let prompts = engine.prompts.lock().unwrap();
        for axis in [
            "coherence",
            "completeness",
            "accuracy",
            "conciseness",
            "actionability",
            "tone",
            "structure",
        ] {
            assert!(prompts[0].contains(axis), "prompt missing `{axis}`");
        }
    }
}

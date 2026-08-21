//! Incremental parser for the result envelope.
//!
//! GBNF key order is `answer`, `reasoning_summary`, `confidence`. Keys are
//! skipped; only values are kept. The live buffer is the current string.

use crate::error::ReasoningError;
use crate::level::ReasoningLevel;
use crate::result::ReasoningResult;

#[derive(Debug)]
enum Phase {
    /// Next `"` starts a key name.
    Key,
    /// Collecting a key name (inside quotes).
    KeyBody,
    /// Saw a key; waiting for `:`.
    Colon {
        key: String,
    },
    /// Waiting for the value's opening `"`.
    ValueQuote {
        key: String,
    },
    /// Collecting a string value.
    ValueBody {
        key: String,
    },
    /// Collecting the confidence number.
    Confidence,
    Done,
}

#[derive(Debug)]
pub struct ResultStreamParser {
    phase: Phase,
    escape: bool,
    current: String,
    answer: String,
    summary: String,
    confidence: Option<f32>,
}

impl Default for ResultStreamParser {
    fn default() -> Self {
        Self::new()
    }
}

impl ResultStreamParser {
    pub fn new() -> Self {
        Self {
            phase: Phase::Key,
            escape: false,
            current: String::new(),
            answer: String::new(),
            summary: String::new(),
            confidence: None,
        }
    }

    /// Push a token fragment. Returns newly available answer-value text.
    pub fn push(&mut self, chunk: &str) -> Result<String, ReasoningError> {
        let mut answer_delta = String::new();
        for ch in chunk.chars() {
            self.push_char(ch, &mut answer_delta)?;
        }
        Ok(answer_delta)
    }

    pub fn finish(mut self, level: ReasoningLevel) -> Result<ReasoningResult, ReasoningError> {
        if matches!(self.phase, Phase::Confidence) && !self.current.is_empty() {
            self.flush_confidence()?;
        }
        if self.answer.is_empty() {
            return Err(ReasoningError::InvalidModelOutput);
        }
        let summary = if self.summary.trim().is_empty() {
            None
        } else {
            Some(self.summary)
        };
        Ok(ReasoningResult {
            answer: self.answer,
            reasoning_summary: summary,
            level,
            confidence: self.confidence,
            tool_calls: Vec::new(),
        })
    }

    fn push_char(&mut self, ch: char, answer_delta: &mut String) -> Result<(), ReasoningError> {
        match &self.phase {
            Phase::Done => Ok(()),
            Phase::Key => {
                if ch == '"' {
                    self.current.clear();
                    self.escape = false;
                    self.phase = Phase::KeyBody;
                }
                Ok(())
            }
            Phase::KeyBody => self.push_quoted(ch, false, answer_delta),
            Phase::Colon { .. } => {
                if ch == ':' {
                    let key = match std::mem::replace(&mut self.phase, Phase::Done) {
                        Phase::Colon { key } => key,
                        _ => unreachable!(),
                    };
                    if key == "confidence" {
                        self.current.clear();
                        self.phase = Phase::Confidence;
                    } else {
                        self.phase = Phase::ValueQuote { key };
                    }
                }
                Ok(())
            }
            Phase::ValueQuote { .. } => {
                if ch == '"' {
                    let key = match std::mem::replace(&mut self.phase, Phase::Done) {
                        Phase::ValueQuote { key } => key,
                        _ => unreachable!(),
                    };
                    self.current.clear();
                    self.escape = false;
                    self.phase = Phase::ValueBody { key };
                }
                Ok(())
            }
            Phase::ValueBody { .. } => self.push_quoted(ch, true, answer_delta),
            Phase::Confidence => self.push_confidence(ch),
        }
    }

    fn push_quoted(
        &mut self,
        ch: char,
        is_value: bool,
        answer_delta: &mut String,
    ) -> Result<(), ReasoningError> {
        if self.escape {
            let decoded = unescape(ch);
            self.current.push(decoded);
            if is_value {
                if let Phase::ValueBody { key } = &self.phase {
                    if key == "answer" {
                        answer_delta.push(decoded);
                    }
                }
            }
            self.escape = false;
            return Ok(());
        }
        if ch == '\\' {
            self.escape = true;
            return Ok(());
        }
        if ch == '"' {
            let value = std::mem::take(&mut self.current);
            if !is_value {
                if is_banned_key(&value) {
                    return Err(ReasoningError::InvalidModelOutput);
                }
                self.phase = Phase::Colon { key: value };
                return Ok(());
            }
            if let Phase::ValueBody { key } = std::mem::replace(&mut self.phase, Phase::Key) {
                match key.as_str() {
                    "answer" => self.answer = value,
                    "reasoning_summary" => self.summary = value,
                    _ => {}
                }
            }
            return Ok(());
        }
        self.current.push(ch);
        if is_value {
            if let Phase::ValueBody { key } = &self.phase {
                if key == "answer" {
                    answer_delta.push(ch);
                }
            }
        }
        Ok(())
    }

    fn push_confidence(&mut self, ch: char) -> Result<(), ReasoningError> {
        if ch.is_ascii_digit() || ch == '.' {
            self.current.push(ch);
            return Ok(());
        }
        if self.current.is_empty() {
            return Ok(());
        }
        self.flush_confidence()
    }

    fn flush_confidence(&mut self) -> Result<(), ReasoningError> {
        let value: f32 = self
            .current
            .parse()
            .map_err(|_| ReasoningError::InvalidModelOutput)?;
        if !(0.0..=1.0).contains(&value) {
            return Err(ReasoningError::InvalidModelOutput);
        }
        self.confidence = Some(value);
        self.current.clear();
        self.phase = Phase::Done;
        Ok(())
    }
}

fn is_banned_key(key: &str) -> bool {
    matches!(
        key,
        "thoughts" | "scratchpad" | "thinking_trace" | "chain_of_thought"
    )
}

fn unescape(ch: char) -> char {
    match ch {
        'n' => '\n',
        't' => '\t',
        'r' => '\r',
        other => other,
    }
}

pub fn reject_unknown_trace_keys(raw: &str) -> Result<(), ReasoningError> {
    let lowered = raw.to_ascii_lowercase();
    for banned in [
        "thoughts",
        "scratchpad",
        "thinking_trace",
        "chain_of_thought",
    ] {
        if lowered.contains(&format!("\"{banned}\"")) {
            return Err(ReasoningError::InvalidModelOutput);
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fragmented_tokens_rebuild_the_answer() {
        let mut p = ResultStreamParser::new();
        let mut answer = String::new();
        for piece in [
            r#"{"ans"#,
            r#"wer":"You have "#,
            r#"three meetings","reasoning_summary":"Checked calendar.","confidence":0.96}"#,
        ] {
            answer.push_str(&p.push(piece).unwrap());
        }
        let result = p.finish(ReasoningLevel::Light).unwrap();
        assert_eq!(result.answer, "You have three meetings");
        assert_eq!(answer, "You have three meetings");
        assert_eq!(
            result.reasoning_summary.as_deref(),
            Some("Checked calendar.")
        );
        assert_eq!(result.confidence, Some(0.96));
    }

    #[test]
    fn missing_answer_is_invalid() {
        let p = ResultStreamParser::new();
        assert_eq!(
            p.finish(ReasoningLevel::None),
            Err(ReasoningError::InvalidModelOutput)
        );
    }

    #[test]
    fn thoughts_key_is_rejected() {
        assert!(reject_unknown_trace_keys(r#"{"thoughts":"secret"}"#).is_err());
        assert!(reject_unknown_trace_keys(r#"{"answer":"ok"}"#).is_ok());
        let mut p = ResultStreamParser::new();
        let err = p.push(r#"{"thoughts":"nope"}"#).err();
        assert_eq!(err, Some(ReasoningError::InvalidModelOutput));
    }

    #[test]
    fn escaped_quote_stays_inside_answer() {
        let mut p = ResultStreamParser::new();
        p.push(r#"{"answer":"He said \"hi\"","reasoning_summary":"s","confidence":1.0}"#)
            .unwrap();
        let result = p.finish(ReasoningLevel::None).unwrap();
        assert_eq!(result.answer, r#"He said "hi""#);
    }
}

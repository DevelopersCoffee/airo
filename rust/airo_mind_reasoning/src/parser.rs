//! Incremental parser for the result envelope.
//!
//! GBNF key order is `answer`, `reasoning_summary`, `confidence`. Keys are
//! skipped; only values are kept. The live buffer is the current string.

use crate::error::ReasoningError;
use crate::level::ReasoningLevel;
use crate::result::{ReasoningResult, ToolCall};

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

/// Drops a model thinking channel (`<think>`, `<thought>`, `<thinking>`)
/// so only the JSON envelope reaches the parser. Partial tags that straddle
/// tokens are held until they resolve.
pub struct ThinkingChannelStripper {
    skipping: bool,
    pending: String,
}

impl Default for ThinkingChannelStripper {
    fn default() -> Self {
        Self::new()
    }
}

impl ThinkingChannelStripper {
    pub fn new() -> Self {
        Self {
            skipping: false,
            pending: String::new(),
        }
    }

    pub fn push(&mut self, chunk: &str) -> String {
        let mut out = String::new();
        for ch in chunk.chars() {
            self.push_char(ch, &mut out);
        }
        out
    }

    pub fn finish(mut self) -> String {
        let mut out = String::new();
        if !self.skipping {
            out.push_str(&self.pending);
        }
        self.pending.clear();
        out
    }

    fn push_char(&mut self, ch: char, out: &mut String) {
        self.pending.push(ch);
        let lower = self.pending.to_ascii_lowercase();
        if self.skipping {
            if close_tag(&lower).is_some() {
                self.pending.clear();
                self.skipping = false;
            } else if !could_be_close(&lower) {
                self.pending.clear();
            }
            return;
        }
        if let Some(len) = open_tag(&lower) {
            let _ = self.pending.drain(..len);
            self.skipping = true;
            if !self.pending.is_empty() {
                let rest = std::mem::take(&mut self.pending);
                for next in rest.chars() {
                    self.push_char(next, out);
                }
            }
            return;
        }
        if could_be_open(&lower) {
            return;
        }
        let emit = std::mem::take(&mut self.pending);
        out.push_str(&emit);
    }
}

fn open_tag(lower: &str) -> Option<usize> {
    for tag in ["<thinking>", "<thought>", "<think>"] {
        if lower == tag {
            return Some(tag.len());
        }
    }
    None
}

fn close_tag(lower: &str) -> Option<usize> {
    for tag in ["</thinking>", "</thought>", "</think>"] {
        if lower == tag {
            return Some(tag.len());
        }
    }
    None
}

fn could_be_open(lower: &str) -> bool {
    ["<think>", "<thought>", "<thinking>"]
        .iter()
        .any(|tag| tag.starts_with(lower))
}

fn could_be_close(lower: &str) -> bool {
    ["</think>", "</thought>", "</thinking>"]
        .iter()
        .any(|tag| tag.starts_with(lower))
}

/// Pull `tool_calls` from the finished envelope. The streaming FSM only
/// tracks `answer` / `reasoning_summary` / `confidence`; the array is not
/// streamed to the UI.
pub fn extract_tool_calls(raw: &str) -> Vec<ToolCall> {
    let Some(value) = parse_envelope_json(raw) else {
        return Vec::new();
    };
    let Some(items) = value.get("tool_calls").and_then(|v| v.as_array()) else {
        return Vec::new();
    };
    items
        .iter()
        .filter_map(|item| {
            let name = item.get("name")?.as_str()?.trim();
            if name.is_empty() {
                return None;
            }
            let arguments_json = item
                .get("arguments_json")
                .and_then(|v| v.as_str())
                .unwrap_or("{}")
                .to_string();
            Some(ToolCall {
                name: name.to_string(),
                arguments_json,
            })
        })
        .collect()
}

/// Accept a full object or the body after a teacher-forced `{`.
fn parse_envelope_json(raw: &str) -> Option<serde_json::Value> {
    if let Ok(value) = serde_json::from_str(raw) {
        return Some(value);
    }
    let trimmed = raw.trim_start();
    if trimmed.starts_with('{') {
        return None;
    }
    serde_json::from_str(&format!("{{{trimmed}")).ok()
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
    fn missing_answer_is_empty_until_validated() {
        let p = ResultStreamParser::new();
        let result = p.finish(ReasoningLevel::None).unwrap();
        assert!(result.answer.is_empty());
        assert!(crate::validator::validate_result(&result).is_err());
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

    #[test]
    fn tool_calls_are_extracted_from_the_envelope() {
        let raw = r#"{"answer":"","reasoning_summary":"Need calendar.","confidence":0.80,"tool_calls":[{"name":"read_calendar_events","arguments_json":"{\"day\":\"tomorrow\"}"}]}"#;
        let calls = extract_tool_calls(raw);
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].name, "read_calendar_events");
        assert!(calls[0].arguments_json.contains("tomorrow"));
    }

    #[test]
    fn tool_calls_are_extracted_when_the_open_brace_was_teacher_forced() {
        let raw = r#""answer":"","reasoning_summary":"Need calendar.","confidence":0.80,"tool_calls":[{"name":"read_calendar_events","arguments_json":"{}"}]}"#;
        let calls = extract_tool_calls(raw);
        assert_eq!(calls.len(), 1);
        assert_eq!(calls[0].name, "read_calendar_events");
    }

    #[test]
    fn fragmented_tokens_rebuild_an_answer_without_the_open_brace() {
        let mut p = ResultStreamParser::new();
        let mut answer = String::new();
        for piece in [
            r#""answer":"You have "#,
            r#"three meetings","reasoning_summary":"Checked calendar.","confidence":0.96}"#,
        ] {
            answer.push_str(&p.push(piece).unwrap());
        }
        let result = p.finish(ReasoningLevel::Light).unwrap();
        assert_eq!(result.answer, "You have three meetings");
        assert_eq!(answer, "You have three meetings");
    }

    #[test]
    fn answer_only_envelope_is_enough_for_none() {
        let mut p = ResultStreamParser::new();
        p.push(r#""answer":"It is Tuesday."}"#).unwrap();
        let result = p.finish(ReasoningLevel::None).unwrap();
        assert_eq!(result.answer, "It is Tuesday.");
        assert!(result.reasoning_summary.is_none());
        assert!(crate::validator::validate_result(&result).is_ok());
    }

    #[test]
    fn missing_tool_calls_is_empty() {
        assert!(
            extract_tool_calls(r#"{"answer":"ok","reasoning_summary":"s","confidence":1}"#)
                .is_empty()
        );
    }

    #[test]
    fn thinking_channel_is_stripped_before_the_envelope() {
        let mut s = ThinkingChannelStripper::new();
        let visible = s.push("<think>private chain</think>");
        let visible = format!(
            "{visible}{}",
            s.push(
                r#"{"answer":"Tuesday","reasoning_summary":"Named the day.","confidence":0.90}"#
            )
        );
        let visible = format!("{visible}{}", s.finish());
        assert!(!visible.to_ascii_lowercase().contains("private"));
        assert!(visible.contains("\"answer\":\"Tuesday\""));

        let mut p = ResultStreamParser::new();
        p.push(&visible).unwrap();
        let result = p.finish(ReasoningLevel::Standard).unwrap();
        assert_eq!(result.answer, "Tuesday");
        assert!(!result.answer.contains("private"));
    }

    #[test]
    fn thinking_channel_strips_across_token_fragments() {
        let mut s = ThinkingChannelStripper::new();
        let mut visible = String::new();
        for piece in ["<th", "ink>hide", " me</th", "ink>{\"answer\":\"ok\""] {
            visible.push_str(&s.push(piece));
        }
        visible.push_str(&s.finish());
        assert_eq!(visible, r#"{"answer":"ok""#);
    }
}

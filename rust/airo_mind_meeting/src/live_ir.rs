//! Incremental Conversation IR — event-driven, no live LLM.
//!
//! Stable sentences are the boundary. Deep summary stays post-recording
//! (`pass1` / `pass2`). This module extracts high-confidence surface facts
//! that the live UI may show; speculative claims are not emitted.

use serde::{Deserialize, Serialize};

/// Kind of a named entity spotted on a stable sentence.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LiveEntityKind {
    Person,
    Date,
    Project,
}

/// One incremental IR event. Evidence is a segment id, never a raw snippet
/// copy of `secret`-class audio (ADR-0022).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ConversationIrEvent {
    Segment {
        segment_id: String,
        speaker_id: Option<String>,
        text: String,
        start_ms: u64,
        end_ms: u64,
    },
    Entity {
        kind: LiveEntityKind,
        text: String,
        evidence: String,
        confidence: f32,
    },
    Action {
        text: String,
        evidence: String,
        confidence: f32,
    },
    Decision {
        text: String,
        evidence: String,
        confidence: f32,
    },
    Question {
        text: String,
        evidence: String,
    },
    Topic {
        title: String,
        evidence: String,
    },
}

/// Rolling Conversation IR built from stable sentences only.
#[derive(Clone, Debug, Default)]
pub struct IncrementalConversationIr {
    events: Vec<ConversationIrEvent>,
}

impl IncrementalConversationIr {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn events(&self) -> &[ConversationIrEvent] {
        &self.events
    }

    /// Process one stabilizer-committed sentence. Never runs an LLM.
    pub fn on_stable_sentence(
        &mut self,
        segment_id: impl Into<String>,
        speaker_id: Option<String>,
        text: &str,
        start_ms: u64,
        end_ms: u64,
    ) -> Vec<ConversationIrEvent> {
        let segment_id = segment_id.into();
        let trimmed = text.trim();
        if trimmed.is_empty() {
            return Vec::new();
        }

        let mut produced = Vec::new();
        produced.push(ConversationIrEvent::Segment {
            segment_id: segment_id.clone(),
            speaker_id,
            text: trimmed.to_string(),
            start_ms,
            end_ms,
        });

        if trimmed.ends_with('?') {
            produced.push(ConversationIrEvent::Question {
                text: trimmed.to_string(),
                evidence: segment_id.clone(),
            });
        }

        if looks_like_decision(trimmed) {
            produced.push(ConversationIrEvent::Decision {
                text: trimmed.to_string(),
                evidence: segment_id.clone(),
                confidence: 0.86,
            });
        }

        if looks_like_action(trimmed) {
            produced.push(ConversationIrEvent::Action {
                text: trimmed.to_string(),
                evidence: segment_id.clone(),
                confidence: 0.84,
            });
        }

        if let Some(date) = extract_date(trimmed) {
            produced.push(ConversationIrEvent::Entity {
                kind: LiveEntityKind::Date,
                text: date,
                evidence: segment_id.clone(),
                confidence: 0.9,
            });
        }

        if let Some(person) = extract_person(trimmed) {
            produced.push(ConversationIrEvent::Entity {
                kind: LiveEntityKind::Person,
                text: person,
                evidence: segment_id.clone(),
                confidence: 0.8,
            });
        }

        if let Some(topic) = extract_topic(trimmed) {
            produced.push(ConversationIrEvent::Topic {
                title: topic,
                evidence: segment_id,
            });
        }

        self.events.extend(produced.iter().cloned());
        produced
    }
}

fn looks_like_decision(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    lower.contains("we decided")
        || lower.contains("we agreed")
        || lower.contains("decision is")
        || lower.contains("let's go with")
        || lower.contains("lets go with")
}

fn looks_like_action(text: &str) -> bool {
    let lower = text.to_ascii_lowercase();
    lower.contains("will ")
        || lower.contains("please ")
        || lower.contains("need to ")
        || lower.contains("i'll ")
        || lower.contains("i will ")
        || lower.starts_with("action:")
}

fn extract_date(text: &str) -> Option<String> {
    const DAYS: [&str; 7] = [
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
    ];
    let lower = text.to_ascii_lowercase();
    for day in DAYS {
        if lower.contains(day) {
            return Some(day[..1].to_uppercase() + &day[1..]);
        }
    }
    None
}

fn extract_person(text: &str) -> Option<String> {
    // High-confidence only: "X will" / "X, please" with a capitalized token.
    let words: Vec<&str> = text.split_whitespace().collect();
    for window in words.windows(2) {
        let name = window[0].trim_matches(|c: char| !c.is_ascii_alphabetic());
        let next = window[1].to_ascii_lowercase();
        if name.len() > 1
            && name.chars().next().is_some_and(|c| c.is_uppercase())
            && (next.starts_with("will") || next.starts_with("please"))
        {
            return Some(name.to_string());
        }
    }
    None
}

fn extract_topic(text: &str) -> Option<String> {
    let lower = text.to_ascii_lowercase();
    if lower.contains("migrat") {
        return Some("Migration".into());
    }
    if lower.contains("database") {
        return Some("Database".into());
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stable_sentence_emits_segment_and_high_confidence_facts() {
        let mut ir = IncrementalConversationIr::new();
        let events = ir.on_stable_sentence(
            "s0",
            Some("sp0".into()),
            "Uday will own database changes by Friday. We decided the migration deadline is Friday.",
            0,
            4_000,
        );
        assert!(events.iter().any(
            |e| matches!(e, ConversationIrEvent::Segment { segment_id, .. } if segment_id == "s0")
        ));
        assert!(events
            .iter()
            .any(|e| matches!(e, ConversationIrEvent::Action { .. })));
        assert!(events
            .iter()
            .any(|e| matches!(e, ConversationIrEvent::Decision { .. })));
        assert!(events.iter().any(|e| matches!(
            e,
            ConversationIrEvent::Entity {
                kind: LiveEntityKind::Date,
                ..
            }
        )));
        assert!(events.iter().any(|e| matches!(
            e,
            ConversationIrEvent::Entity {
                kind: LiveEntityKind::Person,
                text,
                ..
            } if text == "Uday"
        )));
        assert!(events.iter().any(|e| matches!(e, ConversationIrEvent::Topic { title, .. } if title == "Migration" || title == "Database")));
    }

    #[test]
    fn questions_are_detected_without_an_llm() {
        let mut ir = IncrementalConversationIr::new();
        let events = ir.on_stable_sentence("s1", None, "Can we ship on Thursday?", 10, 20);
        assert!(events
            .iter()
            .any(|e| matches!(e, ConversationIrEvent::Question { .. })));
        assert!(events.iter().any(|e| matches!(
            e,
            ConversationIrEvent::Entity {
                kind: LiveEntityKind::Date,
                ..
            }
        )));
    }

    #[test]
    fn empty_text_emits_nothing() {
        let mut ir = IncrementalConversationIr::new();
        assert!(ir.on_stable_sentence("s2", None, "   ", 0, 1).is_empty());
    }

    #[test]
    fn events_serialize_with_type_tag_for_the_dart_rail() {
        let event = ConversationIrEvent::Decision {
            text: "We decided Friday".into(),
            evidence: "s0".into(),
            confidence: 0.86,
        };
        let json = serde_json::to_string(&event).expect("serialize");
        assert!(json.contains("\"type\":\"decision\""));
        assert!(json.contains("\"evidence\":\"s0\""));
    }
}

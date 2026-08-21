//! Prompt strategy by reasoning level. No public THINKING_TRACE protocol.

use crate::context::{ContextLimits, ReasoningContext};
use crate::grammar::ENVELOPE_OPEN;
use crate::level::ReasoningLevel;
use crate::request::ReasoningRequest;

pub fn build_prompt(
    request: &ReasoningRequest,
    level: ReasoningLevel,
    limits: ContextLimits,
) -> String {
    let packed = request.context.bounded(limits);
    let mut out = String::new();
    out.push_str(system_for(level));
    out.push_str("\n\n");
    append_section(&mut out, "Context", &packed);
    out.push_str("User request:\n");
    out.push_str(&request.user_query);
    out.push('\n');
    if !request.available_tools.is_empty() {
        out.push_str("\nAvailable tools:\n");
        for tool in &request.available_tools {
            out.push_str("- ");
            out.push_str(&tool.name);
            if !tool.description.is_empty() {
                out.push_str(": ");
                out.push_str(&tool.description);
            }
            out.push('\n');
        }
    }
    if request.available_tools.is_empty() {
        out.push_str(
            "\nRespond as JSON with keys answer, reasoning_summary, confidence only.\nJSON:\n",
        );
    } else {
        out.push_str(
            "\nRespond as JSON with keys answer, reasoning_summary, confidence. \
If you must call a listed tool, add tool_calls as an array of objects with \
name and arguments_json, and set answer to an empty string. \
Do not invent tools. Do not include a thoughts field.\nJSON:\n",
        );
    }
    out.push_str(ENVELOPE_OPEN);
    out
}

fn system_for(level: ReasoningLevel) -> &'static str {
    match level {
        ReasoningLevel::None => {
            "Answer the user's request directly. Do not perform unnecessary analysis."
        }
        ReasoningLevel::Light => {
            "Solve the task with the supplied context. Return a concise answer and a one-sentence basis."
        }
        ReasoningLevel::Standard => {
            "You may reason privately. Do not write thoughts, a scratchpad, or chain-of-thought \
into the output. Check the conclusion, then return only the JSON envelope with the answer \
and a concise user-facing explanation."
        }
        ReasoningLevel::Deep => {
            "You may reason privately and systematically. Consider constraints, relevant context, \
available tools, alternatives, contradictions, and edge cases. Never write thoughts, a \
scratchpad, or chain-of-thought into the output. Validate, then return only the JSON envelope \
with a concise answer and a short user-facing basis."
        }
    }
}

fn append_section(out: &mut String, title: &str, ctx: &ReasoningContext) {
    if ctx.total_chars() == 0 {
        return;
    }
    out.push_str(title);
    out.push_str(":\n");
    for (label, items) in [
        ("memories", &ctx.memories),
        ("documents", &ctx.documents),
        ("tool_results", &ctx.tool_results),
        ("history", &ctx.history),
    ] {
        for item in items {
            out.push_str("- [");
            out.push_str(label);
            out.push('/');
            out.push_str(&item.source);
            out.push_str("] ");
            out.push_str(&item.text);
            out.push('\n');
        }
    }
    out.push('\n');
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::request::ReasoningRequest;

    #[test]
    fn none_prompt_forbids_analysis() {
        let req = ReasoningRequest::fixture("time_query", 0.0);
        let prompt = build_prompt(&req, ReasoningLevel::None, ContextLimits::default());
        assert!(prompt.contains("Do not perform unnecessary analysis"));
        assert!(!prompt.contains("THINKING_TRACE"));
        assert!(!prompt.contains("scratchpad"));
        assert!(
            prompt.ends_with("JSON:\n{"),
            "teacher-force the envelope open so generation starts at \"answer\", not EOG: {prompt}"
        );
    }

    #[test]
    fn tools_prompt_mentions_tool_calls_not_thoughts() {
        let mut req = ReasoningRequest::fixture("calendar_retrieval", 0.1);
        req.available_tools = vec![crate::request::ToolDefinition {
            name: "read_calendar_events".into(),
            description: "List events for a day.".into(),
        }];
        let prompt = build_prompt(&req, ReasoningLevel::None, ContextLimits::default());
        assert!(prompt.contains("tool_calls"));
        assert!(prompt.contains("read_calendar_events"));
        assert!(!prompt.contains("THINKING_TRACE"));
        assert!(!prompt.contains("scratchpad"));
    }

    #[test]
    fn packed_context_respects_char_budget() {
        let mut req = ReasoningRequest::fixture("summarization", 0.4);
        req.context.history = (0..50)
            .map(|n| crate::context::ContextItem {
                source: format!("{n}"),
                text: "word ".repeat(200),
            })
            .collect();
        let prompt = build_prompt(
            &req,
            ReasoningLevel::Light,
            ContextLimits {
                max_chars: 2_000,
                ..ContextLimits::default()
            },
        );
        assert!(prompt.len() < 4_000);
    }

    #[test]
    fn standard_and_deep_reason_privately_without_a_thoughts_field() {
        let req = ReasoningRequest::fixture("planning", 0.8);
        let standard = build_prompt(&req, ReasoningLevel::Standard, ContextLimits::default());
        let deep = build_prompt(&req, ReasoningLevel::Deep, ContextLimits::default());
        for prompt in [&standard, &deep] {
            assert!(prompt.contains("reason privately"));
            assert!(prompt.contains("JSON:"));
            assert!(!prompt.contains("THINKING_TRACE"));
            assert!(
                prompt.contains("Do not write thoughts") || prompt.contains("Never write thoughts")
            );
        }
        assert!(!standard.contains("systematically"));
        assert!(deep.contains("systematically"));
    }
}

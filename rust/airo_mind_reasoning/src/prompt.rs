//! Prompt strategy by reasoning level. No public THINKING_TRACE protocol.

use crate::context::{ContextLimits, ReasoningContext};
use crate::grammar::ENVELOPE_OPEN;
use crate::level::ReasoningLevel;
use crate::request::ReasoningRequest;

/// PD-PERF-002: never more than two envelope shots. `none`/`light` take zero.
pub const MAX_ENVELOPE_SHOTS: usize = 2;

const DIRECT_USER: &str = "Why does ice float?";
const DIRECT_ENVELOPE: &str = r#"{"answer":"Ice is less dense than liquid water.","reasoning_summary":"Used density.","confidence":0.92}"#;

pub fn build_prompt(
    request: &ReasoningRequest,
    level: ReasoningLevel,
    limits: ContextLimits,
) -> String {
    let packed = request.context.bounded(limits);
    let mut out = String::new();
    out.push_str(system_for(level));
    out.push_str("\n\n");
    append_shots(&mut out, request, level, limits, packed.total_chars());
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
    out.push_str(json_instruction(level, !request.available_tools.is_empty()));
    out.push_str(ENVELOPE_OPEN);
    out
}

fn append_shots(
    out: &mut String,
    request: &ReasoningRequest,
    level: ReasoningLevel,
    limits: ContextLimits,
    packed_chars: usize,
) {
    if !matches!(level, ReasoningLevel::Standard | ReasoningLevel::Deep) {
        return;
    }
    let remaining = limits.max_chars.saturating_sub(packed_chars);
    let mut shots = vec![render_shot(DIRECT_USER, DIRECT_ENVELOPE)];
    if let Some(tool) = request.available_tools.first() {
        shots.push(render_shot(
            "What is on my calendar tomorrow?",
            &tool_envelope(&tool.name),
        ));
    }
    shots.truncate(MAX_ENVELOPE_SHOTS);
    const HEADER: &str =
        "Examples (match this envelope; reason privately; do not emit thoughts):\n";
    while !shots.is_empty() {
        let used: usize = HEADER.len() + shots.iter().map(String::len).sum::<usize>();
        if used <= remaining {
            break;
        }
        shots.pop();
    }
    if shots.is_empty() {
        return;
    }
    out.push_str(HEADER);
    for shot in &shots {
        out.push_str(shot);
    }
    out.push('\n');
}

fn render_shot(user: &str, envelope: &str) -> String {
    format!("User request:\n{user}\nJSON:\n{envelope}\n\n")
}

fn tool_envelope(name: &str) -> String {
    format!(
        r#"{{"answer":"","reasoning_summary":"Need listed tool.","confidence":0.80,"tool_calls":[{{"name":"{name}","arguments_json":"{{\"day\":\"tomorrow\"}}"}}]}}"#
    )
}

fn json_instruction(level: ReasoningLevel, has_tools: bool) -> &'static str {
    let lookup = matches!(level, ReasoningLevel::None | ReasoningLevel::Light);
    match (lookup, has_tools) {
        (true, false) => {
            "\nRespond as JSON. Key answer is required. reasoning_summary and \
confidence are optional. Do not include a thoughts field.\nJSON:\n"
        }
        (true, true) => {
            "\nRespond as JSON. Key answer is required. reasoning_summary and \
confidence are optional. If you must call a listed tool, add tool_calls as an \
array of objects with name and arguments_json, and set answer to an empty \
string. Do not invent tools. Do not include a thoughts field.\nJSON:\n"
        }
        (false, false) => {
            "\nRespond as JSON with keys answer, reasoning_summary, confidence only.\nJSON:\n"
        }
        (false, true) => {
            "\nRespond as JSON with keys answer, reasoning_summary, confidence. \
If you must call a listed tool, add tool_calls as an array of objects with \
name and arguments_json, and set answer to an empty string. \
Do not invent tools. Do not include a thoughts field.\nJSON:\n"
        }
    }
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
        assert!(
            prompt.contains("optional"),
            "none/light must not require a summary: {prompt}"
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
            assert!(
                !prompt.contains("are optional"),
                "standard/deep keep the full envelope: {prompt}"
            );
        }
        assert!(!standard.contains("systematically"));
        assert!(deep.contains("systematically"));
    }

    #[test]
    fn none_and_light_do_not_pay_for_few_shots() {
        let req = ReasoningRequest::fixture("time_query", 0.0);
        for level in [ReasoningLevel::None, ReasoningLevel::Light] {
            let prompt = build_prompt(&req, level, ContextLimits::default());
            assert!(
                !prompt.contains("Examples"),
                "{level:?} must stay zero-shot: {prompt}"
            );
            assert!(!prompt.contains("Why does ice float?"));
            assert!(
                prompt.contains("optional"),
                "{level:?} must not require a summary: {prompt}"
            );
        }
    }

    #[test]
    fn standard_and_deep_include_an_envelope_shot_without_a_thoughts_field() {
        let req = ReasoningRequest::fixture("planning", 0.8);
        for level in [ReasoningLevel::Standard, ReasoningLevel::Deep] {
            let prompt = build_prompt(&req, level, ContextLimits::default());
            assert!(prompt.contains("Examples"), "{level:?}: {prompt}");
            assert!(prompt.contains("Why does ice float?"), "{level:?}");
            assert!(prompt.contains(r#""answer":"Ice is less dense than liquid water.""#));
            assert!(!prompt.contains("\"thoughts\""));
            assert!(!prompt.contains("\"scratchpad\""));
            assert!(
                prompt.find("Examples").unwrap() < prompt.find("User request:").unwrap(),
                "shots belong in the cacheable prefix before the live turn"
            );
        }
    }

    #[test]
    fn tools_add_a_tool_call_shot_and_cap_at_two() {
        let mut req = ReasoningRequest::fixture("calendar_retrieval", 0.4);
        req.available_tools = vec![crate::request::ToolDefinition {
            name: "read_calendar_events".into(),
            description: "List events for a day.".into(),
        }];
        let prompt = build_prompt(&req, ReasoningLevel::Standard, ContextLimits::default());
        assert!(prompt.contains("Why does ice float?"));
        assert!(prompt.contains("read_calendar_events"));
        assert!(prompt.contains("\"tool_calls\""));
        let examples = prompt.matches("JSON:\n{").count();
        assert!(
            examples <= MAX_ENVELOPE_SHOTS + 1,
            "at most {MAX_ENVELOPE_SHOTS} shots plus the live JSON header, got {examples}: {prompt}"
        );
    }

    #[test]
    fn tight_context_budget_drops_shots_pd_perf_002() {
        let mut req = ReasoningRequest::fixture("planning", 0.8);
        req.user_query = "Plan the week.".into();
        req.context.history = vec![crate::context::ContextItem {
            source: "chat".into(),
            text: "word ".repeat(80),
        }];
        let prompt = build_prompt(
            &req,
            ReasoningLevel::Standard,
            ContextLimits {
                max_chars: 200,
                ..ContextLimits::default()
            },
        );
        assert!(
            !prompt.contains("Why does ice float?"),
            "PD-PERF-002: drop shots when they would crowd the live turn: {prompt}"
        );
        assert!(prompt.contains("Plan the week."));
    }
}

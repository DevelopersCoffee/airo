//! Result-envelope GBNF. Start symbol `root`, matching `GenerationRequest`.
//!
//! Fixed key order so the incremental parser can emit `answer` deltas without
//! buffering the whole object. There is no `thoughts` production.
//!
//! llama.cpp treats a newline as the end of a top-level alternative
//! (`parse_space(..., newline_ok=false)` after a symbol). Each rule must
//! therefore live on one line. Meeting's `chunk_facts.v1.gbnf` uses the same
//! constraint.
//!
//! The opening `{` is teacher-forced in the prompt so greedy GGUF does not
//! sample EOG before JSON. Generated tokens start at `"answer"`.
//!
//! `none`/`light` use [`LOOKUP_GRAMMAR`]: `answer` is required;
//! `reasoning_summary`, `confidence`, and `tool_calls` are optional.
//! `standard`/`deep` keep the full envelope.

use crate::level::ReasoningLevel;

/// Prefixed onto the prompt so generation does not have to sample `{`.
pub const ENVELOPE_OPEN: &str = "{";

pub const RESULT_GRAMMAR: &str = r#"
root ::= "\"answer\":" ws string "," ws "\"reasoning_summary\":" ws string "," ws "\"confidence\":" ws confidence tool-calls-tail ws "}"
tool-calls-tail ::= ("," ws "\"tool_calls\":" ws "[" ws tool-items ws "]")?
tool-items ::= (tool-item (ws "," ws tool-item)*)?
tool-item ::= "{" ws "\"name\":" ws string "," ws "\"arguments_json\":" ws string ws "}"
confidence ::= "0." [0-9] [0-9] | "1.00" | "1.0" | "0"
string ::= "\"" char* "\""
char ::= [^"\\\x00-\x1F] | "\\" (["\\/bfnrt] | "u" hex hex hex hex)
hex ::= [0-9a-fA-F]
ws ::= [ \t\n]*
"#;

/// Answer-first envelope for lookup turns. Summary and confidence stay
/// allowed so a model that emits them still parses; they are not required.
pub const LOOKUP_GRAMMAR: &str = r#"
root ::= "\"answer\":" ws string lookup-tail ws "}"
lookup-tail ::= ("," ws "\"reasoning_summary\":" ws string)? ("," ws "\"confidence\":" ws confidence)? tool-calls-tail
tool-calls-tail ::= ("," ws "\"tool_calls\":" ws "[" ws tool-items ws "]")?
tool-items ::= (tool-item (ws "," ws tool-item)*)?
tool-item ::= "{" ws "\"name\":" ws string "," ws "\"arguments_json\":" ws string ws "}"
confidence ::= "0." [0-9] [0-9] | "1.00" | "1.0" | "0"
string ::= "\"" char* "\""
char ::= [^"\\\x00-\x1F] | "\\" (["\\/bfnrt] | "u" hex hex hex hex)
hex ::= [0-9a-fA-F]
ws ::= [ \t\n]*
"#;

pub fn grammar_for(level: ReasoningLevel) -> &'static str {
    match level {
        ReasoningLevel::None | ReasoningLevel::Light => LOOKUP_GRAMMAR,
        ReasoningLevel::Standard | ReasoningLevel::Deep => RESULT_GRAMMAR,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn grammar_has_root_and_no_thoughts_key() {
        assert!(RESULT_GRAMMAR.contains("root ::="));
        assert!(RESULT_GRAMMAR.contains("answer"));
        assert!(RESULT_GRAMMAR.contains("tool_calls"));
        assert!(!RESULT_GRAMMAR.contains("thoughts"));
        assert!(!RESULT_GRAMMAR.contains("scratchpad"));
        assert!(
            !RESULT_GRAMMAR.contains(r#"root ::= "{""#),
            "opening brace is teacher-forced in the prompt; GBNF must start at \"answer\""
        );
        for line in RESULT_GRAMMAR.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("root ::=") {
                assert!(
                    trimmed.contains("}"),
                    "llama.cpp ends a top-level alternative at a newline; root must be one line"
                );
            }
        }
    }

    #[test]
    fn lookup_grammar_makes_summary_optional() {
        assert!(LOOKUP_GRAMMAR.contains("lookup-tail"));
        assert!(LOOKUP_GRAMMAR.contains("reasoning_summary"));
        assert!(
            grammar_for(crate::level::ReasoningLevel::None).contains("lookup-tail"),
            "none/light must not require summary"
        );
        assert!(
            !grammar_for(crate::level::ReasoningLevel::Standard).contains("lookup-tail"),
            "standard/deep keep the full envelope"
        );
        for line in LOOKUP_GRAMMAR.lines() {
            let trimmed = line.trim();
            if trimmed.starts_with("root ::=") {
                assert!(
                    trimmed.contains("}"),
                    "llama.cpp ends a top-level alternative at a newline; root must be one line"
                );
            }
        }
    }
}

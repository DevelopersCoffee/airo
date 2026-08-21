//! Result-envelope GBNF. Start symbol `root`, matching `GenerationRequest`.
//!
//! Fixed key order so the incremental parser can emit `answer` deltas without
//! buffering the whole object. There is no `thoughts` production.

pub const RESULT_GRAMMAR: &str = r#"
root ::= "{" ws
  "\"answer\":" ws string "," ws
  "\"reasoning_summary\":" ws string "," ws
  "\"confidence\":" ws confidence
ws "}"

confidence ::= "0." [0-9] [0-9] | "1.00" | "1.0" | "0"

string ::= "\"" char* "\""
char ::= [^"\\\x00-\x1F] | "\\" (["\\/bfnrt] | "u" hex hex hex hex)
hex ::= [0-9a-fA-F]
ws ::= [ \t\n]*
"#;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn grammar_has_root_and_no_thoughts_key() {
        assert!(RESULT_GRAMMAR.contains("root ::="));
        assert!(RESULT_GRAMMAR.contains("answer"));
        assert!(!RESULT_GRAMMAR.contains("thoughts"));
        assert!(!RESULT_GRAMMAR.contains("scratchpad"));
    }
}

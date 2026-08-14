//! The GBNF grammar pass 1 hands to `GenerationRequest::grammar` (`#1628`).
//!
//! This grammar constrains the token stream to syntactically valid generic
//! JSON — the same shape as llama.cpp's own reference `grammars/json.gbnf`
//! (root/object/array/string/number/ws), not a grammar specific to
//! [`crate::schema::ChunkFacts`]'s exact keys.
//!
//! That is a deliberate scope line, not a shortcut taken to avoid writing a
//! bigger grammar. `LlamaSampler::grammar` constrains *token-level syntax*;
//! it has no notion of "this key is required" or "this array holds objects
//! shaped like `Fact`". Encoding the full `ChunkFacts` schema into GBNF would
//! need one rule per field with exact key literals in a fixed order, which
//! is brittle against a model that (correctly, per JSON) emits keys in a
//! different order or omits an empty array — and brittleness here would
//! silently reject *valid* extractions, not just malformed ones.
//!
//! So the grammar's job is narrower and firmer: guarantee the output parses
//! as JSON at all (ruling out prose, markdown fences, truncated output, and
//! the single-quote/trailing-comma mistakes small models make under no
//! constraint). `extract::extract_chunk_facts`'s retry loop is what checks
//! the *shape* — deserializes into [`crate::schema::ChunkFacts`] (tolerant of
//! missing/reordered keys via `#[serde(default)]`) and validates evidence ids
//! — and re-prompts with the concrete error on failure.
//!
//! # Not wired up by default — a real `llama-cpp-2` 0.1.153 crash
//!
//! This constant exists, is well-formed GBNF, and is unit-tested below, but
//! [`crate::extract::ExtractionConfig::use_gbnf_grammar`] defaults to
//! `false` — see that field's doc comment for the full account of a crash
//! discovered live while building `#1633`: `llama-cpp-2` 0.1.153 aborts the
//! process (`GGML_ASSERT(!stacks.empty())`) on the token immediately after
//! ANY finite/terminable GBNF grammar reaches a fully-matched state,
//! reproduced with a grammar as trivial as `root ::= "{" "}"`. Since valid
//! JSON always eventually terminates, this grammar cannot currently be used
//! for real generation without crashing. It is kept in-repo, versioned, and
//! tested as the grammar to re-enable once the upstream crash is fixed or
//! worked around — not dead code, code waiting on a dependency fix.
//!
//! Written WITHOUT the `{m,n}` bounded-repetition operator GBNF supports in
//! newer llama.cpp releases; every quantifier below is `*`/`+`/`?` only,
//! the older, more broadly-supported subset -- functionally equivalent, just
//! spelled out one character/digit at a time instead of with a repetition
//! count. (This was the first, incorrect, hypothesis for the crash above;
//! kept because it is still the more portable spelling, not because it
//! turned out to matter.)
pub const JSON_GRAMMAR: &str = r#"
root   ::= object
value  ::= object | array | string | number | ("true" | "false" | "null") ws

object ::=
  "{" ws (
            string ":" ws value
    ("," ws string ":" ws value)*
  )? "}" ws

array  ::=
  "[" ws (
            value
    ("," ws value)*
  )? "]" ws

string ::=
  "\"" (
    [^"\\] |
    "\\" (["\\/bfnrt] | "u" [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F])
  )* "\"" ws

number ::= ("-"? ([0-9] | [1-9] [0-9]*)) ("." [0-9]+)? ([eE] [-+]? [0-9]+)? ws

ws ::= ([ \t\n] ws)?
"#;

#[cfg(test)]
mod tests {
    use super::*;

    /// Not a grammar-execution test (that needs llama.cpp's sampler, proven
    /// in `airo_mind_llama`'s own
    /// `a_gbnf_grammar_constrains_every_generated_character`) — just a
    /// sanity check that the constant is non-empty and declares the `root`
    /// rule `GRAMMAR_ROOT` in `airo_mind_llama::llama` requires.
    #[test]
    fn the_grammar_declares_a_root_rule() {
        assert!(JSON_GRAMMAR.contains("root"));
        assert!(JSON_GRAMMAR.trim_start().starts_with("root"));
    }
}

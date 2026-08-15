//! Near-duplicate detection for Pass 2.
//!
//! # Why this is not a second LLM call
//!
//! The obvious implementation of "dedupe semantically" is to hand every
//! candidate pair back to the model. That costs a second full generation pass
//! over an O(n²) pair set, on a device already budgeted for one — and it makes
//! consolidation non-deterministic, which means the same meeting can produce two
//! different IRs and neither the golden test here nor the F1 harness
//! (MIND-LLM-11) can tell a regression from sampling noise.
//!
//! # Why not embeddings
//!
//! Checked first, as the cheaper-primitive rule requires: there is no
//! embedding primitive available to this crate. `packages/core_ai` has an
//! `EmbeddingService`, but it is Dart and above the FFI boundary — calling *up*
//! into it from an extraction pass would invert the dependency and put a
//! network-capable client on a local-first path. Nothing in `rust/` produces
//! vectors (`airo_core`'s "dedup" is `normalize_channel_name`, an alphanumeric
//! squash for channel titles). Adding an embedding model would mean a second
//! model download, a second memory budget and a new dependency — a large
//! decision that belongs to the milestone, not to this function.
//!
//! # What this is instead
//!
//! Token-set (Jaccard) similarity over a normalised, lightly stemmed token
//! stream, with a small synonym lexicon that collapses the phrasings meeting
//! speech actually varies on. The issue's own example is the design target:
//!
//! ```text
//! "Check Temporal signalling limit"      -> {@inquire, temporal, signal, @capacity}
//! "Confirm Temporal signalling capacity" -> {@inquire, temporal, signal, @capacity}
//! "Ask Temporal team about signalling"   -> {@inquire, temporal, signal}
//! ```
//!
//! all of which pass the threshold against each other, while
//! `"Check the Kafka retention limit"` — same verb class, same `@capacity`
//! class, different subject — does not.
//!
//! **A similarity score is not enough on its own.** Two items must also share a
//! *domain* token (one that is not a synonym-class placeholder) before they can
//! merge, so "confirm the limit" and "confirm the budget" cannot collapse into
//! each other on the strength of their verbs.
//!
//! This is a first cut with an explicitly tunable threshold, not a claim to have
//! solved semantic equivalence. MIND-LLM-11's F1 harness is where the threshold
//! and the lexicon get measured against real meetings; this module is written to
//! be tuned from outside rather than to be right by assertion.

use std::collections::BTreeSet;

/// How aggressively Pass 2 merges.
#[derive(Clone, Debug, PartialEq)]
pub struct DedupConfig {
    /// Minimum Jaccard similarity between two items' token sets.
    ///
    /// `0.5` — measured against the issue's worked example, whose weakest pair
    /// scores `0.75`, and against the near-miss guard in this module's tests,
    /// which scores `0.33`. There is real room on both sides of it, which is
    /// what makes it a threshold rather than a fitted constant.
    pub similarity_threshold: f64,
    /// When false, only byte-identical text merges. An escape hatch for a
    /// caller that would rather see duplicates than risk a wrong merge.
    pub semantic: bool,
}

impl Default for DedupConfig {
    fn default() -> Self {
        Self {
            similarity_threshold: 0.5,
            semantic: true,
        }
    }
}

/// Words carrying no discriminating content in meeting speech. Removing them
/// keeps a shared "the" from inflating similarity between unrelated items.
const STOPWORDS: &[&str] = &[
    "a", "about", "again", "against", "all", "also", "an", "and", "any", "are", "as", "at", "back",
    "be", "been", "being", "both", "but", "by", "can", "could", "did", "do", "does", "doing",
    "down", "each", "for", "from", "further", "guys", "had", "has", "have", "he", "her", "here",
    "hers", "him", "his", "how", "i", "if", "in", "into", "is", "it", "its", "just", "like", "me",
    "more", "most", "my", "no", "nor", "not", "now", "of", "off", "on", "once", "only", "or",
    "other", "our", "ours", "out", "over", "own", "people", "person", "same", "she", "should",
    "side", "so", "some", "still", "such", "team", "teams", "than", "that", "the", "their",
    "theirs", "them", "then", "there", "these", "they", "thing", "things", "this", "those",
    "through", "to", "too", "under", "until", "up", "us", "very", "was", "we", "were", "what",
    "when", "where", "which", "while", "who", "whom", "why", "will", "with", "would", "you",
    "your", "yours",
];

/// Phrasings that mean the same act. The canonical form starts with `@` so it
/// can never collide with a real transcript word, and so
/// [`shares_a_domain_token`] can tell a subject apart from a verb.
///
/// Deliberately small and boring. Every entry is a phrasing meeting speech
/// actually alternates between; this is not a thesaurus, and a broad one would
/// merge things that differ.
const SYNONYMS: &[(&str, &[&str])] = &[
    (
        "@inquire",
        &[
            "ask",
            "check",
            "chase",
            "clarify",
            "confirm",
            "follow",
            "investigate",
            "query",
            "validate",
            "verify",
        ],
    ),
    (
        "@capacity",
        &[
            "cap",
            "capacity",
            "ceiling",
            "headroom",
            "limit",
            "max",
            "maximum",
            "quota",
            "threshold",
        ],
    ),
    (
        "@decide",
        &["agree", "approve", "decide", "decision", "settle", "sign"],
    ),
    ("@ship", &["deploy", "launch", "release", "rollout", "ship"]),
    ("@fix", &["fix", "patch", "repair", "resolve", "unblock"]),
    ("@write", &["doc", "document", "draft", "note", "write"]),
    ("@send", &["email", "message", "post", "send", "share"]),
    ("@meet", &["call", "meet", "meeting", "schedule", "sync"]),
];

/// Lowercases, splits on anything non-alphanumeric, stems, drops stopwords,
/// and folds synonyms to their class.
///
/// Returns a set, not a list: repetition inside one statement says nothing
/// about whether it matches another one.
pub(crate) fn tokenize(text: &str) -> BTreeSet<String> {
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty())
        .map(|w| w.to_lowercase())
        .map(|w| stem(&w))
        .filter(|w| w.chars().count() > 1 && !STOPWORDS.contains(&w.as_str()))
        .map(|w| synonym_class(&w).unwrap_or(w))
        .collect()
}

/// A deliberately minimal suffix stripper — the first step of a Porter stemmer
/// and nothing more.
///
/// It exists for one case that matters here: a meeting says "signalling" in one
/// chunk and "signalled" in another, and those must land on the same token.
/// Anything more aggressive starts conflating words that differ.
fn stem(word: &str) -> String {
    // Byte slicing below is only sound on ASCII, and the suffix rules are
    // English ones anyway — a non-ASCII token is returned untouched rather
    // than mangled or panicked on.
    if !word.is_ascii() {
        return word.to_string();
    }
    let len = word.len();
    let stemmed: String = if len > 4 && (word.ends_with("ies") || word.ends_with("ied")) {
        format!("{}y", &word[..len - 3])
    } else if len > 5 && word.ends_with("ing") {
        word[..len - 3].to_string()
    } else if len > 5 && word.ends_with("ed") {
        word[..len - 2].to_string()
    } else if len > 3 && word.ends_with('s') && !word.ends_with("ss") {
        word[..len - 1].to_string()
    } else {
        word.to_string()
    };
    collapse_doubled_ending(&stemmed)
}

/// `signall` -> `signal`, `shipp` -> `ship`. English doubles a final consonant
/// before `-ing`/`-ed`; stripping the suffix leaves the double behind.
fn collapse_doubled_ending(word: &str) -> String {
    let chars: Vec<char> = word.chars().collect();
    let n = chars.len();
    if n >= 3 && chars[n - 1] == chars[n - 2] && !matches!(chars[n - 1], 's' | 'l' | 'e' | 'o') {
        return chars[..n - 1].iter().collect();
    }
    // `-ll` is the common English doubling (`signalling`, `cancelled`) and is
    // safe to collapse when what remains is still a plausible stem; `-ss`
    // (`discuss`, `process`) is not a doubling at all.
    if n >= 4 && chars[n - 1] == 'l' && chars[n - 2] == 'l' {
        return chars[..n - 1].iter().collect();
    }
    word.to_string()
}

fn synonym_class(word: &str) -> Option<String> {
    SYNONYMS
        .iter()
        .find_map(|(class, members)| members.contains(&word).then(|| (*class).to_string()))
}

fn jaccard(a: &BTreeSet<String>, b: &BTreeSet<String>) -> f64 {
    if a.is_empty() && b.is_empty() {
        return 1.0;
    }
    let intersection = a.intersection(b).count();
    let union = a.union(b).count();
    if union == 0 {
        return 0.0;
    }
    intersection as f64 / union as f64
}

/// True when the two sets share at least one token that is a real word rather
/// than a synonym-class placeholder — i.e. they are about the same *thing*, not
/// merely the same kind of act.
fn shares_a_domain_token(a: &BTreeSet<String>, b: &BTreeSet<String>) -> bool {
    a.intersection(b).any(|t| !t.starts_with('@'))
}

/// Whether two items' texts should be treated as the same fact.
///
/// Byte-identical text (what overlapping chunks produce for a fact sitting on a
/// boundary) short-circuits, so the exact-duplicate case never depends on the
/// heuristic at all.
///
/// `pub`, not `pub(crate)`: `airo_mind_eval` (`#1636`) scores extraction
/// precision/recall/F1 by semantically matching predicted facts against a
/// golden IR, and that is exactly this function's job. Widening the
/// visibility here means the eval harness measures Pass 2's actual matching
/// behaviour rather than a second, drifting reimplementation of it.
pub fn is_near_duplicate(left: &str, right: &str, config: &DedupConfig) -> bool {
    if left.eq_ignore_ascii_case(right) {
        return true;
    }
    if !config.semantic {
        return false;
    }
    let a = tokenize(left);
    let b = tokenize(right);
    if a.is_empty() || b.is_empty() {
        return false;
    }
    jaccard(&a, &b) >= config.similarity_threshold && shares_a_domain_token(&a, &b)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tokens(text: &str) -> Vec<String> {
        tokenize(text).into_iter().collect()
    }

    #[test]
    fn the_issues_worked_example_collapses_to_one_item() {
        let config = DedupConfig::default();
        let phrasings = [
            "Check Temporal signalling limit",
            "Confirm Temporal signalling capacity",
            "Ask Temporal team about signalling",
        ];
        for (i, left) in phrasings.iter().enumerate() {
            for right in phrasings.iter().skip(i + 1) {
                assert!(
                    is_near_duplicate(left, right, &config),
                    "`{left}` and `{right}` should be one item"
                );
            }
        }
    }

    #[test]
    fn the_same_verb_class_on_a_different_subject_does_not_merge() {
        let config = DedupConfig::default();
        assert!(!is_near_duplicate(
            "Check the Temporal signalling limit",
            "Check the Kafka retention limit",
            &config
        ));
        assert!(!is_near_duplicate(
            "Confirm the budget",
            "Confirm the limit",
            &config
        ));
    }

    #[test]
    fn identical_text_merges_without_consulting_the_heuristic() {
        let strict = DedupConfig {
            semantic: false,
            ..DedupConfig::default()
        };
        assert!(is_near_duplicate(
            "Ship the release on Friday",
            "ship the release on friday",
            &strict
        ));
        assert!(!is_near_duplicate(
            "Check Temporal signalling limit",
            "Confirm Temporal signalling capacity",
            &strict
        ));
    }

    #[test]
    fn inflections_of_the_same_word_land_on_the_same_token() {
        assert_eq!(stem("signalling"), "signal");
        assert_eq!(stem("signalled"), "signal");
        assert_eq!(stem("signals"), "signal");
        assert_eq!(stem("shipping"), "ship");
        assert_eq!(stem("verified"), "verify");
        assert_eq!(stem("queries"), "query");
        // Not a doubling — must survive intact.
        assert_eq!(stem("process"), "process");
        assert_eq!(stem("discuss"), "discuss");
    }

    #[test]
    fn stopwords_and_synonym_classes_leave_only_the_subject_behind() {
        assert_eq!(
            tokens("Ask the Temporal team about signalling"),
            vec![
                "@inquire".to_string(),
                "signal".to_string(),
                "temporal".to_string()
            ]
        );
    }

    #[test]
    fn an_item_that_is_only_stopwords_never_merges_with_anything() {
        let config = DedupConfig::default();
        assert!(!is_near_duplicate("the it a", "Check the limit", &config));
    }

    #[test]
    fn similarity_is_symmetric() {
        let config = DedupConfig::default();
        let a = "Confirm Temporal signalling capacity";
        let b = "Ask Temporal team about signalling";
        assert_eq!(
            is_near_duplicate(a, b, &config),
            is_near_duplicate(b, a, &config)
        );
    }
}

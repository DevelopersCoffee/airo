//! Raw/normalized text, per `#1632`.
//!
//! `raw` is never touched — it is the evidence text a fact's segment id
//! ultimately points back to, and "aggressively rewriting raw" is the
//! specific mistake the issue calls out. `normalized` is a corrected copy
//! built alongside it, fed to extraction instead.
//!
//! Two kinds of correction, run in a fixed order so the result is
//! deterministic for a given input:
//!
//! 1. **Technical-term dictionary** — ASR mishears a fixed vocabulary of
//!    product/infra nouns in predictable ways ("temple workspace" for
//!    "Temporal workspace", "worklows" for "workflows"). Phrase-level
//!    corrections run first (multi-word ASR damage), then single-word
//!    corrections (casing/known misspellings of one term).
//! 2. **Number normalization** — a digit run gets a canonical integer value
//!    and a comma-grouped display form. `"500,000"` round-trips to the same
//!    display; an ungrouped `"500000"` gets grouped for readability. Only
//!    the *normalized* text changes — `raw` still has whatever digits ASR
//!    produced.
//!
//! Both passes are ASCII-oriented (the technical terms and digit grouping
//! this crate corrects are ASCII by construction); a transcript is assumed
//! English for the extent that matters to matching case-insensitively.

use std::collections::HashMap;

/// One phrase-level correction applied to the text: what ASR produced, and
/// what it was corrected to. `raw` is the exact matched substring — kept so
/// a caller (or a test) can show its provenance, not just the outcome.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TermCorrection {
    pub raw: String,
    pub corrected: String,
}

/// One number found in the text: the literal digits ASR/the source produced,
/// the canonical integer value, and a comma-grouped display form.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NumberNormalization {
    pub raw: String,
    pub canonical: i64,
    pub display: String,
}

/// The result of normalizing one piece of text (typically one segment's
/// `text`, but the same function works on a joined transcript).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct NormalizationResult {
    /// Byte-for-byte identical to the input. Never mutated.
    pub raw: String,
    /// The corrected copy, fed to extraction.
    pub normalized: String,
    pub terms_corrected: Vec<TermCorrection>,
    pub numbers: Vec<NumberNormalization>,
}

/// Multi-word ASR damage: phrases whisper is known to mis-transcribe as a
/// whole, corrected before single-word lookup runs. Matched case-insensitively
/// against contiguous text (`replace_ci`), longest-first so a longer phrase
/// is not shadowed by a shorter one nested inside it.
const PHRASE_CORRECTIONS: &[(&str, &str)] = &[
    ("temple workspace", "Temporal workspace"),
    ("temple work space", "Temporal workspace"),
    ("temporal work space", "Temporal workspace"),
    ("yuga byte db", "YugabyteDB"),
    ("yugabyte db", "YugabyteDB"),
    ("g rpc", "gRPC"),
    ("name space", "namespace"),
];

/// Single-token technical-term dictionary. Keys are matched case-insensitively
/// against a whole word; the value is what the word becomes in `normalized`.
/// Extend this list as new ASR-damaged or inconsistently-cased terms show up
/// in real meetings — it is intentionally a flat, easy-to-append table rather
/// than anything cleverer.
const TERM_CORRECTIONS: &[(&str, &str)] = &[
    ("temporal", "Temporal"),
    ("yugabytedb", "YugabyteDB"),
    ("yugabyte", "Yugabyte"),
    ("gcp", "GCP"),
    ("jvm", "JVM"),
    ("kubernetes", "Kubernetes"),
    ("kubernettis", "Kubernetes"),
    ("kubernetees", "Kubernetes"),
    ("k8s", "K8s"),
    ("namespace", "namespace"),
    ("namespaces", "namespaces"),
    ("signalling", "signaling"),
    ("signaling", "signaling"),
    ("worklows", "workflows"),
    ("worklfows", "workflows"),
    ("workflow", "workflow"),
    ("workflows", "workflows"),
    ("grpc", "gRPC"),
    ("postgres", "PostgreSQL"),
    ("postgresql", "PostgreSQL"),
    ("redis", "Redis"),
    ("kafka", "Kafka"),
    ("docker", "Docker"),
    ("terraform", "Terraform"),
    ("oauth", "OAuth"),
    ("api", "API"),
    ("apis", "APIs"),
    ("sdk", "SDK"),
    ("cicd", "CI/CD"),
    ("tls", "TLS"),
    ("ssl", "SSL"),
];

/// Normalizes one piece of text: phrase corrections, then single-word
/// corrections, then number normalization. `raw` in the result is the
/// caller's `text` unchanged.
pub fn normalize(text: &str) -> NormalizationResult {
    let mut terms_corrected = Vec::new();

    let mut working = text.to_string();
    for (phrase, replacement) in PHRASE_CORRECTIONS {
        working = replace_ci(&working, phrase, replacement, &mut terms_corrected);
    }
    working = correct_words(&working, &mut terms_corrected);

    let (working, numbers) = normalize_numbers(&working);

    NormalizationResult {
        raw: text.to_string(),
        normalized: working,
        terms_corrected,
        numbers,
    }
}

/// Case-insensitive, non-overlapping find-and-replace of `needle` in `text`,
/// recording each match as a [`TermCorrection`]. ASCII-oriented: byte offsets
/// from the lowercased haystack are assumed to line up with the original,
/// which holds for the ASCII technical terms this crate corrects.
fn replace_ci(
    text: &str,
    needle: &str,
    replacement: &str,
    corrections: &mut Vec<TermCorrection>,
) -> String {
    if needle.is_empty() {
        return text.to_string();
    }
    let lower_text = text.to_lowercase();
    let lower_needle = needle.to_lowercase();
    let mut result = String::with_capacity(text.len());
    let mut i = 0usize;
    while let Some(pos) = lower_text[i..].find(&lower_needle) {
        let start = i + pos;
        let end = start + lower_needle.len();
        result.push_str(&text[i..start]);
        result.push_str(replacement);
        corrections.push(TermCorrection {
            raw: text[start..end].to_string(),
            corrected: replacement.to_string(),
        });
        i = end;
    }
    result.push_str(&text[i..]);
    result
}

/// Word-boundary tokenizer: splits `text` into alphanumeric "word" runs and
/// everything else ("separator" runs — spaces, punctuation), preserving
/// separators exactly so the text can be reconstructed byte-for-byte from its
/// pieces when nothing is corrected.
fn tokenize_words(text: &str) -> Vec<(bool, String)> {
    let mut pieces = Vec::new();
    let mut current = String::new();
    let mut current_is_word: Option<bool> = None;
    for ch in text.chars() {
        let is_word = ch.is_alphanumeric();
        match current_is_word {
            Some(w) if w == is_word => current.push(ch),
            _ => {
                if !current.is_empty() {
                    pieces.push((current_is_word.unwrap(), std::mem::take(&mut current)));
                }
                current.push(ch);
                current_is_word = Some(is_word);
            }
        }
    }
    if !current.is_empty() {
        pieces.push((current_is_word.unwrap(), current));
    }
    pieces
}

/// Applies [`TERM_CORRECTIONS`] to every word token in `text`, case-insensitively.
fn correct_words(text: &str, corrections: &mut Vec<TermCorrection>) -> String {
    let dict: HashMap<&str, &str> = TERM_CORRECTIONS.iter().copied().collect();
    let mut out = String::with_capacity(text.len());
    for (is_word, piece) in tokenize_words(text) {
        if is_word {
            if let Some(replacement) = dict.get(piece.to_lowercase().as_str()) {
                if *replacement != piece {
                    corrections.push(TermCorrection {
                        raw: piece.clone(),
                        corrected: replacement.to_string(),
                    });
                }
                out.push_str(replacement);
                continue;
            }
        }
        out.push_str(&piece);
    }
    out
}

/// Finds digit runs (optionally comma-grouped) worth normalizing, and
/// rewrites the text so every one is displayed comma-grouped. A run is
/// "worth normalizing" if it already contains a comma (the source clearly
/// intended a grouped number) or has 4+ digits (large enough that grouping
/// helps readability) — small figures like "2 people" are left alone.
fn normalize_numbers(text: &str) -> (String, Vec<NumberNormalization>) {
    let mut numbers = Vec::new();
    let mut out = String::with_capacity(text.len());
    let chars: Vec<char> = text.chars().collect();
    let mut i = 0usize;
    while i < chars.len() {
        if chars[i].is_ascii_digit() {
            let start = i;
            let mut j = i;
            while j < chars.len() && (chars[j].is_ascii_digit() || chars[j] == ',') {
                j += 1;
            }
            // Trailing comma (e.g. "500," at end of a clause) is not part of
            // the number; back it off the run.
            while j > start && chars[j - 1] == ',' {
                j -= 1;
            }
            let raw: String = chars[start..j].iter().collect();
            if let Some((canonical, display)) = parse_grouped_number(&raw) {
                out.push_str(&display);
                numbers.push(NumberNormalization {
                    raw,
                    canonical,
                    display,
                });
            } else {
                out.push_str(&raw);
            }
            i = j;
            continue;
        }
        out.push(chars[i]);
        i += 1;
    }
    (out, numbers)
}

/// Validates and parses a digit-and-comma run as a number, returning its
/// canonical integer value and a canonical comma-grouped display form.
/// Rejects malformed grouping (e.g. `"500,00"`) by returning `None` — an
/// ambiguous token is left in the text untouched rather than guessed at.
/// Only numbers with 4+ digits or an existing comma are treated as worth
/// normalizing, matching `normalize_numbers`'s call site.
fn parse_grouped_number(raw: &str) -> Option<(i64, String)> {
    let has_comma = raw.contains(',');
    let digits: String = raw.chars().filter(|c| *c != ',').collect();
    if digits.is_empty() || digits.len() > 18 {
        return None;
    }
    if !has_comma && digits.len() < 4 {
        return None;
    }
    if has_comma {
        let groups: Vec<&str> = raw.split(',').collect();
        if groups.iter().any(|g| g.is_empty()) {
            return None;
        }
        if groups[0].len() > 3 || groups[0].is_empty() {
            return None;
        }
        if groups[1..].iter().any(|g| g.len() != 3) {
            return None;
        }
    }
    let canonical: i64 = digits.parse().ok()?;
    Some((canonical, group_thousands(canonical)))
}

/// Formats a non-negative integer with `,` every three digits from the right.
///
/// `% 3 == 0` rather than `is_multiple_of` (clippy's suggestion) — this
/// workspace does not pin an MSRV above the one that predates that method.
#[allow(clippy::manual_is_multiple_of)]
fn group_thousands(value: i64) -> String {
    let digits = value.abs().to_string();
    let mut grouped = String::with_capacity(digits.len() + digits.len() / 3);
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (digits.len() - i) % 3 == 0 {
            grouped.push(',');
        }
        grouped.push(ch);
    }
    if value < 0 {
        format!("-{grouped}")
    } else {
        grouped
    }
}

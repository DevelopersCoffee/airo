//! Vocabulary Intelligence — confidence-based correction on stable transcript text.
//!
//! Runs after the transcript stabilizer commits [`Stable`] segments, not on
//! every partial token. Preserves raw STT output alongside corrections for
//! provenance (`ADR-0022` / Conversation IR).

use std::collections::HashMap;

use crate::normalize::normalize;

/// Layer in the vocabulary stack.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VocabularyCategory {
    Product,
    Technical,
    Person,
    Organization,
    Domain,
    User,
}

/// Where an entry came from.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VocabularySource {
    Global,
    UserDefined,
    Project,
    DomainPack,
    Conversation,
    RecentMemory,
}

/// One canonical term and its known mis-hearings.
#[derive(Clone, Debug, PartialEq)]
pub struct VocabularyEntry {
    pub canonical: String,
    pub aliases: Vec<String>,
    pub phonetic_forms: Vec<String>,
    pub category: VocabularyCategory,
    pub source: VocabularySource,
    pub priority: u8,
    pub confidence: f32,
}

/// Named vocabulary layers merged at correction time.
#[derive(Clone, Debug, Default)]
pub struct VocabularyContext {
    pub global: Vec<VocabularyEntry>,
    pub user: Vec<VocabularyEntry>,
    pub project: Vec<VocabularyEntry>,
    pub domain: Vec<VocabularyEntry>,
    pub conversation: Vec<VocabularyEntry>,
}

impl VocabularyContext {
    pub fn with_defaults() -> Self {
        Self {
            global: default_global_entries(),
            user: Vec::new(),
            project: Vec::new(),
            domain: Vec::new(),
            conversation: Vec::new(),
        }
    }

    pub fn all_entries(&self) -> Vec<&VocabularyEntry> {
        let mut entries: Vec<&VocabularyEntry> = self
            .global
            .iter()
            .chain(&self.user)
            .chain(&self.project)
            .chain(&self.domain)
            .chain(&self.conversation)
            .collect();
        entries.sort_by(|a, b| b.priority.cmp(&a.priority));
        entries
    }
}

/// One applied substitution with audit metadata.
#[derive(Clone, Debug, PartialEq)]
pub struct VocabularyCorrection {
    pub original: String,
    pub replacement: String,
    pub confidence: f32,
    pub source: VocabularySource,
}

/// Outcome of correcting one stable segment.
#[derive(Clone, Debug, PartialEq)]
pub struct CorrectionResult {
    pub original_text: String,
    pub corrected_text: String,
    pub corrections: Vec<VocabularyCorrection>,
    pub confidence: f32,
}

/// Deterministic + phonetic/fuzzy vocabulary corrector (no LLM on the hot path).
pub struct VocabularyIntelligence {
    context: VocabularyContext,
    min_confidence: f32,
}

impl VocabularyIntelligence {
    pub fn new(context: VocabularyContext) -> Self {
        Self {
            context,
            min_confidence: 0.85,
        }
    }

    pub fn with_defaults() -> Self {
        Self::new(VocabularyContext::with_defaults())
    }

    pub fn correct(&self, text: &str) -> CorrectionResult {
        let original_text = text.to_string();
        let norm = normalize(text);
        let mut working = norm.normalized;
        let mut corrections: Vec<VocabularyCorrection> = norm
            .terms_corrected
            .into_iter()
            .map(|t| VocabularyCorrection {
                original: t.raw,
                replacement: t.corrected,
                confidence: 0.98,
                source: VocabularySource::Global,
            })
            .collect();

        for entry in self.context.all_entries() {
            for alias in entry.aliases.iter().chain(&entry.phonetic_forms) {
                if alias.is_empty() {
                    continue;
                }
                let replaced = replace_ci_record(
                    &working,
                    alias,
                    &entry.canonical,
                    entry.confidence,
                    entry.source,
                    &mut corrections,
                );
                working = replaced;
            }
        }

        working = correct_fuzzy_words(&working, &self.context, &mut corrections, self.min_confidence);

        let confidence = if corrections.is_empty() {
            1.0
        } else {
            corrections.iter().map(|c| c.confidence).fold(1.0, f32::min)
        };

        CorrectionResult {
            original_text,
            corrected_text: working,
            corrections,
            confidence,
        }
    }
}

fn default_global_entries() -> Vec<VocabularyEntry> {
    vec![
        entry(
            "Airo Mind",
            &[
                "arrow mind",
                "aero mind",
                "airo mine",
                "iro mind",
                "airomind",
            ],
            &["ero mnd", "aro mnd"],
            VocabularyCategory::Product,
            VocabularySource::Global,
            100,
            0.96,
        ),
        entry(
            "Flutter",
            &["flatter", "fluter"],
            &[],
            VocabularyCategory::Technical,
            VocabularySource::Global,
            80,
            0.9,
        ),
        entry(
            "llama.cpp",
            &["llama cpp", "llamaCP"],
            &[],
            VocabularyCategory::Technical,
            VocabularySource::Global,
            80,
            0.9,
        ),
    ]
}

fn entry(
    canonical: &str,
    aliases: &[&str],
    phonetic: &[&str],
    category: VocabularyCategory,
    source: VocabularySource,
    priority: u8,
    confidence: f32,
) -> VocabularyEntry {
    VocabularyEntry {
        canonical: canonical.to_string(),
        aliases: aliases.iter().map(|s| s.to_string()).collect(),
        phonetic_forms: phonetic.iter().map(|s| s.to_string()).collect(),
        category,
        source,
        priority,
        confidence,
    }
}

fn replace_ci_record(
    text: &str,
    needle: &str,
    replacement: &str,
    confidence: f32,
    source: VocabularySource,
    corrections: &mut Vec<VocabularyCorrection>,
) -> String {
    if needle.is_empty() {
        return text.to_string();
    }
    if needle.contains(' ') {
        return replace_phrase_ci(text, needle, replacement, confidence, source, corrections);
    }
    let lower_text = text.to_lowercase();
    let lower_needle = needle.to_lowercase();
    let mut result = String::with_capacity(text.len());
    let mut i = 0usize;
    while let Some(pos) = lower_text[i..].find(&lower_needle) {
        let start = i + pos;
        let end = start + lower_needle.len();
        if !word_boundary_match(text, start, end) {
            result.push_str(&text[i..start + 1]);
            i = start + 1;
            continue;
        }
        result.push_str(&text[i..start]);
        result.push_str(replacement);
        corrections.push(VocabularyCorrection {
            original: text[start..end].to_string(),
            replacement: replacement.to_string(),
            confidence,
            source,
        });
        i = end;
    }
    result.push_str(&text[i..]);
    result
}

fn replace_phrase_ci(
    text: &str,
    needle: &str,
    replacement: &str,
    confidence: f32,
    source: VocabularySource,
    corrections: &mut Vec<VocabularyCorrection>,
) -> String {
    let lower_text = text.to_lowercase();
    let lower_needle = needle.to_lowercase();
    let mut result = String::with_capacity(text.len());
    let mut i = 0usize;
    while let Some(pos) = lower_text[i..].find(&lower_needle) {
        let start = i + pos;
        let end = start + lower_needle.len();
        if !word_boundary_match(text, start, end) {
            result.push_str(&text[i..start + 1]);
            i = start + 1;
            continue;
        }
        result.push_str(&text[i..start]);
        result.push_str(replacement);
        corrections.push(VocabularyCorrection {
            original: text[start..end].to_string(),
            replacement: replacement.to_string(),
            confidence,
            source,
        });
        i = end;
    }
    result.push_str(&text[i..]);
    result
}

fn word_boundary_match(text: &str, start: usize, end: usize) -> bool {
    let before_ok = start == 0 || !text[..start].chars().last().is_some_and(|c| c.is_alphanumeric());
    let after_ok = end >= text.len()
        || !text[end..].chars().next().is_some_and(|c| c.is_alphanumeric());
    before_ok && after_ok
}

fn correct_fuzzy_words(
    text: &str,
    context: &VocabularyContext,
    corrections: &mut Vec<VocabularyCorrection>,
    min_confidence: f32,
) -> String {
    let dict: HashMap<String, (&VocabularyEntry, f32)> = context
        .all_entries()
        .into_iter()
        .flat_map(|e| {
            let key = normalize_token(&e.canonical);
            vec![(key, (e, e.confidence))]
        })
        .collect();

    let mut out = String::with_capacity(text.len());
    for (is_word, piece) in tokenize_words(text) {
        if !is_word {
            out.push_str(&piece);
            continue;
        }
        let token = normalize_token(&piece);
        if dict.contains_key(&token) {
            out.push_str(&piece);
            continue;
        }
        let mut best: Option<(&VocabularyEntry, f32)> = None;
        for (canonical_key, (entry, base)) in &dict {
            let dist = levenshtein(&token, canonical_key);
            if dist == 0 {
                continue;
            }
            if dist > 2 {
                continue;
            }
            let score = *base * (1.0 - dist as f32 * 0.15);
            if score >= min_confidence {
                if best.map(|(_, s)| score > s).unwrap_or(true) {
                    best = Some((entry, score));
                }
            }
        }
        if let Some((entry, score)) = best {
            corrections.push(VocabularyCorrection {
                original: piece.clone(),
                replacement: entry.canonical.clone(),
                confidence: score,
                source: entry.source,
            });
            out.push_str(&entry.canonical);
        } else {
            out.push_str(&piece);
        }
    }
    out
}

fn normalize_token(token: &str) -> String {
    token
        .chars()
        .filter(|c| c.is_ascii_alphanumeric())
        .collect::<String>()
        .to_lowercase()
}

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

fn levenshtein(a: &str, b: &str) -> usize {
    if a == b {
        return 0;
    }
    let a_chars: Vec<char> = a.chars().collect();
    let b_chars: Vec<char> = b.chars().collect();
    let mut prev: Vec<usize> = (0..=b_chars.len()).collect();
    let mut cur = vec![0; b_chars.len() + 1];
    for (i, ac) in a_chars.iter().enumerate() {
        cur[0] = i + 1;
        for (j, bc) in b_chars.iter().enumerate() {
            let cost = if ac == bc { 0 } else { 1 };
            cur[j + 1] = (cur[j] + 1)
                .min(prev[j + 1] + 1)
                .min(prev[j] + cost);
        }
        prev.clone_from_slice(&cur);
    }
    prev[b_chars.len()]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn corrects_arrow_mind_to_airo_mind_with_provenance() {
        let intel = VocabularyIntelligence::with_defaults();
        let result = intel.correct("we need to update arrow mind");
        assert_eq!(result.corrected_text, "we need to update Airo Mind");
        assert_eq!(result.original_text, "we need to update arrow mind");
        assert!(result.corrections.iter().any(|c| c.original == "arrow mind"));
        assert!(result.confidence >= 0.85);
    }

    #[test]
    fn low_confidence_candidate_is_not_applied() {
        let intel = VocabularyIntelligence::with_defaults();
        let result = intel.correct("we will deploy this to arrow");
        assert_eq!(result.corrected_text, "we will deploy this to arrow");
    }

    #[test]
    fn preserves_raw_when_nothing_matches() {
        let intel = VocabularyIntelligence::with_defaults();
        let raw = "plain transcript with no hits";
        let result = intel.correct(raw);
        assert_eq!(result.original_text, raw);
        assert_eq!(result.corrected_text, raw);
        assert!(result.corrections.is_empty());
    }
}

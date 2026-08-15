//! Grounding: evidence accuracy and unsupported-claim rate. `#1636`.
//!
//! `airo_mind_meeting::validate` already grounds every *fact in the IR*
//! against the segments it cites, with no model in the loop. This module
//! reuses exactly that pattern -- a claim's numbers and content words must
//! appear in the transcript text its underlying evidence cites -- one level
//! up, on the *prose* the MoM's narrative sections generate from those
//! already-grounded facts (`airo_mind_meeting::mom::generate_mom`'s
//! `objective_facts`/`discussion_facts`, which pull from `topics`,
//! `decisions` and `observations`).
//!
//! The MoM's other three sections (Decisions & Direction, Action Items, Next
//! Steps) are rendered as byte-copies of IR fields
//! (`airo_mind_meeting::mom::render_*`) -- not prose a model could
//! misrepresent, so this module does not re-score them sentence by sentence;
//! their grounding is exactly the IR's own grounding, already checked by
//! `validate::validate` before a MoM is ever generated. What can still go
//! wrong, and what `#1636`'s issue explicitly calls out, is the two sections
//! that *are* prose.

use std::collections::BTreeSet;

use airo_mind_meeting::ir::MeetingIr;
use airo_mind_transcript::Segment;

/// How well one MoM sentence is backed by the evidence its underlying facts
/// cite.
#[derive(Clone, Copy, Debug, PartialEq, Eq, serde::Serialize)]
pub enum GroundingClass {
    /// Every number the sentence quotes appears in the evidence, and most of
    /// its content words do too.
    Supported,
    /// No invented number, but the content-word overlap is too low to call
    /// it fully backed -- generic or vaguely-worded, not necessarily wrong.
    Partial,
    /// Quotes a number the evidence never mentions, or shares almost no
    /// vocabulary with it at all.
    Unsupported,
}

/// Content-word overlap ratio at or above this counts as [`GroundingClass::Supported`].
///
/// A first-cut, explicitly tunable number, the same posture
/// `airo_mind_meeting::dedup`'s own `similarity_threshold` doc comment takes
/// ("a first cut with an explicitly tunable threshold, not a claim to have
/// solved semantic equivalence"). `0.4` rather than something stricter:
/// narrative prose legitimately adds connective and framing words a purely
/// extractive sentence would not ("ahead of the planned migration" glossing a
/// decision's "before the release") -- the golden MoM fixture's own Meeting
/// Objective sentence is exactly this shape, and a threshold that flags it as
/// unsupported would be scoring narrative synthesis as a defect. MIND-LLM-11's
/// eventual 10-20 real meetings are where this gets fitted against real
/// hallucinations rather than one hand-authored example.
const SUPPORTED_THRESHOLD: f64 = 0.4;
/// Below [`SUPPORTED_THRESHOLD`] but at or above this counts as
/// [`GroundingClass::Partial`]; below it, [`GroundingClass::Unsupported`].
const PARTIAL_THRESHOLD: f64 = 0.15;

/// Stopwords excluded from the content-word overlap calculation -- the same
/// idea `airo_mind_meeting::dedup` applies before comparing fact text, kept
/// short and specific to this module rather than importing `dedup`'s (larger,
/// synonym-aware) list, which is tuned for near-duplicate *fact* text, not
/// full sentences.
const STOPWORDS: &[&str] = &[
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "had", "has", "have", "in",
    "is", "it", "of", "on", "or", "our", "that", "the", "this", "to", "was", "we", "with",
];

fn content_words(text: &str) -> BTreeSet<String> {
    text.split(|c: char| !c.is_alphanumeric())
        .map(|w| w.to_lowercase())
        .filter(|w| !w.is_empty() && !STOPWORDS.contains(&w.as_str()))
        .collect()
}

fn digit_tokens(text: &str) -> BTreeSet<String> {
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|w| !w.is_empty() && w.chars().all(|c| c.is_ascii_digit()))
        .map(|w| w.to_string())
        .collect()
}

/// Classifies one sentence against the combined text of the evidence its
/// underlying facts cite.
pub fn classify_sentence(sentence: &str, evidence_text: &str) -> GroundingClass {
    let claimed_numbers = digit_tokens(sentence);
    let available_numbers = digit_tokens(evidence_text);
    if !claimed_numbers.is_subset(&available_numbers) {
        return GroundingClass::Unsupported;
    }

    let sentence_words = content_words(sentence);
    if sentence_words.is_empty() {
        // Nothing to check (e.g. "Yes." or punctuation-only) -- no number was
        // invented, so this is not a claim the harness can call unsupported.
        return GroundingClass::Supported;
    }
    let evidence_words = content_words(evidence_text);
    let overlap = sentence_words.intersection(&evidence_words).count() as f64;
    let ratio = overlap / sentence_words.len() as f64;

    if ratio >= SUPPORTED_THRESHOLD {
        GroundingClass::Supported
    } else if ratio >= PARTIAL_THRESHOLD {
        GroundingClass::Partial
    } else {
        GroundingClass::Unsupported
    }
}

/// One classified sentence, kept alongside its verdict for the report.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct SentenceGrounding {
    pub sentence: String,
    pub class: GroundingClass,
}

/// Aggregate grounding outcome for a MoM's narrative prose.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct GroundingReport {
    pub sentences: Vec<SentenceGrounding>,
    /// `SUPPORTED count / total`. `1.0` when there were no sentences to
    /// check.
    pub evidence_accuracy: f64,
    /// `UNSUPPORTED count / total`. `0.0` when there were no sentences to
    /// check -- nothing was left unsupported.
    pub unsupported_rate: f64,
}

/// Splits `text` into sentences on `.`/`!`/`?`, trimming whitespace and
/// dropping empties. Deliberately simple -- meeting-narrative prose is short,
/// declarative sentences (the mom prompts ask for exactly that), not text
/// with abbreviations or nested punctuation that would need a real sentence
/// splitter.
fn split_sentences(text: &str) -> Vec<String> {
    text.split(['.', '!', '?'])
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| s.to_string())
        .collect()
}

/// Extracts the text between a `## <heading>` line and the next `## `
/// heading (or end of document).
fn section(mom: &str, heading: &str) -> Option<String> {
    let marker = format!("## {heading}");
    let start = mom.find(&marker)? + marker.len();
    let rest = &mom[start..];
    let end = rest.find("\n## ").unwrap_or(rest.len());
    Some(rest[..end].trim().to_string())
}

/// The evidence text backing the MoM's narrative sections: every segment
/// cited by a topic, decision or observation -- exactly the categories
/// `airo_mind_meeting::mom::objective_facts`/`discussion_facts` draw from.
///
/// Normalized, not raw: `airo_mind_meeting::extract` runs Pass 1/2 against
/// `ProcessedSegment::normalized`, never `Segment::text` directly (see that
/// crate's `lib.rs`, `extract`'s `segment_text` map) -- a fact's wording (and
/// the MoM prose built from it) reflects the corrected term, not whatever ASR
/// produced verbatim ("signaling", not "signalling"). Comparing narrative
/// prose against *raw* segment text would flag every corrected technical term
/// as unsupported, which is not the failure mode this module exists to catch.
fn narrative_evidence_text(ir: &MeetingIr, segments: &[Segment]) -> String {
    let normalized: std::collections::BTreeMap<&str, String> = segments
        .iter()
        .map(|s| {
            (
                s.id.as_str(),
                airo_mind_transcript::normalize::normalize(&s.text).normalized,
            )
        })
        .collect();
    let segment_text: std::collections::BTreeMap<&str, &str> = normalized
        .iter()
        .map(|(id, text)| (*id, text.as_str()))
        .collect();

    let mut cited_ids: Vec<&str> = Vec::new();
    for topic in &ir.facts.topics {
        cited_ids.extend(topic.evidence.iter().map(String::as_str));
    }
    for decision in &ir.facts.decisions {
        cited_ids.extend(decision.evidence.iter().map(String::as_str));
    }
    for observation in &ir.facts.observations {
        cited_ids.extend(observation.evidence.iter().map(String::as_str));
    }

    cited_ids
        .into_iter()
        .filter_map(|id| segment_text.get(id).copied())
        .collect::<Vec<_>>()
        .join(" ")
}

/// Evaluates every sentence of the MoM's Meeting Objective and Key Discussion
/// Points sections against the evidence their underlying facts cite.
pub fn evaluate_mom_grounding(ir: &MeetingIr, segments: &[Segment], mom: &str) -> GroundingReport {
    let evidence_text = narrative_evidence_text(ir, segments);

    let mut sentences = Vec::new();
    for heading in ["Meeting Objective", "Key Discussion Points"] {
        if let Some(body) = section(mom, heading) {
            for sentence in split_sentences(&body) {
                let class = classify_sentence(&sentence, &evidence_text);
                sentences.push(SentenceGrounding { sentence, class });
            }
        }
    }

    let total = sentences.len();
    let supported = sentences
        .iter()
        .filter(|s| s.class == GroundingClass::Supported)
        .count();
    let unsupported = sentences
        .iter()
        .filter(|s| s.class == GroundingClass::Unsupported)
        .count();

    let evidence_accuracy = if total == 0 {
        1.0
    } else {
        supported as f64 / total as f64
    };
    let unsupported_rate = if total == 0 {
        0.0
    } else {
        unsupported as f64 / total as f64
    };

    GroundingReport {
        sentences,
        evidence_accuracy,
        unsupported_rate,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use airo_mind_meeting::ir::{Decision, Facts, Meeting, Topic, IR_SCHEMA_VERSION};

    fn segments() -> Vec<Segment> {
        vec![
            Segment {
                id: "s0".into(),
                start_ms: 0,
                end_ms: 1_000,
                text: "Right, let us start with the Temporal signaling limit.".into(),
            },
            Segment {
                id: "s4".into(),
                start_ms: 1_000,
                end_ms: 2_000,
                text: "We agreed to move signaling onto the queue before the release.".into(),
            },
        ]
    }

    // -- classify_sentence ----------------------------------------------------

    #[test]
    fn a_sentence_fully_backed_by_its_evidence_is_supported() {
        let class = classify_sentence(
            "We discussed the Temporal signaling limit",
            "Right, let us start with the Temporal signaling limit.",
        );
        assert_eq!(class, GroundingClass::Supported);
    }

    #[test]
    fn a_sentence_quoting_a_number_the_evidence_never_said_is_unsupported() {
        let class = classify_sentence(
            "the team covered 3 topics today",
            "Right, let us start with the Temporal signaling limit.",
        );
        assert_eq!(class, GroundingClass::Unsupported);
    }

    #[test]
    fn a_number_the_evidence_does_quote_does_not_make_it_unsupported() {
        let class = classify_sentence(
            "about 500000 events a day were discussed",
            "the service handles about 500000 events a day",
        );
        assert_ne!(class, GroundingClass::Unsupported);
    }

    #[test]
    fn a_sentence_sharing_no_vocabulary_with_its_evidence_is_unsupported() {
        let class = classify_sentence(
            "the team ordered lunch and left early",
            "Right, let us start with the Temporal signaling limit.",
        );
        assert_eq!(class, GroundingClass::Unsupported);
    }

    #[test]
    fn a_partially_overlapping_sentence_is_partial() {
        // Content words {team, discussed, signaling}: one of three ("signaling")
        // is in the evidence -- 0.33 overlap, inside [0.3, 0.7).
        let class = classify_sentence(
            "team discussed signaling",
            "Right, let us start with the Temporal signaling limit.",
        );
        assert_eq!(class, GroundingClass::Partial);
    }

    #[test]
    fn empty_evidence_text_leaves_only_no_number_no_word_sentences_supported() {
        assert_eq!(classify_sentence("", ""), GroundingClass::Supported);
        assert_eq!(
            classify_sentence("we discussed the plan", ""),
            GroundingClass::Unsupported
        );
    }

    // -- evaluate_mom_grounding -------------------------------------------------

    fn ir_with(facts: Facts) -> MeetingIr {
        MeetingIr {
            schema_version: IR_SCHEMA_VERSION.into(),
            meeting: Meeting {
                id: "meeting-0".into(),
                prompt_version: "chunk_facts.v1".into(),
                ..Meeting::default()
            },
            facts,
        }
    }

    #[test]
    fn a_grounded_mom_scores_full_evidence_accuracy_and_no_unsupported_claims() {
        let ir = ir_with(Facts {
            topics: vec![Topic {
                title: "Temporal signaling limit".into(),
                evidence: vec!["s0".into()],
                ..Topic::default()
            }],
            decisions: vec![Decision {
                statement: "move signaling onto the queue before the release".into(),
                evidence: vec!["s4".into()],
                ..Decision::default()
            }],
            ..Facts::default()
        });
        let mom = "# Minutes of Meeting\n\n\
                   ## Meeting Objective\n\n\
                   Review the Temporal signaling limit.\n\n\
                   ## Key Discussion Points\n\n\
                   The team agreed to move signaling onto the queue before the release.\n\n\
                   ## Decisions & Direction\n\n_No decisions recorded._\n";

        let report = evaluate_mom_grounding(&ir, &segments(), mom);

        assert_eq!(report.evidence_accuracy, 1.0);
        assert_eq!(report.unsupported_rate, 0.0);
        assert_eq!(report.sentences.len(), 2);
    }

    #[test]
    fn a_hallucinated_number_in_the_narrative_lowers_evidence_accuracy() {
        let ir = ir_with(Facts {
            topics: vec![Topic {
                title: "Temporal signaling limit".into(),
                evidence: vec!["s0".into()],
                ..Topic::default()
            }],
            ..Facts::default()
        });
        let mom = "## Meeting Objective\n\nThe team covered 3 topics today.\n\n\
                   ## Key Discussion Points\n\nNothing else came up.\n";

        let report = evaluate_mom_grounding(&ir, &segments(), mom);

        assert!(report.unsupported_rate > 0.0);
        assert!(report
            .sentences
            .iter()
            .any(|s| s.class == GroundingClass::Unsupported));
    }

    #[test]
    fn a_mom_with_no_narrative_sections_reports_a_vacuous_perfect_score() {
        let ir = ir_with(Facts::default());
        let mom = "## Decisions & Direction\n\n_No decisions recorded._\n";
        let report = evaluate_mom_grounding(&ir, &segments(), mom);
        assert!(report.sentences.is_empty());
        assert_eq!(report.evidence_accuracy, 1.0);
        assert_eq!(report.unsupported_rate, 0.0);
    }
}

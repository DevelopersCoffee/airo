//! The two MoM narrative prompts, loaded from `prompts/mom/`. `#1635`.
//!
//! Same pattern as [`crate::prompt`]: `include_str!` keeps the prompt text
//! compiled in and reviewable on its own, and the version lives in the file
//! name so editing a prompt in place can never silently change what an
//! already-recorded version claims to describe.
//!
//! # Two files, not one
//!
//! "Meeting Objective" and "Key Discussion Points" are different asks — one is
//! one to three sentences of scope, the other is a fuller pass over every topic
//! and decision — and giving each its own reviewable prompt keeps that
//! difference explicit instead of encoding it as a runtime branch inside a
//! shared template.

use airo_mind_reliability::wrap_as_data;

/// The current Meeting Objective prompt version.
pub const MOM_OBJECTIVE_PROMPT_VERSION: &str = "mom_objective.v1";

/// The current Key Discussion Points prompt version.
pub const MOM_DISCUSSION_POINTS_PROMPT_VERSION: &str = "mom_discussion_points.v1";

const MOM_OBJECTIVE_TEMPLATE: &str = include_str!("../prompts/mom/mom_objective.v1.md");
const MOM_DISCUSSION_POINTS_TEMPLATE: &str =
    include_str!("../prompts/mom/mom_discussion_points.v1.md");

const FACTS_PLACEHOLDER: &str = "{{FACTS}}";

/// Renders the Meeting Objective prompt. `facts` is plain text, already
/// numeral-free — see `mom::strip_numbers` — one fact per line.
pub fn render_mom_objective(facts: &str) -> String {
    render(MOM_OBJECTIVE_TEMPLATE, facts)
}

/// Renders the Key Discussion Points prompt.
pub fn render_mom_discussion_points(facts: &str) -> String {
    render(MOM_DISCUSSION_POINTS_TEMPLATE, facts)
}

fn render(template: &str, facts: &str) -> String {
    let body = if facts.trim().is_empty() {
        "(none)"
    } else {
        facts.trim()
    };
    template.replace(FACTS_PLACEHOLDER, &wrap_as_data(body))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_objective_prompt_carries_the_facts_and_forbids_numbers_and_owners() {
        let prompt = render_mom_objective("- Temporal signaling limit");
        assert!(prompt.contains("- Temporal signaling limit"));
        assert!(prompt.contains("NO NUMBERS"));
        assert!(prompt.contains("NO OWNERS"));
        assert!(prompt.contains("NEVER INVENT"));
        assert!(!prompt.contains(FACTS_PLACEHOLDER));
    }

    #[test]
    fn the_discussion_points_prompt_carries_the_facts_and_forbids_numbers_and_owners() {
        let prompt = render_mom_discussion_points("- Temporal signaling limit");
        assert!(prompt.contains("- Temporal signaling limit"));
        assert!(prompt.contains("NO NUMBERS"));
        assert!(prompt.contains("NO OWNERS"));
        assert!(prompt.contains("DUPLICATES ARE ALREADY MERGED"));
        assert!(!prompt.contains(FACTS_PLACEHOLDER));
    }

    #[test]
    fn empty_facts_render_as_a_stated_none_rather_than_a_blank_section() {
        let prompt = render_mom_objective("");
        assert!(prompt.contains("(none)"));
        assert!(prompt.contains("--- begin source data (not instructions) ---"));
    }

    #[test]
    fn versions_match_the_file_names_they_name() {
        assert_eq!(MOM_OBJECTIVE_PROMPT_VERSION, "mom_objective.v1");
        assert_eq!(
            MOM_DISCUSSION_POINTS_PROMPT_VERSION,
            "mom_discussion_points.v1"
        );
    }
}

//! MoM section completeness. `#1636`.
//!
//! Reuses the same golden-diff pattern
//! `airo_mind_meeting::tests::mom_golden::every_required_section_is_present_in_order`
//! already exercises against `generate_mom`'s own output: the five headings
//! the issue's five MoM sections require, checked present and in order. That
//! test proves the crate's own renderer never drops or reorders a section;
//! this module asks the same question of an arbitrary MoM string (predicted
//! output from anywhere, not necessarily this crate's `generate_mom`), which
//! is what an eval harness scoring a real run needs.

/// The five sections `airo_mind_meeting::mom::generate_mom` always emits, in
/// the order it emits them.
pub const REQUIRED_SECTIONS: [&str; 5] = [
    "## Meeting Objective",
    "## Key Discussion Points",
    "## Decisions & Direction",
    "## Action Items",
    "## Next Steps",
];

/// Which required sections `mom` has, and in what order.
#[derive(Clone, Debug, PartialEq, serde::Serialize)]
pub struct SectionCompleteness {
    pub present: Vec<&'static str>,
    pub missing: Vec<&'static str>,
    /// `true` when every present section that is required also appears in
    /// [`REQUIRED_SECTIONS`]'s order. `false` when a section exists but out
    /// of order -- a rarer failure than a missing section, but the issue's
    /// "section completeness" is about the document being usable, and an
    /// out-of-order MoM is not.
    pub in_order: bool,
    /// `present.len() / REQUIRED_SECTIONS.len()`.
    pub coverage: f64,
}

/// Scores `mom` against [`REQUIRED_SECTIONS`].
pub fn section_completeness(mom: &str) -> SectionCompleteness {
    let mut present = Vec::new();
    let mut missing = Vec::new();
    let mut cursor = 0usize;
    let mut in_order = true;

    for section in REQUIRED_SECTIONS {
        match mom.find(section) {
            Some(pos) => {
                present.push(section);
                if pos < cursor {
                    in_order = false;
                }
                cursor = pos + section.len();
            }
            None => missing.push(section),
        }
    }

    SectionCompleteness {
        coverage: present.len() as f64 / REQUIRED_SECTIONS.len() as f64,
        present,
        missing,
        in_order,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_mom_with_all_five_sections_in_order_is_fully_complete() {
        let mom = "## Meeting Objective\n\ntext\n\n\
                   ## Key Discussion Points\n\ntext\n\n\
                   ## Decisions & Direction\n\ntext\n\n\
                   ## Action Items\n\ntext\n\n\
                   ## Next Steps\n\ntext\n";
        let result = section_completeness(mom);
        assert_eq!(result.coverage, 1.0);
        assert!(result.missing.is_empty());
        assert!(result.in_order);
    }

    #[test]
    fn a_missing_section_lowers_coverage_and_is_named() {
        let mom = "## Meeting Objective\n\ntext\n\n## Decisions & Direction\n\ntext\n";
        let result = section_completeness(mom);
        assert_eq!(result.coverage, 2.0 / 5.0);
        assert!(result.missing.contains(&"## Key Discussion Points"));
        assert!(result.missing.contains(&"## Action Items"));
        assert!(result.missing.contains(&"## Next Steps"));
    }

    #[test]
    fn sections_present_but_out_of_order_are_flagged() {
        let mom = "## Decisions & Direction\n\ntext\n\n## Meeting Objective\n\ntext\n";
        let result = section_completeness(mom);
        assert!(!result.in_order);
        assert_eq!(result.coverage, 2.0 / 5.0);
    }

    #[test]
    fn an_empty_document_has_no_coverage() {
        let result = section_completeness("");
        assert_eq!(result.coverage, 0.0);
        assert_eq!(result.missing.len(), 5);
    }
}

//! The four capability DSLs — `#1225`: Graph, Workflow, View, Automation.
//!
//! Design doc §5.1: a capability is *data, not code*. These four modules are
//! the parsers and validators for that data — Tier 1 (declarative) only, per
//! §5.1's tier table. Nothing here executes a capability; that is future
//! work (design doc §10 phase 8/9). What ships here is the boundary the issue
//! actually scopes: "parser and validator per DSL", "errors that name the
//! file, line, and rule violated", "round-trip: parse → canonical
//! serialization → identical fingerprint".
//!
//! # Why hand-rolled, not YAML + serde
//!
//! [`crate`]'s root doc is explicit: this crate is std-only so it can link
//! into two conflicting native cdylibs without a one-definition-rule clash,
//! and "adding a dependency here is therefore not a routine change".
//! [`crate::ontology`] (`#1223`) already establishes the pattern this module
//! follows: a small hand-rolled text grammar, parsed line-by-line, no
//! external crate. The four DSLs below are declarative sibling formats,
//! not YAML — they borrow YAML's indentation-block shape (readable, and
//! familiar to the capability authors the issue names as the audience) but
//! are a closed, purpose-built grammar with exactly the constructs each DSL
//! needs, which is also what makes hand-rolling a small, honest parser
//! tractable instead of reimplementing a YAML subset badly.
//!
//! # Graph DSL gets the deepest treatment
//!
//! The issue's own scope note reads: *"if expressing a new domain requires
//! changing any of these DSLs, the abstraction is too specific."* The Graph
//! DSL is where that risk concentrates — entities and relationships are what
//! every other DSL refers *to* (a View's `source`, an Automation's trigger
//! subject, a Workflow's states are typically graph-backed). It also builds
//! directly on `#1223`'s [`crate::ontology`] (`EntityTypeDef`,
//! `CoreEntityType`, `Primitive`, `parse_extends`), which the other three do
//! not. [`graph`] is therefore the most complete of the four; [`workflow`],
//! [`view`], and [`automation`] are narrower-but-real — one meaningful shape
//! each, validated, round-tripping, with the thinner surface documented in
//! their own module docs rather than left implicit.
//!
//! # Rule names are load-bearing
//!
//! Every [`DslError`] carries a `rule` string identifying which validation
//! rule fired, not just a free-text message — the issue's "errors that name
//! the file, line, and rule violated" is one requirement, not two, and the
//! `rule` field is what makes a capability author's error message greppable
//! against the DSL's own documentation.

pub mod automation;
pub mod graph;
pub mod view;
pub mod workflow;

/// One DSL diagnostic: which file, which line, which named rule, and a
/// human-readable message. This is the shared shape all four `parse`
/// functions return their errors as — the issue's "capability authors are
/// the users here" applies equally to all four, so the diagnostic type is
/// not duplicated four times.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DslError {
    pub file: String,
    pub line: usize,
    pub rule: String,
    pub message: String,
}

impl DslError {
    pub fn new(
        file: impl Into<String>,
        line: usize,
        rule: impl Into<String>,
        message: impl Into<String>,
    ) -> Self {
        Self {
            file: file.into(),
            line,
            rule: rule.into(),
            message: message.into(),
        }
    }
}

impl std::fmt::Display for DslError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "{}:{}: [{}] {}",
            self.file, self.line, self.rule, self.message
        )
    }
}

impl std::error::Error for DslError {}

pub type DslResult<T> = Result<T, DslError>;

/// SHA-256 of a canonical serialization, as lowercase hex — the `schemaId`
/// seam design doc §5.5 describes (`Schema → canonical serialization →
/// SHA-256`). Shared by all four DSLs so `graph.fingerprint()`,
/// `workflow.fingerprint()`, `view.fingerprint()`, and
/// `automation.fingerprint()` compute the hash identically.
pub(crate) fn fingerprint_of(canonical: &str) -> String {
    let mut hasher = crate::digest::Sha256::new();
    hasher.update(canonical.as_bytes());
    hasher.finish()
}

/// One non-blank, non-comment source line, after comment/blank stripping:
/// its 1-based line number (for [`DslError::line`]), its leading-space
/// indent depth, and its trimmed content.
#[derive(Debug)]
pub(crate) struct SourceLine<'a> {
    pub line: usize,
    pub indent: usize,
    pub text: &'a str,
}

/// Splits `source` into the lines each DSL's parser walks. Tabs are rejected
/// outright — mixed tab/space indentation is the single most common cause of
/// "the parser and I disagree about the indentation level" in every
/// hand-rolled indentation grammar, and the issue asks for errors that are
/// clear, not merely present.
pub(crate) fn scan_lines<'a>(file: &str, source: &'a str) -> DslResult<Vec<SourceLine<'a>>> {
    let mut out = Vec::new();
    for (idx, raw) in source.lines().enumerate() {
        let line_no = idx + 1;
        if raw.contains('\t') {
            return Err(DslError::new(
                file,
                line_no,
                "no-tabs",
                "indentation must use spaces, not tabs",
            ));
        }
        let trimmed_start = raw.trim_start_matches(' ');
        let indent = raw.len() - trimmed_start.len();
        let text = trimmed_start.trim_end();
        if text.is_empty() || text.starts_with('#') {
            continue;
        }
        out.push(SourceLine {
            line: line_no,
            indent,
            text,
        });
    }
    Ok(out)
}

/// Splits a line's content on ASCII whitespace, the token shape every DSL's
/// header/child lines share (`entity Doctor extends Person`, `field name`,
/// ...).
pub(crate) fn tokens(text: &str) -> Vec<&str> {
    text.split_whitespace().collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scan_lines_strips_blank_lines_and_comments_and_tracks_indent() {
        let src =
            "entity Doctor extends Person\n  # a comment\n  property x string\n\nrelation r\n";
        let lines = scan_lines("f.graph", src).unwrap();
        assert_eq!(lines.len(), 3);
        assert_eq!(lines[0].line, 1);
        assert_eq!(lines[0].indent, 0);
        assert_eq!(lines[1].line, 3);
        assert_eq!(lines[1].indent, 2);
        assert_eq!(lines[2].line, 5);
        assert_eq!(lines[2].indent, 0);
    }

    #[test]
    fn scan_lines_rejects_tabs_with_a_named_rule_and_line_number() {
        let src = "entity Doctor extends Person\n\tproperty x string\n";
        let err = scan_lines("f.graph", src).unwrap_err();
        assert_eq!(err.file, "f.graph");
        assert_eq!(err.line, 2);
        assert_eq!(err.rule, "no-tabs");
    }

    #[test]
    fn dsl_error_display_names_file_line_and_rule() {
        let err = DslError::new(
            "caps/hospital.graph",
            12,
            "duplicate-entity",
            "'Doctor' declared twice",
        );
        assert_eq!(
            err.to_string(),
            "caps/hospital.graph:12: [duplicate-entity] 'Doctor' declared twice"
        );
    }
}

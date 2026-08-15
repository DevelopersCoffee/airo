//! View DSL — `#1225`: how a projection gets rendered/queried for UI
//! consumption. Issue text names four kinds, verbatim: *"timeline, form,
//! dashboard, checklist"*.
//!
//! # Grammar
//!
//! ```text
//! view PatientTimeline kind timeline
//!   source Patient
//!   field admittedAt
//!   field dischargedAt
//!
//! view IntakeForm kind form
//!   source Patient
//!   field name
//!   field dateOfBirth
//! ```
//!
//! A document is a list of `view` blocks (unlike [`crate::dsl::workflow`],
//! which allows exactly one `workflow` header — a capability typically ships
//! several views over the same graph, so the document-level container here
//! is a list, matching [`crate::dsl::graph`]'s and
//! [`crate::dsl::automation`]'s own shape).
//!
//! # Field order is preserved, not canonicalized
//!
//! [`crate::dsl::graph::GraphDsl::to_canonical`] sorts an entity's labels
//! because labels are a set — order carries no meaning. A view's `field`
//! list is different: for a `form` or `checklist`, field order **is** the
//! on-screen order a user sees, which is real authored content, not
//! incidental syntax. This module therefore preserves declaration order in
//! [`ViewDef::fields`] and in [`ViewDsl::to_canonical`] rather than sorting
//! it — the one place this DSL's canonicalization policy differs from
//! [`crate::dsl::graph`]'s, called out explicitly rather than left as a
//! silent inconsistency.
//!
//! # Honestly thin
//!
//! This module validates shape (`kind` is one of the four named values,
//! `source` and at least one `field` are present, no duplicates) and nothing
//! about rendering semantics — a `dashboard` view's actual layout, a
//! `checklist`'s completion semantics, and how a `field` maps to a
//! [`crate::ontology::Primitive`] on the named `source` entity are all
//! unspecified by the issue text and are not invented here. `source` is a
//! bare entity-type name string, not cross-validated against a
//! [`crate::dsl::graph::GraphDsl`] document — the issue does not ask for
//! cross-DSL referential integrity, and inventing it risks coupling two
//! documents that a capability pack may reasonably keep in separate files
//! loaded and validated independently.

use std::collections::BTreeSet;

use super::{fingerprint_of, scan_lines, tokens, DslError, DslResult};

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum ViewKind {
    Timeline,
    Form,
    Dashboard,
    Checklist,
}

const ALL_VIEW_KINDS: &[ViewKind] = &[
    ViewKind::Timeline,
    ViewKind::Form,
    ViewKind::Dashboard,
    ViewKind::Checklist,
];

impl ViewKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Timeline => "timeline",
            Self::Form => "form",
            Self::Dashboard => "dashboard",
            Self::Checklist => "checklist",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        ALL_VIEW_KINDS.iter().copied().find(|k| k.as_str() == s)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ViewDef {
    pub name: String,
    pub kind: ViewKind,
    pub source: String,
    /// Declaration order, deliberately not sorted — see the module doc.
    pub fields: Vec<String>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct ViewDsl {
    pub views: Vec<ViewDef>,
}

impl ViewDsl {
    pub fn parse(file: &str, source: &str) -> DslResult<ViewDsl> {
        let lines = scan_lines(file, source)?;
        if lines.is_empty() {
            return Err(DslError::new(
                file,
                1,
                "empty-document",
                "view DSL document has no views",
            ));
        }

        let mut seen_names: BTreeSet<String> = BTreeSet::new();
        let mut views = Vec::new();

        let mut i = 0usize;
        while i < lines.len() {
            let header = &lines[i];
            if header.indent != 0 {
                return Err(DslError::new(
                    file,
                    header.line,
                    "unexpected-indent",
                    "expected a top-level 'view' declaration",
                ));
            }
            let toks = tokens(header.text);
            let mut j = i + 1;
            while j < lines.len() && lines[j].indent > 0 {
                j += 1;
            }
            let children = &lines[i + 1..j];

            if toks.first().copied() != Some("view") {
                return Err(DslError::new(
                    file,
                    header.line,
                    "unknown-block",
                    format!("expected 'view', got '{}'", header.text),
                ));
            }
            if toks.len() != 4 || toks[2] != "kind" {
                return Err(DslError::new(
                    file,
                    header.line,
                    "malformed-view-header",
                    "expected 'view <Name> kind <timeline|form|dashboard|checklist>'",
                ));
            }
            let name = toks[1].to_string();
            let kind = ViewKind::parse(toks[3]).ok_or_else(|| {
                DslError::new(
                    file,
                    header.line,
                    "unknown-view-kind",
                    format!(
                        "'{}' is not timeline, form, dashboard, or checklist",
                        toks[3]
                    ),
                )
            })?;
            if !seen_names.insert(name.clone()) {
                return Err(DslError::new(
                    file,
                    header.line,
                    "duplicate-view",
                    format!("view '{name}' is declared more than once"),
                ));
            }

            let mut source_field: Option<String> = None;
            let mut fields: Vec<String> = Vec::new();
            let mut seen_fields: BTreeSet<String> = BTreeSet::new();
            for child in children {
                let ctoks = tokens(child.text);
                match ctoks.first().copied() {
                    Some("source") if ctoks.len() == 2 => {
                        if source_field.is_some() {
                            return Err(DslError::new(
                                file,
                                child.line,
                                "view-duplicate-source",
                                format!("view '{name}' declares 'source' more than once"),
                            ));
                        }
                        source_field = Some(ctoks[1].to_string());
                    }
                    Some("field") if ctoks.len() == 2 => {
                        if !seen_fields.insert(ctoks[1].to_string()) {
                            return Err(DslError::new(
                                file,
                                child.line,
                                "view-duplicate-field",
                                format!(
                                    "view '{name}' declares field '{}' more than once",
                                    ctoks[1]
                                ),
                            ));
                        }
                        fields.push(ctoks[1].to_string());
                    }
                    _ => {
                        return Err(DslError::new(
                            file,
                            child.line,
                            "unexpected-child",
                            format!(
                                "expected 'source <Entity>' or 'field <name>', got '{}'",
                                child.text
                            ),
                        ));
                    }
                }
            }

            let source_field = source_field.ok_or_else(|| {
                DslError::new(
                    file,
                    header.line,
                    "view-missing-source",
                    format!("view '{name}' has no 'source'"),
                )
            })?;
            if fields.is_empty() {
                return Err(DslError::new(
                    file,
                    header.line,
                    "view-empty",
                    format!("view '{name}' declares no fields"),
                ));
            }

            views.push(ViewDef {
                name,
                kind,
                source: source_field,
                fields,
            });
            i = j;
        }

        views.sort_by(|a, b| a.name.cmp(&b.name));
        Ok(ViewDsl { views })
    }

    /// Views sorted by name; each view's `field` list kept in declaration
    /// order — see the module doc's "Field order is preserved" note.
    pub fn to_canonical(&self) -> String {
        let mut out = String::new();
        for v in &self.views {
            out.push_str(&format!("view {} kind {}\n", v.name, v.kind.as_str()));
            out.push_str(&format!("  source {}\n", v.source));
            for f in &v.fields {
                out.push_str(&format!("  field {f}\n"));
            }
            out.push('\n');
        }
        out
    }

    pub fn fingerprint(&self) -> String {
        fingerprint_of(&self.to_canonical())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const HOSPITAL_VIEWS: &str = "\
view PatientTimeline kind timeline
  source Patient
  field admittedAt
  field dischargedAt

view IntakeForm kind form
  source Patient
  field name
  field dateOfBirth
";

    const JOB_SEARCH_VIEWS: &str = "\
view ApplicationsDashboard kind dashboard
  source Application
  field status
  field appliedAt

view PrepChecklist kind checklist
  source Application
  field resumeUpdated
  field coverLetterWritten
";

    #[test]
    fn valid_hospital_views_parse() {
        let v = ViewDsl::parse("hosp.view", HOSPITAL_VIEWS).unwrap();
        assert_eq!(v.views.len(), 2);
        assert_eq!(v.views[0].name, "IntakeForm");
        assert_eq!(v.views[0].kind, ViewKind::Form);
        assert_eq!(v.views[0].fields, vec!["name", "dateOfBirth"]);
    }

    /// Test-the-abstraction: job search views, same grammar.
    #[test]
    fn valid_job_search_views_parse_with_the_same_grammar() {
        let v = ViewDsl::parse("jobsearch.view", JOB_SEARCH_VIEWS).unwrap();
        assert_eq!(v.views.len(), 2);
        assert!(v.views.iter().any(|d| d.kind == ViewKind::Dashboard));
        assert!(v.views.iter().any(|d| d.kind == ViewKind::Checklist));
    }

    #[test]
    fn unknown_view_kind_is_rejected() {
        let src = "view X kind bogus\n  source Y\n  field z\n";
        let err = ViewDsl::parse("bad.view", src).unwrap_err();
        assert_eq!(err.rule, "unknown-view-kind");
    }

    #[test]
    fn duplicate_view_name_is_rejected() {
        let src =
            "view X kind form\n  source Y\n  field z\n\nview X kind form\n  source Y\n  field z\n";
        let err = ViewDsl::parse("bad.view", src).unwrap_err();
        assert_eq!(err.rule, "duplicate-view");
    }

    #[test]
    fn view_with_no_fields_is_rejected() {
        let src = "view X kind form\n  source Y\n";
        let err = ViewDsl::parse("bad.view", src).unwrap_err();
        assert_eq!(err.rule, "view-empty");
    }

    #[test]
    fn view_with_no_source_is_rejected() {
        let src = "view X kind form\n  field z\n";
        let err = ViewDsl::parse("bad.view", src).unwrap_err();
        assert_eq!(err.rule, "view-missing-source");
    }

    #[test]
    fn duplicate_field_is_rejected() {
        let src = "view X kind form\n  source Y\n  field z\n  field z\n";
        let err = ViewDsl::parse("bad.view", src).unwrap_err();
        assert_eq!(err.rule, "view-duplicate-field");
    }

    #[test]
    fn parser_does_not_panic_on_malformed_input() {
        for src in [
            "view",
            "view X",
            "view X kind",
            "view X sort form",
            "  view X kind form",
        ] {
            assert!(
                ViewDsl::parse("fuzz.view", src).is_err(),
                "expected error for {src:?}"
            );
        }
    }

    #[test]
    fn round_trips_through_canonical_serialization_with_an_identical_fingerprint() {
        let v1 = ViewDsl::parse("hosp.view", HOSPITAL_VIEWS).unwrap();
        let canonical = v1.to_canonical();
        let v2 = ViewDsl::parse("hosp.canonical.view", &canonical).unwrap();
        assert_eq!(v1.fingerprint(), v2.fingerprint());
        assert_eq!(canonical, v2.to_canonical());
    }

    #[test]
    fn field_order_changes_the_fingerprint_unlike_graph_labels() {
        let a = "view X kind form\n  source Y\n  field a\n  field b\n";
        let b = "view X kind form\n  source Y\n  field b\n  field a\n";
        let va = ViewDsl::parse("a.view", a).unwrap();
        let vb = ViewDsl::parse("b.view", b).unwrap();
        assert_ne!(va.fingerprint(), vb.fingerprint());
    }

    #[test]
    fn view_declaration_order_does_not_affect_the_fingerprint() {
        let reordered = "\
view IntakeForm kind form
  source Patient
  field name
  field dateOfBirth

view PatientTimeline kind timeline
  source Patient
  field admittedAt
  field dischargedAt
";
        let a = ViewDsl::parse("a.view", HOSPITAL_VIEWS).unwrap();
        let b = ViewDsl::parse("b.view", reordered).unwrap();
        assert_eq!(a.fingerprint(), b.fingerprint());
    }
}

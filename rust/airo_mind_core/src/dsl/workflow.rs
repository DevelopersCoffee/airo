//! Workflow DSL — `#1225`: states and transitions, fully generic.
//!
//! Issue text, verbatim: *"not `Admission → Surgery → Recovery` but
//! `State → Transition → State`. A hospitalization and a startup use the
//! same engine."* This module enforces that genericity structurally — there
//! is no field anywhere here for a domain-specific concept. A state is a
//! name. A transition is a name plus a `from` state and a `to` state. That
//! is the entire vocabulary; a capability's domain meaning lives entirely in
//! *which names it chooses*, never in a construct this grammar would need to
//! grow to express it.
//!
//! # Grammar
//!
//! ```text
//! workflow Hospitalization
//!   initial Admission
//!
//! state Admission
//! state Surgery
//! state Recovery
//! state Discharged
//!
//! transition admit
//!   from Admission
//!   to Surgery
//!
//! transition operate
//!   from Surgery
//!   to Recovery
//!
//! transition discharge
//!   from Recovery
//!   to Discharged
//! ```
//!
//! Exactly one `workflow` header per document, naming the workflow and its
//! `initial` state. Any number of `state` and `transition` blocks follow, in
//! any order — `state`/`transition` may reference a state declared later in
//! the file, matching [`crate::dsl::graph`]'s own forward-reference
//! allowance.
//!
//! # Honestly thinner than Graph
//!
//! This module validates that every `from`/`to`/`initial` names a declared
//! state and that names do not collide — the structural half of "a valid
//! state machine". It does **not** validate reachability (an unreachable
//! state is not rejected) or determinism (two transitions with the same
//! `from` and no distinguishing trigger are both accepted) — the issue does
//! not specify either as a requirement, and guessing a policy here risks
//! exactly the "invents a concrete value nothing asked for" mistake
//! [`crate::ontology`]'s own module doc calls out. Flagged rather than
//! silently assumed.

use std::collections::BTreeMap;

use super::{fingerprint_of, scan_lines, tokens, DslError, DslResult};

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct TransitionDef {
    pub name: String,
    pub from: String,
    pub to: String,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct WorkflowDsl {
    pub name: String,
    pub initial: String,
    pub states: Vec<String>,
    pub transitions: Vec<TransitionDef>,
}

impl WorkflowDsl {
    pub fn parse(file: &str, source: &str) -> DslResult<WorkflowDsl> {
        let lines = scan_lines(file, source)?;
        if lines.is_empty() {
            return Err(DslError::new(
                file,
                1,
                "empty-document",
                "workflow DSL document is empty",
            ));
        }

        let mut workflow_name: Option<String> = None;
        let mut initial: Option<String> = None;
        let mut states: BTreeMap<String, usize> = BTreeMap::new();
        let mut transitions: BTreeMap<String, TransitionDef> = BTreeMap::new();

        let mut i = 0usize;
        while i < lines.len() {
            let header = &lines[i];
            if header.indent != 0 {
                return Err(DslError::new(
                    file,
                    header.line,
                    "unexpected-indent",
                    "expected a top-level 'workflow', 'state', or 'transition' declaration",
                ));
            }
            let toks = tokens(header.text);
            let mut j = i + 1;
            while j < lines.len() && lines[j].indent > 0 {
                j += 1;
            }
            let children = &lines[i + 1..j];

            match toks.first().copied() {
                Some("workflow") => {
                    if toks.len() != 2 {
                        return Err(DslError::new(
                            file,
                            header.line,
                            "malformed-workflow-header",
                            "expected 'workflow <Name>'",
                        ));
                    }
                    if workflow_name.is_some() {
                        return Err(DslError::new(
                            file,
                            header.line,
                            "duplicate-workflow-header",
                            "only one 'workflow' declaration is allowed per document",
                        ));
                    }
                    workflow_name = Some(toks[1].to_string());
                    for child in children {
                        let ctoks = tokens(child.text);
                        match ctoks.first().copied() {
                            Some("initial") if ctoks.len() == 2 => {
                                initial = Some(ctoks[1].to_string());
                            }
                            _ => {
                                return Err(DslError::new(
                                    file,
                                    child.line,
                                    "unexpected-child",
                                    format!("expected 'initial <State>', got '{}'", child.text),
                                ));
                            }
                        }
                    }
                }
                Some("state") => {
                    if toks.len() != 2 {
                        return Err(DslError::new(
                            file,
                            header.line,
                            "malformed-state-header",
                            "expected 'state <Name>'",
                        ));
                    }
                    if !children.is_empty() {
                        return Err(DslError::new(
                            file,
                            children[0].line,
                            "unexpected-child",
                            "'state' declarations take no children",
                        ));
                    }
                    if states.contains_key(toks[1]) {
                        return Err(DslError::new(
                            file,
                            header.line,
                            "duplicate-state",
                            format!("state '{}' is declared more than once", toks[1]),
                        ));
                    }
                    states.insert(toks[1].to_string(), header.line);
                }
                Some("transition") => {
                    if toks.len() != 2 {
                        return Err(DslError::new(
                            file,
                            header.line,
                            "malformed-transition-header",
                            "expected 'transition <Name>'",
                        ));
                    }
                    if transitions.contains_key(toks[1]) {
                        return Err(DslError::new(
                            file,
                            header.line,
                            "duplicate-transition",
                            format!("transition '{}' is declared more than once", toks[1]),
                        ));
                    }
                    let mut from: Option<String> = None;
                    let mut to: Option<String> = None;
                    for child in children {
                        let ctoks = tokens(child.text);
                        match ctoks.first().copied() {
                            Some("from") if ctoks.len() == 2 => from = Some(ctoks[1].to_string()),
                            Some("to") if ctoks.len() == 2 => to = Some(ctoks[1].to_string()),
                            _ => {
                                return Err(DslError::new(
                                    file,
                                    child.line,
                                    "unexpected-child",
                                    format!(
                                        "expected 'from <State>' or 'to <State>', got '{}'",
                                        child.text
                                    ),
                                ));
                            }
                        }
                    }
                    let from = from.ok_or_else(|| {
                        DslError::new(
                            file,
                            header.line,
                            "transition-missing-from",
                            format!("transition '{}' has no 'from'", toks[1]),
                        )
                    })?;
                    let to = to.ok_or_else(|| {
                        DslError::new(
                            file,
                            header.line,
                            "transition-missing-to",
                            format!("transition '{}' has no 'to'", toks[1]),
                        )
                    })?;
                    transitions.insert(
                        toks[1].to_string(),
                        TransitionDef {
                            name: toks[1].to_string(),
                            from,
                            to,
                        },
                    );
                }
                _ => {
                    return Err(DslError::new(
                        file,
                        header.line,
                        "unknown-block",
                        format!(
                            "expected 'workflow', 'state', or 'transition', got '{}'",
                            header.text
                        ),
                    ));
                }
            }
            i = j;
        }

        let name = workflow_name.ok_or_else(|| {
            DslError::new(
                file,
                1,
                "missing-workflow-header",
                "document has no 'workflow' declaration",
            )
        })?;
        let initial = initial.ok_or_else(|| {
            DslError::new(
                file,
                1,
                "missing-initial-state",
                "'workflow' declaration has no 'initial' state",
            )
        })?;
        if states.is_empty() {
            return Err(DslError::new(
                file,
                1,
                "empty-workflow",
                "workflow declares no states",
            ));
        }
        if !states.contains_key(&initial) {
            return Err(DslError::new(
                file,
                1,
                "unknown-initial-state",
                format!("initial state '{initial}' is not declared with a 'state' block"),
            ));
        }
        for t in transitions.values() {
            if !states.contains_key(&t.from) {
                return Err(DslError::new(
                    file,
                    1,
                    "transition-unknown-from",
                    format!(
                        "transition '{}' from-state '{}' is not declared",
                        t.name, t.from
                    ),
                ));
            }
            if !states.contains_key(&t.to) {
                return Err(DslError::new(
                    file,
                    1,
                    "transition-unknown-to",
                    format!(
                        "transition '{}' to-state '{}' is not declared",
                        t.name, t.to
                    ),
                ));
            }
        }

        Ok(WorkflowDsl {
            name,
            initial,
            states: states.into_keys().collect(),
            transitions: transitions.into_values().collect(),
        })
    }

    /// Deterministic re-serialization: states and transitions sorted by
    /// name, the same discipline [`crate::dsl::graph::GraphDsl`] uses.
    pub fn to_canonical(&self) -> String {
        let mut out = String::new();
        out.push_str(&format!(
            "workflow {}\n  initial {}\n\n",
            self.name, self.initial
        ));
        for state in &self.states {
            out.push_str(&format!("state {state}\n"));
        }
        out.push('\n');
        for t in &self.transitions {
            out.push_str(&format!(
                "transition {}\n  from {}\n  to {}\n\n",
                t.name, t.from, t.to
            ));
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

    const HOSPITALIZATION: &str = "\
workflow Hospitalization
  initial Admission

state Admission
state Surgery
state Recovery
state Discharged

transition admit
  from Admission
  to Surgery

transition operate
  from Surgery
  to Recovery

transition discharge
  from Recovery
  to Discharged
";

    const JOB_SEARCH: &str = "\
workflow JobSearch
  initial Applied

state Applied
state Interviewing
state Offered
state Rejected

transition advance
  from Applied
  to Interviewing

transition extend_offer
  from Interviewing
  to Offered

transition reject
  from Interviewing
  to Rejected
";

    #[test]
    fn valid_hospitalization_workflow_parses() {
        let w = WorkflowDsl::parse("hosp.workflow", HOSPITALIZATION).unwrap();
        assert_eq!(w.name, "Hospitalization");
        assert_eq!(w.initial, "Admission");
        assert_eq!(w.states.len(), 4);
        assert_eq!(w.transitions.len(), 3);
    }

    /// Test-the-abstraction: same grammar, unrelated domain — a job search
    /// state machine, no DSL change.
    #[test]
    fn valid_job_search_workflow_parses_with_the_same_grammar() {
        let w = WorkflowDsl::parse("jobsearch.workflow", JOB_SEARCH).unwrap();
        assert_eq!(w.states.len(), 4);
        assert_eq!(w.transitions.len(), 3);
    }

    #[test]
    fn unknown_initial_state_is_rejected() {
        let src = "workflow W\n  initial Nope\n\nstate Admission\n";
        let err = WorkflowDsl::parse("bad.workflow", src).unwrap_err();
        assert_eq!(err.rule, "unknown-initial-state");
    }

    #[test]
    fn transition_to_an_undeclared_state_is_rejected() {
        let src = "workflow W\n  initial A\n\nstate A\n\ntransition go\n  from A\n  to Nowhere\n";
        let err = WorkflowDsl::parse("bad.workflow", src).unwrap_err();
        assert_eq!(err.rule, "transition-unknown-to");
    }

    #[test]
    fn duplicate_state_is_rejected() {
        let src = "workflow W\n  initial A\n\nstate A\nstate A\n";
        let err = WorkflowDsl::parse("bad.workflow", src).unwrap_err();
        assert_eq!(err.rule, "duplicate-state");
    }

    #[test]
    fn duplicate_transition_is_rejected() {
        let src = "workflow W\n  initial A\n\nstate A\nstate B\n\ntransition go\n  from A\n  to B\n\ntransition go\n  from A\n  to B\n";
        let err = WorkflowDsl::parse("bad.workflow", src).unwrap_err();
        assert_eq!(err.rule, "duplicate-transition");
    }

    #[test]
    fn missing_workflow_header_is_rejected() {
        let src = "state A\n";
        let err = WorkflowDsl::parse("bad.workflow", src).unwrap_err();
        assert_eq!(err.rule, "missing-workflow-header");
    }

    #[test]
    fn second_workflow_header_is_rejected() {
        let src = "workflow A\n  initial X\n\nworkflow B\n  initial Y\n";
        let err = WorkflowDsl::parse("bad.workflow", src).unwrap_err();
        assert_eq!(err.rule, "duplicate-workflow-header");
    }

    #[test]
    fn workflow_with_no_states_is_rejected() {
        let src = "workflow W\n  initial A\n";
        let err = WorkflowDsl::parse("bad.workflow", src).unwrap_err();
        assert_eq!(err.rule, "empty-workflow");
    }

    #[test]
    fn parser_does_not_panic_on_malformed_input() {
        for src in [
            "workflow",
            "workflow W extra",
            "state",
            "transition",
            "transition go\n  from A\n",
            "workflow W\n  initial A\n  bogus X\n",
        ] {
            assert!(
                WorkflowDsl::parse("fuzz.workflow", src).is_err(),
                "expected error for {src:?}"
            );
        }
    }

    #[test]
    fn round_trips_through_canonical_serialization_with_an_identical_fingerprint() {
        let w1 = WorkflowDsl::parse("hosp.workflow", HOSPITALIZATION).unwrap();
        let canonical = w1.to_canonical();
        let w2 = WorkflowDsl::parse("hosp.canonical.workflow", &canonical).unwrap();
        assert_eq!(w1.fingerprint(), w2.fingerprint());
        assert_eq!(canonical, w2.to_canonical());
    }

    #[test]
    fn state_and_transition_declaration_order_does_not_affect_the_fingerprint() {
        let reordered = "\
workflow Hospitalization
  initial Admission

state Discharged
state Admission
state Recovery
state Surgery

transition discharge
  from Recovery
  to Discharged

transition admit
  from Admission
  to Surgery

transition operate
  from Surgery
  to Recovery
";
        let a = WorkflowDsl::parse("a.workflow", HOSPITALIZATION).unwrap();
        let b = WorkflowDsl::parse("b.workflow", reordered).unwrap();
        assert_eq!(a.fingerprint(), b.fingerprint());
    }
}

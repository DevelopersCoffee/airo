//! Four DSLs conformance — `#1225`: Graph, Workflow, View, Automation.
//!
//! Black-box, against `airo_mind_core`'s public API only, the same style as
//! `tests/type_system_conformance.rs`. Proves, per DSL, the three things the
//! issue's Scope section asks for: valid input parses and validates, invalid
//! input is rejected with a named rule (never a panic), and a document
//! round-trips through canonical serialization to an identical fingerprint.
//! It also proves the issue's own "test the abstraction" acceptance check:
//! two unrelated domains — a hospitalization and a job search — model on
//! each DSL with no construct the other domain did not also need.

use airo_mind_core::{AutomationDsl, GraphDsl, ViewDsl, WorkflowDsl};

// ---------------------------------------------------------------------------
// Graph DSL
// ---------------------------------------------------------------------------

const HOSPITAL_GRAPH: &str = "\
entity Doctor extends Person
  label Doctor
  label Clinician
  property speciality string

entity Hospital extends Organization
  property name string

relation employs
  source Hospital
  target Doctor
  cardinality many-to-many
";

const JOB_SEARCH_GRAPH: &str = "\
entity Company extends Organization
  label Company

entity Role extends Task
  property title string

relation posts
  source Company
  target Role
  cardinality one-to-many
";

#[test]
fn graph_dsl_two_unrelated_domains_model_with_no_dsl_change() {
    let hospital = GraphDsl::parse("hospital.graph", HOSPITAL_GRAPH).unwrap();
    let job_search = GraphDsl::parse("jobsearch.graph", JOB_SEARCH_GRAPH).unwrap();
    assert_eq!(hospital.entities.len(), 2);
    assert_eq!(job_search.entities.len(), 2);
}

#[test]
fn graph_dsl_invalid_input_is_rejected_with_a_named_rule_not_a_panic() {
    let err = GraphDsl::parse("bad.graph", "entity Bad extends Actor\n").unwrap_err();
    assert_eq!(err.file, "bad.graph");
    assert_eq!(err.line, 1);
    assert_eq!(err.rule, "extends-core-ontology-only");
}

#[test]
fn graph_dsl_round_trips_to_an_identical_fingerprint() {
    let original = GraphDsl::parse("hospital.graph", HOSPITAL_GRAPH).unwrap();
    let reparsed = GraphDsl::parse("canonical.graph", &original.to_canonical()).unwrap();
    assert_eq!(original.fingerprint(), reparsed.fingerprint());
}

// ---------------------------------------------------------------------------
// Workflow DSL
// ---------------------------------------------------------------------------

const HOSPITALIZATION_WORKFLOW: &str = "\
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

const JOB_SEARCH_WORKFLOW: &str = "\
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
";

#[test]
fn workflow_dsl_two_unrelated_domains_use_the_same_generic_engine() {
    let hospitalization = WorkflowDsl::parse("hosp.workflow", HOSPITALIZATION_WORKFLOW).unwrap();
    let job_search = WorkflowDsl::parse("jobsearch.workflow", JOB_SEARCH_WORKFLOW).unwrap();
    // Both are State -> Transition -> State; neither's transitions carry any
    // construct the other domain did not also need.
    assert!(!hospitalization.transitions.is_empty());
    assert!(!job_search.transitions.is_empty());
}

#[test]
fn workflow_dsl_invalid_input_is_rejected_with_a_named_rule_not_a_panic() {
    let err = WorkflowDsl::parse(
        "bad.workflow",
        "workflow W\n  initial Nope\n\nstate Admission\n",
    )
    .unwrap_err();
    assert_eq!(err.rule, "unknown-initial-state");
}

#[test]
fn workflow_dsl_round_trips_to_an_identical_fingerprint() {
    let original = WorkflowDsl::parse("hosp.workflow", HOSPITALIZATION_WORKFLOW).unwrap();
    let reparsed = WorkflowDsl::parse("canonical.workflow", &original.to_canonical()).unwrap();
    assert_eq!(original.fingerprint(), reparsed.fingerprint());
}

// ---------------------------------------------------------------------------
// View DSL
// ---------------------------------------------------------------------------

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
fn view_dsl_two_unrelated_domains_reuse_the_same_four_kinds() {
    let hospital = ViewDsl::parse("hosp.view", HOSPITAL_VIEWS).unwrap();
    let job_search = ViewDsl::parse("jobsearch.view", JOB_SEARCH_VIEWS).unwrap();
    assert_eq!(hospital.views.len(), 2);
    assert_eq!(job_search.views.len(), 2);
}

#[test]
fn view_dsl_invalid_input_is_rejected_with_a_named_rule_not_a_panic() {
    let err = ViewDsl::parse("bad.view", "view X kind bogus\n  source Y\n  field z\n").unwrap_err();
    assert_eq!(err.rule, "unknown-view-kind");
}

#[test]
fn view_dsl_round_trips_to_an_identical_fingerprint() {
    let original = ViewDsl::parse("hosp.view", HOSPITAL_VIEWS).unwrap();
    let reparsed = ViewDsl::parse("canonical.view", &original.to_canonical()).unwrap();
    assert_eq!(original.fingerprint(), reparsed.fingerprint());
}

// ---------------------------------------------------------------------------
// Automation DSL
// ---------------------------------------------------------------------------

const MEDICATION_REMINDER_AUTOMATION: &str = "\
automation NotifyOnAdmission
  trigger EntityCreated Patient
  condition status equals Admitted
  action EmitEvent medication.reminder
";

const JOB_OFFER_AUTOMATION: &str = "\
automation NotifyOnOffer
  trigger PropertyChanged Application.status
  condition status equals Offered
  action EmitEvent job.offer_received
";

#[test]
fn automation_dsl_two_unrelated_domains_reuse_trigger_condition_action() {
    let hospital = AutomationDsl::parse("hosp.automation", MEDICATION_REMINDER_AUTOMATION).unwrap();
    let job_search = AutomationDsl::parse("jobsearch.automation", JOB_OFFER_AUTOMATION).unwrap();
    // Neither automation's shape names a domain concept — "medication" and
    // "job offer" live only in the opaque subject/target strings.
    assert_eq!(hospital.automations[0].actions.len(), 1);
    assert_eq!(job_search.automations[0].actions.len(), 1);
}

#[test]
fn automation_dsl_invalid_input_is_rejected_with_a_named_rule_not_a_panic() {
    let err = AutomationDsl::parse(
        "bad.automation",
        "automation X\n  trigger EntityCreated Y\n  action Bogus z\n",
    )
    .unwrap_err();
    assert_eq!(err.rule, "unknown-action-kind");
}

#[test]
fn automation_dsl_round_trips_to_an_identical_fingerprint() {
    let original = AutomationDsl::parse("hosp.automation", MEDICATION_REMINDER_AUTOMATION).unwrap();
    let reparsed = AutomationDsl::parse("canonical.automation", &original.to_canonical()).unwrap();
    assert_eq!(original.fingerprint(), reparsed.fingerprint());
}

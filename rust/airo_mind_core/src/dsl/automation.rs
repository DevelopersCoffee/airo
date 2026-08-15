//! Automation DSL — `#1225`: `Trigger → Condition → Action`.
//!
//! Issue text, verbatim: *"not 'take medicine'."* Like
//! [`crate::dsl::workflow`], the genericity is structural: [`TriggerKind`],
//! [`ConditionOperator`], and [`ActionKind`] are small, closed, domain-free
//! vocabularies (mirroring [`crate::verb::Verb`]'s own closed-set pattern —
//! the runtime-level vocabulary a capability's free-form data rides on top
//! of). "Take medicine" is expressible as data — an `EmitEvent` action whose
//! target string happens to be `"medication.reminder"` — never as a new
//! automation construct.
//!
//! # Grammar
//!
//! ```text
//! automation NotifyOnAdmission
//!   trigger EntityCreated Patient
//!   condition status equals Admitted
//!   action EmitEvent medication.reminder
//! ```
//!
//! `trigger <TriggerKind> <subject>` — exactly one, required.
//! `condition <field> <operator> <value>` — zero or more, implicitly ANDed.
//! `action <ActionKind> <target>` — one or more, required, in declared order
//! (actions are a sequence, not a set — order is meaningful, same reasoning
//! as [`crate::dsl::view`]'s field order).
//!
//! # Conditions are sorted; actions are not
//!
//! An implicit-AND condition list is commutative — `A AND B` and `B AND A`
//! evaluate identically — so [`AutomationDef::conditions`] is sorted at
//! parse time for a stable fingerprint, the same reasoning
//! [`crate::dsl::graph::GraphDsl`] applies to a set-like label list. Actions
//! run in sequence and are **not** reordered.
//!
//! # Honestly thin
//!
//! Trigger `subject`, condition `field`/`value`, and action `target` are all
//! opaque strings here — this module does not know what a "field" is on any
//! particular entity, does not evaluate conditions, and does not execute
//! actions. That is deliberate: `5.1`'s Tier 1 scope is declarative data,
//! and the issue's own scope list for `#1225` stops at "parsed and
//! validated", not "run". Cross-device idempotency for automations (design
//! doc §10 phase 8: *"automations do not fire twice"*) is explicitly a later
//! phase, not this module's job.

use std::collections::BTreeSet;

use super::{fingerprint_of, scan_lines, tokens, DslError, DslResult};

// ---------------------------------------------------------------------------
// Closed vocabularies
// ---------------------------------------------------------------------------

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum TriggerKind {
    EntityCreated,
    EntityUpdated,
    EntityDeleted,
    PropertyChanged,
    Scheduled,
}

const ALL_TRIGGER_KINDS: &[TriggerKind] = &[
    TriggerKind::EntityCreated,
    TriggerKind::EntityUpdated,
    TriggerKind::EntityDeleted,
    TriggerKind::PropertyChanged,
    TriggerKind::Scheduled,
];

impl TriggerKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::EntityCreated => "EntityCreated",
            Self::EntityUpdated => "EntityUpdated",
            Self::EntityDeleted => "EntityDeleted",
            Self::PropertyChanged => "PropertyChanged",
            Self::Scheduled => "Scheduled",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        ALL_TRIGGER_KINDS.iter().copied().find(|k| k.as_str() == s)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum ConditionOperator {
    Equals,
    NotEquals,
    GreaterThan,
    LessThan,
    Exists,
}

const ALL_CONDITION_OPERATORS: &[ConditionOperator] = &[
    ConditionOperator::Equals,
    ConditionOperator::NotEquals,
    ConditionOperator::GreaterThan,
    ConditionOperator::LessThan,
    ConditionOperator::Exists,
];

impl ConditionOperator {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Equals => "equals",
            Self::NotEquals => "not_equals",
            Self::GreaterThan => "greater_than",
            Self::LessThan => "less_than",
            Self::Exists => "exists",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        ALL_CONDITION_OPERATORS
            .iter()
            .copied()
            .find(|o| o.as_str() == s)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum ActionKind {
    EmitEvent,
    SetProperty,
    CreateEntity,
    AddRelation,
}

const ALL_ACTION_KINDS: &[ActionKind] = &[
    ActionKind::EmitEvent,
    ActionKind::SetProperty,
    ActionKind::CreateEntity,
    ActionKind::AddRelation,
];

impl ActionKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::EmitEvent => "EmitEvent",
            Self::SetProperty => "SetProperty",
            Self::CreateEntity => "CreateEntity",
            Self::AddRelation => "AddRelation",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        ALL_ACTION_KINDS.iter().copied().find(|k| k.as_str() == s)
    }
}

// ---------------------------------------------------------------------------
// Defs
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct TriggerDef {
    pub kind: TriggerKind,
    pub subject: String,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct ConditionDef {
    pub field: String,
    pub operator: ConditionOperator,
    pub value: String,
}

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct ActionDef {
    pub kind: ActionKind,
    pub target: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AutomationDef {
    pub name: String,
    pub trigger: TriggerDef,
    /// Sorted — conditions are an implicit AND, which is commutative. See
    /// the module doc.
    pub conditions: Vec<ConditionDef>,
    /// Declaration order preserved — actions run in sequence.
    pub actions: Vec<ActionDef>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct AutomationDsl {
    pub automations: Vec<AutomationDef>,
}

impl AutomationDsl {
    pub fn parse(file: &str, source: &str) -> DslResult<AutomationDsl> {
        let lines = scan_lines(file, source)?;
        if lines.is_empty() {
            return Err(DslError::new(
                file,
                1,
                "empty-document",
                "automation DSL document has no automations",
            ));
        }

        let mut seen_names: BTreeSet<String> = BTreeSet::new();
        let mut automations = Vec::new();

        let mut i = 0usize;
        while i < lines.len() {
            let header = &lines[i];
            if header.indent != 0 {
                return Err(DslError::new(
                    file,
                    header.line,
                    "unexpected-indent",
                    "expected a top-level 'automation' declaration",
                ));
            }
            let toks = tokens(header.text);
            let mut j = i + 1;
            while j < lines.len() && lines[j].indent > 0 {
                j += 1;
            }
            let children = &lines[i + 1..j];

            if toks.first().copied() != Some("automation") {
                return Err(DslError::new(
                    file,
                    header.line,
                    "unknown-block",
                    format!("expected 'automation', got '{}'", header.text),
                ));
            }
            if toks.len() != 2 {
                return Err(DslError::new(
                    file,
                    header.line,
                    "malformed-automation-header",
                    "expected 'automation <Name>'",
                ));
            }
            let name = toks[1].to_string();
            if !seen_names.insert(name.clone()) {
                return Err(DslError::new(
                    file,
                    header.line,
                    "duplicate-automation",
                    format!("automation '{name}' is declared more than once"),
                ));
            }

            let mut trigger: Option<TriggerDef> = None;
            let mut conditions: Vec<ConditionDef> = Vec::new();
            let mut actions: Vec<ActionDef> = Vec::new();

            for child in children {
                let ctoks = tokens(child.text);
                match ctoks.first().copied() {
                    Some("trigger") if ctoks.len() == 3 => {
                        if trigger.is_some() {
                            return Err(DslError::new(
                                file,
                                child.line,
                                "automation-duplicate-trigger",
                                format!("automation '{name}' declares more than one 'trigger'"),
                            ));
                        }
                        let kind = TriggerKind::parse(ctoks[1]).ok_or_else(|| {
                            DslError::new(
                                file,
                                child.line,
                                "unknown-trigger-kind",
                                format!("'{}' is not a known trigger kind", ctoks[1]),
                            )
                        })?;
                        trigger = Some(TriggerDef {
                            kind,
                            subject: ctoks[2].to_string(),
                        });
                    }
                    Some("condition") if ctoks.len() == 4 => {
                        let operator = ConditionOperator::parse(ctoks[2]).ok_or_else(|| {
                            DslError::new(
                                file,
                                child.line,
                                "unknown-condition-operator",
                                format!("'{}' is not a known condition operator", ctoks[2]),
                            )
                        })?;
                        conditions.push(ConditionDef {
                            field: ctoks[1].to_string(),
                            operator,
                            value: ctoks[3].to_string(),
                        });
                    }
                    Some("action") if ctoks.len() == 3 => {
                        let kind = ActionKind::parse(ctoks[1]).ok_or_else(|| {
                            DslError::new(
                                file,
                                child.line,
                                "unknown-action-kind",
                                format!("'{}' is not a known action kind", ctoks[1]),
                            )
                        })?;
                        actions.push(ActionDef {
                            kind,
                            target: ctoks[2].to_string(),
                        });
                    }
                    _ => {
                        return Err(DslError::new(
                            file,
                            child.line,
                            "unexpected-child",
                            format!(
                                "expected 'trigger <Kind> <subject>', 'condition <field> <op> <value>', or 'action <Kind> <target>', got '{}'",
                                child.text
                            ),
                        ));
                    }
                }
            }

            let trigger = trigger.ok_or_else(|| {
                DslError::new(
                    file,
                    header.line,
                    "automation-missing-trigger",
                    format!("automation '{name}' has no 'trigger'"),
                )
            })?;
            if actions.is_empty() {
                return Err(DslError::new(
                    file,
                    header.line,
                    "automation-missing-action",
                    format!("automation '{name}' declares no actions"),
                ));
            }
            conditions.sort();

            automations.push(AutomationDef {
                name,
                trigger,
                conditions,
                actions,
            });
            i = j;
        }

        automations.sort_by(|a, b| a.name.cmp(&b.name));
        Ok(AutomationDsl { automations })
    }

    /// Automations sorted by name; each automation's `condition` list
    /// sorted (commutative AND); `action` list kept in declaration order
    /// (a sequence) — see the module doc.
    pub fn to_canonical(&self) -> String {
        let mut out = String::new();
        for a in &self.automations {
            out.push_str(&format!("automation {}\n", a.name));
            out.push_str(&format!(
                "  trigger {} {}\n",
                a.trigger.kind.as_str(),
                a.trigger.subject
            ));
            for c in &a.conditions {
                out.push_str(&format!(
                    "  condition {} {} {}\n",
                    c.field,
                    c.operator.as_str(),
                    c.value
                ));
            }
            for act in &a.actions {
                out.push_str(&format!("  action {} {}\n", act.kind.as_str(), act.target));
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

    const MEDICATION_REMINDER: &str = "\
automation NotifyOnAdmission
  trigger EntityCreated Patient
  condition status equals Admitted
  action EmitEvent medication.reminder
";

    const JOB_SEARCH_AUTOMATION: &str = "\
automation NotifyOnOffer
  trigger PropertyChanged Application.status
  condition status equals Offered
  action EmitEvent job.offer_received
  action SetProperty celebrated=true
";

    #[test]
    fn valid_medication_reminder_automation_parses() {
        let a = AutomationDsl::parse("hosp.automation", MEDICATION_REMINDER).unwrap();
        assert_eq!(a.automations.len(), 1);
        assert_eq!(a.automations[0].trigger.kind, TriggerKind::EntityCreated);
        assert_eq!(a.automations[0].conditions.len(), 1);
        assert_eq!(a.automations[0].actions.len(), 1);
    }

    /// Test-the-abstraction: a job search automation, same grammar, and the
    /// "not 'take medicine'" principle holds for both — the specific action
    /// name lives entirely in the `target` string.
    #[test]
    fn valid_job_search_automation_parses_with_the_same_grammar() {
        let a = AutomationDsl::parse("jobsearch.automation", JOB_SEARCH_AUTOMATION).unwrap();
        assert_eq!(a.automations[0].actions.len(), 2);
    }

    #[test]
    fn missing_trigger_is_rejected() {
        let src = "automation X\n  action EmitEvent y\n";
        let err = AutomationDsl::parse("bad.automation", src).unwrap_err();
        assert_eq!(err.rule, "automation-missing-trigger");
    }

    #[test]
    fn missing_action_is_rejected() {
        let src = "automation X\n  trigger EntityCreated Y\n";
        let err = AutomationDsl::parse("bad.automation", src).unwrap_err();
        assert_eq!(err.rule, "automation-missing-action");
    }

    #[test]
    fn unknown_trigger_kind_is_rejected() {
        let src = "automation X\n  trigger Bogus Y\n  action EmitEvent z\n";
        let err = AutomationDsl::parse("bad.automation", src).unwrap_err();
        assert_eq!(err.rule, "unknown-trigger-kind");
    }

    #[test]
    fn unknown_condition_operator_is_rejected() {
        let src = "automation X\n  trigger EntityCreated Y\n  condition f bogus v\n  action EmitEvent z\n";
        let err = AutomationDsl::parse("bad.automation", src).unwrap_err();
        assert_eq!(err.rule, "unknown-condition-operator");
    }

    #[test]
    fn unknown_action_kind_is_rejected() {
        let src = "automation X\n  trigger EntityCreated Y\n  action Bogus z\n";
        let err = AutomationDsl::parse("bad.automation", src).unwrap_err();
        assert_eq!(err.rule, "unknown-action-kind");
    }

    #[test]
    fn duplicate_automation_name_is_rejected() {
        let src = "automation X\n  trigger EntityCreated Y\n  action EmitEvent z\n\nautomation X\n  trigger EntityCreated Y\n  action EmitEvent z\n";
        let err = AutomationDsl::parse("bad.automation", src).unwrap_err();
        assert_eq!(err.rule, "duplicate-automation");
    }

    #[test]
    fn duplicate_trigger_is_rejected() {
        let src = "automation X\n  trigger EntityCreated Y\n  trigger Scheduled Z\n  action EmitEvent z\n";
        let err = AutomationDsl::parse("bad.automation", src).unwrap_err();
        assert_eq!(err.rule, "automation-duplicate-trigger");
    }

    #[test]
    fn parser_does_not_panic_on_malformed_input() {
        for src in [
            "automation",
            "automation X Y",
            "automation X\n  trigger EntityCreated\n",
            "automation X\n  condition f equals\n",
            "automation X\n  action Bogus\n",
        ] {
            assert!(
                AutomationDsl::parse("fuzz.automation", src).is_err(),
                "expected error for {src:?}"
            );
        }
    }

    #[test]
    fn round_trips_through_canonical_serialization_with_an_identical_fingerprint() {
        let a1 = AutomationDsl::parse("hosp.automation", MEDICATION_REMINDER).unwrap();
        let canonical = a1.to_canonical();
        let a2 = AutomationDsl::parse("hosp.canonical.automation", &canonical).unwrap();
        assert_eq!(a1.fingerprint(), a2.fingerprint());
        assert_eq!(canonical, a2.to_canonical());
    }

    #[test]
    fn condition_order_does_not_affect_the_fingerprint_but_action_order_does() {
        let a = "automation X\n  trigger EntityCreated Y\n  condition f1 equals v1\n  condition f2 equals v2\n  action EmitEvent one\n  action EmitEvent two\n";
        let b_conditions_swapped = "automation X\n  trigger EntityCreated Y\n  condition f2 equals v2\n  condition f1 equals v1\n  action EmitEvent one\n  action EmitEvent two\n";
        let b_actions_swapped = "automation X\n  trigger EntityCreated Y\n  condition f1 equals v1\n  condition f2 equals v2\n  action EmitEvent two\n  action EmitEvent one\n";

        let da = AutomationDsl::parse("a.automation", a).unwrap();
        let db_cond = AutomationDsl::parse("b.automation", b_conditions_swapped).unwrap();
        let db_act = AutomationDsl::parse("c.automation", b_actions_swapped).unwrap();

        assert_eq!(da.fingerprint(), db_cond.fingerprint());
        assert_ne!(da.fingerprint(), db_act.fingerprint());
    }
}

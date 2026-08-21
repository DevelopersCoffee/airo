//! Prompt Quality Gate — runs **before** the model.
//!
//! Prevents predictable inference when the prompt artifact is defective.
//! Runtime/reasoning failures (PM-*, AIRO-R*) are classified after the model.

use crate::ids::RecoveryAction;
use crate::prompt::{
    estimate_tokens, is_ambiguous, looks_like_dangling_reference, looks_like_injection,
    CompiledPrompt, InstructionIssueKind, InstructionSet, PromptDefinition,
};
use crate::prompt_defect::PromptDefect;
use crate::task::{CompiledContext, TaskIr, TrustClass};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PromptGateDecision {
    /// Prompt is usable. Warnings may still be attached.
    Allow,
    /// Ambiguous / missing criteria / dangling reference. Do not call the model.
    AskUser,
    /// Context overflow, noise, or budget miss. Rebuild then re-inspect.
    RebuildContext,
    /// Injection, policy, or unsatisfiable instructions. Do not call the model.
    Abort,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PromptFindingSeverity {
    Warning,
    Blocking,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PromptFinding {
    pub defect: PromptDefect,
    pub severity: PromptFindingSeverity,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ContextHealthStatus {
    Healthy,
    Degraded,
    Invalid,
}

/// Context compiler report. Not a retrieval score and not a proof of correctness.
#[derive(Clone, Debug, PartialEq)]
pub struct ContextHealthReport {
    pub token_budget: u32,
    pub estimated_tokens: u32,
    pub relevance: f32,
    pub redundancy: f32,
    pub stale_content: f32,
    pub instruction_conflicts: u32,
    pub missing_dependencies: u32,
    pub status: ContextHealthStatus,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct PromptBudget {
    pub model_context_limit: u32,
    pub input_tokens: u32,
    pub context_tokens: u32,
    pub memory_tokens: u32,
    pub retrieval_tokens: u32,
    pub instruction_tokens: u32,
    pub output_budget: u32,
}

impl PromptBudget {
    pub fn total_reserved(&self) -> u32 {
        self.input_tokens
            .saturating_add(self.context_tokens)
            .saturating_add(self.memory_tokens)
            .saturating_add(self.retrieval_tokens)
            .saturating_add(self.instruction_tokens)
            .saturating_add(self.output_budget.max(1))
    }

    pub fn fits(&self) -> bool {
        self.total_reserved() <= self.model_context_limit
    }
}

/// Whether the active model adapter can reuse a static prompt prefix.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum PrefixCacheCapability {
    #[default]
    Unsupported,
    Supported,
}

pub struct PromptInspection<'a> {
    pub task: &'a TaskIr,
    pub instructions: &'a InstructionSet,
    pub prompt: &'a CompiledPrompt,
    pub context: Option<&'a CompiledContext>,
    pub budget: PromptBudget,
    pub definition: Option<&'a PromptDefinition>,
    pub prefix_cache: PrefixCacheCapability,
    pub history_empty: bool,
    pub requires_structured_output: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct PromptGateReport {
    pub decision: PromptGateDecision,
    pub findings: Vec<PromptFinding>,
    pub health: ContextHealthReport,
    pub recovery: Option<RecoveryAction>,
}

impl PromptGateReport {
    pub fn blocks_inference(&self) -> bool {
        !matches!(self.decision, PromptGateDecision::Allow)
    }
}

pub struct PromptQualityGate;

impl PromptQualityGate {
    pub fn inspect(input: PromptInspection<'_>) -> PromptGateReport {
        let mut findings = Vec::new();
        let instruction_issues = input
            .instructions
            .analyze(!input.task.completion_criteria.is_empty());

        for issue in &instruction_issues {
            let severity = match issue.kind {
                InstructionIssueKind::Duplicate | InstructionIssueKind::Conflict => {
                    PromptFindingSeverity::Warning
                }
                InstructionIssueKind::Ambiguous
                | InstructionIssueKind::Missing
                | InstructionIssueKind::Unsatisfiable => PromptFindingSeverity::Blocking,
            };
            push_unique(&mut findings, issue.defect, severity);
        }

        if looks_like_injection(&input.prompt.user) {
            push_unique(
                &mut findings,
                PromptDefect::Input002PromptInjection,
                PromptFindingSeverity::Blocking,
            );
        }

        if input.context.is_some_and(|c| {
            c.items
                .iter()
                .any(|item| item.trust == TrustClass::Untrusted && looks_like_injection(&item.id))
        }) {
            push_unique(
                &mut findings,
                PromptDefect::Input002PromptInjection,
                PromptFindingSeverity::Warning,
            );
        }

        if !input.prompt.has_role_separation() && !input.prompt.tools.is_empty() {
            push_unique(
                &mut findings,
                PromptDefect::Struct001RoleSeparation,
                PromptFindingSeverity::Blocking,
            );
        }

        if !input.prompt.formatting_ok() {
            push_unique(
                &mut findings,
                PromptDefect::Struct003FormattingError,
                PromptFindingSeverity::Blocking,
            );
        }

        if input.requires_structured_output && input.prompt.output_contract.trim().is_empty() {
            push_unique(
                &mut findings,
                PromptDefect::Struct004UndefinedOutputFormat,
                PromptFindingSeverity::Blocking,
            );
        }

        if overloaded(&input.prompt.user) {
            push_unique(
                &mut findings,
                PromptDefect::Struct005OverloadedPrompt,
                PromptFindingSeverity::Warning,
            );
        }

        if input.history_empty && looks_like_dangling_reference(&input.prompt.user) {
            push_unique(
                &mut findings,
                PromptDefect::Context004Misreferencing,
                PromptFindingSeverity::Blocking,
            );
        }

        if input.budget.output_budget == 0 {
            push_unique(
                &mut findings,
                PromptDefect::Perf004UnboundedOutput,
                PromptFindingSeverity::Warning,
            );
        }

        if !input.budget.fits() {
            push_unique(
                &mut findings,
                PromptDefect::Perf001ExcessiveLength,
                PromptFindingSeverity::Blocking,
            );
            push_unique(
                &mut findings,
                PromptDefect::Context001Overflow,
                PromptFindingSeverity::Blocking,
            );
        }

        if input.prefix_cache == PrefixCacheCapability::Unsupported
            && estimate_tokens(&input.prompt.cacheable_prefix()) > 256
        {
            push_unique(
                &mut findings,
                PromptDefect::Perf003NoPrefixCache,
                PromptFindingSeverity::Warning,
            );
        }

        if let Some(def) = input.definition {
            if !def.is_registered() {
                push_unique(
                    &mut findings,
                    PromptDefect::Eng001HardCodedPrompt,
                    PromptFindingSeverity::Warning,
                );
            }
            if !def.has_eval_suite {
                push_unique(
                    &mut findings,
                    PromptDefect::Eng002InsufficientTesting,
                    PromptFindingSeverity::Warning,
                );
            }
            if !def.documented {
                push_unique(
                    &mut findings,
                    PromptDefect::Eng003PoorDocumentation,
                    PromptFindingSeverity::Warning,
                );
            }
            if !def.has_security_policy && !input.prompt.tools.is_empty() {
                push_unique(
                    &mut findings,
                    PromptDefect::Eng004SecurityReviewGap,
                    PromptFindingSeverity::Warning,
                );
            }
            if input.requires_structured_output
                && !def.output_schema.is_empty()
                && !input.prompt.output_contract.is_empty()
                && def.output_schema != input.prompt.output_contract
            {
                push_unique(
                    &mut findings,
                    PromptDefect::Eng005IntegrationMismatch,
                    PromptFindingSeverity::Blocking,
                );
            }
        } else {
            push_unique(
                &mut findings,
                PromptDefect::Eng001HardCodedPrompt,
                PromptFindingSeverity::Warning,
            );
        }

        let missing_dependencies =
            u32::from(input.history_empty && looks_like_dangling_reference(&input.prompt.user));
        let health = context_health(
            input.context,
            &input.budget,
            input.prompt,
            missing_dependencies,
        );

        match health.status {
            ContextHealthStatus::Invalid if !input.budget.fits() => {
                push_unique(
                    &mut findings,
                    PromptDefect::Context001Overflow,
                    PromptFindingSeverity::Blocking,
                );
            }
            ContextHealthStatus::Invalid if missing_dependencies > 0 => {
                push_unique(
                    &mut findings,
                    PromptDefect::Context002MissingContext,
                    PromptFindingSeverity::Blocking,
                );
            }
            ContextHealthStatus::Degraded => {
                if health.relevance < 0.4 {
                    push_unique(
                        &mut findings,
                        PromptDefect::Context003NoisyContext,
                        PromptFindingSeverity::Warning,
                    );
                }
            }
            _ => {}
        }

        if is_ambiguous(&input.prompt.user) && input.task.completion_criteria.is_empty() {
            push_unique(
                &mut findings,
                PromptDefect::Spec001AmbiguousInstruction,
                PromptFindingSeverity::Blocking,
            );
            push_unique(
                &mut findings,
                PromptDefect::Spec002UnderspecifiedConstraints,
                PromptFindingSeverity::Blocking,
            );
        }

        let decision = decide(&findings, &health);
        let recovery = match decision {
            PromptGateDecision::Allow => None,
            PromptGateDecision::AskUser => Some(RecoveryAction::AskUser),
            PromptGateDecision::RebuildContext => Some(RecoveryAction::RebuildContext),
            PromptGateDecision::Abort => Some(RecoveryAction::Abort),
        };

        PromptGateReport {
            decision,
            findings,
            health,
            recovery,
        }
    }
}

pub fn context_health(
    context: Option<&CompiledContext>,
    budget: &PromptBudget,
    prompt: &CompiledPrompt,
    missing_dependencies: u32,
) -> ContextHealthReport {
    let estimated = prompt.estimated_tokens().max(budget.total_reserved());
    let (relevance, redundancy, stale, conflicts) = if let Some(compiled) = context {
        let n = compiled.items.len().max(1) as f32;
        let relevance = compiled.items.iter().map(|i| i.relevance).sum::<f32>() / n;
        let redundancy = compiled.items.iter().filter(|i| i.relevance < 0.35).count() as f32 / n;
        let total = (compiled.items.len() + compiled.dropped_stale).max(1) as f32;
        let stale = compiled.dropped_stale as f32 / total;
        (
            relevance,
            redundancy,
            stale,
            compiled.conflicts_resolved as u32,
        )
    } else {
        (1.0, 0.0, 0.0, 0)
    };

    let status = if budget.total_reserved() > budget.model_context_limit.saturating_mul(2) {
        ContextHealthStatus::Invalid
    } else if !budget.fits() {
        ContextHealthStatus::Degraded
    } else if missing_dependencies > 0 && context.map(|c| c.items.is_empty()).unwrap_or(true) {
        ContextHealthStatus::Invalid
    } else if redundancy > 0.25 || stale > 0.2 || conflicts > 0 {
        ContextHealthStatus::Degraded
    } else {
        ContextHealthStatus::Healthy
    };

    ContextHealthReport {
        token_budget: budget.model_context_limit,
        estimated_tokens: estimated,
        relevance,
        redundancy,
        stale_content: stale,
        instruction_conflicts: conflicts,
        missing_dependencies,
        status,
    }
}

fn decide(findings: &[PromptFinding], health: &ContextHealthReport) -> PromptGateDecision {
    let blocking: Vec<PromptDefect> = findings
        .iter()
        .filter(|f| f.severity == PromptFindingSeverity::Blocking)
        .map(|f| f.defect)
        .collect();
    if blocking.iter().any(|d| {
        matches!(
            d,
            PromptDefect::Input002PromptInjection
                | PromptDefect::Input003PolicyViolatingInput
                | PromptDefect::Eng005IntegrationMismatch
        )
    }) || findings.iter().any(|f| {
        f.defect == PromptDefect::Spec003ConflictingInstructions
            && f.severity == PromptFindingSeverity::Blocking
    }) {
        return PromptGateDecision::Abort;
    }
    if blocking.iter().any(|d| {
        matches!(
            d,
            PromptDefect::Spec001AmbiguousInstruction
                | PromptDefect::Spec002UnderspecifiedConstraints
                | PromptDefect::Spec004IntentMisalignment
                | PromptDefect::Context002MissingContext
                | PromptDefect::Context004Misreferencing
                | PromptDefect::Struct001RoleSeparation
                | PromptDefect::Struct003FormattingError
                | PromptDefect::Struct004UndefinedOutputFormat
        )
    }) {
        return PromptGateDecision::AskUser;
    }
    if blocking.iter().any(|d| {
        matches!(
            d,
            PromptDefect::Context001Overflow | PromptDefect::Perf001ExcessiveLength
        )
    }) || health.status == ContextHealthStatus::Degraded
        && blocking
            .iter()
            .any(|d| matches!(d, PromptDefect::Context001Overflow))
    {
        return PromptGateDecision::RebuildContext;
    }
    PromptGateDecision::Allow
}

fn overloaded(user: &str) -> bool {
    let t = user.to_ascii_lowercase();
    let verbs = [
        "translate",
        "optimize",
        "summarize",
        "refactor",
        "document",
        "test",
    ];
    verbs.iter().filter(|v| t.contains(*v)).count() >= 3
}

fn push_unique(
    findings: &mut Vec<PromptFinding>,
    defect: PromptDefect,
    severity: PromptFindingSeverity,
) {
    if let Some(existing) = findings.iter_mut().find(|f| f.defect == defect) {
        if severity == PromptFindingSeverity::Blocking {
            existing.severity = PromptFindingSeverity::Blocking;
        }
        return;
    }
    findings.push(PromptFinding { defect, severity });
}

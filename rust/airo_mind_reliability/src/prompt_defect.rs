//! Prompt-defect taxonomy (Tian et al., 2025).
//!
//! These IDs classify defects **in the prompt artifact** before inference.
//! They are a different failure domain from [`crate::ids::FailureMode`] (PM-01
//! ..PM-16) and [`crate::ids::RuntimeFailure`] (AIRO-Rxx). Do not fold them
//! together.

/// Which side of the reliability split a diagnostic belongs to.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum FailureDomain {
    /// Defect in the compiled prompt / task IR. Evaluated before the model.
    PromptDefect,
    /// Failure after the model ran, or in the runtime around it.
    RuntimeReasoning,
}

/// Six paper dimensions. Subtypes are [`PromptDefect`].
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum PromptDefectCategory {
    Specification,
    Input,
    Structure,
    Context,
    Performance,
    Engineering,
}

impl PromptDefectCategory {
    pub fn id(self) -> &'static str {
        match self {
            Self::Specification => "PD-SPEC",
            Self::Input => "PD-INPUT",
            Self::Structure => "PD-STRUCT",
            Self::Context => "PD-CONTEXT",
            Self::Performance => "PD-PERF",
            Self::Engineering => "PD-ENG",
        }
    }
}

/// Stable prompt-defect IDs. Classification only — never prompt text.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum PromptDefect {
    Spec001AmbiguousInstruction,
    Spec002UnderspecifiedConstraints,
    Spec003ConflictingInstructions,
    Spec004IntentMisalignment,
    Input001MisleadingContent,
    Input002PromptInjection,
    Input003PolicyViolatingInput,
    Input004CrossModalMisalignment,
    Struct001RoleSeparation,
    Struct002PoorOrganization,
    Struct003FormattingError,
    Struct004UndefinedOutputFormat,
    Struct005OverloadedPrompt,
    Context001Overflow,
    Context002MissingContext,
    Context003NoisyContext,
    Context004Misreferencing,
    Context005ForgottenInstructions,
    Perf001ExcessiveLength,
    Perf002InefficientFewShot,
    Perf003NoPrefixCache,
    Perf004UnboundedOutput,
    Eng001HardCodedPrompt,
    Eng002InsufficientTesting,
    Eng003PoorDocumentation,
    Eng004SecurityReviewGap,
    Eng005IntegrationMismatch,
}

impl PromptDefect {
    pub const ALL: [PromptDefect; 27] = [
        Self::Spec001AmbiguousInstruction,
        Self::Spec002UnderspecifiedConstraints,
        Self::Spec003ConflictingInstructions,
        Self::Spec004IntentMisalignment,
        Self::Input001MisleadingContent,
        Self::Input002PromptInjection,
        Self::Input003PolicyViolatingInput,
        Self::Input004CrossModalMisalignment,
        Self::Struct001RoleSeparation,
        Self::Struct002PoorOrganization,
        Self::Struct003FormattingError,
        Self::Struct004UndefinedOutputFormat,
        Self::Struct005OverloadedPrompt,
        Self::Context001Overflow,
        Self::Context002MissingContext,
        Self::Context003NoisyContext,
        Self::Context004Misreferencing,
        Self::Context005ForgottenInstructions,
        Self::Perf001ExcessiveLength,
        Self::Perf002InefficientFewShot,
        Self::Perf003NoPrefixCache,
        Self::Perf004UnboundedOutput,
        Self::Eng001HardCodedPrompt,
        Self::Eng002InsufficientTesting,
        Self::Eng003PoorDocumentation,
        Self::Eng004SecurityReviewGap,
        Self::Eng005IntegrationMismatch,
    ];

    pub fn id(self) -> &'static str {
        match self {
            Self::Spec001AmbiguousInstruction => "PD-SPEC-001",
            Self::Spec002UnderspecifiedConstraints => "PD-SPEC-002",
            Self::Spec003ConflictingInstructions => "PD-SPEC-003",
            Self::Spec004IntentMisalignment => "PD-SPEC-004",
            Self::Input001MisleadingContent => "PD-INPUT-001",
            Self::Input002PromptInjection => "PD-INPUT-002",
            Self::Input003PolicyViolatingInput => "PD-INPUT-003",
            Self::Input004CrossModalMisalignment => "PD-INPUT-004",
            Self::Struct001RoleSeparation => "PD-STRUCT-001",
            Self::Struct002PoorOrganization => "PD-STRUCT-002",
            Self::Struct003FormattingError => "PD-STRUCT-003",
            Self::Struct004UndefinedOutputFormat => "PD-STRUCT-004",
            Self::Struct005OverloadedPrompt => "PD-STRUCT-005",
            Self::Context001Overflow => "PD-CONTEXT-001",
            Self::Context002MissingContext => "PD-CONTEXT-002",
            Self::Context003NoisyContext => "PD-CONTEXT-003",
            Self::Context004Misreferencing => "PD-CONTEXT-004",
            Self::Context005ForgottenInstructions => "PD-CONTEXT-005",
            Self::Perf001ExcessiveLength => "PD-PERF-001",
            Self::Perf002InefficientFewShot => "PD-PERF-002",
            Self::Perf003NoPrefixCache => "PD-PERF-003",
            Self::Perf004UnboundedOutput => "PD-PERF-004",
            Self::Eng001HardCodedPrompt => "PD-ENG-001",
            Self::Eng002InsufficientTesting => "PD-ENG-002",
            Self::Eng003PoorDocumentation => "PD-ENG-003",
            Self::Eng004SecurityReviewGap => "PD-ENG-004",
            Self::Eng005IntegrationMismatch => "PD-ENG-005",
        }
    }

    pub fn category(self) -> PromptDefectCategory {
        match self {
            Self::Spec001AmbiguousInstruction
            | Self::Spec002UnderspecifiedConstraints
            | Self::Spec003ConflictingInstructions
            | Self::Spec004IntentMisalignment => PromptDefectCategory::Specification,
            Self::Input001MisleadingContent
            | Self::Input002PromptInjection
            | Self::Input003PolicyViolatingInput
            | Self::Input004CrossModalMisalignment => PromptDefectCategory::Input,
            Self::Struct001RoleSeparation
            | Self::Struct002PoorOrganization
            | Self::Struct003FormattingError
            | Self::Struct004UndefinedOutputFormat
            | Self::Struct005OverloadedPrompt => PromptDefectCategory::Structure,
            Self::Context001Overflow
            | Self::Context002MissingContext
            | Self::Context003NoisyContext
            | Self::Context004Misreferencing
            | Self::Context005ForgottenInstructions => PromptDefectCategory::Context,
            Self::Perf001ExcessiveLength
            | Self::Perf002InefficientFewShot
            | Self::Perf003NoPrefixCache
            | Self::Perf004UnboundedOutput => PromptDefectCategory::Performance,
            Self::Eng001HardCodedPrompt
            | Self::Eng002InsufficientTesting
            | Self::Eng003PoorDocumentation
            | Self::Eng004SecurityReviewGap
            | Self::Eng005IntegrationMismatch => PromptDefectCategory::Engineering,
        }
    }

    pub fn domain(self) -> FailureDomain {
        FailureDomain::PromptDefect
    }

    pub fn from_id(id: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|defect| defect.id() == id)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ids::{FailureMode, RuntimeFailure};

    #[test]
    fn pd_ids_are_stable_and_do_not_collide_with_pm_or_airo_r() {
        for defect in PromptDefect::ALL {
            assert!(defect.id().starts_with("PD-"));
            assert_eq!(PromptDefect::from_id(defect.id()), Some(defect));
            assert!(FailureMode::from_id(defect.id()).is_none());
            assert!(RuntimeFailure::from_id(defect.id()).is_none());
        }
        assert!(PromptDefect::from_id("PM-01").is_none());
        assert!(PromptDefect::from_id("AIRO-R04").is_none());
    }
}

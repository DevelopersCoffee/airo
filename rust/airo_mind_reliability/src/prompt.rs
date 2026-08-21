//! Machine-readable prompt IR.
//!
//! Prompts are compiled artifacts, not concatenated strings. Model adapters
//! turn [`CompiledPrompt`] into Qwen/Gemma/Llama wrappers. Prefix caching is
//! an **adapter capability**, not a hard requirement.

use crate::prompt_defect::PromptDefect;

/// Layered instructions, highest authority first.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum InstructionLayer {
    System,
    Task,
    User,
    Context,
    Output,
}

impl InstructionLayer {
    pub fn rank(self) -> u8 {
        match self {
            Self::System => 0,
            Self::Task => 1,
            Self::User => 2,
            Self::Context => 3,
            Self::Output => 4,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Instruction {
    pub layer: InstructionLayer,
    pub text: String,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct InstructionSet {
    pub items: Vec<Instruction>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InstructionIssueKind {
    Conflict,
    Missing,
    Ambiguous,
    Duplicate,
    Unsatisfiable,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct InstructionIssue {
    pub kind: InstructionIssueKind,
    pub defect: PromptDefect,
    pub left: usize,
    pub right: usize,
}

/// Versioned prompt definition. Replaces hard-coded string literals.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PromptDefinition {
    pub id: String,
    pub version: String,
    pub task_type: String,
    pub output_schema: String,
    pub has_eval_suite: bool,
    pub has_security_policy: bool,
    pub documented: bool,
}

impl PromptDefinition {
    pub fn is_registered(&self) -> bool {
        !self.id.is_empty() && !self.version.is_empty()
    }
}

/// Structured prompt ready for a model adapter. Not a chat string.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct CompiledPrompt {
    pub system: Vec<String>,
    pub developer: Vec<String>,
    pub context: Vec<String>,
    pub memory: Vec<String>,
    pub user: String,
    pub tools: Vec<String>,
    pub output_contract: String,
}

impl CompiledPrompt {
    pub fn has_role_separation(&self) -> bool {
        !self.system.is_empty() && !self.user.trim().is_empty()
    }

    pub fn formatting_ok(&self) -> bool {
        self.system
            .iter()
            .chain(self.developer.iter())
            .chain(self.context.iter())
            .chain(self.memory.iter())
            .chain(std::iter::once(&self.user))
            .chain(std::iter::once(&self.output_contract))
            .all(|block| balanced_fences(block))
    }

    /// Stable prefix for backends that support KV/prefix cache.
    pub fn cacheable_prefix(&self) -> String {
        let mut parts = Vec::new();
        parts.extend(self.system.iter().cloned());
        parts.extend(self.developer.iter().cloned());
        if !self.tools.is_empty() {
            parts.push(self.tools.join("\n"));
        }
        if !self.output_contract.is_empty() {
            parts.push(self.output_contract.clone());
        }
        parts.join("\n")
    }

    pub fn estimated_tokens(&self) -> u32 {
        estimate_tokens(&self.cacheable_prefix())
            + estimate_tokens(&self.context.join("\n"))
            + estimate_tokens(&self.memory.join("\n"))
            + estimate_tokens(&self.user)
    }
}

pub fn estimate_tokens(text: &str) -> u32 {
    ((text.len() as u32) + 3) / 4
}

fn balanced_fences(text: &str) -> bool {
    let fences = text.matches("```").count();
    fences % 2 == 0
}

impl InstructionSet {
    pub fn analyze(&self, has_acceptance_criteria: bool) -> Vec<InstructionIssue> {
        let mut issues = Vec::new();
        self.collect_duplicates(&mut issues);
        self.collect_polarity_issues(&mut issues);
        if self.user_text().is_empty() {
            issues.push(InstructionIssue {
                kind: InstructionIssueKind::Missing,
                defect: PromptDefect::Spec002UnderspecifiedConstraints,
                left: 0,
                right: 0,
            });
        }
        if is_ambiguous(self.user_text()) {
            issues.push(InstructionIssue {
                kind: InstructionIssueKind::Ambiguous,
                defect: PromptDefect::Spec001AmbiguousInstruction,
                left: 0,
                right: 0,
            });
        }
        if !has_acceptance_criteria && needs_criteria(self.user_text()) {
            issues.push(InstructionIssue {
                kind: InstructionIssueKind::Missing,
                defect: PromptDefect::Spec002UnderspecifiedConstraints,
                left: 0,
                right: 0,
            });
        }
        issues
    }

    fn user_text(&self) -> &str {
        self.items
            .iter()
            .find(|i| i.layer == InstructionLayer::User)
            .map(|i| i.text.as_str())
            .unwrap_or("")
    }

    fn collect_duplicates(&self, issues: &mut Vec<InstructionIssue>) {
        for i in 0..self.items.len() {
            for j in (i + 1)..self.items.len() {
                if normalize(&self.items[i].text) == normalize(&self.items[j].text)
                    && !self.items[i].text.trim().is_empty()
                {
                    issues.push(InstructionIssue {
                        kind: InstructionIssueKind::Duplicate,
                        defect: PromptDefect::Spec003ConflictingInstructions,
                        left: i,
                        right: j,
                    });
                }
            }
        }
    }

    fn collect_polarity_issues(&self, issues: &mut Vec<InstructionIssue>) {
        collect_axis(self, issues, brevity_polarity);
        collect_axis(self, issues, format_polarity);
    }
}

fn collect_axis(
    set: &InstructionSet,
    issues: &mut Vec<InstructionIssue>,
    polarity: fn(&str) -> Option<bool>,
) {
    let mut seen: Vec<(usize, bool, InstructionLayer)> = Vec::new();
    for (idx, item) in set.items.iter().enumerate() {
        if let Some(pole) = polarity(&item.text) {
            for (other_idx, other_pole, other_layer) in &seen {
                if pole != *other_pole {
                    let same_layer = item.layer == *other_layer;
                    issues.push(InstructionIssue {
                        kind: if same_layer {
                            InstructionIssueKind::Unsatisfiable
                        } else {
                            InstructionIssueKind::Conflict
                        },
                        defect: PromptDefect::Spec003ConflictingInstructions,
                        left: *other_idx,
                        right: idx,
                    });
                }
            }
            seen.push((idx, pole, item.layer));
        }
    }
}

fn normalize(text: &str) -> String {
    text.chars()
        .filter(|c| c.is_ascii_alphanumeric() || c.is_ascii_whitespace())
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

fn brevity_polarity(text: &str) -> Option<bool> {
    let t = text.to_ascii_lowercase();
    let brief = t.contains("be brief")
        || t.contains("concise")
        || t.contains("one sentence")
        || t.contains("short answer");
    let detailed = t.contains("extensive detail")
        || t.contains("be detailed")
        || t.contains("comprehensive")
        || t.contains("as much detail");
    match (brief, detailed) {
        (true, false) => Some(true),
        (false, true) => Some(false),
        _ => None,
    }
}

fn format_polarity(text: &str) -> Option<bool> {
    let t = text.to_ascii_lowercase();
    let json =
        t.contains("json only") || t.contains("respond in json") || t.contains("output json");
    let markdown = t.contains("markdown only")
        || t.contains("respond in markdown")
        || t.contains("output markdown");
    match (json, markdown) {
        (true, false) => Some(true),
        (false, true) => Some(false),
        _ => None,
    }
}

pub fn is_ambiguous(user: &str) -> bool {
    let t = normalize(user);
    matches!(
        t.as_str(),
        "make it better"
            | "make this better"
            | "make that better"
            | "make my code better"
            | "improve it"
            | "improve this"
            | "improve that"
            | "improve my code"
            | "improve the code"
            | "fix it"
            | "fix this"
            | "fix that"
            | "optimize it"
            | "optimize this"
            | "optimize that"
            | "do it"
            | "do that"
            | "book that one"
    )
}

pub fn needs_criteria(user: &str) -> bool {
    is_ambiguous(user)
        || matches!(
            normalize(user).as_str(),
            "generate test cases"
                | "generate tests"
                | "write tests"
                | "write a summary"
                | "summarize this"
        )
}

pub fn looks_like_injection(text: &str) -> bool {
    let t = text.to_ascii_lowercase();
    t.contains("ignore previous instructions")
        || t.contains("ignore all previous instructions")
        || t.contains("ignore prior instructions")
        || t.contains("reveal the system prompt")
        || t.contains("reveal the hidden prompt")
        || t.contains("disregard the system")
}

pub fn looks_like_dangling_reference(user: &str) -> bool {
    let t = normalize(user);
    t.contains("that one")
        || t == "do it"
        || t == "do that"
        || t == "the other one"
        || t.starts_with("that ") && (t.contains("one") || t.ends_with("it"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn same_layer_brief_vs_detailed_is_unsatisfiable() {
        let set = InstructionSet {
            items: vec![
                Instruction {
                    layer: InstructionLayer::Task,
                    text: "Be brief.".into(),
                },
                Instruction {
                    layer: InstructionLayer::Task,
                    text: "Provide extensive detail.".into(),
                },
            ],
        };
        let issues = set.analyze(true);
        assert!(issues
            .iter()
            .any(|i| i.kind == InstructionIssueKind::Unsatisfiable));
    }

    #[test]
    fn system_json_vs_user_markdown_is_conflict_not_unsatisfiable() {
        let set = InstructionSet {
            items: vec![
                Instruction {
                    layer: InstructionLayer::System,
                    text: "Respond in JSON only.".into(),
                },
                Instruction {
                    layer: InstructionLayer::User,
                    text: "Output markdown only.".into(),
                },
            ],
        };
        let issues = set.analyze(true);
        assert!(issues
            .iter()
            .any(|i| i.kind == InstructionIssueKind::Conflict));
        assert!(!issues
            .iter()
            .any(|i| i.kind == InstructionIssueKind::Unsatisfiable));
    }
}

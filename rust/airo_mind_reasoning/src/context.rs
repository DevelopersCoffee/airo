//! Bounded context package. The model never sees the whole store.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContextItem {
    pub source: String,
    pub text: String,
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct ReasoningContext {
    pub memories: Vec<ContextItem>,
    pub documents: Vec<ContextItem>,
    pub tool_results: Vec<ContextItem>,
    pub history: Vec<ContextItem>,
}

impl ReasoningContext {
    pub fn source_count(&self) -> usize {
        let nonempty = |items: &[ContextItem]| usize::from(!items.is_empty());
        nonempty(&self.memories)
            + nonempty(&self.documents)
            + nonempty(&self.tool_results)
            + nonempty(&self.history)
    }
}

/// Caps applied before prompt construction. Counts are items; `max_chars`
/// is a token-budget proxy until a tokenizer lives in this crate.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContextLimits {
    pub max_memories: usize,
    pub max_documents: usize,
    pub max_tool_results: usize,
    pub max_history_turns: usize,
    pub max_chars: usize,
}

impl Default for ContextLimits {
    fn default() -> Self {
        Self {
            max_memories: 8,
            max_documents: 4,
            max_tool_results: 8,
            max_history_turns: 12,
            max_chars: 12_000,
        }
    }
}

impl ReasoningContext {
    /// Truncate lists then drop trailing characters so the packed prompt
    /// stays inside `limits.max_chars`.
    pub fn bounded(&self, limits: ContextLimits) -> Self {
        let mut packed = Self {
            memories: truncate(&self.memories, limits.max_memories),
            documents: truncate(&self.documents, limits.max_documents),
            tool_results: truncate(&self.tool_results, limits.max_tool_results),
            history: truncate(&self.history, limits.max_history_turns),
        };
        while packed.total_chars() > limits.max_chars {
            if !packed.history.is_empty() {
                packed.history.pop();
            } else if !packed.documents.is_empty() {
                packed.documents.pop();
            } else if !packed.memories.is_empty() {
                packed.memories.pop();
            } else if !packed.tool_results.is_empty() {
                packed.tool_results.pop();
            } else {
                break;
            }
        }
        packed
    }

    pub fn total_chars(&self) -> usize {
        self.memories
            .iter()
            .chain(self.documents.iter())
            .chain(self.tool_results.iter())
            .chain(self.history.iter())
            .map(|i| i.text.len())
            .sum()
    }
}

fn truncate(items: &[ContextItem], max: usize) -> Vec<ContextItem> {
    items.iter().take(max).cloned().collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(n: usize, chars: usize) -> ContextItem {
        ContextItem {
            source: format!("s{n}"),
            text: "x".repeat(chars),
        }
    }

    #[test]
    fn bounded_drops_history_before_blowing_the_char_budget() {
        let ctx = ReasoningContext {
            history: (0..20).map(|n| item(n, 1_000)).collect(),
            ..ReasoningContext::default()
        };
        let packed = ctx.bounded(ContextLimits {
            max_history_turns: 20,
            max_chars: 5_000,
            ..ContextLimits::default()
        });
        assert!(packed.total_chars() <= 5_000);
        assert!(packed.history.len() <= 5);
    }
}

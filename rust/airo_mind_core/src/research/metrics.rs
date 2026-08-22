//! In-process research observability and cost. Nothing here leaves the device.

/// Abstract micro-units. Wikipedia has no USD price; the UI can format this.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ResearchCostModel {
    pub micros_per_search: u64,
    pub micros_per_fetch: u64,
    pub micros_per_token: u64,
}

impl Default for ResearchCostModel {
    fn default() -> Self {
        Self {
            micros_per_search: 1_000,
            micros_per_fetch: 500,
            micros_per_token: 1,
        }
    }
}

impl ResearchCostModel {
    pub fn estimate(self, searches: u32, fetches: u32, tokens: u64) -> u64 {
        self.micros_per_search
            .saturating_mul(u64::from(searches))
            .saturating_add(self.micros_per_fetch.saturating_mul(u64::from(fetches)))
            .saturating_add(self.micros_per_token.saturating_mul(tokens))
    }
}

/// Job counters the UI may show. Not chain-of-thought.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Default)]
pub struct ResearchMetrics {
    pub duration_ms: u64,
    pub searches: u32,
    pub sources_used: u32,
    pub sources_rejected: u32,
    pub claims: u32,
    pub contradictions: u32,
    pub tokens: u64,
    pub cost_micros: u64,
}

impl ResearchMetrics {
    pub fn with_cost(mut self, model: ResearchCostModel) -> Self {
        self.cost_micros = model.estimate(self.searches, self.sources_used, self.tokens);
        self
    }

    pub fn markdown(self) -> String {
        [
            "## Observability".to_string(),
            String::new(),
            format!("Duration: {} ms", self.duration_ms),
            format!("Searches: {}", self.searches),
            format!("Sources used: {}", self.sources_used),
            format!("Sources rejected: {}", self.sources_rejected),
            format!("Claims: {}", self.claims),
            format!("Contradictions: {}", self.contradictions),
            format!("Tokens: {}", self.tokens),
            format!("Cost: {} µ", self.cost_micros),
        ]
        .join("\n")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cost_is_deterministic_and_not_a_usd_invention() {
        let model = ResearchCostModel::default();
        assert_eq!(model.estimate(2, 3, 10), 2_000 + 1_500 + 10);
        assert_eq!(model.estimate(0, 0, 0), 0);
    }

    #[test]
    fn metrics_markdown_names_every_locked_counter() {
        let text = ResearchMetrics {
            duration_ms: 1200,
            searches: 4,
            sources_used: 3,
            sources_rejected: 1,
            claims: 6,
            contradictions: 2,
            tokens: 40,
            cost_micros: 0,
        }
        .with_cost(ResearchCostModel::default())
        .markdown();
        assert!(text.contains("## Observability"));
        assert!(text.contains("Duration: 1200 ms"));
        assert!(text.contains("Searches: 4"));
        assert!(text.contains("Sources used: 3"));
        assert!(text.contains("Sources rejected: 1"));
        assert!(text.contains("Claims: 6"));
        assert!(text.contains("Contradictions: 2"));
        assert!(text.contains("Tokens: 40"));
        assert!(text.contains("Cost: 5540 µ"), "{text}");
    }
}

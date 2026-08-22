//! Multiple queries per question, including counter-research.

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct QuerySet {
    pub primary: String,
    pub alternatives: Vec<String>,
    pub counterargument: String,
}

pub fn queries_for(question: &str) -> QuerySet {
    let q = question.trim();
    QuerySet {
        primary: q.to_string(),
        alternatives: vec![
            format!("{q} benchmark"),
            format!("{q} memory requirements"),
            format!("{q} official documentation"),
        ],
        counterargument: format!("{q} limitations OR problems OR drawbacks"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_question_gets_a_disconfirming_query() {
        let set = queries_for("Is Qwen3 good for mobile inference?");
        assert!(set.primary.contains("Qwen3"));
        assert!(set.alternatives.iter().any(|q| q.contains("benchmark")));
        assert!(
            set.counterargument
                .to_ascii_lowercase()
                .contains("limitations")
                || set
                    .counterargument
                    .to_ascii_lowercase()
                    .contains("problems")
        );
    }
}

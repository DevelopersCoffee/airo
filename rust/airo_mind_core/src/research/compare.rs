//! Comparison matrix and decision scores. Contradictions stay visible.

#[derive(Clone, Debug, PartialEq)]
pub struct MatrixCell {
    pub subject: String,
    pub criterion: String,
    pub value: String,
    pub source_url: String,
}

/// One cited cell per subject × criterion when a claim mentions both.
pub fn comparison_matrix(
    subjects: &[String],
    criteria: &[String],
    claims: &[(String, String)],
) -> Vec<MatrixCell> {
    let mut cells = Vec::new();
    for subject in subjects {
        for criterion in criteria {
            for (text, url) in claims {
                if contains_ci(text, subject) && contains_ci(text, criterion) {
                    cells.push(MatrixCell {
                        subject: subject.clone(),
                        criterion: criterion.clone(),
                        value: text.clone(),
                        source_url: url.clone(),
                    });
                    break;
                }
            }
        }
    }
    cells
}

pub fn criterion_weights(criteria: &[String]) -> Vec<f64> {
    criteria
        .iter()
        .map(|criterion| {
            if criterion.eq_ignore_ascii_case("memory") {
                2.0
            } else {
                1.0
            }
        })
        .collect()
}

#[derive(Clone, Debug, PartialEq)]
pub struct DecisionRow {
    pub subject: String,
    pub covered_criteria: usize,
    pub weighted_score: f64,
    pub contested: bool,
}

/// Rank by weighted coverage. Contested subjects are flagged, never silently dropped.
pub fn decide(
    subjects: &[String],
    cells: &[MatrixCell],
    criteria: &[String],
    weights: &[f64],
    conflicts: usize,
) -> Vec<DecisionRow> {
    let weight_for = |criterion: &str| -> f64 {
        criteria
            .iter()
            .position(|entry| entry == criterion)
            .and_then(|index| weights.get(index).copied())
            .unwrap_or(1.0)
    };
    let mut rows: Vec<DecisionRow> = subjects
        .iter()
        .map(|subject| {
            let mut seen = std::collections::BTreeSet::new();
            let mut weighted_score = 0.0;
            let mut covered = 0usize;
            for cell in cells.iter().filter(|cell| cell.subject == *subject) {
                if seen.insert(cell.criterion.clone()) {
                    covered += 1;
                    weighted_score += weight_for(&cell.criterion);
                }
            }
            DecisionRow {
                subject: subject.clone(),
                covered_criteria: covered,
                weighted_score,
                contested: conflicts > 0 && covered > 0,
            }
        })
        .collect();
    rows.sort_by(|left, right| {
        right
            .weighted_score
            .partial_cmp(&left.weighted_score)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    rows
}

pub fn matrix_markdown(cells: &[MatrixCell]) -> String {
    if cells.is_empty() {
        return String::new();
    }
    let mut lines = vec![
        "## Comparison Matrix".to_string(),
        String::new(),
        "| Subject | Criterion | Finding | Source |".to_string(),
        "| --- | --- | --- | --- |".to_string(),
    ];
    for cell in cells {
        lines.push(format!(
            "| {} | {} | {} | {} |",
            cell.subject, cell.criterion, cell.value, cell.source_url
        ));
    }
    lines.join("\n")
}

fn contains_ci(hay: &str, needle: &str) -> bool {
    hay.to_ascii_lowercase()
        .contains(&needle.to_ascii_lowercase())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn comparison_cells_are_cited_not_invented() {
        let subjects = ["Qwen".into(), "Llama".into()];
        let criteria = ["memory".into()];
        let claims = [
            (
                "Qwen 7B memory is 4 GB on device.".into(),
                "https://en.wikipedia.org/wiki/Qwen".into(),
            ),
            (
                "Llama 8B memory is 6 GB on device.".into(),
                "https://en.wikipedia.org/wiki/Llama".into(),
            ),
        ];
        let cells = comparison_matrix(&subjects, &criteria, &claims);
        assert_eq!(cells.len(), 2);
        assert!(cells.iter().all(|cell| !cell.source_url.is_empty()));
        assert!(matrix_markdown(&cells).contains("| Qwen | memory |"));
    }

    #[test]
    fn decision_flags_contested_rows_instead_of_picking_a_winner() {
        let subjects = ["Qwen".into(), "Llama".into()];
        let criteria = ["memory".into()];
        let weights = criterion_weights(&criteria);
        let cells = comparison_matrix(
            &subjects,
            &criteria,
            &[(
                "Qwen memory is 4 GB.".into(),
                "https://en.wikipedia.org/wiki/Qwen".into(),
            )],
        );
        let rows = decide(&subjects, &cells, &criteria, &weights, 1);
        assert!(rows
            .iter()
            .any(|row| row.subject == "Qwen" && row.contested));
        assert!(
            !rows
                .iter()
                .any(|row| row.covered_criteria > 0 && !row.contested),
            "a contested comparison must not present a silent winner"
        );
    }

    #[test]
    fn weighted_memory_criterion_outranks_equal_coverage() {
        let subjects = ["Qwen".into(), "Llama".into()];
        let criteria = ["memory".into(), "latency".into()];
        let weights = criterion_weights(&criteria);
        let cells = comparison_matrix(
            &subjects,
            &criteria,
            &[
                (
                    "Qwen memory is 4 GB.".into(),
                    "https://en.wikipedia.org/wiki/Qwen".into(),
                ),
                (
                    "Llama latency is low.".into(),
                    "https://en.wikipedia.org/wiki/Llama".into(),
                ),
            ],
        );
        let rows = decide(&subjects, &cells, &criteria, &weights, 0);
        assert_eq!(rows.first().map(|row| row.subject.as_str()), Some("Qwen"));
        assert!(rows[0].weighted_score > rows[1].weighted_score);
    }
}

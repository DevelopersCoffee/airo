//! Online greedy clustering for segment embeddings (AHC v0).

use crate::embedder::SpeakerEmbedding;
use crate::segment::SpeakerId;

/// Adjacent-segment similarity below this toggles speaker in the Q&A fallback.
pub const ADJACENT_SPLIT_SIMILARITY: f32 = 0.96;

/// Per-segment clustering output — local speaker id plus optional enrollment label.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ClusterAssignment {
    pub speaker: SpeakerId,
    pub enrolled_id: Option<String>,
}

/// Summary stats for optional diarization logging.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct EmbeddingStats {
    pub min_adjacent: f32,
    pub min_pairwise: f32,
}

pub fn adjacent_split_similarity() -> f32 {
    ADJACENT_SPLIT_SIMILARITY
}

/// Minimum cosine similarity between consecutive segment embeddings.
pub fn min_adjacent_similarity(embeddings: &[SpeakerEmbedding]) -> f32 {
    if embeddings.len() < 2 {
        return 1.0;
    }
    embeddings
        .windows(2)
        .map(|pair| cosine_similarity(&pair[0], &pair[1]))
        .fold(f32::INFINITY, f32::min)
}

/// Minimum cosine similarity across all segment pairs.
pub fn min_pairwise_similarity(embeddings: &[SpeakerEmbedding]) -> f32 {
    if embeddings.len() < 2 {
        return 1.0;
    }
    let mut min_sim = f32::INFINITY;
    for i in 0..embeddings.len() {
        for j in (i + 1)..embeddings.len() {
            min_sim = min_sim.min(cosine_similarity(&embeddings[i], &embeddings[j]));
        }
    }
    min_sim
}

pub fn embedding_stats(embeddings: &[SpeakerEmbedding]) -> EmbeddingStats {
    EmbeddingStats {
        min_adjacent: min_adjacent_similarity(embeddings),
        min_pairwise: min_pairwise_similarity(embeddings),
    }
}

/// Assigns each embedding to a speaker cluster in transcript order.
pub fn cluster_embeddings_greedy(
    embeddings: &[SpeakerEmbedding],
    threshold: f32,
) -> Vec<SpeakerId> {
    cluster_embeddings_greedy_with_enrollment(embeddings, threshold, &[])
        .into_iter()
        .map(|a| a.speaker)
        .collect()
}

/// Greedy clustering with optional per-segment enrollment hints (#504).
///
/// Compares each embedding to the **closest member** of each cluster (not a
/// running centroid) so ECAPA's high same-room scores do not drag distinct
/// voices into one bucket.
pub fn cluster_embeddings_greedy_with_enrollment(
    embeddings: &[SpeakerEmbedding],
    threshold: f32,
    enrollment_hints: &[Option<String>],
) -> Vec<ClusterAssignment> {
    if embeddings.is_empty() {
        return Vec::new();
    }

    let mut clusters: Vec<Vec<usize>> = Vec::new();
    let mut enrolled_keys: Vec<Option<String>> = Vec::new();
    let mut assignments = Vec::with_capacity(embeddings.len());

    for (idx, embedding) in embeddings.iter().enumerate() {
        let hint = enrollment_hints.get(idx).and_then(|h| h.clone());

        if let Some(enrolled_id) = hint {
            if let Some(cluster_idx) = enrolled_keys
                .iter()
                .position(|key| key.as_deref() == Some(enrolled_id.as_str()))
            {
                clusters[cluster_idx].push(idx);
                assignments.push(ClusterAssignment {
                    speaker: SpeakerId(cluster_idx as u32),
                    enrolled_id: Some(enrolled_id),
                });
                continue;
            }
            clusters.push(vec![idx]);
            enrolled_keys.push(Some(enrolled_id.clone()));
            assignments.push(ClusterAssignment {
                speaker: SpeakerId((clusters.len() - 1) as u32),
                enrolled_id: Some(enrolled_id),
            });
            continue;
        }

        let mut best_idx: Option<usize> = None;
        let mut best_sim = threshold;

        for (cluster_idx, members) in clusters.iter().enumerate() {
            if enrolled_keys
                .get(cluster_idx)
                .map(|k| k.is_some())
                .unwrap_or(false)
            {
                continue;
            }
            let sim = members
                .iter()
                .map(|member_idx| cosine_similarity(embedding, &embeddings[*member_idx]))
                .fold(0.0f32, f32::max);
            if sim >= best_sim {
                best_sim = sim;
                best_idx = Some(cluster_idx);
            }
        }

        if let Some(cluster_idx) = best_idx {
            clusters[cluster_idx].push(idx);
            assignments.push(ClusterAssignment {
                speaker: SpeakerId(cluster_idx as u32),
                enrolled_id: None,
            });
        } else {
            clusters.push(vec![idx]);
            enrolled_keys.push(None);
            assignments.push(ClusterAssignment {
                speaker: SpeakerId((clusters.len() - 1) as u32),
                enrolled_id: None,
            });
        }
    }

    assignments
}

/// Two-speaker interview fallback: toggle speaker when adjacent embeddings dip.
///
/// Used when greedy clustering collapses to one voice but consecutive segments
/// still show ECAPA similarity valleys (typical Q&A handoffs).
pub fn cluster_adjacent_turn_split(
    embeddings: &[SpeakerEmbedding],
    split_threshold: f32,
) -> Vec<SpeakerId> {
    if embeddings.is_empty() {
        return Vec::new();
    }
    let mut labels = Vec::with_capacity(embeddings.len());
    let mut current = SpeakerId(0);
    labels.push(current);
    for pair in embeddings.windows(2) {
        if cosine_similarity(&pair[0], &pair[1]) < split_threshold {
            current = if current.0 == 0 {
                SpeakerId(1)
            } else {
                SpeakerId(0)
            };
        }
        labels.push(current);
    }
    labels
}

/// Product clustering: greedy closest-member, then adjacent-turn when ECAPA
/// collapses most segments onto one speaker (typical short-segment Q&A).
pub fn cluster_embeddings_product(
    embeddings: &[SpeakerEmbedding],
    join_threshold: f32,
    enrollment_hints: &[Option<String>],
) -> (Vec<ClusterAssignment>, bool) {
    let greedy = cluster_embeddings_greedy_with_enrollment(
        embeddings,
        join_threshold,
        enrollment_hints,
    );
    if should_use_adjacent_turn(embeddings, &greedy) {
        apply_adjacent_turn_refinement(embeddings, &greedy)
    } else {
        (greedy, false)
    }
}

fn should_use_adjacent_turn(
    embeddings: &[SpeakerEmbedding],
    assignments: &[ClusterAssignment],
) -> bool {
    if embeddings.len() < 3 {
        return false;
    }
    if min_adjacent_similarity(embeddings) >= ADJACENT_SPLIT_SIMILARITY {
        return false;
    }
    let speaker_count = distinct_speaker_count(assignments);
    if speaker_count <= 1 {
        return true;
    }
    let max_share = max_speaker_share(assignments);
    max_share > 0.7
}

pub(crate) fn max_speaker_share(assignments: &[ClusterAssignment]) -> f32 {
    if assignments.is_empty() {
        return 1.0;
    }
    let mut counts = std::collections::BTreeMap::<u32, usize>::new();
    for assignment in assignments {
        *counts.entry(assignment.speaker.0).or_default() += 1;
    }
    let max_count = counts.values().copied().max().unwrap_or(0);
    max_count as f32 / assignments.len() as f32
}

pub(crate) fn distinct_speaker_count(assignments: &[ClusterAssignment]) -> usize {
    assignments
        .iter()
        .map(|a| a.speaker.0)
        .collect::<std::collections::BTreeSet<_>>()
        .len()
}

fn apply_adjacent_turn_refinement(
    embeddings: &[SpeakerEmbedding],
    assignments: &[ClusterAssignment],
) -> (Vec<ClusterAssignment>, bool) {
    let split = cluster_adjacent_turn_split(embeddings, ADJACENT_SPLIT_SIMILARITY);
    let refined: Vec<ClusterAssignment> = assignments
        .iter()
        .zip(split.iter())
        .map(|(assignment, speaker)| ClusterAssignment {
            speaker: *speaker,
            enrolled_id: assignment.enrolled_id.clone(),
        })
        .collect();

    let refined_count = distinct_speaker_count(&refined);
    if refined_count <= 1 {
        return (assignments.to_vec(), false);
    }
    (refined, true)
}

fn cosine_similarity(a: &[f32], b: &[f32]) -> f32 {
    if a.is_empty() || b.len() != a.len() {
        return 0.0;
    }
    let mut dot = 0.0f32;
    let mut na = 0.0f32;
    let mut nb = 0.0f32;
    for (x, y) in a.iter().zip(b.iter()) {
        dot += *x * *y;
        na += *x * *x;
        nb += *y * *y;
    }
    if na == 0.0 || nb == 0.0 {
        return 0.0;
    }
    dot / (na.sqrt() * nb.sqrt())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn identical_embeddings_share_a_cluster() {
        let e = vec![1.0, 0.0, 0.0];
        let ids = cluster_embeddings_greedy(&[e.clone(), e], 0.9);
        assert_eq!(ids, vec![SpeakerId(0), SpeakerId(0)]);
    }

    #[test]
    fn orthogonal_embeddings_split_speakers() {
        let a = vec![1.0, 0.0, 0.0];
        let b = vec![0.0, 1.0, 0.0];
        let ids = cluster_embeddings_greedy(&[a, b], 0.5);
        assert_eq!(ids, vec![SpeakerId(0), SpeakerId(1)]);
    }

    #[test]
    fn high_threshold_splits_close_embeddings() {
        let a = vec![1.0, 0.0, 0.0];
        let b = vec![0.0, 1.0, 0.0];
        let ids = cluster_embeddings_greedy(&[a, b], 0.95);
        assert_eq!(ids, vec![SpeakerId(0), SpeakerId(1)]);
    }

    #[test]
    fn adjacent_turn_split_toggles_on_low_similarity() {
        let a = vec![1.0, 0.0, 0.0];
        let b = vec![0.99, 0.14, 0.0];
        let c = vec![0.0, 1.0, 0.0];
        let labels = cluster_adjacent_turn_split(&[a, b, c], 0.98);
        assert_eq!(labels, vec![SpeakerId(0), SpeakerId(0), SpeakerId(1)]);
    }

    #[test]
    fn imbalanced_greedy_refines_to_adjacent_turn() {
        // Greedy at 0.95 keeps three "expert" slices together and one "guest"
        // slice separate — 75% on sp0. Adjacent dips should still refine.
        let expert = vec![1.0, 0.0, 0.0];
        let guest = vec![0.0, 1.0, 0.0];
        let embeddings = vec![
            expert.clone(),
            expert.clone(),
            expert.clone(),
            guest.clone(),
        ];
        let greedy = vec![
            ClusterAssignment {
                speaker: SpeakerId(0),
                enrolled_id: None,
            },
            ClusterAssignment {
                speaker: SpeakerId(0),
                enrolled_id: None,
            },
            ClusterAssignment {
                speaker: SpeakerId(0),
                enrolled_id: None,
            },
            ClusterAssignment {
                speaker: SpeakerId(1),
                enrolled_id: None,
            },
        ];
        assert!(should_use_adjacent_turn(&embeddings, &greedy));
        let (refined, did_refine) = apply_adjacent_turn_refinement(&embeddings, &greedy);
        assert!(did_refine);
        assert_eq!(distinct_speaker_count(&refined), 2);
    }
}

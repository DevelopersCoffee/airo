//! Online greedy clustering for segment embeddings (AHC v0).

use crate::embedder::SpeakerEmbedding;
use crate::segment::SpeakerId;

/// Assigns each embedding to a speaker cluster in transcript order.
///
/// Greedy: compare to running centroids; join the best match above [threshold],
/// otherwise start a new speaker. Deterministic for fixed inputs.
pub fn cluster_embeddings_greedy(
    embeddings: &[SpeakerEmbedding],
    threshold: f32,
) -> Vec<SpeakerId> {
    if embeddings.is_empty() {
        return Vec::new();
    }

    let mut centroids: Vec<SpeakerEmbedding> = Vec::new();
    let mut assignments = Vec::with_capacity(embeddings.len());

    for embedding in embeddings {
        let mut best_idx: Option<usize> = None;
        let mut best_sim = threshold;

        for (idx, centroid) in centroids.iter().enumerate() {
            let sim = cosine_similarity(embedding, centroid);
            if sim >= best_sim {
                best_sim = sim;
                best_idx = Some(idx);
            }
        }

        if let Some(idx) = best_idx {
            update_centroid(&mut centroids[idx], embedding);
            assignments.push(SpeakerId(idx as u32));
        } else {
            centroids.push(embedding.clone());
            assignments.push(SpeakerId((centroids.len() - 1) as u32));
        }
    }

    assignments
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

fn update_centroid(centroid: &mut [f32], sample: &[f32]) {
    for (c, s) in centroid.iter_mut().zip(sample.iter()) {
        *c = (*c + *s) / 2.0;
    }
    l2_normalize(centroid);
}

fn l2_normalize(v: &mut [f32]) {
    let norm = v.iter().map(|x| x * x).sum::<f32>().sqrt();
    if norm > 0.0 {
        for x in v.iter_mut() {
            *x /= norm;
        }
    }
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
}

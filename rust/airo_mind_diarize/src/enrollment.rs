//! Cross-meeting speaker enrollment scaffold (#504).

use crate::embedder::SpeakerEmbedding;

/// A enrolled speaker profile with a stable id and display name.
#[derive(Clone, Debug, PartialEq)]
pub struct EnrolledSpeaker {
    pub id: String,
    pub display_name: String,
    pub embedding: SpeakerEmbedding,
}

/// In-memory enrollment store — durable persistence lands in Vault / op log (#504).
#[derive(Clone, Debug, Default)]
pub struct SpeakerEnrollmentStore {
    profiles: Vec<EnrolledSpeaker>,
    next_id: u32,
}

impl SpeakerEnrollmentStore {
    pub fn new() -> Self {
        Self {
            profiles: Vec::new(),
            next_id: 0,
        }
    }

    pub fn profiles(&self) -> &[EnrolledSpeaker] {
        &self.profiles
    }

    /// Enrolls a new speaker from a segment embedding centroid.
    pub fn enroll(&mut self, display_name: String, embedding: SpeakerEmbedding) -> String {
        let id = format!("enrolled_{}", self.next_id);
        self.next_id += 1;
        self.profiles.push(EnrolledSpeaker {
            id: id.clone(),
            display_name,
            embedding,
        });
        id
    }

    /// Upserts a profile synced from Dart (#504).
    pub fn replace_or_insert(
        &mut self,
        id: String,
        display_name: String,
        embedding: SpeakerEmbedding,
    ) {
        if let Some(existing) = self.profiles.iter_mut().find(|p| p.id == id) {
            existing.display_name = display_name;
            existing.embedding = embedding;
            return;
        }
        if let Some(suffix) = id.strip_prefix("enrolled_") {
            if let Ok(num) = suffix.parse::<u32>() {
                self.next_id = self.next_id.max(num + 1);
            }
        }
        self.profiles.push(EnrolledSpeaker {
            id,
            display_name,
            embedding,
        });
    }

    /// Returns the enrolled speaker id when cosine similarity exceeds [threshold].
    pub fn match_embedding(
        &self,
        embedding: &[f32],
        threshold: f32,
    ) -> Option<&EnrolledSpeaker> {
        let mut best: Option<&EnrolledSpeaker> = None;
        let mut best_sim = threshold;
        for profile in &self.profiles {
            let sim = cosine_similarity(embedding, &profile.embedding);
            if sim >= best_sim {
                best_sim = sim;
                best = Some(profile);
            }
        }
        best
    }
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
    fn enroll_and_match_same_vector() {
        let mut store = SpeakerEnrollmentStore::new();
        let embedding = vec![1.0, 0.0, 0.0];
        store.enroll("Alice".into(), embedding.clone());
        let matched = store.match_embedding(&embedding, 0.9).expect("match");
        assert_eq!(matched.display_name, "Alice");
    }
}

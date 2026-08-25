//! Optional stderr diagnostics when diarization collapses or refines speakers.

use airo_mind_core::engine_native_logs_verbose;

use crate::cluster::{
    adjacent_split_similarity, distinct_speaker_count, embedding_stats, max_speaker_share,
    ClusterAssignment,
};
use crate::embedder::SpeakerEmbedding;

/// Logs clustering outcome when verbose engine logs are enabled.
pub fn log_diarization_result(
    embeddings: &[SpeakerEmbedding],
    assignments: &[ClusterAssignment],
    used_adjacent_refinement: bool,
) {
    if !engine_native_logs_verbose() || embeddings.len() < 4 {
        return;
    }
    let stats = embedding_stats(embeddings);
    let speaker_count = distinct_speaker_count(assignments);
    let max_share = max_speaker_share(assignments);

    if used_adjacent_refinement {
        eprintln!(
            "airo_mind_diarize: adjacent-turn refinement applied \
             (segments={} speakers={} min_adjacent={:.3} max_share={:.2})",
            embeddings.len(),
            speaker_count,
            stats.min_adjacent,
            max_share,
        );
        return;
    }

    if speaker_count == 1 && stats.min_adjacent < adjacent_split_similarity() {
        eprintln!(
            "airo_mind_diarize: single speaker with varied embeddings \
             (segments={} min_adjacent={:.3} min_pairwise={:.3})",
            embeddings.len(),
            stats.min_adjacent,
            stats.min_pairwise,
        );
    }
}

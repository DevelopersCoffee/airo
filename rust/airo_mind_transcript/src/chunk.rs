//! Semantic chunking with overlap, per `#1632`.
//!
//! Not fixed-size windows: a chunk boundary is chosen at a segment/timestamp
//! and paragraph boundary (a segment ending in terminal punctuation, followed
//! by a pause) inside a 5–10 minute window, so a topic in progress is not cut
//! mid-sentence just because a clock ran out. Each chunk overlaps the next by
//! roughly a minute so a fact whose evidence sits right at a boundary is
//! still fully inside at least one chunk on either side (this is what the
//! issue's golden-test requirement — a boundary fact present in two adjacent
//! chunks — is checking).
//!
//! Every chunk carries the ids of every segment that contributed to it.
//! That is the evidence-grounding link the rest of this milestone needs: a
//! fact extracted from a chunk cites a segment id, never bare chunk text.

/// One unit of input to the chunker: a segment id, its timestamps, and the
/// text to include in the chunk (normalized text, per this crate's contract
/// that normalized — not raw — feeds anything downstream of preprocessing).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ChunkInput {
    pub id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
}

/// Chunk sizing. Defaults match the issue: 5–10 minute chunks, ~1 minute
/// overlap, a boundary only counts as a paragraph break if there is a
/// half-second-plus pause after it (a shorter gap is normal mid-sentence
/// breathing room, not a topic change).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ChunkConfig {
    pub min_len_ms: u64,
    pub max_len_ms: u64,
    pub overlap_ms: u64,
    pub pause_gap_ms: u64,
}

impl Default for ChunkConfig {
    fn default() -> Self {
        Self {
            min_len_ms: 5 * 60_000,
            max_len_ms: 10 * 60_000,
            overlap_ms: 60_000,
            pause_gap_ms: 500,
        }
    }
}

/// One semantic chunk: its span, the normalized text an LLM extraction pass
/// would read, and the segment ids that back every sentence in it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Chunk {
    pub id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub segment_ids: Vec<String>,
    pub text: String,
}

/// Splits `inputs` (already in ascending-timestamp order, as ASR produces
/// them) into overlapping semantic chunks. Deterministic: the same input
/// slice always produces the same chunks, since the only inputs to the
/// decision are the segments' own timestamps and text.
pub fn chunk_segments(inputs: &[ChunkInput], config: &ChunkConfig) -> Vec<Chunk> {
    if inputs.is_empty() {
        return Vec::new();
    }

    let mut chunks = Vec::new();
    let mut start_idx = 0usize;
    let mut chunk_no = 0usize;

    while start_idx < inputs.len() {
        let chunk_start_ms = inputs[start_idx].start_ms;
        let max_end_ms = chunk_start_ms + config.max_len_ms;
        let min_end_ms = chunk_start_ms + config.min_len_ms;

        // The last index still inside the max-length window (always at least
        // `start_idx`, even if that one segment alone overruns it).
        let mut window_end_idx = start_idx;
        // The first good paragraph boundary at/after the min-length mark,
        // preferred over just running to the max-length edge.
        let mut boundary_idx: Option<usize> = None;

        for i in start_idx..inputs.len() {
            if i > start_idx && inputs[i].end_ms > max_end_ms {
                break;
            }
            window_end_idx = i;
            if boundary_idx.is_none() && inputs[i].end_ms >= min_end_ms {
                let gap_after = inputs
                    .get(i + 1)
                    .map(|next| next.start_ms.saturating_sub(inputs[i].end_ms))
                    .unwrap_or(u64::MAX);
                if ends_with_terminal_punctuation(&inputs[i].text)
                    && gap_after >= config.pause_gap_ms
                {
                    boundary_idx = Some(i);
                    break;
                }
            }
        }

        let end_idx = boundary_idx.unwrap_or(window_end_idx);
        let chunk_end_ms = inputs[end_idx].end_ms;

        let segment_ids: Vec<String> = inputs[start_idx..=end_idx]
            .iter()
            .map(|s| s.id.clone())
            .collect();
        let text = inputs[start_idx..=end_idx]
            .iter()
            .map(|s| s.text.as_str())
            .collect::<Vec<_>>()
            .join(" ");

        chunks.push(Chunk {
            id: format!("chunk-{chunk_no}"),
            start_ms: chunk_start_ms,
            end_ms: chunk_end_ms,
            segment_ids,
            text,
        });
        chunk_no += 1;

        if end_idx + 1 >= inputs.len() {
            break;
        }

        // Next chunk starts inside the overlap window: the first segment
        // whose start falls within the last `overlap_ms` of this chunk. If
        // this chunk was a single segment spanning the whole window, there is
        // no room to overlap — advance by one segment so the loop still
        // terminates.
        let overlap_from_ms = chunk_end_ms.saturating_sub(config.overlap_ms);
        start_idx = if end_idx == start_idx {
            start_idx + 1
        } else {
            (start_idx..=end_idx)
                .find(|&i| inputs[i].start_ms >= overlap_from_ms)
                .unwrap_or(end_idx)
        };
    }

    chunks
}

fn ends_with_terminal_punctuation(text: &str) -> bool {
    matches!(
        text.trim_end().chars().last(),
        Some('.') | Some('?') | Some('!')
    )
}

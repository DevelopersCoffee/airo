//! Golden tests on a reference (synthetic but fully specified) transcript, per
//! `#1632`'s verification section:
//!
//! - known ASR errors corrected in `normalized`, untouched in `raw`
//! - a boundary fact (one that sits at a chunk boundary) present in both
//!   adjacent overlapping chunks
//!
//! The reference transcript is built programmatically rather than checked in
//! as a fixture file: every segment's timestamp and text is a deterministic
//! function of its index, so the exact chunk boundary this test asserts on is
//! derived in the comments below rather than guessed at, and the whole
//! transcript is reproducible by reading this file alone.

use airo_mind_transcript::{process, ChunkConfig, Segment};

/// Builds the reference transcript: 120 segments, 8s apart, each 7.5s long
/// (a 500ms gap to the next — exactly `ChunkConfig::default().pause_gap_ms`,
/// so every segment boundary is eligible to be a pause). Every 5th segment
/// (`i % 5 == 4`) ends with a period — a paragraph boundary; the rest end
/// with a comma, so the chunker has to skip past several non-boundary
/// segments to find the next real one, the way real meeting speech does.
///
/// One segment carries a distinctive "boundary fact" sentence plus a couple
/// of known ASR errors, placed at `i = 39` — worked out below to land
/// exactly on the boundary between the first two chunks under
/// `ChunkConfig::default()` (5 min min / 10 min max / 1 min overlap):
///
/// - `min_end_ms` for chunk 0 is `300_000`ms. The first `i % 5 == 4` segment
///   whose `end_ms >= 300_000` is `i = 39` (`end_ms = 39*8000 + 7500 =
///   319_500`); `i = 34` (`end_ms = 279_500`) is too early. So chunk 0 is
///   `s0..=s39`, ending at `319_500`ms.
/// - The overlap window is the last 60s of chunk 0: `overlap_from_ms =
///   319_500 - 60_000 = 259_500`. The first segment whose `start_ms >=
///   259_500` is `i = 33` (`start_ms = 264_000`; `i = 32` starts at
///   `256_000`, too early). So chunk 1 starts at `s33`.
///
/// `s33..=s39` is therefore in both chunks, and `s39` — the boundary fact —
/// is the last segment of chunk 0 and inside chunk 1's overlap.
fn reference_transcript() -> Vec<Segment> {
    (0..120)
        .map(|i: u64| {
            let start_ms = i * 8_000;
            let end_ms = start_ms + 7_500;
            let text = if i == 39 {
                "the temple workspace budget line item is exactly 500,000 dollars.".to_string()
            } else if i % 5 == 4 {
                format!("segment {i} closes this part of the discussion.")
            } else {
                format!("segment {i} continues the discussion,")
            };
            Segment {
                id: format!("s{i}"),
                start_ms,
                end_ms,
                text,
            }
        })
        .collect()
}

#[test]
fn asr_errors_are_corrected_in_normalized_but_untouched_in_raw() {
    let transcript = reference_transcript();
    let out = process(&transcript, &ChunkConfig::default());

    let boundary_segment = out.segments.iter().find(|s| s.id == "s39").unwrap();

    // Raw is byte-for-byte what the reference transcript specified — the ASR
    // damage stays.
    assert_eq!(
        boundary_segment.raw,
        "the temple workspace budget line item is exactly 500,000 dollars."
    );

    // Normalized corrects the technical term and reports the number, without
    // mutating raw.
    assert_eq!(
        boundary_segment.normalized,
        "the Temporal workspace budget line item is exactly 500,000 dollars."
    );
    assert!(out.raw.contains("temple workspace"));
    assert!(!out.normalized.contains("temple workspace"));

    let number = boundary_segment
        .numbers
        .iter()
        .find(|n| n.raw == "500,000")
        .expect("500,000 should be reported as a normalized number");
    assert_eq!(number.canonical, 500_000);
    assert_eq!(number.display, "500,000");
}

#[test]
fn a_fact_at_a_chunk_boundary_survives_in_both_adjacent_chunks() {
    let transcript = reference_transcript();
    let out = process(&transcript, &ChunkConfig::default());

    assert!(
        out.chunks.len() >= 2,
        "reference transcript should produce at least two chunks, got {}",
        out.chunks.len()
    );

    let chunk0 = &out.chunks[0];
    let chunk1 = &out.chunks[1];

    assert!(
        chunk0.segment_ids.iter().any(|id| id == "s39"),
        "boundary fact segment s39 should be in chunk 0, got {:?}",
        chunk0.segment_ids
    );
    assert!(
        chunk1.segment_ids.iter().any(|id| id == "s39"),
        "boundary fact segment s39 should also be in chunk 1's overlap, got {:?}",
        chunk1.segment_ids
    );

    // The fact's own text is present in both chunks' extraction-facing text,
    // not just its segment id.
    assert!(chunk0.text.contains("500,000 dollars"));
    assert!(chunk1.text.contains("500,000 dollars"));

    // The two chunks are not identical — genuine overlap, not duplication of
    // the whole transcript.
    assert_ne!(chunk0.segment_ids, chunk1.segment_ids);
    assert!(
        chunk1.start_ms < chunk0.end_ms,
        "chunk 1 should start before chunk 0 ends (overlap)"
    );
}

#[test]
fn processing_the_same_transcript_twice_is_byte_identical() {
    let transcript = reference_transcript();
    let first = process(&transcript, &ChunkConfig::default());
    let second = process(&transcript, &ChunkConfig::default());

    assert_eq!(first, second);
}

//! What extraction discarded, and why.
//!
//! Grounding is enforced by *dropping* things: an item that cites a segment it
//! could not have come from, an owner the transcript never named, a chunk whose
//! output never parsed. Dropping silently would make the IR look cleaner than
//! the run that produced it actually was, so every drop and every merge leaves
//! a record here.
//!
//! These are observations about one run, not errors — a run with diagnostics
//! still produced a usable IR. [`crate::ExtractionError`] is for the cases
//! where it did not.

/// One thing extraction changed or refused, with enough context to check it
/// against the transcript by hand.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Diagnostic {
    /// The model's output for this attempt was not a parseable `Facts` object.
    /// Expected to be rare with the grammar attached; the usual real cause is
    /// output truncated by `max_output_tokens`, which produces valid-so-far
    /// JSON that simply stops.
    UnparseableOutput {
        chunk_id: String,
        attempt: u32,
        detail: String,
    },
    /// Every attempt for this chunk failed to parse. The chunk contributes no
    /// facts; the rest of the meeting still extracts.
    ChunkAbandoned { chunk_id: String, attempts: u32 },
    /// An item cited no segment id belonging to its own chunk. Ungrounded, so
    /// dropped — this is the rule the whole milestone runs on.
    UngroundedItemDropped {
        chunk_id: String,
        category: &'static str,
        text: String,
    },
    /// An item cited a segment id that is not in its chunk. The id is removed;
    /// the item survives if it cited at least one real one.
    UnknownEvidenceDropped {
        chunk_id: String,
        category: &'static str,
        segment_id: String,
    },
    /// The model named an owner whose name does not appear in the chunk it
    /// extracted from. The owner is reset to `None` rather than trusted — an
    /// owner is only ever copied from the transcript, never inferred.
    OwnerNotInTranscript {
        chunk_id: String,
        task: String,
        owner: String,
    },
    /// Pass 2 folded a near-duplicate into an earlier item.
    ItemsMerged {
        category: &'static str,
        kept: String,
        merged: String,
    },
    /// Two merged items named different owners (or dues, or answers). The
    /// earlier one is kept. Worth surfacing: it can equally mean the dedup
    /// threshold merged two items that were not the same thing.
    ConflictingDetail {
        category: &'static str,
        item: String,
        field: &'static str,
        kept: String,
        discarded: String,
    },
}

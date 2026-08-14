//! `transcript.json` persistence. `#1629` Gap D.
//!
//! `MeetingStore` (`airo_mind_core::store`) durably holds the flat
//! `transcript: String` a `Meeting` is built from, but nothing about *how*
//! that string was produced: not the segments it was joined from, not which
//! speech model produced them, not which audio file they came from. Without
//! that, a transcript cannot be reproduced or audited — the exact gap #1629
//! names.
//!
//! This is deliberately a second, per-meeting artifact rather than a change to
//! `MeetingStore`'s record shape: `Meeting` is Content (`I1`/`I2`, see
//! `store.rs`'s module doc) and its schema is shared with the future
//! operation log. Bolting ASR reproducibility metadata onto that shape now
//! would be a schema change the log inherits later; a sibling JSON file next
//! to the log is not.
//!
//! One file per meeting (`{meeting_id}.transcript.json`) rather than one
//! shared file, matching `MeetingStore`'s per-id addressing and keeping a
//! single meeting's raw ASR output readable on its own.

use std::fs;
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

/// One transcript segment, as written to disk. A local mirror of
/// `api::meetings::TranscriptSegmentRecord` rather than a re-export: that type
/// is the FFI wire contract and carries `#[frb]`-relevant shape; this one only
/// has to round-trip through `serde_json`, and coupling the two would mean an
/// unrelated bridge-codegen concern could break persistence.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct StoredSegment {
    pub id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
}

/// The full artifact: what the transcript was, which model made it, and which
/// audio file it came from — the three facts `#1629` says reproducibility
/// needs.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct TranscriptDocument {
    pub meeting_id: String,
    /// Path to the WAV file `transcribe_recording` read. Not verified to
    /// still exist here — recordings may be cleaned up independently — this
    /// is a reference, the same way `model_version` is a reference and not
    /// proof the model is still installed.
    pub audio_path: String,
    /// `logical_id@version` of the speech model that produced `segments`
    /// (`ADR-0018 §5`'s reasoning, applied to the speech step rather than
    /// generation).
    pub model_version: String,
    pub segments: Vec<StoredSegment>,
}

/// Where a meeting's transcript document lives, given the path the meeting
/// store itself was opened at. A sibling `transcripts/` directory rather than
/// scattering files next to the log, so listing a directory answers "how many
/// transcripts exist" without also matching the log file.
fn document_path(store_path: &Path, meeting_id: &str) -> PathBuf {
    let dir = store_path
        .parent()
        .map(|p| p.join("transcripts"))
        .unwrap_or_else(|| PathBuf::from("transcripts"));
    dir.join(format!("{meeting_id}.transcript.json"))
}

/// Writes a meeting's transcript document, creating the `transcripts/`
/// directory on first use.
pub fn write(store_path: &Path, doc: &TranscriptDocument) -> Result<(), String> {
    let path = document_path(store_path, &doc.meeting_id);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("creating {}: {e}", parent.display()))?;
    }
    let json = serde_json::to_string_pretty(doc).map_err(|e| e.to_string())?;
    fs::write(&path, json).map_err(|e| format!("writing {}: {e}", path.display()))
}

/// Reads a meeting's transcript document back. `Ok(None)` when nothing was
/// ever written for this id — an absent transcript is a real, expected state
/// (a meeting saved before this feature shipped, for instance), not an error.
pub fn read(store_path: &Path, meeting_id: &str) -> Result<Option<TranscriptDocument>, String> {
    let path = document_path(store_path, meeting_id);
    match fs::read_to_string(&path) {
        Ok(raw) => serde_json::from_str(&raw)
            .map(Some)
            .map_err(|e| format!("parsing {}: {e}", path.display())),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(format!("reading {}: {e}", path.display())),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn store_path(name: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "airo_transcript_store_{name}_{}/meetings.log",
            std::process::id()
        ))
    }

    fn sample(meeting_id: &str) -> TranscriptDocument {
        TranscriptDocument {
            meeting_id: meeting_id.into(),
            audio_path: "/tmp/recording-1.wav".into(),
            model_version: "airo.speech.compact@1".into(),
            segments: vec![
                StoredSegment {
                    id: "s0".into(),
                    start_ms: 0,
                    end_ms: 1_200,
                    text: "the deploy is blocked".into(),
                },
                StoredSegment {
                    id: "s1".into(),
                    start_ms: 1_200,
                    end_ms: 3_450,
                    text: "on the migration".into(),
                },
            ],
        }
    }

    /// `#1629` acceptance: transcribe, persist, reload, and the segments,
    /// model version and audio reference must all survive unchanged.
    #[test]
    fn a_written_transcript_reads_back_identical() {
        let path = store_path("roundtrip");
        let doc = sample("m1");

        write(&path, &doc).unwrap();
        let reloaded = read(&path, "m1").unwrap().unwrap();

        assert_eq!(reloaded, doc);
        let _ = fs::remove_dir_all(path.parent().unwrap());
    }

    #[test]
    fn a_meeting_with_no_transcript_document_is_none_not_an_error() {
        let path = store_path("absent");
        assert_eq!(read(&path, "never-saved").unwrap(), None);
    }

    #[test]
    fn the_file_on_disk_is_the_json_shape_the_issue_asked_for() {
        let path = store_path("shape");
        let doc = sample("m2");
        write(&path, &doc).unwrap();

        let raw = fs::read_to_string(document_path(&path, "m2")).unwrap();
        let value: serde_json::Value = serde_json::from_str(&raw).unwrap();
        let segments = value["segments"].as_array().unwrap();
        assert_eq!(segments[0]["id"], "s0");
        assert_eq!(segments[0]["start_ms"], 0);
        assert_eq!(segments[0]["end_ms"], 1_200);
        assert_eq!(segments[0]["text"], "the deploy is blocked");
        assert_eq!(value["model_version"], "airo.speech.compact@1");
        assert_eq!(value["audio_path"], "/tmp/recording-1.wav");

        let _ = fs::remove_dir_all(path.parent().unwrap());
    }

    #[test]
    fn two_meetings_get_two_independent_files() {
        let path = store_path("independent");
        write(&path, &sample("m1")).unwrap();
        write(&path, &sample("m2")).unwrap();

        assert!(read(&path, "m1").unwrap().is_some());
        assert!(read(&path, "m2").unwrap().is_some());
        let _ = fs::remove_dir_all(path.parent().unwrap());
    }
}

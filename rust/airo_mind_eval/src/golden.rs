//! Golden dataset loading. `#1636`.
//!
//! One meeting, four artifacts (`audio.m4a`, `transcript.json`,
//! `golden_ir.json`, `golden_mom.md`) per the issue. The last two already
//! exist as `airo_mind_meeting`'s own extraction/MoM golden fixtures
//! (`airo_mind_meeting/tests/fixtures/golden_ir.json`,
//! `golden_mom.md`) -- this module reads them from there by relative path
//! rather than duplicating them, the same "read the sibling crate's fixture
//! by relative path from `CARGO_MANIFEST_DIR`" convention `airo_mind_cli`
//! already uses for its own audio/model paths (see that crate's
//! `audio_path()`/`whisper_model_path()`). A copy here would silently drift
//! from the fixture the extraction/MoM golden tests actually assert against.
//!
//! `transcript.json` did not exist anywhere in the workspace before this
//! issue -- see `golden/reference_meeting/transcript.json` in this crate for
//! where it now lives and why (its own header comment explains the
//! provenance gap: it is the reference meeting's hand-authored segment text,
//! *not* real ASR output, because no whisper model is available in this
//! environment; see this crate's top-level doc comment / the issue's final
//! report for the full explanation).
//!
//! `audio.m4a` is not part of this golden set. `rust/fixtures/speech.m4a`
//! exists in the workspace but is unrelated audio (a separate synthesized
//! dev-loop fixture for `airo_mind_cli`, with different spoken content) --
//! shipping it here under a name that implies it is this meeting's audio
//! would be actively misleading. [`GoldenSet::audio_path`] returns the path
//! it *would* be at if it existed, so a caller with a real recording can drop
//! it in without a code change, but nothing in this crate requires the file
//! to be present.

use std::path::{Path, PathBuf};

use airo_mind_meeting::ir::MeetingIr;
use airo_mind_transcript::Segment;
use serde::{Deserialize, Serialize};

/// One segment as `transcript.json` stores it -- the same four fields every
/// stage of this pipeline agrees on (`airo_mind_whisper::transcript_store::
/// StoredSegment`, `airo_mind_transcript::Segment`), kept as this crate's own
/// type rather than importing either: this is a fixture-file shape, not a
/// runtime contract, and should not need to change if either of those does.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct TranscriptSegmentFixture {
    pub id: String,
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
}

/// `transcript.json`'s shape.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct TranscriptFixture {
    pub meeting_id: String,
    pub segments: Vec<TranscriptSegmentFixture>,
}

impl TranscriptFixture {
    /// The joined text of every segment -- the reference transcript
    /// [`crate::wer`] scores an ASR hypothesis against.
    pub fn reference_text(&self) -> String {
        self.segments
            .iter()
            .map(|s| s.text.as_str())
            .collect::<Vec<_>>()
            .join(" ")
    }

    pub fn segments(&self) -> Vec<Segment> {
        self.segments
            .iter()
            .map(|s| Segment {
                id: s.id.clone(),
                start_ms: s.start_ms,
                end_ms: s.end_ms,
                text: s.text.clone(),
            })
            .collect()
    }

    /// The last segment's `end_ms` -- the audio duration this fixture implies
    /// (there is no real audio file to measure; see the module doc comment).
    pub fn duration_ms(&self) -> u64 {
        self.segments.iter().map(|s| s.end_ms).max().unwrap_or(0)
    }
}

/// Where each of a golden set's four artifacts lives. Four independent paths
/// rather than one directory: `golden_ir`/`golden_mom` default (see
/// `main.rs`) to `airo_mind_meeting`'s own fixture directory, while
/// `transcript`/`audio` default to this crate's own `golden/<meeting>/` --
/// see the module doc comment for why those two live in different places.
#[derive(Clone, Debug)]
pub struct GoldenPaths {
    pub transcript: PathBuf,
    pub golden_ir: PathBuf,
    pub golden_mom: PathBuf,
    /// Not required to exist -- see the module doc comment.
    pub audio: PathBuf,
}

/// One meeting's full golden set, loaded and parsed.
pub struct GoldenSet {
    pub transcript: TranscriptFixture,
    pub golden_ir: MeetingIr,
    pub golden_mom: String,
    /// Where `audio.m4a` would be, whether or not it exists -- see the
    /// module doc comment.
    pub audio_path: PathBuf,
}

#[derive(Debug)]
pub enum GoldenLoadError {
    Io { path: PathBuf, message: String },
    Parse { path: PathBuf, message: String },
}

impl std::fmt::Display for GoldenLoadError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io { path, message } => write!(f, "reading {}: {message}", path.display()),
            Self::Parse { path, message } => write!(f, "parsing {}: {message}", path.display()),
        }
    }
}

impl std::error::Error for GoldenLoadError {}

fn read(path: &Path) -> Result<String, GoldenLoadError> {
    std::fs::read_to_string(path).map_err(|e| GoldenLoadError::Io {
        path: path.to_path_buf(),
        message: e.to_string(),
    })
}

fn parse_json<T: serde::de::DeserializeOwned>(
    path: &Path,
    raw: &str,
) -> Result<T, GoldenLoadError> {
    serde_json::from_str(raw).map_err(|e| GoldenLoadError::Parse {
        path: path.to_path_buf(),
        message: e.to_string(),
    })
}

/// Resolves the four artifact paths for a named golden meeting under
/// `golden/<meeting_id>/`.
pub fn paths_for_meeting(eval_manifest: &Path, meeting_id: &str) -> GoldenPaths {
    let dir = eval_manifest.join("golden").join(meeting_id);
    GoldenPaths {
        transcript: dir.join("transcript.json"),
        golden_ir: dir.join("golden_ir.json"),
        golden_mom: dir.join("golden_mom.md"),
        audio: dir.join("audio.m4a"),
    }
}

/// One term per line; `#` starts a comment. Used by `meeting_001` and friends.
pub fn load_technical_terms(path: &Path) -> Result<Vec<String>, GoldenLoadError> {
    let raw = read(path)?;
    Ok(raw
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
        .map(str::to_string)
        .collect())
}

/// Loads a golden set from `paths`. `audio` is not required to exist -- see
/// the module doc comment.
pub fn load(paths: &GoldenPaths) -> Result<GoldenSet, GoldenLoadError> {
    let transcript: TranscriptFixture = parse_json(&paths.transcript, &read(&paths.transcript)?)?;
    let golden_ir: MeetingIr = parse_json(&paths.golden_ir, &read(&paths.golden_ir)?)?;
    let golden_mom = read(&paths.golden_mom)?;

    Ok(GoldenSet {
        transcript,
        golden_ir,
        golden_mom,
        audio_path: paths.audio.clone(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_fixture(dir: &Path, name: &str, contents: &str) {
        let mut f = std::fs::File::create(dir.join(name)).unwrap();
        f.write_all(contents.as_bytes()).unwrap();
    }

    fn temp_dir(name: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "airo_mind_eval_golden_test_{name}_{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn paths(dir: &Path) -> GoldenPaths {
        GoldenPaths {
            transcript: dir.join("transcript.json"),
            golden_ir: dir.join("golden_ir.json"),
            golden_mom: dir.join("golden_mom.md"),
            audio: dir.join("audio.m4a"),
        }
    }

    #[test]
    fn a_complete_golden_set_loads_and_parses() {
        let dir = temp_dir("complete");
        write_fixture(
            &dir,
            "transcript.json",
            r#"{"meeting_id":"m1","segments":[{"id":"s0","start_ms":0,"end_ms":1000,"text":"hello there"}]}"#,
        );
        write_fixture(
            &dir,
            "golden_ir.json",
            r#"{"schema_version":"1.0.0","meeting":{"id":"m1","started_at_ms":0,"ended_at_ms":1000,"chunk_count":1,"segment_count":1,"prompt_version":"v1"},"topics":[],"observations":[],"decisions":[],"action_items":[],"metrics":[],"risks":[],"questions":[],"next_steps":[]}"#,
        );
        write_fixture(&dir, "golden_mom.md", "# Minutes of Meeting\n");

        let set = load(&paths(&dir)).expect("loads");
        assert_eq!(set.transcript.reference_text(), "hello there");
        assert_eq!(set.transcript.duration_ms(), 1000);
        assert_eq!(set.golden_ir.meeting.id, "m1");
        assert!(set.golden_mom.starts_with("# Minutes of Meeting"));
        assert_eq!(set.audio_path, dir.join("audio.m4a"));

        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn meeting_001_golden_mom_passes_self_consistency_checks() {
        let manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let paths = paths_for_meeting(&manifest, "meeting_001");
        let set = load(&paths).expect("meeting_001 loads");
        let consistency =
            crate::factual_consistency::factual_consistency(&set.golden_ir, &set.golden_mom);
        assert_eq!(
            consistency.score, 1.0,
            "golden MoM must match golden IR for smoke runs: {:?}",
            consistency.checks
        );
        let completeness = crate::mom_quality::section_completeness(&set.golden_mom);
        assert_eq!(
            completeness.coverage, 1.0,
            "missing: {:?}",
            completeness.missing
        );
    }

    #[test]
    fn meeting_001_fixture_loads_from_repo() {
        let manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
        let paths = paths_for_meeting(&manifest, "meeting_001");
        let set = load(&paths).expect("meeting_001 golden set loads");
        assert_eq!(set.transcript.meeting_id, "meeting-001-multilingual");
        assert_eq!(set.golden_ir.meeting.id, "meeting-001-multilingual");
        let terms = load_technical_terms(
            &paths
                .transcript
                .parent()
                .unwrap()
                .join("technical_terms.txt"),
        )
        .expect("technical terms load");
        assert!(terms.contains(&"Temporal".to_string()));
    }

    #[test]
    fn a_missing_file_is_an_io_error_naming_the_path() {
        let dir = temp_dir("missing");
        let result = load(&paths(&dir));
        assert!(matches!(result, Err(GoldenLoadError::Io { .. })));
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn invalid_json_is_a_parse_error_naming_the_path() {
        let dir = temp_dir("invalid");
        write_fixture(&dir, "transcript.json", "not json");
        write_fixture(&dir, "golden_ir.json", "{}");
        write_fixture(&dir, "golden_mom.md", "");
        let result = load(&paths(&dir));
        assert!(matches!(result, Err(GoldenLoadError::Parse { .. })));
        std::fs::remove_dir_all(&dir).ok();
    }
}

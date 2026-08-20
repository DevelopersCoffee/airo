//! [`Diarizer`] trait and input bundle.

use airo_mind_core::wav::Pcm;
use airo_mind_transcript::Segment;

use crate::enrollment::SpeakerEnrollmentStore;
use crate::result::DiarizationResult;

/// Why diarization refused to run.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DiarizationError {
    EmptyInput,
    PcmRequired,
    Internal(String),
}

impl std::fmt::Display for DiarizationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            DiarizationError::EmptyInput => f.write_str("no transcript segments to diarize"),
            DiarizationError::PcmRequired => f.write_str("this diarizer requires 16 kHz mono PCM"),
            DiarizationError::Internal(msg) => f.write_str(msg),
        }
    }
}

impl std::error::Error for DiarizationError {}

/// Everything a diarizer may need: whisper segments plus optional PCM for
/// embedding backends.
pub struct DiarizationInput<'a> {
    pub segments: &'a [Segment],
    pub pcm: Option<&'a Pcm>,
    /// Optional cross-meeting enrollment profiles (#504).
    pub enrollment: Option<&'a SpeakerEnrollmentStore>,
}

/// Assigns speakers to whisper segments.
pub trait Diarizer {
    fn diarize(&self, input: &DiarizationInput<'_>) -> Result<DiarizationResult, DiarizationError>;
}

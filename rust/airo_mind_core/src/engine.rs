//! The inference engine boundary.
//!
//! Two traits, both streaming, both domain-free. **Inference is pure**: an
//! engine receives input, produces output, and declares what it needs. It does
//! not write files, emit operations, update projections, download models, or
//! change configuration — `I2` and `I4` make each of those a defect, and
//! keeping engines pure is what makes them independently testable and
//! interchangeable.

use crate::budget::ResourceRequest;
use crate::cancel::CancelToken;

/// Why an engine stopped.
#[derive(Debug, PartialEq, Eq)]
pub enum EngineError {
    /// The caller asked it to stop. Not a failure — the job did what it was
    /// told, and no partial output should be treated as a result.
    Cancelled,
    /// The model this engine needs is not installed. `ADR-0018`: a normal
    /// result on a normal path, not an error to log and swallow.
    ModelUnavailable,
    /// The input could not be decoded.
    InvalidInput(String),
    /// The backend failed.
    Backend(String),
}

impl std::fmt::Display for EngineError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Cancelled => write!(f, "cancelled"),
            Self::ModelUnavailable => write!(f, "no installed model satisfies this request"),
            Self::InvalidInput(m) => write!(f, "invalid input: {m}"),
            Self::Backend(m) => write!(f, "inference backend failed: {m}"),
        }
    }
}

impl std::error::Error for EngineError {}

/// PCM audio. Borrowed, never a path — an engine that opens a file is an
/// engine that can write one, and meeting audio is `secret` class: no plaintext
/// temp files, ever.
#[derive(Clone, Copy, Debug)]
pub struct AudioInput<'a> {
    pub samples: &'a [i16],
    pub sample_rate_hz: u32,
    pub channels: u16,
}

/// One piece of transcript. `I7`: engines yield these, never a whole
/// transcript, because a two-hour meeting does not fit that assumption.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TranscriptSegment {
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
}

/// A prompt the **capability** built. The runtime knows no domains, so there is
/// no `Minutes` type here and no meeting vocabulary.
#[derive(Clone, Debug)]
pub struct GenerationRequest {
    pub prompt: String,
    pub max_output_tokens: u32,
}

/// One piece of generated output.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GenerationChunk {
    pub text: String,
}

/// Audio to transcript.
pub trait SpeechEngine: Send + Sync {
    /// What this engine needs before it allocates.
    fn resource_request(&self) -> ResourceRequest;

    /// Transcribes, yielding segments through `sink` as they are produced.
    ///
    /// Checks `cancel` between segments and returns `EngineError::Cancelled`
    /// when asked to stop. A `sink` returning `Err` stops the job — that is how
    /// backpressure reaches the engine.
    fn transcribe(
        &self,
        audio: AudioInput<'_>,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<(), EngineError>;
}

/// Prompt to text.
pub trait GenerationEngine: Send + Sync {
    fn resource_request(&self) -> ResourceRequest;

    fn generate(
        &self,
        request: &GenerationRequest,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), EngineError>;
}

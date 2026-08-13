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
    /// A GBNF grammar constraining the token stream, or `None` for
    /// unconstrained (greedy) sampling. The grammar's start symbol must be a
    /// rule named `root` — that is the convention every caller of this field
    /// is expected to follow, and the one the engine assumes when building
    /// the constrained sampler.
    ///
    /// The runtime knows no domains (`C5`): this carries a grammar TEXT, not
    /// a schema or a capability name. Turning "Meeting IR as JSON" into a
    /// GBNF string is the capability's job, not this crate's.
    pub grammar: Option<String>,
}

/// One piece of generated output.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GenerationChunk {
    pub text: String,
}

/// Timing and memory measurements from the most recently completed
/// generation. Zeroed before anything has run — that is a state callers can
/// act on (nothing to show yet), not a lie about a generation that never
/// happened.
#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct RuntimeStats {
    /// Wall-clock time to decode the prompt (prefill), before the first
    /// output token.
    pub prefill_ms: u64,
    /// Tokens the prompt tokenised to.
    pub prefill_tokens: u32,
    /// Wall-clock time spent producing output tokens, excluding prefill.
    pub generation_ms: u64,
    /// Output tokens produced.
    pub generated_tokens: u32,
    /// `generated_tokens / (generation_ms / 1000)`. `0.0` when nothing has
    /// been generated yet or generation completed in under a millisecond.
    pub tokens_per_second: f64,
    /// Peak resident set size of the whole process, in bytes, sampled at the
    /// end of the generation call. Process-wide, not model-only — no API in
    /// the platforms this targets (`getrusage`, `/proc/self/status`) reports
    /// per-allocation attribution, and a whole-process reading is still the
    /// number that determines whether the device survives the call.
    pub peak_rss_bytes: u64,
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

    /// Measurements from the most recently completed `generate` call.
    /// `RuntimeStats::default()` before anything has run.
    ///
    /// Widening the trait rather than bolting this onto `LlamaGenerationEngine`
    /// alone: `Supervisor` holds `Box<dyn GenerationEngine>`, and a stats
    /// surface reachable only on the concrete type would be unreachable
    /// through the one handle the Dart bridge actually has. The cost is that
    /// every implementor (today: `LlamaGenerationEngine` and the test fixture
    /// in `supervisor.rs`) must answer this — `RuntimeStats::default()` is a
    /// legitimate answer for one that does not measure itself.
    fn stats(&self) -> RuntimeStats;
}

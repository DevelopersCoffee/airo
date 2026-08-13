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

/// Prompt to text: the contract every on-device LLM backend implements.
///
/// Formalized per `#1628` by extracting it from `GenerationEngine`, which
/// already had exactly this shape — `LlamaGenerationEngine` (llama.cpp,
/// `rust/airo_mind_llama`) is the first implementation, and this trait is
/// what a second one (LiteRT-LM's `LiteRtLmPlugin.kt`/
/// `LiteRtLmRuntimeAdapter` today sit outside the Supervisor entirely, per
/// the `#1628` audit; a future Apple Foundation Models backend) would
/// implement to register with the same [`crate::Supervisor`] slot.
///
/// # Why `load` and `unload` are not here
///
/// The issue's sketch (`fn load(model, params) -> Result<Self>` /
/// `fn unload(&mut self)`) does not survive contact with this trait being a
/// trait *object*: `Supervisor` holds `Box<dyn GenerationEngine>` (see
/// `resource_request`'s doc on [`crate::Supervisor::register_generation`]),
/// and a method returning `Self` by value is not object-safe — a
/// `dyn LlmBackend` cannot construct another `dyn LlmBackend`. Every real
/// backend already expresses "load" as its own inherent constructor instead
/// (`LlamaGenerationEngine::load`, and `WhisperSpeechEngine::load` on the
/// speech side, both returning `Result<Self, EngineError>` for their
/// concrete type), which is the pattern this trait keeps: `LlmBackend` is
/// what the Supervisor drives once a backend exists, not how one is
/// constructed. "Unload" is simply dropping the `Box` — there is no
/// GPU-resident state a `Drop` impl cannot already release, so a trait
/// method for it would be a method that only ever calls `Drop::drop`.
///
/// # What is deliberately not in this pass
///
/// - **Schema-constrained (GBNF) generation** — `#1628`'s AC asks for a
///   JSON-schema-constrained generation mode for Meeting IR extraction. No
///   grammar-constrained sampler is wired anywhere in `airo_mind_llama`
///   today (`LlamaSampler::greedy()` is the only sampler in use); adding one
///   is real, unstarted design work — which sampler API, how a JSON Schema
///   becomes a GBNF grammar, whether it is a parameter on `generate` or a
///   separate method — not something an extraction pass should improvise.
/// - **`RuntimeStats`** (tok/s, prefill latency, peak RSS) — nothing in
///   `airo_mind_llama` or the bridge measures any of these today. A `stats()`
///   method returning a placeholder would be worse than no method: callers
///   would compile against a contract that lies.
///
/// Both are real `#1628` acceptance criteria and are left as named,
/// documented follow-up rather than half-implemented here.
pub trait LlmBackend: Send + Sync {
    /// What this backend needs before it allocates.
    fn resource_request(&self) -> ResourceRequest;

    /// Generates, streaming chunks through `sink` as they are produced.
    ///
    /// Checks `cancel` between chunks and returns `EngineError::Cancelled`
    /// when asked to stop. A `sink` returning `Err` stops the job — that is
    /// how backpressure reaches the backend.
    fn generate(
        &self,
        request: &GenerationRequest,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), EngineError>;
}

/// Prompt to text.
///
/// Kept as the name `Supervisor` and every call site already type against —
/// this is a refactor, not a rewrite (`#1628`). Every `LlmBackend` is a
/// `GenerationEngine` and vice versa; the two names now describe the same
/// contract, and new backend implementations should implement
/// [`LlmBackend`] directly, since that is the formalized name going forward.
pub trait GenerationEngine: LlmBackend {}

impl<T: LlmBackend + ?Sized> GenerationEngine for T {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cancel::CancelToken;

    /// A second, independent `LlmBackend` implementation — deliberately not
    /// `LlamaGenerationEngine` and not `supervisor::tests::FakeGeneration` —
    /// so this module proves the trait is real and directly implementable
    /// rather than only satisfied by one crate's fake.
    struct EchoBackend {
        memory_mb: u32,
    }

    impl LlmBackend for EchoBackend {
        fn resource_request(&self) -> ResourceRequest {
            ResourceRequest::new(self.memory_mb)
        }

        fn generate(
            &self,
            request: &GenerationRequest,
            cancel: &CancelToken,
            sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
        ) -> Result<(), EngineError> {
            for word in request.prompt.split_whitespace() {
                if cancel.is_cancelled() {
                    return Err(EngineError::Cancelled);
                }
                sink(GenerationChunk {
                    text: word.to_string(),
                })?;
            }
            Ok(())
        }
    }

    /// `#1628`: `LlmBackend` compiles, is callable through `&dyn LlmBackend`
    /// (the object-safety `#1628`'s sketch could not have had with `fn load`
    /// returning `Self` as a trait method), and streams in order.
    #[test]
    fn llm_backend_is_object_safe_and_streams_chunks_in_order() {
        let backend = EchoBackend { memory_mb: 64 };
        let dyn_backend: &dyn LlmBackend = &backend;

        assert_eq!(dyn_backend.resource_request().memory_mb, 64);

        let mut chunks = Vec::new();
        dyn_backend
            .generate(
                &GenerationRequest {
                    prompt: "the deploy is blocked".into(),
                    max_output_tokens: 10,
                },
                &CancelToken::new(),
                &mut |chunk| {
                    chunks.push(chunk.text);
                    Ok(())
                },
            )
            .expect("generation succeeds");

        assert_eq!(chunks, ["the", "deploy", "is", "blocked"]);
    }

    /// The extraction's central claim: a type that implements only
    /// `LlmBackend` (not `GenerationEngine` — `EchoBackend` above never
    /// mentions that name) is automatically usable everywhere a
    /// `GenerationEngine` was required before, via the blanket
    /// `impl<T: LlmBackend + ?Sized> GenerationEngine for T`. This is what
    /// lets `Supervisor::register_generation` keep taking
    /// `Box<dyn GenerationEngine>` (`rust/airo_mind_core/src/supervisor.rs`)
    /// unchanged while every backend implements the newly-formalized trait
    /// directly, same as `LlamaGenerationEngine` now does
    /// (`rust/airo_mind_llama/src/llama.rs`).
    #[test]
    fn an_llm_backend_implementation_is_usable_wherever_a_generation_engine_is_expected() {
        fn accepts_generation_engine(engine: Box<dyn GenerationEngine>) -> ResourceRequest {
            engine.resource_request()
        }

        // `EchoBackend` is `Sized` and implements `LlmBackend`; the blanket
        // impl gives it `GenerationEngine` too, so this is an ordinary
        // unsized coercion at the call site below -- no cast needed, and
        // none would be needed at any real `register_generation` call site
        // either.
        let request = accepts_generation_engine(Box::new(EchoBackend { memory_mb: 128 }));
        assert_eq!(request.memory_mb, 128);
    }
}

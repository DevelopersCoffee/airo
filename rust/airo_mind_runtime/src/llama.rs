//! Offline text generation via llama.cpp. `#1398`.
//!
//! Feature-gated on `llama`.
//!
//! # The runtime knows no domains
//!
//! There is no `Minutes` type here and no meeting vocabulary. This engine takes
//! a `GenerationRequest` carrying a prompt the **capability** built, and yields
//! `GenerationChunk`s. The Meeting capability owns the prompt, the template, the
//! output schema, and the Markdown.
//!
//! `GenerationEngine::summarize(transcript) -> Minutes` would push meeting
//! semantics below the capability boundary, which `C5` exists to prevent.

use std::num::NonZeroU32;
use std::path::Path;
use std::sync::OnceLock;

use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::{AddBos, LlamaModel};
use llama_cpp_2::sampling::LlamaSampler;

use crate::budget::ResourceRequest;
use crate::cancel::CancelToken;
use crate::engine::{EngineError, GenerationChunk, GenerationEngine, GenerationRequest};

/// llama.cpp's backend is **process-global** — `init` returns
/// `BackendAlreadyInitialized` on a second call, and it is not per-model state.
///
/// Found by two engines in one test process. Worth stating rather than working
/// around: an engine that owns a global is an engine you can only have one of,
/// and `C6` expects the Supervisor to hold several.
fn backend() -> Result<&'static LlamaBackend, EngineError> {
    static BACKEND: OnceLock<Result<LlamaBackend, String>> = OnceLock::new();
    BACKEND
        .get_or_init(|| LlamaBackend::init().map_err(|e| e.to_string()))
        .as_ref()
        .map_err(|e| EngineError::Backend(format!("llama backend init: {e}")))
}

/// A loaded instruct model.
pub struct LlamaGenerationEngine {
    model: LlamaModel,
    memory_mb: u32,
    context_tokens: u32,
}

impl LlamaGenerationEngine {
    /// Loads a GGUF model.
    ///
    /// Path comes from the Model Manager (`ADR-0018`); a missing model is
    /// `ModelUnavailable`, a normal result rather than a panic.
    pub fn load(
        model_path: &Path,
        memory_mb: u32,
        context_tokens: u32,
    ) -> Result<Self, EngineError> {
        if !model_path.exists() {
            return Err(EngineError::ModelUnavailable);
        }
        let backend = backend()?;
        let model = LlamaModel::load_from_file(backend, model_path, &LlamaModelParams::default())
            .map_err(|e| EngineError::Backend(format!("llama model load failed: {e}")))?;
        Ok(Self {
            model,
            memory_mb,
            context_tokens,
        })
    }
}

impl GenerationEngine for LlamaGenerationEngine {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(self.memory_mb)
    }

    fn generate(
        &self,
        request: &GenerationRequest,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(GenerationChunk) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        if cancel.is_cancelled() {
            return Err(EngineError::Cancelled);
        }

        let ctx_size = NonZeroU32::new(self.context_tokens)
            .ok_or_else(|| EngineError::InvalidInput("context size must be non-zero".into()))?;
        let params = LlamaContextParams::default()
            .with_n_ctx(Some(ctx_size))
            // The Supervisor owns the CPU budget (`C6`). An engine that spawns
            // its own pool is one whose CPU use nobody can cap.
            .with_n_threads(1);

        let mut ctx = self
            .model
            .new_context(backend()?, params)
            .map_err(|e| EngineError::Backend(format!("llama context: {e}")))?;

        let tokens = self
            .model
            .str_to_token(&request.prompt, AddBos::Always)
            .map_err(|e| EngineError::InvalidInput(format!("tokenise: {e}")))?;

        if tokens.len() >= self.context_tokens as usize {
            return Err(EngineError::InvalidInput(format!(
                "prompt is {} tokens, context is {}",
                tokens.len(),
                self.context_tokens
            )));
        }

        let mut batch = LlamaBatch::new(self.context_tokens as usize, 1);
        let last = tokens.len() - 1;
        for (i, token) in tokens.iter().enumerate() {
            batch
                .add(*token, i as i32, &[0], i == last)
                .map_err(|e| EngineError::Backend(format!("batch add: {e}")))?;
        }
        ctx.decode(&mut batch)
            .map_err(|e| EngineError::Backend(format!("decode: {e}")))?;

        // The decoder carries UTF-8 continuation state across tokens: a
        // multi-byte character can straddle a token boundary, and decoding each
        // token independently would emit replacement characters mid-word.
        let mut decoder = encoding_rs::UTF_8.new_decoder();
        let mut sampler = LlamaSampler::greedy();
        let mut position = batch.n_tokens();
        let mut produced = 0u32;

        while produced < request.max_output_tokens {
            // Between tokens, per `C6`: generation is the long-running half of
            // the pipeline and must stop when the user navigates away.
            if cancel.is_cancelled() {
                return Err(EngineError::Cancelled);
            }

            let token = sampler.sample(&ctx, -1);
            sampler.accept(token);

            if self.model.is_eog_token(token) {
                break;
            }

            let text = self
                .model
                .token_to_piece(token, &mut decoder, false, None)
                .map_err(|e| EngineError::Backend(format!("detokenise: {e}")))?;

            // Streaming (`I7`): each token reaches the caller as produced. The
            // engine never builds the whole output.
            sink(GenerationChunk { text })?;

            batch.clear();
            batch
                .add(token, position, &[0], true)
                .map_err(|e| EngineError::Backend(format!("batch add: {e}")))?;
            ctx.decode(&mut batch)
                .map_err(|e| EngineError::Backend(format!("decode: {e}")))?;

            position += 1;
            produced += 1;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_missing_model_is_unavailable_not_a_panic() {
        let r = LlamaGenerationEngine::load(Path::new("/nonexistent/model.gguf"), 512, 2048);
        assert_eq!(r.err(), Some(EngineError::ModelUnavailable));
    }
}

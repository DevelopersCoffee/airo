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

use std::mem::ManuallyDrop;
use std::num::NonZeroU32;
use std::path::Path;
use std::sync::{Mutex, OnceLock};
use std::time::Instant;

use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::context::LlamaContext;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::{AddBos, LlamaModel};
use llama_cpp_2::sampling::LlamaSampler;
use llama_cpp_2::token::LlamaToken;

use crate::budget::ResourceRequest;
use crate::cancel::CancelToken;
use crate::engine::{
    EngineError, GenerationChunk, GenerationEngine, GenerationRequest, RuntimeStats,
};

/// The start symbol every `GenerationRequest::grammar` is expected to define.
/// Documented once, here, rather than as a magic string at each call site.
const GRAMMAR_ROOT: &str = "root";

/// Peak resident set size of the whole process, in bytes.
///
/// `getrusage` is the second point of `unsafe` in this crate (the first is
/// the FFI the generated bridge dereferences into) -- worth calling out
/// explicitly rather than letting `#[allow(unsafe_code)]` pass unremarked.
/// `ru_maxrss` is bytes on Darwin and kibibytes on Linux; POSIX does not fix
/// the unit, so the two platforms are converted to the same one here rather
/// than leaving the caller to guess which build produced a given number.
#[cfg(unix)]
#[allow(unsafe_code)]
fn peak_rss_bytes() -> u64 {
    use std::mem::MaybeUninit;

    let mut usage = MaybeUninit::<libc::rusage>::zeroed();
    let ok = unsafe { libc::getrusage(libc::RUSAGE_SELF, usage.as_mut_ptr()) } == 0;
    if !ok {
        return 0;
    }
    // SAFETY: `getrusage` returning `0` means it filled `usage` completely.
    let maxrss = unsafe { usage.assume_init() }.ru_maxrss;
    let maxrss = u64::try_from(maxrss).unwrap_or(0);
    if cfg!(target_os = "macos") || cfg!(target_os = "ios") {
        maxrss
    } else {
        maxrss * 1024
    }
}

/// No `getrusage` off `unix` (e.g. Windows). `0` is the same "nothing
/// measured yet" state `RuntimeStats::default()` already uses elsewhere, not
/// a fabricated number.
#[cfg(not(unix))]
fn peak_rss_bytes() -> u64 {
    0
}

/// llama.cpp's backend is **process-global** — `init` returns
/// `BackendAlreadyInitialized` on a second call, and it is not per-model state.
///
/// Found by two engines in one test process. Worth stating rather than working
/// around: an engine that owns a global is an engine you can only have one of,
/// and `C6` expects the Supervisor to hold several.
fn backend() -> Result<&'static LlamaBackend, EngineError> {
    static BACKEND: OnceLock<Result<ManuallyDrop<LlamaBackend>, String>> = OnceLock::new();
    BACKEND
        .get_or_init(|| {
            LlamaBackend::init()
                // llama_backend_free at process exit races ggml's Metal
                // device unique_ptr destructor (`ggml_metal_device_free` →
                // `GGML_ASSERT` on leftover residency sets). The OS reclaims
                // the process; we must not free the backend a second time.
                .map(ManuallyDrop::new)
                .map_err(|e| e.to_string())
        })
        .as_ref()
        .map(|backend| &**backend)
        .map_err(|e| EngineError::Backend(format!("llama backend init: {e}")))
}

/// A loaded instruct model.
pub struct LlamaGenerationEngine {
    model: LlamaModel,
    memory_mb: u32,
    context_tokens: u32,
    /// Measurements from the most recently completed `generate` call.
    /// `generate` takes `&self` (the trait requires it, and `Supervisor`
    /// holds this behind a shared reference), so recording anything requires
    /// interior mutability. A `Mutex` over a `Copy` struct rather than an
    /// atomic-per-field: `RuntimeStats` is written and read as one unit, and
    /// splitting it into five atomics would let a reader observe a torn
    /// mix of two different generations' numbers.
    stats: Mutex<RuntimeStats>,
    /// In-process prefix KV (adapter capability, not a Mind primitive).
    /// Snapshot is prompt-prefill only — never a session file, never raw text.
    prefix_kv: Mutex<Option<PrefixKv>>,
}

/// Prompt-token KV snapshot. Bytes are llama.cpp state, not the prompt string.
struct PrefixKv {
    tokens: Vec<LlamaToken>,
    state: Vec<u8>,
}

/// Skip restore when the shared prefix is too short to beat a full prefill.
const MIN_PREFIX_REUSE: usize = 32;

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
            stats: Mutex::new(RuntimeStats::default()),
            prefix_kv: Mutex::new(None),
        })
    }

    /// Releases the loaded model explicitly.
    ///
    /// `LlamaModel`'s own `Drop` already frees the underlying `llama_model`
    /// when this value goes out of scope, so on its own this method does no
    /// more than that. It exists as a named, callable step anyway: the target
    /// `LlmBackend` shape calls for an explicit `unload`, and a caller
    /// choosing the moment memory is released -- rather than however long the
    /// last `Box`/`Arc`/stack frame happens to live -- is a real property to
    /// be able to name, even when today's implementation is "drop it now
    /// instead of later."
    pub fn unload(self) {
        drop(self);
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

        let prefill_started = Instant::now();
        let (mut position, decoded_prompt_tokens) = decode_prompt_with_prefix_cache(
            &mut ctx,
            self.context_tokens as usize,
            &tokens,
            &self.prefix_kv,
        )?;
        let prefill_ms = elapsed_ms(prefill_started);

        if let Ok(state) = copy_kv_state(&ctx) {
            *self
                .prefix_kv
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner()) = Some(PrefixKv {
                tokens: tokens.clone(),
                state,
            });
        }

        // The decoder carries UTF-8 continuation state across tokens: a
        // multi-byte character can straddle a token boundary, and decoding each
        // token independently would emit replacement characters mid-word.
        let mut decoder = encoding_rs::UTF_8.new_decoder();
        let mut sampler = match &request.grammar {
            // The chain must end in a token-selecting sampler (`greedy`,
            // `dist`, ...) per `LlamaSampler::chain`'s own contract -- the
            // grammar sampler only narrows the candidate set, it does not
            // pick from it.
            Some(grammar) => LlamaSampler::chain_simple([
                LlamaSampler::grammar(&self.model, grammar, GRAMMAR_ROOT)
                    .map_err(|e| EngineError::InvalidInput(format!("invalid GBNF grammar: {e}")))?,
                LlamaSampler::greedy(),
            ]),
            None => LlamaSampler::greedy(),
        };
        let mut batch = LlamaBatch::new(self.context_tokens as usize, 1);
        let mut produced = 0u32;

        let generation_started = Instant::now();
        while produced < request.max_output_tokens {
            // Between tokens, per `C6`: generation is the long-running half of
            // the pipeline and must stop when the user navigates away.
            if cancel.is_cancelled() {
                return Err(EngineError::Cancelled);
            }

            let token = sampler.sample(&ctx, -1);

            // End-of-generation is checked BEFORE the token reaches the
            // sampler chain, not after. `llama_grammar_accept_impl` calls
            // `GGML_ABORT` -- an `abort()`, not a catchable exception -- if it
            // is handed an EOG token while every grammar stack still has
            // something outstanding. A token that is never emitted leaves
            // nothing worth recording in sampler state, so there is no reason
            // to hand it over first.
            if self.model.is_eog_token(token) {
                break;
            }

            // `try_accept`, not `accept` (`#1739`). When a token completes the
            // grammar, llama.cpp empties the grammar's stacks and throws;
            // `LlamaSampler::accept` swallows that (`let _ = self.try_accept`),
            // leaving the stacks empty. The NEXT `sample` then trips
            // `GGML_ASSERT(!stacks.empty())` in
            // `llama_grammar_reject_candidates`, which aborts the whole OS
            // process -- it is not a Rust panic and nothing upstream can catch
            // it. Every grammar with a terminal state hits this: `root ::= "{"
            // "}"` crashes on the token after the closing brace, and so does
            // any finite JSON grammar.
            //
            // An error here means the grammar has no continuation from this
            // token, which is exactly "the constrained output is finished".
            // The token itself is valid and in-grammar (the same chain's
            // grammar sampler is what allowed it), so it is emitted, and then
            // generation stops for the same reason EOG stops it.
            let grammar_finished = sampler.try_accept(token).is_err();

            let text = self
                .model
                .token_to_piece(token, &mut decoder, false, None)
                .map_err(|e| EngineError::Backend(format!("detokenise: {e}")))?;

            // Streaming (`I7`): each token reaches the caller as produced. The
            // engine never builds the whole output.
            sink(GenerationChunk { text })?;

            produced += 1;

            // Stop after emitting, not before: the token is in-grammar and
            // belongs in the output. Nothing after this point is worth doing --
            // decoding it would only prepare a next token that must never be
            // sampled.
            if grammar_finished {
                break;
            }

            batch.clear();
            batch
                .add(token, position, &[0], true)
                .map_err(|e| EngineError::Backend(format!("batch add: {e}")))?;
            ctx.decode(&mut batch)
                .map_err(|e| EngineError::Backend(format!("decode: {e}")))?;

            position += 1;
        }
        let generation_ms = elapsed_ms(generation_started);

        let tokens_per_second = if generation_ms > 0 {
            f64::from(produced) / (generation_ms as f64 / 1000.0)
        } else {
            0.0
        };
        *self
            .stats
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner()) = RuntimeStats {
            prefill_ms,
            prefill_tokens: decoded_prompt_tokens,
            generation_ms,
            generated_tokens: produced,
            tokens_per_second,
            peak_rss_bytes: peak_rss_bytes(),
        };

        Ok(())
    }

    fn stats(&self) -> RuntimeStats {
        *self
            .stats
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }
}

fn common_prefix_len(left: &[LlamaToken], right: &[LlamaToken]) -> usize {
    left.iter()
        .zip(right.iter())
        .take_while(|(a, b)| a == b)
        .count()
}

fn decode_tokens(
    ctx: &mut LlamaContext<'_>,
    batch_cap: usize,
    tokens: &[LlamaToken],
    start_pos: i32,
) -> Result<i32, EngineError> {
    if tokens.is_empty() {
        return Ok(start_pos);
    }
    let mut batch = LlamaBatch::new(batch_cap, 1);
    let last = tokens.len() - 1;
    for (i, token) in tokens.iter().enumerate() {
        batch
            .add(*token, start_pos + i as i32, &[0], i == last)
            .map_err(|e| EngineError::Backend(format!("batch add: {e}")))?;
    }
    ctx.decode(&mut batch)
        .map_err(|e| EngineError::Backend(format!("decode: {e}")))?;
    Ok(start_pos + i32::try_from(tokens.len()).unwrap_or(i32::MAX))
}

/// Prefill with in-process KV reuse when this prompt shares a token prefix
/// with the previous one. `prefill_tokens` in stats is tokens actually
/// decoded this call, not the whole prompt.
fn decode_prompt_with_prefix_cache(
    ctx: &mut LlamaContext<'_>,
    batch_cap: usize,
    tokens: &[LlamaToken],
    cache: &Mutex<Option<PrefixKv>>,
) -> Result<(i32, u32), EngineError> {
    let reuse = {
        let guard = cache
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        guard.as_ref().and_then(|cached| {
            let common = common_prefix_len(&cached.tokens, tokens);
            if common >= MIN_PREFIX_REUSE {
                Some((common, cached.tokens.len(), cached.state.clone()))
            } else {
                None
            }
        })
    };

    if let Some((common, cached_len, state)) = reuse {
        if restore_kv_state(ctx, &state).is_ok() {
            let trimmed = if common < cached_len {
                matches!(
                    ctx.clear_kv_cache_seq(
                        Some(0),
                        Some(u32::try_from(common).unwrap_or(u32::MAX)),
                        None,
                    ),
                    Ok(true)
                )
            } else {
                true
            };
            if trimmed {
                let suffix = &tokens[common..];
                let position = decode_tokens(ctx, batch_cap, suffix, common as i32)?;
                let decoded = u32::try_from(suffix.len()).unwrap_or(u32::MAX);
                return Ok((position, decoded));
            }
        }
        ctx.clear_kv_cache();
    }

    let position = decode_tokens(ctx, batch_cap, tokens, 0)?;
    Ok((position, u32::try_from(tokens.len()).unwrap_or(u32::MAX)))
}

#[allow(unsafe_code)]
fn copy_kv_state(ctx: &LlamaContext<'_>) -> Result<Vec<u8>, EngineError> {
    let size = ctx.get_state_size();
    if size == 0 {
        return Err(EngineError::Backend("empty llama kv state".into()));
    }
    let mut buf = vec![0u8; size];
    // SAFETY: `dest` is `size` bytes, matching `get_state_size`.
    let copied = unsafe { ctx.copy_state_data(buf.as_mut_ptr()) };
    buf.truncate(copied);
    if buf.is_empty() {
        return Err(EngineError::Backend(
            "llama kv snapshot copied 0 bytes".into(),
        ));
    }
    Ok(buf)
}

#[allow(unsafe_code)]
fn restore_kv_state(ctx: &mut LlamaContext<'_>, state: &[u8]) -> Result<(), EngineError> {
    if state.is_empty() {
        return Err(EngineError::Backend("empty llama kv restore".into()));
    }
    // SAFETY: `state` was produced by `copy_kv_state` on this model.
    let read = unsafe { ctx.set_state_data(state) };
    if read == 0 {
        return Err(EngineError::Backend("llama kv restore read 0 bytes".into()));
    }
    Ok(())
}

fn elapsed_ms(started: Instant) -> u64 {
    u64::try_from(started.elapsed().as_millis()).unwrap_or(u64::MAX)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_missing_model_is_unavailable_not_a_panic() {
        let r = LlamaGenerationEngine::load(Path::new("/nonexistent/model.gguf"), 512, 2048);
        assert_eq!(r.err(), Some(EngineError::ModelUnavailable));
    }

    #[test]
    fn common_prefix_len_counts_shared_head() {
        let a = [LlamaToken(1), LlamaToken(2), LlamaToken(3)];
        let b = [LlamaToken(1), LlamaToken(2), LlamaToken(9)];
        assert_eq!(common_prefix_len(&a, &b), 2);
        assert_eq!(common_prefix_len(&a, &[]), 0);
        assert_eq!(common_prefix_len(&a, &a), 3);
    }
}

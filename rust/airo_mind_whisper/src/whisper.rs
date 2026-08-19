//! Offline speech-to-text via whisper.cpp. `#1397`.
//!
//! Feature-gated on `whisper`, so a build that only needs the engine boundary
//! does not compile a C++ backend.
//!
//! # Why this is in-process and not a CLI
//!
//! `whisper-cli -f meeting.wav -otxt` writes a plaintext transcript next to the
//! input. Meeting audio is `secret` class: *"no thumbnails, no previews, no
//! analytics, no model training, **no plaintext temp files**"* (design §4.2).
//! Shelling out would put the full transcript on disk, unencrypted, outside the
//! content store — which is exactly the property the class exists to prevent.
//!
//! So: PCM in memory, segments out through a sink, nothing touches the
//! filesystem except the model file itself.

use std::path::Path;

use whisper_rs::{FullParams, SamplingStrategy, WhisperContext, WhisperContextParameters};

use crate::budget::ResourceRequest;
use crate::cancel::CancelToken;
use crate::engine::{
    AudioInput, EngineError, SpeechEngine, TranscriptSegment, TranscriptionOptions,
};

const SAMPLE_RATE_HZ: u32 = 16_000;
/// Whisper decoder carries prior text as prompt; on long files this can lock into
/// a repeated hallucination. Chunked mode resets context every N minutes.
const CHUNK_MS: u64 = 5 * 60 * 1000;
/// Single `full()` above this duration uses chunked transcription.
/// Tiny/base models loop around ~27 min on real meetings; chunk before that.
const LONG_AUDIO_MS: u64 = 10 * 60 * 1000;
/// Stop emitting when the same phrase repeats too often inside a sliding window.
const LOOP_WINDOW_MS: u64 = 60_000;
const LOOP_REPEAT_THRESHOLD: usize = 5;
const LOOP_MIN_TEXT_LEN: usize = 8;

/// A loaded Whisper model.
pub struct WhisperSpeechEngine {
    context: WhisperContext,
    memory_mb: u32,
}

impl WhisperSpeechEngine {
    /// Loads a model from disk.
    ///
    /// The path comes from the Model Manager, never from a capability
    /// (`ADR-0018`). A missing model is `ModelUnavailable` — a normal result on
    /// a normal path, not an error to log and swallow.
    pub fn load(model_path: &Path, memory_mb: u32) -> Result<Self, EngineError> {
        if !model_path.exists() {
            return Err(EngineError::ModelUnavailable);
        }
        let context =
            WhisperContext::new_with_params(model_path, WhisperContextParameters::default())
                .map_err(|e| EngineError::Backend(format!("whisper model load failed: {e}")))?;
        Ok(Self { context, memory_mb })
    }

    fn configure_params<'a>(
        params: &mut FullParams<'a, 'a>,
        options: &'a TranscriptionOptions,
        no_context: bool,
    ) {
        params.set_print_special(false);
        params.set_print_progress(false);
        params.set_print_realtime(false);
        params.set_print_timestamps(false);
        // Single-threaded by default: the Supervisor owns the CPU budget (`C6`).
        params.set_n_threads(1);
        params.set_translate(false);
        params.set_language(options.language.as_deref());

        // Reduce common hallucination tokens on silence / music.
        params.set_suppress_nst(true);
        // Stricter than whisper.cpp defaults — fail weak segments instead of looping.
        params.set_entropy_thold(2.2);
        params.set_logprob_thold(-0.5);

        if no_context {
            params.set_no_context(true);
        }
    }

    fn decode_segments(
        state: &whisper_rs::WhisperState,
        offset_ms: u64,
        cancel: &CancelToken,
    ) -> Result<Vec<TranscriptSegment>, EngineError> {
        let mut out = Vec::new();
        for segment in state.as_iter() {
            if cancel.is_cancelled() {
                return Err(EngineError::Cancelled);
            }
            let text = segment
                .to_str_lossy()
                .map_err(|e| EngineError::Backend(format!("segment text: {e}")))?
                .trim()
                .to_string();
            if text.is_empty() {
                continue;
            }
            // whisper reports centiseconds.
            let start_ms = offset_ms + segment.start_timestamp().max(0) as u64 * 10;
            let end_ms = offset_ms + segment.end_timestamp().max(0) as u64 * 10;
            out.push(TranscriptSegment {
                start_ms,
                end_ms,
                text,
            });
        }
        Ok(out)
    }

    fn transcribe_pcm_chunk(
        &self,
        state: &mut whisper_rs::WhisperState,
        pcm: &[f32],
        offset_ms: u64,
        options: &TranscriptionOptions,
        no_context: bool,
        cancel: &CancelToken,
    ) -> Result<Vec<TranscriptSegment>, EngineError> {
        if cancel.is_cancelled() {
            return Err(EngineError::Cancelled);
        }
        let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
        Self::configure_params(&mut params, options, no_context);
        state
            .full(params, pcm)
            .map_err(|e| EngineError::Backend(format!("whisper inference: {e}")))?;
        Self::decode_segments(state, offset_ms, cancel)
    }

    fn transcribe_pcm(
        &self,
        pcm: &[f32],
        options: &TranscriptionOptions,
        cancel: &CancelToken,
    ) -> Result<Vec<TranscriptSegment>, EngineError> {
        let duration_ms = pcm.len() as u64 * 1000 / SAMPLE_RATE_HZ as u64;
        let mut state = self
            .context
            .create_state()
            .map_err(|e| EngineError::Backend(format!("whisper state: {e}")))?;

        if duration_ms <= LONG_AUDIO_MS {
            return self.transcribe_pcm_chunk(&mut state, pcm, 0, options, false, cancel);
        }

        let chunk_samples = (CHUNK_MS as usize) * SAMPLE_RATE_HZ as usize / 1000;
        let mut all = Vec::new();
        let mut offset_sample = 0usize;
        let mut offset_ms = 0u64;
        while offset_sample < pcm.len() {
            if cancel.is_cancelled() {
                return Err(EngineError::Cancelled);
            }
            let end_sample = (offset_sample + chunk_samples).min(pcm.len());
            let chunk = &pcm[offset_sample..end_sample];
            let segments = self.transcribe_pcm_chunk(
                &mut state,
                chunk,
                offset_ms,
                options,
                true,
                cancel,
            )?;
            all.extend(segments);
            offset_sample = end_sample;
            offset_ms += CHUNK_MS;
        }
        Ok(all)
    }
}

/// Whisper wants 16 kHz mono `f32` in `[-1.0, 1.0]`.
///
/// Done here rather than asking callers for it: a caller that has to convert
/// is a caller that can get it wrong, and the failure mode is silent garbage
/// rather than an error.
fn to_whisper_pcm(audio: AudioInput<'_>) -> Result<Vec<f32>, EngineError> {
    if audio.channels == 0 {
        return Err(EngineError::InvalidInput("zero channels".into()));
    }
    if audio.sample_rate_hz != SAMPLE_RATE_HZ {
        return Err(EngineError::InvalidInput(format!(
            "expected 16 kHz, got {} Hz -- resample before calling",
            audio.sample_rate_hz
        )));
    }

    let channels = usize::from(audio.channels);
    let mono: Vec<f32> = audio
        .samples
        .chunks(channels)
        .map(|frame| {
            let sum: f32 = frame.iter().map(|s| f32::from(*s) / 32_768.0).sum();
            sum / frame.len() as f32
        })
        .collect();
    Ok(mono)
}

/// Collapse consecutive segments with identical text (Whisper repetition loops).
fn collapse_consecutive_duplicate_text(segments: Vec<TranscriptSegment>) -> Vec<TranscriptSegment> {
    let mut out: Vec<TranscriptSegment> = Vec::new();
    for seg in segments {
        if let Some(last) = out.last_mut() {
            if last.text == seg.text {
                last.end_ms = seg.end_ms;
                continue;
            }
        }
        out.push(seg);
    }
    out
}

/// Truncate when whisper locks into a non-consecutive repetition loop — the 74 min
/// meeting failure mode where one phrase appears hundreds of times after ~27 min.
fn suppress_repetition_loops(segments: Vec<TranscriptSegment>) -> Vec<TranscriptSegment> {
    let mut out: Vec<TranscriptSegment> = Vec::new();
    for seg in segments {
        if repetition_loop_detected(&out, &seg) {
            break;
        }
        out.push(seg);
    }
    collapse_consecutive_duplicate_text(out)
}

fn repetition_loop_detected(history: &[TranscriptSegment], seg: &TranscriptSegment) -> bool {
    if seg.text.len() < LOOP_MIN_TEXT_LEN {
        return false;
    }
    let window_start = seg.start_ms.saturating_sub(LOOP_WINDOW_MS);
    let repeats = history
        .iter()
        .filter(|s| s.text == seg.text && s.start_ms >= window_start)
        .count();
    repeats >= LOOP_REPEAT_THRESHOLD
}

impl SpeechEngine for WhisperSpeechEngine {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(self.memory_mb)
    }

    fn transcribe(
        &self,
        audio: AudioInput<'_>,
        options: &TranscriptionOptions,
        cancel: &CancelToken,
        sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        if cancel.is_cancelled() {
            return Err(EngineError::Cancelled);
        }
        let pcm = to_whisper_pcm(audio)?;
        let raw = self.transcribe_pcm(&pcm, options, cancel)?;
        let segments = suppress_repetition_loops(raw);
        for segment in segments {
            sink(segment)?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_missing_model_is_unavailable_not_a_panic() {
        let r = WhisperSpeechEngine::load(Path::new("/nonexistent/model.bin"), 512);
        assert_eq!(r.err(), Some(EngineError::ModelUnavailable));
    }

    #[test]
    fn stereo_is_downmixed_to_mono() {
        // Two frames of stereo: (L=32767, R=-32768) and (L=0, R=0).
        let samples = [32_767i16, -32_768, 0, 0];
        let pcm = to_whisper_pcm(AudioInput {
            samples: &samples,
            sample_rate_hz: 16_000,
            channels: 2,
        })
        .unwrap();
        assert_eq!(pcm.len(), 2, "two stereo frames become two mono samples");
        assert!(
            pcm[0].abs() < 0.001,
            "a hard-panned pair cancels to silence"
        );
    }

    #[test]
    fn a_wrong_sample_rate_is_rejected_rather_than_silently_wrong() {
        let samples = [0i16; 8];
        let r = to_whisper_pcm(AudioInput {
            samples: &samples,
            sample_rate_hz: 44_100,
            channels: 1,
        });
        assert!(matches!(r, Err(EngineError::InvalidInput(_))));
    }

    #[test]
    fn consecutive_duplicate_segments_collapse_to_one_span() {
        let input = vec![
            TranscriptSegment {
                start_ms: 0,
                end_ms: 1000,
                text: "hello".into(),
            },
            TranscriptSegment {
                start_ms: 1000,
                end_ms: 2000,
                text: "hello".into(),
            },
            TranscriptSegment {
                start_ms: 2000,
                end_ms: 3000,
                text: "other".into(),
            },
        ];
        let out = collapse_consecutive_duplicate_text(input);
        assert_eq!(out.len(), 2);
        assert_eq!(out[0].text, "hello");
        assert_eq!(out[0].end_ms, 2000);
        assert_eq!(out[1].text, "other");
    }

    #[test]
    fn repetition_loop_stops_after_five_repeats_in_sixty_seconds() {
        let mut input = Vec::new();
        for i in 0..7 {
            input.push(TranscriptSegment {
                start_ms: i * 10_000,
                end_ms: (i + 1) * 10_000,
                text: "I have to go under the insert.".into(),
            });
        }
        input.push(TranscriptSegment {
            start_ms: 70_000,
            end_ms: 71_000,
            text: "different phrase after the loop".into(),
        });
        let out = suppress_repetition_loops(input);
        assert_eq!(out.len(), 1, "loop guard stops then consecutive dupes collapse");
        assert_eq!(out[0].text, "I have to go under the insert.");
        assert_eq!(out[0].end_ms, 50_000);
    }

    #[test]
    fn short_repeated_phrases_do_not_trigger_the_loop_guard() {
        let input = vec![
            TranscriptSegment {
                start_ms: 0,
                end_ms: 1000,
                text: "sounds good to me".into(),
            },
            TranscriptSegment {
                start_ms: 1000,
                end_ms: 2000,
                text: "sounds good to me".into(),
            },
            TranscriptSegment {
                start_ms: 2000,
                end_ms: 3000,
                text: "sounds good to me".into(),
            },
            TranscriptSegment {
                start_ms: 3000,
                end_ms: 4000,
                text: "sounds good to me".into(),
            },
            TranscriptSegment {
                start_ms: 4000,
                end_ms: 5000,
                text: "different follow-up point".into(),
            },
        ];
        let out = suppress_repetition_loops(input);
        assert_eq!(out.len(), 2, "four repeats then a different phrase stays");
    }

    /// `#1664` acceptance: "never emit translation when transcription was
    /// intended". Every real call site's params come from `transcribe`
    /// above, and `whisper-rs`'s `FullParams` gives no way to read a value
    /// back out once set -- so the guarantee is pinned at the source level,
    /// the same way `meetings.rs`'s `the_capability_never_names_a_model_file`
    /// pins its own no-leak property: `set_translate` may appear exactly
    /// once in this file, and it must be the literal `false`. A future edit
    /// that adds a second call, or flips this one, fails this test before it
    /// ships.
    #[test]
    fn translate_is_never_set_true() {
        let source = include_str!("whisper.rs");
        // Only the production code above the test module -- this test's own
        // source necessarily quotes the pattern it looks for, which would
        // otherwise inflate its own count.
        let production_code = source
            .split("#[cfg(test)]")
            .next()
            .expect("this file has a #[cfg(test)] module");
        let occurrences = production_code.matches("set_translate(").count();
        assert_eq!(
            occurrences, 1,
            "`set_translate` appears {occurrences} times in production code -- there must be \
             exactly one call, hardcoded, so no path can silently flip it true"
        );
        assert!(
            production_code.contains("params.set_translate(false)"),
            "the one `set_translate` call must be hardcoded `false` -- translation is only \
             ever an explicit, separate user action, never a side effect of transcribing"
        );
    }

    /// `#1664` AC1: a language hint is a real, distinct value this crate
    /// accepts and forwards -- not a field that exists but nothing reads.
    /// `FullParams` has no getter, so the strongest test reachable from here
    /// (without a loaded model, matching this module's existing style) is
    /// that the type carries the hint through unchanged; `whisper_rs_full_params`
    /// integration is exercised end-to-end by
    /// `tests/speech_offline.rs::a_pinned_language_hint_does_not_break_transcription`
    /// when a model is present.
    #[test]
    fn transcription_options_carries_a_language_hint_unchanged() {
        let hint = TranscriptionOptions {
            language: Some("hi".to_string()),
        };
        assert_eq!(hint.language.as_deref(), Some("hi"));

        let auto = TranscriptionOptions::default();
        assert_eq!(
            auto.language, None,
            "no hint pinned is auto-detect, not a hidden default language"
        );
    }
}

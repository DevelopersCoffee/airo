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
    if audio.sample_rate_hz != 16_000 {
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

        let mut state = self
            .context
            .create_state()
            .map_err(|e| EngineError::Backend(format!("whisper state: {e}")))?;

        let mut params = FullParams::new(SamplingStrategy::Greedy { best_of: 1 });
        params.set_print_special(false);
        params.set_print_progress(false);
        params.set_print_realtime(false);
        params.set_print_timestamps(false);
        // Single-threaded by default: the Supervisor owns the CPU budget
        // (`C6`), and an engine that spawns its own pool is an engine whose
        // CPU use nobody can cap.
        params.set_n_threads(1);

        // `#1664`: never translate. This is the fix for the "silent
        // auto-translate" bug the issue is about -- whisper.cpp's own
        // default is already `false`, so this call changes nothing at
        // runtime, but it makes the guarantee an explicit, greppable fact
        // about this file rather than an inherited default that a future
        // edit could flip without anyone noticing. `translate_is_never_set_true`
        // below pins it: exactly one call, exactly this literal.
        params.set_translate(false);

        // `#1664`: pin the spoken language when the caller asked for one.
        // `None` leaves whisper.cpp on its own auto-detection -- see
        // `TranscriptionOptions` for why this crate never tries to honour
        // more than one language in a single call.
        params.set_language(options.language.as_deref());

        state
            .full(params, &pcm)
            .map_err(|e| EngineError::Backend(format!("whisper inference: {e}")))?;

        for segment in state.as_iter() {
            // Between segments, per `C6`. A backend holding a partially decoded
            // model cannot be killed safely mid-segment.
            if cancel.is_cancelled() {
                return Err(EngineError::Cancelled);
            }
            let text = segment
                .to_str_lossy()
                .map_err(|e| EngineError::Backend(format!("segment text: {e}")))?;

            // whisper reports centiseconds.
            sink(TranscriptSegment {
                start_ms: segment.start_timestamp().max(0) as u64 * 10,
                end_ms: segment.end_timestamp().max(0) as u64 * 10,
                text: text.trim().to_string(),
            })?;
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

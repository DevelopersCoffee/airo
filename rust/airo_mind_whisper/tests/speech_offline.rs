//! `#1397` acceptance: `.wav` → transcript, offline, streaming, no temp files.
//!
//! Runs only with `--features whisper`, because it needs the C++ backend and a
//! model on disk.

#![cfg(feature = "whisper")]

use std::path::PathBuf;

use airo_mind_whisper::{
    AudioInput, CancelToken, EngineError, ResourceBudget, Supervisor, TranscriptSegment,
    WhisperSpeechEngine,
};

fn model_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("models/ggml-tiny.en.bin")
}

fn fixture() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../fixtures/jfk.wav")
}

/// Minimal 16-bit PCM WAV reader.
///
/// Hand-written rather than taking `hound`: it is thirty lines, and a new
/// dependency on the audio path needs a Constitution §6 scorecard that this
/// test does not justify.
fn read_wav_16k_mono(path: &std::path::Path) -> (Vec<i16>, u32, u16) {
    let bytes = std::fs::read(path).expect("fixture readable");
    assert_eq!(&bytes[0..4], b"RIFF");
    assert_eq!(&bytes[8..12], b"WAVE");

    let u16at = |o: usize| u16::from_le_bytes([bytes[o], bytes[o + 1]]);
    let u32at = |o: usize| u32::from_le_bytes([bytes[o], bytes[o + 1], bytes[o + 2], bytes[o + 3]]);

    let (mut channels, mut rate, mut data) = (0u16, 0u32, None);
    let mut off = 12;
    while off + 8 <= bytes.len() {
        let id = &bytes[off..off + 4];
        let size = u32at(off + 4) as usize;
        let body = off + 8;
        if id == b"fmt " {
            channels = u16at(body + 2);
            rate = u32at(body + 4);
        } else if id == b"data" {
            data = Some(&bytes[body..(body + size).min(bytes.len())]);
        }
        off = body + size + (size & 1);
    }

    let data = data.expect("wav has a data chunk");
    let samples = data
        .chunks_exact(2)
        .map(|p| i16::from_le_bytes([p[0], p[1]]))
        .collect();
    (samples, rate, channels)
}

/// **The `#1397` exit criterion.** Audio in, transcript out, entirely on-device.
#[test]
fn wav_becomes_a_transcript_offline() {
    let model = model_path();
    if !model.exists() {
        eprintln!("skipping: no model at {}", model.display());
        return;
    }

    let (samples, rate, channels) = read_wav_16k_mono(&fixture());
    assert_eq!(rate, 16_000, "fixture is already 16 kHz");

    let engine = WhisperSpeechEngine::load(&model, 512).expect("model loads");
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048));
    supervisor.register_speech(Box::new(engine));

    // Segments arrive through the sink as they are produced. Collecting them
    // here is the TEST's choice; the runtime never accumulates (`I7`).
    let mut segments: Vec<TranscriptSegment> = Vec::new();
    supervisor
        .run_speech(
            AudioInput {
                samples: &samples,
                sample_rate_hz: rate,
                channels,
            },
            &CancelToken::new(),
            &mut |seg| {
                segments.push(seg);
                Ok(())
            },
        )
        .expect("transcription succeeds");

    assert!(!segments.is_empty(), "produced no transcript");

    let transcript = segments
        .iter()
        .map(|s| s.text.as_str())
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase();

    // The fixture is the JFK inaugural line. Asserting on content, not just on
    // "something came back" -- a transcriber that returns empty strings would
    // otherwise pass.
    assert!(
        transcript.contains("country"),
        "expected recognisable speech, got: {transcript}"
    );
    assert!(
        transcript.contains("ask not") || transcript.contains("fellow americans"),
        "expected the JFK line, got: {transcript}"
    );

    // Timestamps are real, not zeroed.
    assert!(
        segments.iter().any(|s| s.end_ms > s.start_ms),
        "segments carry no duration"
    );
}

/// Cancellation reaches the real backend, not only the fake one.
#[test]
fn a_cancelled_transcription_stops_and_reports_it() {
    let model = model_path();
    if !model.exists() {
        return;
    }
    let (samples, rate, channels) = read_wav_16k_mono(&fixture());

    let engine = WhisperSpeechEngine::load(&model, 512).expect("model loads");
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048));
    supervisor.register_speech(Box::new(engine));

    let cancel = CancelToken::new();
    cancel.cancel();

    let r = supervisor.run_speech(
        AudioInput {
            samples: &samples,
            sample_rate_hz: rate,
            channels,
        },
        &cancel,
        &mut |_| Ok(()),
    );
    assert!(matches!(
        r,
        Err(airo_mind_whisper::RuntimeError::Engine(
            EngineError::Cancelled
        ))
    ));
}

/// The `secret`-class guarantee: transcription writes nothing to disk.
///
/// A CLI backend with `-otxt` would fail this, which is why the engine is
/// in-process.
#[test]
fn transcription_writes_no_files() {
    let model = model_path();
    if !model.exists() {
        return;
    }
    let dir = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../fixtures");
    let before: Vec<_> = std::fs::read_dir(&dir)
        .unwrap()
        .filter_map(|e| e.ok().map(|e| e.file_name()))
        .collect();

    let (samples, rate, channels) = read_wav_16k_mono(&fixture());
    let engine = WhisperSpeechEngine::load(&model, 512).unwrap();
    let mut supervisor = Supervisor::new(ResourceBudget::new(2048));
    supervisor.register_speech(Box::new(engine));
    let _ = supervisor.run_speech(
        AudioInput {
            samples: &samples,
            sample_rate_hz: rate,
            channels,
        },
        &CancelToken::new(),
        &mut |_| Ok(()),
    );

    let after: Vec<_> = std::fs::read_dir(&dir)
        .unwrap()
        .filter_map(|e| e.ok().map(|e| e.file_name()))
        .collect();
    assert_eq!(
        before.len(),
        after.len(),
        "transcription created a file -- meeting audio is `secret` class"
    );
}

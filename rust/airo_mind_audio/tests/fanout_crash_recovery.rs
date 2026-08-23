//! Mandatory fan-out isolation: live inference death must not kill the file.
//!
//! This is the LIVE_CAPTURE_FAN_OUT crash / failure-isolation conformance test.
//! It does not open a microphone.

use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

use airo_mind_audio::{
    preprocess_path, CaptureFanout, LiveSpeechConfig, LiveSpeechPipeline, TARGET_SAMPLE_RATE,
};
use airo_mind_core::budget::ResourceRequest;
use airo_mind_core::cancel::CancelToken;
use airo_mind_core::engine::{
    AudioInput, EngineError, SpeechEngine, TranscriptSegment, TranscriptionOptions,
};

struct FailingSpeech;

impl SpeechEngine for FailingSpeech {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(512)
    }

    fn transcribe(
        &self,
        _audio: AudioInput<'_>,
        _options: &TranscriptionOptions,
        _cancel: &CancelToken,
        _sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        Err(EngineError::Backend("forced live inference failure".into()))
    }
}

struct OkSpeech;

impl SpeechEngine for OkSpeech {
    fn resource_request(&self) -> ResourceRequest {
        ResourceRequest::new(512)
    }

    fn transcribe(
        &self,
        audio: AudioInput<'_>,
        _options: &TranscriptionOptions,
        _cancel: &CancelToken,
        sink: &mut dyn FnMut(TranscriptSegment) -> Result<(), EngineError>,
    ) -> Result<(), EngineError> {
        if audio.samples.is_empty() {
            return Ok(());
        }
        sink(TranscriptSegment::final_text(0, 100, "recovered".into()))?;
        Ok(())
    }
}

fn loud(n: usize) -> Vec<i16> {
    vec![12_000; n]
}

fn temp_wav(tag: &str) -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!(
        "airo-fanout-iso-{}-{}-{}",
        tag,
        std::process::id(),
        Instant::now().elapsed().as_nanos()
    ));
    dir.join("session.wav")
}

fn cleanup(path: &std::path::Path) {
    if let Some(dir) = path.parent() {
        let _ = std::fs::remove_dir_all(dir);
    }
}

#[test]
fn live_inference_failure_does_not_corrupt_the_recording() {
    let path = temp_wav("infer-fail");
    let mut fanout = CaptureFanout::create_file(&path).unwrap();
    let (fanout_live, rx) = fanout.with_bounded_live(8);
    fanout = fanout_live;

    let worker = thread::spawn(move || {
        let mut pipeline = LiveSpeechPipeline::new(LiveSpeechConfig::default());
        let engine = FailingSpeech;
        let cancel = CancelToken::new();
        while let Ok(chunk) = rx.recv_timeout(Duration::from_millis(200)) {
            pipeline.push_pcm(&chunk);
            let _ = pipeline.step(
                &engine,
                &TranscriptionOptions::default(),
                &cancel,
                &mut |_| Ok(()),
            );
        }
    });

    fanout
        .ingest(&loud(TARGET_SAMPLE_RATE as usize / 2))
        .unwrap();
    fanout
        .ingest(&loud(TARGET_SAMPLE_RATE as usize / 2))
        .unwrap();
    drop(fanout);
    let _ = worker.join();

    let pcm = preprocess_path(&path).expect("recorded file must remain valid");
    assert!(
        pcm.samples.len() >= TARGET_SAMPLE_RATE as usize,
        "expected a full second of PCM, got {}",
        pcm.samples.len()
    );

    let engine = OkSpeech;
    let mut text = String::new();
    engine
        .transcribe(
            AudioInput {
                samples: &pcm.samples,
                sample_rate_hz: pcm.sample_rate_hz,
                channels: pcm.channels,
            },
            &TranscriptionOptions::default(),
            &CancelToken::new(),
            &mut |seg| {
                text.push_str(&seg.text);
                Ok(())
            },
        )
        .unwrap();
    assert_eq!(text, "recovered");
    cleanup(&path);
}

#[test]
fn dropping_the_live_consumer_mid_session_leaves_a_transcribable_file() {
    let path = temp_wav("crash-live");
    let (tx, rx) = mpsc::sync_channel(4);
    let mut fanout = CaptureFanout::create_file(&path).unwrap().with_live(tx);

    fanout.ingest(&loud(800)).unwrap();
    drop(rx);

    let report = fanout
        .ingest(&loud(800))
        .expect("file ingest must survive a dead live consumer");
    assert!(report.live_dropped);
    drop(fanout);

    let pcm = preprocess_path(&path).expect("crash-durable WAV");
    assert_eq!(pcm.samples.len(), 1_600);
    cleanup(&path);
}

//! **The Milestone 2 Definition of Done, as one executable test.**
//!
//! ```text
//! Record → transcribe → generate minutes → store
//!        → close → reopen → search → open the match
//! ```
//!
//! Entirely offline. Needs both backends and both models.

#![cfg(all(feature = "whisper", feature = "llama"))]

use std::path::PathBuf;

use airo_mind_runtime::{
    AudioInput, CancelToken, GenerationRequest, LlamaGenerationEngine, Meeting, MeetingStore,
    ResourceBudget, SearchIndex, Supervisor, TranscriptSegment, WhisperSpeechEngine,
};

fn manifest(rel: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(rel)
}

/// The prompt the Meeting capability owns. In the test, because the runtime
/// knows no domains.
fn minutes_prompt(transcript: &str) -> String {
    format!(
        "<|im_start|>system\nYou are a meeting secretary. Extract Decisions and Action Items. \
         Return Markdown only. Do not invent facts.<|im_end|>\n\
         <|im_start|>user\nTranscript:\n{transcript}<|im_end|>\n\
         <|im_start|>assistant\n"
    )
}

fn read_wav(path: &std::path::Path) -> Vec<i16> {
    let bytes = std::fs::read(path).expect("fixture readable");
    let data_at = bytes
        .windows(4)
        .position(|w| w == b"data")
        .expect("wav has a data chunk")
        + 8;
    bytes[data_at..]
        .chunks_exact(2)
        .map(|p| i16::from_le_bytes([p[0], p[1]]))
        .collect()
}

#[test]
fn a_user_records_a_meeting_and_finds_it_later_offline() {
    let speech_model = manifest("models/ggml-tiny.en.bin");
    let gen_model = manifest("models/qwen2.5-0.5b-instruct-q4_k_m.gguf");
    if !speech_model.exists() || !gen_model.exists() {
        eprintln!("skipping: models not installed");
        return;
    }

    let store_path = std::env::temp_dir().join(format!("airo_journey_{}.log", std::process::id()));
    let _ = std::fs::remove_file(&store_path);

    // ---- Step 1: the app starts and registers its engines -----------------
    let mut supervisor = Supervisor::new(ResourceBudget::new(4096));
    supervisor.register_speech(Box::new(
        WhisperSpeechEngine::load(&speech_model, 512).expect("speech model"),
    ));
    supervisor.register_generation(Box::new(
        LlamaGenerationEngine::load(&gen_model, 1024, 2048).expect("generation model"),
    ));

    // ---- Step 2: record ---------------------------------------------------
    // The fixture stands in for the microphone; everything downstream is the
    // real path.
    let samples = read_wav(&manifest("tests/fixtures/jfk.wav"));

    // ---- Step 3: transcribe, offline --------------------------------------
    let mut segments: Vec<TranscriptSegment> = Vec::new();
    supervisor
        .run_speech(
            AudioInput {
                samples: &samples,
                sample_rate_hz: 16_000,
                channels: 1,
            },
            &CancelToken::new(),
            &mut |s| {
                segments.push(s);
                Ok(())
            },
        )
        .expect("transcription");
    let transcript = segments
        .iter()
        .map(|s| s.text.as_str())
        .collect::<Vec<_>>()
        .join(" ");
    assert!(
        transcript.to_lowercase().contains("country"),
        "transcript is not recognisable speech: {transcript}"
    );

    // ---- Step 4: minutes, offline -----------------------------------------
    let mut minutes = String::new();
    supervisor
        .run_generation(
            &GenerationRequest {
                prompt: minutes_prompt(&transcript),
                max_output_tokens: 128,
            },
            &CancelToken::new(),
            &mut |c| {
                minutes.push_str(&c.text);
                Ok(())
            },
        )
        .expect("generation");
    assert!(!minutes.trim().is_empty(), "no minutes produced");

    // ---- Step 5: store ----------------------------------------------------
    let meeting = Meeting {
        id: "inaugural-address".into(),
        title: "Inaugural address".into(),
        recorded_at: 1_700_000_000,
        transcript: transcript.clone(),
        minutes: minutes.clone(),
        model: "qwen2.5-0.5b-instruct-q4_k_m".into(),
    };
    MeetingStore::open(&store_path).save(&meeting).unwrap();

    // ---- Steps 6-7: close the app, reopen it ------------------------------
    // New handles for everything. Nothing survives in memory.
    let reopened_store = MeetingStore::open(&store_path);
    let all = reopened_store.all().unwrap();
    assert_eq!(all.len(), 1, "the meeting did not survive a restart");

    // The index is a Projection: rebuilt from the store on open, never stored.
    let index = SearchIndex::rebuild(&all);

    // ---- Step 8: search, and open the match -------------------------------
    let hits = index.search("country");
    assert_eq!(hits.len(), 1, "search did not find the meeting");
    assert_eq!(hits[0].meeting_id, "inaugural-address");
    assert!(
        !hits[0].snippet.is_empty(),
        "a hit must show why it matched"
    );

    let opened = reopened_store.get(&hits[0].meeting_id).unwrap().unwrap();
    assert_eq!(opened.transcript, transcript);
    assert_eq!(opened.minutes, minutes);
    assert_eq!(opened.model, "qwen2.5-0.5b-instruct-q4_k_m");

    eprintln!(
        "--- journey ---\ntranscript: {}\nminutes:\n{}\nsearch 'country' -> {} ({})\n---",
        opened.transcript.trim(),
        opened.minutes.trim(),
        hits[0].meeting_id,
        hits[0].title
    );

    let _ = std::fs::remove_file(&store_path);
}

use std::path::PathBuf;

use airo_mind_audio::{preprocess_path, TARGET_CHANNELS, TARGET_SAMPLE_RATE};

fn fixtures_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../fixtures")
}

#[test]
fn speech_m4a_becomes_16k_mono_pcm() {
    let path = fixtures_dir().join("speech.m4a");
    if !path.exists() {
        eprintln!("skip: {} not present", path.display());
        return;
    }

    let pcm = preprocess_path(&path).expect("speech.m4a preprocesses");
    assert_eq!(pcm.sample_rate_hz, TARGET_SAMPLE_RATE);
    assert_eq!(pcm.channels, TARGET_CHANNELS);
    assert!(!pcm.samples.is_empty());

    let duration_secs = pcm.samples.len() as f64 / TARGET_SAMPLE_RATE as f64;
    assert!(
        (2.0..20.0).contains(&duration_secs),
        "unexpected duration {duration_secs}s for speech.m4a"
    );
}

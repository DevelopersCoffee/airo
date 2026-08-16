use std::path::PathBuf;

use airo_mind_audio::{preprocess_path, TARGET_CHANNELS, TARGET_SAMPLE_RATE};

fn fixtures_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../fixtures")
}

/// Same hand-rolled reader `speech_offline.rs` uses for JFK.
fn read_wav_16k_mono(path: &std::path::Path) -> (Vec<i16>, u32, u16) {
    let bytes = std::fs::read(path).expect("read wav");
    let pcm = airo_mind_core::wav::decode(&bytes).expect("decode wav");
    (pcm.samples, pcm.sample_rate_hz, pcm.channels)
}

#[test]
fn jfk_wav_fast_path_matches_direct_decode() {
    let path = fixtures_dir().join("jfk.wav");
    if !path.exists() {
        eprintln!("skip: {} not present", path.display());
        return;
    }

    let (expected_samples, rate, channels) = read_wav_16k_mono(&path);
    assert_eq!(rate, TARGET_SAMPLE_RATE);
    assert_eq!(channels, TARGET_CHANNELS);

    let pcm = preprocess_path(&path).expect("jfk.wav preprocesses");
    assert_eq!(pcm.sample_rate_hz, TARGET_SAMPLE_RATE);
    assert_eq!(pcm.channels, TARGET_CHANNELS);
    assert_eq!(pcm.samples, expected_samples);
}

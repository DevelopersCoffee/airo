//! Optional local smoke test when `fixtures/meeting_001.m4a` is present.

use std::path::PathBuf;

use airo_mind_audio::{preprocess_path, TARGET_CHANNELS, TARGET_SAMPLE_RATE};

fn meeting_001_path() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../fixtures/meeting_001.m4a")
}

#[test]
fn meeting_001_voice_memo_preprocesses_when_present() {
    let path = meeting_001_path();
    if !path.exists() {
        eprintln!(
            "skip: no {} — symlink a local .m4a per airo_mind_cli README",
            path.display()
        );
        return;
    }

    let pcm = preprocess_path(&path).expect("meeting_001.m4a preprocesses");
    assert_eq!(pcm.sample_rate_hz, TARGET_SAMPLE_RATE);
    assert_eq!(pcm.channels, TARGET_CHANNELS);
    assert!(!pcm.samples.is_empty());

    let duration_secs = pcm.samples.len() as f64 / TARGET_SAMPLE_RATE as f64;
    assert!(
        duration_secs > 60.0,
        "expected a long recording, got {duration_secs}s"
    );
}

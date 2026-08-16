//! ECAPA ONNX end-to-end test — requires ONNX Runtime and pinned weights.
//!
//! Run locally:
//!   AIRO_ECAPA_E2E=1 scripts/run-ecapa-ort-tests.sh
//!   # downloads pinned weights via scripts/download-ecapa-model.sh

use std::path::PathBuf;

use airo_mind_core::wav::Pcm;
use airo_mind_diarize::{
    diarize_segments, product_diarization_strategy, DiarizationStrategy, EcapaOnnxEmbedder,
    SpeakerEmbedder,
};

fn synthetic_pcm() -> Pcm {
    let samples: Vec<i16> = (0..48_000)
        .map(|i| ((i % 200) as i16) - 100)
        .collect();
    Pcm {
        samples,
        sample_rate_hz: 16_000,
        channels: 1,
    }
}

#[test]
#[ignore = "requires ORT_LIB_LOCATION and AIRO_ECAPA_MODEL_PATH — see scripts/run-ecapa-ort-tests.sh"]
fn ecapa_onnx_produces_192_dim_normalized_embedding() {
    let model_path = std::env::var("AIRO_ECAPA_MODEL_PATH")
        .map(PathBuf::from)
        .expect("set AIRO_ECAPA_MODEL_PATH to ecapa_tdnn_tiny_int8.onnx");

    let embedder = EcapaOnnxEmbedder::try_new(model_path).expect("load ECAPA ONNX");
    let pcm = synthetic_pcm();
    let embedding = embedder
        .embed_segment(&pcm, 0, 2_000)
        .expect("embed segment");

    assert_eq!(embedding.len(), 192);
    let norm = embedding.iter().map(|x| x * x).sum::<f32>().sqrt();
    assert!((norm - 1.0).abs() < 0.01, "expected L2-normalized embedding, norm={norm}");
}

#[test]
#[ignore = "requires ORT_LIB_LOCATION and AIRO_ECAPA_MODEL_PATH — see scripts/run-ecapa-ort-tests.sh"]
fn ecapa_product_diarization_splits_or_labels_speakers() {
    let model_path = std::env::var("AIRO_ECAPA_MODEL_PATH")
        .map(PathBuf::from)
        .expect("set AIRO_ECAPA_MODEL_PATH");
    let models_dir = model_path.parent().expect("model parent dir");

    let pcm = synthetic_pcm();
    let segments = [
        airo_mind_transcript::Segment {
            id: "s0".into(),
            start_ms: 0,
            end_ms: 1_000,
            text: "hello".into(),
        },
        airo_mind_transcript::Segment {
            id: "s1".into(),
            start_ms: 1_000,
            end_ms: 2_000,
            text: "world".into(),
        },
    ];

    let strategy = product_diarization_strategy(models_dir);
    assert!(
        matches!(strategy, DiarizationStrategy::Embedding { .. }),
        "expected embedding strategy when ECAPA file is present"
    );

    let result = diarize_segments(
        &segments,
        Some(&pcm),
        strategy,
        Some(models_dir),
        None,
    )
    .expect("diarize with ECAPA");

    assert_eq!(result.segments.len(), 2);
    assert!(!result.speakers.is_empty());
}

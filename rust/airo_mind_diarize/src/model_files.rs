//! Pinned diarization model file identity — mirrors `airo_mind_core::models` pins.

use std::path::{Path, PathBuf};

/// ONNX int8 ECAPA-TDNN tiny weights (optional download). Pin syncs with Dart
/// `pinnedEcapaDiarizeModel` in `model_descriptor_adapter.dart`.
pub const ECAPA_TINY_ONNX_FILE: &str = "ecapa_tdnn_tiny_int8.onnx";

/// Returns the path when the ECAPA file is present on disk.
pub fn ecapa_model_path(models_dir: &Path) -> Option<PathBuf> {
    let path = models_dir.join(ECAPA_TINY_ONNX_FILE);
    if path.is_file() {
        Some(path)
    } else {
        None
    }
}

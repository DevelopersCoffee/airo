# airo_mind_diarize

Wave 3 on-device speaker diarization for Airo Mind.

## Pipeline

```text
audio → whisper (segments)
     → airo_mind_diarize (speaker labels)
     → Meeting IR / export
```

## ECAPA ONNX (optional)

Multi-speaker labels use vedk00 ECAPA ONNX weights (`ecapa_tdnn_tiny_int8.onnx`).
Inference is gated behind the `ecapa-ort` feature and links against ONNX Runtime
1.20 — **not** `download-binaries` (edition2024 deps on older Rust).

### Link ONNX Runtime

```bash
source scripts/install-onnxruntime.sh   # sets ORT_LIB_LOCATION
```

### Product whisper + ECAPA (desktop)

```bash
source scripts/install-onnxruntime.sh
scripts/build-whisper-ecapa-desktop.sh
```

Android cargokit builds stay on `whisper` only until ORT is bundled for arm64.

### Test

```bash
scripts/run-ecapa-ort-tests.sh
# With real weights (downloads pinned HF file once):
AIRO_ECAPA_E2E=1 scripts/run-ecapa-ort-tests.sh
```

### FRB regen (whisper bridge)

```bash
scripts/regenerate-mind-whisper-frb.sh   # requires Rust 1.88+ and cargo-expand
scripts/check-mind-whisper-frb.sh        # CI gate — bindings must match committed output
```

## Verify (no ORT)

```bash
cargo test -p airo_mind_diarize
```

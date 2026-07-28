# MediaPipe Text Embedding — API 36 Emulator Evidence

Date: 2026-07-28
Status: exploratory Android runtime evidence; not physical-device qualification

## Environment

- Host: Apple silicon macOS
- Target: `airo_api36`, API 36 ARM64 emulator
- Emulator RAM: 2560 MiB
- App package: `io.airo.app`, debug qualification entry point
- Source commit: `642e8ad6`
- Network state: Android airplane mode enabled; `Active default network: none`
- Provider: `platform_text_embeddings` Android MediaPipe adapter
- Dimensions: 384
- Model artifact: test-only converted
  `sentence-transformers/all-MiniLM-L6-v2`
- Model size: 89,970,492 bytes
- Model SHA-256:
  `f1c6526c0d31cb222f179e1897e6d64d5e9617053261f1345f8536a4eb92b870`

The model was copied into the debug app sandbox only for this run. It was not
added to source control, an APK, a release asset, or a distribution path.

## Results

| Check | Result |
| --- | --- |
| Provider cold open and integrity check | ready in 2335 ms |
| Synthetic fixture 1 | 384 values, norm 1.000000, 47 ms |
| Repeated fixture | 384 values, norm 1.000000, 42 ms |
| Synthetic fixture 3 | 384 values, norm 1.000000, 44 ms |
| Repeat determinism | cosine 1.000000 |
| Provider close behavior | subsequent request returned `provider_closed` |
| Crash/fatal log | none observed |

No vector values or synthetic fixture text were written to the qualification
log. A process-scoped search for Firebase, DataTransport, analytics, telemetry,
upload, and HTTP markers found only the debug runtime's localhost Dart VM
service URL. This aligns with the static dependency audit, but it is not a
packet-capture substitute for the required Pixel 9 network qualification.

## Cleanup

- Provider session closed successfully.
- Test model deleted from
  `/data/user/0/io.airo.app/files/qualification-minilm.tflite`.
- Staging copy deleted from
  `/data/local/tmp/qualification-minilm.tflite`.
- Qualification app process stopped.
- Airplane mode restored to off.
- Temporary Dart entry point and generated Pigeon files removed/restored.

## Qualification boundary

This proves that the real Android MediaPipe path can open the exact model,
produce unit-normalized 384-dimensional embeddings offline, and close cleanly
on an ARM64 API 36 emulator. It does not satisfy the physical Pixel 9 latency,
memory, network-capture, lifecycle, or cleanup evidence required to close
#355. Model distribution and attribution also remain unapproved.

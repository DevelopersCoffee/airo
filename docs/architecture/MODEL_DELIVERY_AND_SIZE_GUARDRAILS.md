# Model Delivery and Size Guardrails

Issue `#253` tracks reducing the full Android APK footprint before production.
The default policy is that large AI model artifacts must not be bundled into
APK, AAB, IPA, or web release bundles.

## Delivery Policy

- Large LLM and embedding artifacts must be delivered at runtime after install.
- The app may keep only tiny pinned classifiers or heuristics assets in the
  bundle when they are below the CI cap and intentionally reviewed.
- Runtime model downloads must verify metadata before activation, including
  size, checksum, runtime compatibility, and version.
- Users must be able to remove downloaded models to recover storage.
- Streaming and TV variants must continue excluding full AI runtime binaries.

## Android Release Shape

Use Android App Bundle or ABI-split artifacts for store release so users only
receive binaries for their device architecture. CI still builds arm64 APKs for
guardrail validation because those builds are deterministic and easy to compare.

The full mobile variant is allowed to produce a size report while issue `#253`
is open. Lean variants remain enforced against their size budgets.

## CI Guardrails

`scripts/check-bundled-model-artifacts.sh` scans release-bearing source paths
for common model binary extensions:

- `.gguf`, `.ggml`, `.safetensors`
- `.pt`, `.pth`, `.onnx`
- `.tflite`, `.litert`, `.task`
- `.mlmodel`, `.mlpackage`

Artifacts above `AIRO_MAX_BUNDLED_MODEL_BYTES` fail CI. The default cap is
5 MiB. Smaller artifacts pass with a warning so intentionally tiny classifiers
can be reviewed without blocking unrelated work.

`scripts/check-apk-size.sh` reports both high-level archive areas and the
largest APK entries. Use the largest-entry table to identify whether APK growth
comes from native libraries, Dart/Flutter assets, resources, or accidentally
bundled model files.

## Operational Checklist

Before adding a new local model capability:

1. Add the model to runtime delivery metadata, not to app assets.
2. Define checksum and expected byte size.
3. Add download, verify, activate, and delete flows.
4. Run the bundled model artifact guardrail.
5. Run APK size checks for the impacted Android variants.
6. Document any intentionally bundled tiny model and its reason in the PR.

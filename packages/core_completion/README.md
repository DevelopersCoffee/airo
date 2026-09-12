# core_completion

Dart completion seam for on-device GGUF: `CompletionClient.generate` streams
tokens with optional GBNF `grammar`. Product packages (Mind, later Anya) depend
on this instead of `feature_mind`.

Does not depend on `feature_mind`, `feature_anya`, or `core_ai`. Load/unload of
model files stays with the product. Chrome Prompt API / Gemini Nano are later
adapters.

See `docs/superpowers/specs/2026-09-12-core-completion-design.md` (#1991).

# ADR-0181: Platform Runtime Orchestration

## Status
Accepted

## Context
AI applications often couple their orchestration logic with a specific inference engine (like llama.cpp). This prevents dynamic engine selection, complicates hardware support, and fragments session lifecycle management. We need a way to support multiple inference backends (llama.cpp, LiteRT, Core ML, MNN, ONNX) while maintaining central control over memory, loading, and runtime decisions.

## Decision
We create `platform_runtime` as an orchestration and management layer, not an inference engine.

### Key Patterns
1. **Stateless Providers**: `RuntimeProvider` acts purely as a factory plugin. It declares its capabilities (`RuntimeDescriptor`) and creates `RuntimeSession` instances, but never manages its own lifecycle or residency logic.
2. **Stateful Sessions**: All mutable execution state (e.g., KV cache, token contexts) is constrained to `RuntimeSession`.
3. **Runtime Selection**: `RuntimeSelector` evaluates the `HardwareProfile`, the `InstalledArtifact`, and available providers in the `RuntimeRegistry` to choose the optimal inference engine dynamically.
4. **Residency Management**: `RuntimeResidencyManager` controls the eviction, preloading, and lifecycle of loaded models centrally to guarantee that system memory budgets are respected across all providers.

## Consequences
- **Positive**: Adding new backends (like LiteRT or CoreML) requires zero changes to core orchestration logic. We can confidently manage multi-modal workloads without OOM crashes.
- **Negative**: Adds a layer of indirection (Selector, Loader, Orchestrator) before generation can actually begin.

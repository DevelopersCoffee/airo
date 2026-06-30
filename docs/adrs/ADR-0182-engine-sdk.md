# ADR-0182: Platform Engine SDK

## Status
Accepted

## Context
AI inference engines (llama.cpp, LiteRT, CoreML, MNN, ONNX Runtime) all have drastically different native APIs. If the orchestration layer (`platform_runtime`) communicates with them using custom data structures, it becomes brittle and vendor-locked. Furthermore, exposing orchestration concerns to engines violates single responsibility.

## Decision
We introduce `platform_engine_sdk` to define the immutable, standardized contract that every inference engine must implement.

### Key Patterns
1. **Engine Abstraction**: A clear boundary separates the orchestrator (`platform_runtime`) from the inference implementation (`platform_engine_llama`, `platform_engine_litert`, etc.).
2. **Stateless Providers**: `EngineProvider` represents a capability and a factory. It has zero mutable execution state.
3. **Session Ownership**: `EngineSession` exclusively owns the mutable inference lifecycle (loading, KV cache, tokenizer state, streaming generation).
4. **Standard Requests & Results**: Native engine concepts are normalized into universal AIRO structures (`GenerationRequest`, `GenerationChunk`, `VisionResult`). No engine-specific types are exposed.
5. **Standardized Error Hierarchy**: All native exceptions are translated into a standardized `EngineException` hierarchy, guaranteeing consistent orchestration recovery.

## Consequences
- **Positive**: Complete vendor independence. AIRO can hot-swap from local inference to cloud inference or between LiteRT and CoreML without touching orchestration logic.
- **Negative**: Engines have to map their native types to AIRO's SDK types, adding minor mapping overhead.

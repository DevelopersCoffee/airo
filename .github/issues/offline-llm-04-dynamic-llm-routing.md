---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Extend LLMRouter to Support Multiple Offline Models'
labels: 'agent/ai-llm, agent/core-architecture, P0, enhancement'
assignees: ''
---

## Agent

**Agent:** agent/ai-llm, agent/core-architecture

## Task Details

**Estimate (hours):** 24

**Priority:** P0

## Description

Extend `LLMRouterImpl` to support dynamic routing between multiple offline LLM models (GGUF format) beyond Gemini Nano.

### Background
The current router only supports Gemini Nano for on-device inference. To enable user-configurable model selection, we need to abstract the LLM client layer.

### Source Reference
- [`src/services/llm.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/llm.ts) - llama.rn integration for GGUF models
- [`src/services/activeModelService.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/activeModelService.ts) - Active model lifecycle management

### Key Patterns from Reference
1. Singleton model loading (prevents duplicate loads)
2. Memory budget checking before load (60% of device RAM)
3. Dynamic context window management
4. GPU acceleration detection (Metal on iOS, OpenCL on Android)
5. Vision model support with mmproj files
6. Performance tracking (tokens/sec, TTFT)

### Current State
- `LLMRouterImpl` at `packages/core_ai/lib/src/llm/llm_router_impl.dart`
- Routes between `GeminiNanoClient` and `GeminiApiClient`
- `GeminiNanoClient` uses platform channel to native AI Core SDK

### Proposed Enhancement
1. Create `GGUFModelClient` implementing `LLMClient` interface
2. Integrate Flutter binding for llama.cpp (consider `flutter_llama` or custom FFI)
3. Create `ActiveModelService` for singleton model lifecycle
4. Implement memory budget checking before model load
5. Add GPU acceleration support detection
6. Extend `AIProvider` enum to support custom models
7. Update `LLMRouterImpl` to route to active offline model

### Technical Approach
```dart
// New AIProvider entries
enum AIProvider {
  nano, cloud, auto,
  gguf,  // Generic GGUF model
  gemma, // Gemma models
  phi,   // Microsoft Phi models
  custom,// User-selected model
}

// New client for GGUF models
class GGUFModelClient implements LLMClient {
  final String modelPath;
  final GGUFModelConfig config;
  // ... llama.cpp FFI integration
}
```

### User Value
- Use preferred offline model (Gemma, Phi, Llama variants)
- Leverage device GPU for faster inference
- Automatic memory management to prevent crashes

## Acceptance Criteria
- [ ] `GGUFModelClient` implementing `LLMClient` interface
- [ ] llama.cpp Flutter FFI integration working
- [ ] `ActiveModelService` with singleton pattern
- [ ] Memory budget checking (60% RAM threshold)
- [ ] GPU detection and offloading support
- [ ] `LLMRouterImpl` extended to route to GGUF models
- [ ] Vision model support (mmproj loading)
- [ ] Unit tests for new components
- [ ] Integration test with sample GGUF model

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
packages/core_ai/lib/src/llm/gguf_model_client.dart (new)
packages/core_ai/lib/src/llm/active_model_service.dart (new)
packages/core_ai/lib/src/llm/memory_manager.dart (new)
packages/core_ai/lib/src/llm/llm_router_impl.dart
packages/core_ai/lib/src/provider/ai_provider.dart
packages/core_ai/lib/core_ai.dart
app/android/app/src/main/kotlin/.../LlamaPlugin.kt (new)
app/ios/Runner/LlamaPlugin.swift (new)
```

## Dependencies
- Issue #01: Model Registry and Catalog System
- Issue #03: Model Download Manager

## Release Note Required?
yes - Support for multiple offline LLM models (GGUF format)


---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Implement Offline LLM Model Registry and Catalog System'
labels: 'agent/ai-llm, P0, enhancement'
assignees: ''
---

## Agent

**Agent:** agent/ai-llm

## Task Details

**Estimate (hours):** 16

**Priority:** P0

## Description

Create a centralized Model Registry system to manage multiple offline LLM models beyond Gemini Nano. This is the foundation for user-configurable model selection.

### Background
Currently, `core_ai` supports only a binary choice between Gemini Nano and Gemini Cloud. Analysis of [offline-mobile-llm-manager](https://github.com/alichherawalla/offline-mobile-llm-manager) reveals a robust model management pattern that we can adapt.

### Source Reference
- [`src/services/modelManager.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/modelManager.ts) - Model lifecycle management
- [`src/types/index.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/types/index.ts) - Type definitions for models

### Current State
- `AIProvider` enum only has: `nano`, `cloud`, `auto`
- `LLMRouterImpl` routes between `GeminiNanoClient` and `GeminiApiClient`
- No support for third-party GGUF models (Gemma, Phi, Llama, etc.)

### Proposed Enhancement
1. Create `OfflineModelInfo` data class with metadata (name, size, quantization, capabilities, memory requirements)
2. Create `ModelRegistry` service to manage available/downloaded models
3. Create `ModelCatalog` for discovering models from HuggingFace or bundled sources
4. Implement model credibility system (official, verified, community)
5. Add model compatibility checking based on device capabilities

### User Value
- Users can choose from multiple offline LLM options based on their device and use case
- Transparent model information (size, quality, capabilities)
- Trust indicators for model sources

## Acceptance Criteria
- [ ] `OfflineModelInfo` data class created with all necessary fields
- [ ] `ModelRegistry` interface and implementation created
- [ ] Model credibility enum and logic implemented
- [ ] Device compatibility checking implemented
- [ ] Unit tests for registry operations
- [ ] Integration with existing `AIProvider` system

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
packages/core_ai/lib/src/models/offline_model_info.dart (new)
packages/core_ai/lib/src/models/model_credibility.dart (new)
packages/core_ai/lib/src/registry/model_registry.dart (new)
packages/core_ai/lib/src/registry/model_catalog.dart (new)
packages/core_ai/lib/src/provider/ai_provider.dart
packages/core_ai/lib/core_ai.dart
packages/core_ai/test/registry/model_registry_test.dart (new)
```

## Dependencies
- None (foundational feature)

## Release Note Required?
yes - Major new feature: Support for multiple offline LLM models


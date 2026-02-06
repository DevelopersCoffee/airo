---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Integrate HuggingFace Model Discovery and Download'
labels: 'agent/ai-llm, P2, enhancement'
assignees: ''
---

## Agent

**Agent:** agent/ai-llm

## Task Details

**Estimate (hours):** 20

**Priority:** P2

## Description

Integrate HuggingFace API for discovering and downloading GGUF models, enabling users to browse a vast catalog of community models.

### Background
HuggingFace hosts thousands of GGUF-format models. The [offline-mobile-llm-manager](https://github.com/alichherawalla/offline-mobile-llm-manager) demonstrates HuggingFace integration for model discovery.

### Source Reference
- [`src/services/huggingFaceService.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/huggingFaceService.ts) - API integration
- [`src/services/huggingFaceModelBrowser.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/huggingFaceModelBrowser.ts) - Model browser logic

### Key Features from Reference
1. Model search with filters (GGUF format, downloads, likes)
2. Model file listing with quantization variants
3. Credibility detection (LM Studio, Official, Verified Quantizer)
4. Model metadata parsing (parameters, context length)
5. Vision model detection (mmproj files)

### HuggingFace API Endpoints
```
GET /api/models?search={query}&filter=gguf&sort=downloads
GET /api/models/{modelId}
GET /api/models/{modelId}/tree/{branch}
```

### Proposed Implementation
1. Create `HuggingFaceService` for API calls
2. Implement model search with GGUF filter
3. Parse model cards for metadata
4. Detect credibility (LM Studio partner, verified quantizers)
5. List quantization variants with sizes
6. Integrate with Model Browser UI
7. Cache model listings for offline use

### Credibility Detection Logic
```dart
ModelCredibility determineCredibility(HFModel model) {
  if (lmStudioPartners.contains(model.author)) return lmstudio;
  if (model.author == officialAuthor) return official;
  if (verifiedQuantizers.contains(model.author)) return verifiedQuantizer;
  return community;
}
```

### User Value
- Access to thousands of community models
- Trust indicators for model sources
- Easy discovery of new models
- Comparison of quantization variants

## Acceptance Criteria
- [ ] `HuggingFaceService` with API client
- [ ] Model search with GGUF filter
- [ ] Model metadata parsing (size, quant, params)
- [ ] Credibility detection implemented
- [ ] Quantization variant listing
- [ ] Vision model detection (mmproj)
- [ ] Offline caching of model listings
- [ ] Integration with Model Browser UI
- [ ] Unit tests for API parsing

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
packages/core_ai/lib/src/huggingface/huggingface_service.dart (new)
packages/core_ai/lib/src/huggingface/hf_model_parser.dart (new)
packages/core_ai/lib/src/huggingface/credibility_detector.dart (new)
packages/core_ai/lib/src/registry/model_catalog.dart
app/lib/features/settings/presentation/screens/ai_models_screen.dart
```

## Dependencies
- Issue #01: Model Registry and Catalog System
- Issue #02: Model Selection UI
- Issue #03: Model Download Manager

## Release Note Required?
yes - Browse and download models from HuggingFace


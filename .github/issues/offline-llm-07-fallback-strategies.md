---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Implement Graceful Fallback Strategies for Model Unavailability'
labels: 'agent/ai-llm, agent/core-architecture, P1, enhancement'
assignees: ''
---

## Agent

**Agent:** agent/ai-llm, agent/core-architecture

## Task Details

**Estimate (hours):** 12

**Priority:** P1

## Description

Implement graceful degradation when the user's selected model is unavailable, ensuring continuous AI functionality.

### Background
Users may select a model that later becomes unavailable (deleted, corrupted, insufficient memory). The system needs automatic fallback with user notification.

### Source Reference
- [`src/services/activeModelService.ts#syncWithNativeState`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/activeModelService.ts) - State reconciliation after app restart
- [`packages/core_ai/lib/src/router/ai_router.dart`](file://packages/core_ai/lib/src/router/ai_router.dart) - Current routing strategies

### Current State
- `AIRoutingStrategy` exists with 5 strategies
- `autoFallback` config option in `AIRouterConfig`
- Limited fallback logic (only nano ↔ cloud)

### Proposed Enhancement
1. Extend `AIRoutingStrategy` with new strategies:
   - `offlinePreferred` - Try offline models, fallback to cloud
   - `specificModel` - Use specific model, fallback to next best
2. Create `FallbackChain` to define fallback order
3. Implement model health checking before routing
4. Add user notification when fallback occurs
5. Persist user's fallback preferences
6. Handle edge cases: corrupted model, insufficient memory, model loading failure

### Fallback Chain Example
```dart
class FallbackChain {
  final List<AIProvider> chain;
  
  // Example: [gguf:gemma-2b, nano, cloud]
  // If Gemma 2B fails, try Nano, then Cloud
}
```

### User Value
- Uninterrupted AI experience
- Transparency about which model is being used
- Control over fallback behavior
- Graceful handling of errors

## Acceptance Criteria
- [ ] Extended `AIRoutingStrategy` with new strategies
- [ ] `FallbackChain` class implemented
- [ ] Model health check before routing
- [ ] User notification on fallback (SnackBar/Toast)
- [ ] Fallback preferences persisted
- [ ] Error handling for all failure modes
- [ ] Unit tests for fallback scenarios

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
packages/core_ai/lib/src/router/ai_router.dart
packages/core_ai/lib/src/router/fallback_chain.dart (new)
packages/core_ai/lib/src/router/model_health_checker.dart (new)
packages/core_ai/lib/src/llm/llm_router_impl.dart
app/lib/core/ai/providers/ai_providers.dart
app/lib/core/ai/widgets/fallback_notification.dart (new)
```

## Dependencies
- Issue #01: Model Registry and Catalog System
- Issue #04: Dynamic LLM Routing

## Release Note Required?
yes - Automatic fallback when selected AI model is unavailable


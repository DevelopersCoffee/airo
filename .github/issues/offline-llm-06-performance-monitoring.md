---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Add Model Performance Monitoring and Metrics'
labels: 'agent/ai-llm, agent/observability, P2, enhancement'
assignees: ''
---

## Agent

**Agent:** agent/ai-llm, agent/observability

## Task Details

**Estimate (hours):** 16

**Priority:** P2

## Description

Implement performance monitoring for LLM inference to help users understand model performance and make informed choices.

### Background
Different models have vastly different performance characteristics. The [offline-mobile-llm-manager](https://github.com/alichherawalla/offline-mobile-llm-manager) tracks detailed metrics that help users understand model behavior.

### Source Reference
- [`src/services/llm.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/llm.ts) - Performance stats tracking
- [`src/types/index.ts#GenerationMeta`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/types/index.ts)

### Key Metrics from Reference
```typescript
interface GenerationMeta {
  gpu: boolean;              // Whether GPU was used
  gpuBackend?: string;       // 'Metal', 'OpenCL', 'CPU'
  gpuLayers?: number;        // Layers offloaded to GPU
  modelName?: string;
  tokensPerSecond?: number;  // Overall including prefill
  decodeTokensPerSecond?: number; // Decode only
  timeToFirstToken?: number; // TTFT in seconds
  tokenCount?: number;
}
```

### Current State
- No performance metrics collection
- No visibility into inference speed or resource usage
- Users can't compare model performance

### Proposed Enhancement
1. Create `InferenceMetrics` data class
2. Track: tokens/sec, TTFT, decode speed, GPU usage
3. Store metrics per model for comparison
4. Add metrics display in chat UI
5. Create performance comparison view in Settings
6. Track battery/energy usage per model (if feasible)

### User Value
- Understand how fast each model responds
- Compare models objectively
- Make informed decisions about speed vs quality tradeoffs
- Identify if GPU acceleration is working

## Acceptance Criteria
- [ ] `InferenceMetrics` data class created
- [ ] Metrics collection during inference implemented
- [ ] Metrics storage per model implemented
- [ ] Metrics display in chat message UI
- [ ] Performance comparison view in Settings
- [ ] GPU usage indicator implemented
- [ ] Unit tests for metrics calculation

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
packages/core_ai/lib/src/metrics/inference_metrics.dart (new)
packages/core_ai/lib/src/metrics/metrics_collector.dart (new)
packages/core_ai/lib/src/metrics/model_performance_store.dart (new)
app/lib/features/settings/presentation/screens/model_performance_screen.dart (new)
app/lib/features/chat/presentation/widgets/message_metrics_badge.dart (new)
```

## Dependencies
- Issue #04: Dynamic LLM Routing

## Release Note Required?
yes - Performance metrics for AI model inference


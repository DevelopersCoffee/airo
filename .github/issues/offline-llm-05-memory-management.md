---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Implement Device Memory Management for LLM Loading'
labels: 'agent/ai-llm, P1, enhancement'
assignees: ''
---

## Agent

**Agent:** agent/ai-llm

## Task Details

**Estimate (hours):** 16

**Priority:** P1

## Description

Implement intelligent memory management to safely load LLM models without causing out-of-memory crashes.

### Background
Large language models require significant RAM. The [offline-mobile-llm-manager](https://github.com/alichherawalla/offline-mobile-llm-manager) implements a dynamic memory budget system that we should adapt.

### Source Reference
- [`src/services/activeModelService.ts#checkMemoryForModel`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/activeModelService.ts)
- [`src/services/hardwareService.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/hardwareService.ts)

### Key Patterns from Reference
```typescript
// Memory budget constants
const MEMORY_BUDGET_PERCENT = 0.60; // 60% of total RAM
const MEMORY_WARNING_PERCENT = 0.50; // Warning threshold
const TEXT_MODEL_OVERHEAD_MULTIPLIER = 1.5; // File size × 1.5
const IMAGE_MODEL_OVERHEAD_MULTIPLIER = 1.8; // File size × 1.8

// Severity levels
type MemorySeverity = 'safe' | 'warning' | 'critical' | 'blocked';
```

### Current State
- No memory checking before model loading
- `GeminiNanoClient` relies on native AI Core SDK memory management
- No visibility into device memory for model recommendations

### Proposed Enhancement
1. Create `DeviceCapabilityService` to query device RAM
2. Create `MemoryBudgetManager` with configurable thresholds
3. Implement pre-load memory checks with severity levels
4. Add model compatibility recommendations based on device
5. Integrate memory warnings into Model Browser UI
6. Add memory usage monitoring during inference

### Memory Estimation Formula
```dart
class MemoryBudgetManager {
  static const memoryBudgetPercent = 0.60;
  static const textModelOverhead = 1.5;
  static const imageModelOverhead = 1.8;
  
  double estimateMemoryUsage(double fileSizeBytes, ModelType type) {
    final overhead = type == ModelType.image ? imageModelOverhead : textModelOverhead;
    return fileSizeBytes * overhead;
  }
  
  MemorySeverity checkMemoryForModel(double estimatedUsage) {
    final totalRam = deviceCapability.totalRamBytes;
    final budget = totalRam * memoryBudgetPercent;
    // ... severity calculation
  }
}
```

### User Value
- Prevents app crashes from loading models too large for device
- Clear recommendations on which models will work
- Warnings before loading borderline models

## Acceptance Criteria
- [ ] `DeviceCapabilityService` with RAM detection
- [ ] `MemoryBudgetManager` with configurable thresholds
- [ ] Memory severity enum (safe, warning, critical, blocked)
- [ ] Pre-load memory check integrated into model loading
- [ ] Model compatibility indicators in UI
- [ ] Memory usage monitoring during inference
- [ ] Unit tests for memory calculations

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
packages/core_ai/lib/src/device/device_capability_service.dart (new)
packages/core_ai/lib/src/device/memory_budget_manager.dart (new)
packages/core_ai/lib/src/device/memory_severity.dart (new)
packages/core_ai/lib/src/llm/active_model_service.dart
app/lib/features/settings/presentation/widgets/model_card.dart
```

## Dependencies
- Issue #04: Dynamic LLM Routing

## Release Note Required?
yes - Smart memory management prevents crashes when loading AI models


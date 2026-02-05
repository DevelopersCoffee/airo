---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Create Model Browser and Selection UI in Settings'
labels: 'agent/mobile-ui, agent/ai-llm, P0, enhancement'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 24

**Priority:** P0

## Description

Create a user-configurable model selection interface in Settings, inspired by the [offline-mobile-llm-manager ModelsScreen](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/screens/ModelsScreen.tsx).

### Background
Users currently have limited visibility into AI model choices. The `AIProviderSelector` widget only shows 3 options (nano, cloud, auto) without model browsing capabilities.

### Source Reference
- [`src/screens/ModelsScreen.tsx`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/screens/ModelsScreen.tsx) - Comprehensive model browser UI
- [`src/components/ModelCard.tsx`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/components/ModelCard.tsx) - Model display component

### Key Features from Reference
1. Tabbed interface (Text Models / Image Models)
2. Search and filter capabilities
3. Credibility badges (LM Studio, Official, Verified, Community)
4. Model type filters (All, Text, Vision, Code, Image Gen)
5. Compatibility toggle ("Show compatible only")
6. Downloaded models section with active indicator
7. Model detail view with quantization options

### Current State
- `AIProviderSelector` widget exists at `app/lib/core/ai/widgets/ai_provider_selector.dart`
- Only shows 3 hardcoded providers
- No model browsing or downloading capability

### Proposed Enhancement
1. Create new "AI Models" section in Settings
2. Create `ModelBrowserScreen` with tabbed interface
3. Create `ModelCard` widget showing model info, size, credibility
4. Create `ModelDetailScreen` for quantization selection
5. Add compatibility indicator based on device RAM
6. Integrate with `ModelRegistry` from Issue #01

### User Value
- Browse available offline models
- Understand model capabilities and requirements
- Make informed choices about which models to use
- See downloaded models and storage usage

## Acceptance Criteria
- [ ] "AI Models" section added to Settings screen
- [ ] `ModelBrowserScreen` with search and filters implemented
- [ ] `ModelCard` widget showing model info and status
- [ ] Credibility badges displayed for each model
- [ ] Device compatibility indicator implemented
- [ ] Downloaded models shown with "Active" badge
- [ ] Widget tests added for new components
- [ ] Responsive layout for different screen sizes

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/settings/presentation/screens/ai_models_screen.dart (new)
app/lib/features/settings/presentation/screens/model_detail_screen.dart (new)
app/lib/features/settings/presentation/widgets/model_card.dart (new)
app/lib/features/settings/presentation/widgets/model_filter_bar.dart (new)
app/lib/features/settings/presentation/widgets/credibility_badge.dart (new)
app/lib/features/agent_chat/presentation/screens/profile_screen.dart
app/lib/core/ai/widgets/ai_provider_selector.dart
```

## Dependencies
- Issue #01: Model Registry and Catalog System

## Release Note Required?
yes - New Settings UI for browsing and selecting offline AI models


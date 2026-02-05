---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Add AI Model Preferences Section to Settings Screen'
labels: 'agent/mobile-ui, agent/ai-llm, P1, enhancement'
assignees: ''
---

## Agent

**Agent:** agent/mobile-ui

## Task Details

**Estimate (hours):** 12

**Priority:** P1

## Description

Add a comprehensive "AI Model Preferences" section to the Settings screen, consolidating all AI-related configuration options.

### Background
AI configuration options should be discoverable and well-organized in Settings. The current profile screen has basic settings but lacks AI model configuration.

### Source Reference
- [`src/screens/SettingsScreen.tsx`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/screens/SettingsScreen.tsx) - Settings organization
- Current app settings: `app/lib/features/agent_chat/presentation/screens/profile_screen.dart`

### Current State
- `profile_screen.dart` has basic settings (Bedtime Mode, Background Audio)
- `AIProviderSelector` exists but is accessed from chat screens
- No centralized AI preferences section

### Proposed Settings Structure
```
AI Model Preferences
├── Active Model: [Gemma 2B] → ModelBrowserScreen
├── Routing Strategy: [Offline Preferred ▼]
├── Fallback Settings →
│   ├── Enable Auto-Fallback: [ON]
│   └── Fallback Order: [Configure]
├── Performance
│   ├── GPU Acceleration: [Auto ▼]
│   ├── Thread Count: [4 ▼]
│   └── Context Length: [2048 ▼]
├── Storage
│   ├── Models: 2.3 GB used
│   ├── Clear Model Cache →
│   └── Download Location: [Internal ▼]
└── Advanced
    ├── Memory Budget: [60% ▼]
    └── Debug Logging: [OFF]
```

### User Value
- One-stop location for all AI settings
- Clear organization of related options
- Easy access to model selection
- Visibility into storage usage

## Acceptance Criteria
- [ ] "AI Model Preferences" section added to Settings
- [ ] Active model display with tap to browse
- [ ] Routing strategy selector implemented
- [ ] Fallback configuration UI implemented
- [ ] Performance settings (GPU, threads, context)
- [ ] Storage usage display with cache clear option
- [ ] Advanced settings section
- [ ] All settings persisted correctly
- [ ] Widget tests for new components

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Widget/golden tests added (if UI)
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
app/lib/features/settings/presentation/screens/settings_screen.dart
app/lib/features/settings/presentation/widgets/ai_preferences_section.dart (new)
app/lib/features/settings/presentation/widgets/routing_strategy_selector.dart (new)
app/lib/features/settings/presentation/widgets/performance_settings.dart (new)
app/lib/features/settings/presentation/widgets/storage_settings.dart (new)
app/lib/core/ai/providers/ai_settings_provider.dart (new)
```

## Dependencies
- Issue #01: Model Registry and Catalog System
- Issue #02: Model Browser UI
- Issue #07: Fallback Strategies

## Release Note Required?
yes - Comprehensive AI settings in Settings screen


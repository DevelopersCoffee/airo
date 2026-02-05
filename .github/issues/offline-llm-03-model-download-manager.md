---
name: Agent Task
about: Task for a specific agent
title: '[AGENT] Implement Model Download Manager with Background Downloads'
labels: 'agent/ai-llm, agent/offline-sync, P1, enhancement'
assignees: ''
---

## Agent

**Agent:** agent/ai-llm, agent/offline-sync

## Task Details

**Estimate (hours):** 32

**Priority:** P1

## Description

Implement a robust model download system with background download support, progress tracking, and storage management.

### Background
Downloading large LLM models (1-8GB) requires reliable background downloads that survive app suspension. The [offline-mobile-llm-manager](https://github.com/alichherawalla/offline-mobile-llm-manager) demonstrates this with Android DownloadManager integration.

### Source Reference
- [`src/services/modelManager.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/modelManager.ts) - Download orchestration
- [`src/services/backgroundDownloadService.ts`](https://github.com/alichherawalla/offline-mobile-llm-manager/blob/main/src/services/backgroundDownloadService.ts) - Native download integration
- [`android/src/main/java/.../BackgroundDownloadModule.kt`](https://github.com/alichherawalla/offline-mobile-llm-manager) - Android DownloadManager bridge

### Key Features from Reference
1. Android DownloadManager for background downloads
2. Combined download progress for vision models (main + mmproj files)
3. Download queue management
4. Progress persistence across app restarts
5. Orphaned file detection and cleanup
6. Storage usage tracking

### Current State
- No model download capability exists
- Gemini Nano is pre-installed on Pixel 9 devices

### Proposed Enhancement
1. Create `ModelDownloadService` for download orchestration
2. Implement Android platform channel for DownloadManager
3. Create iOS background download using URLSession
4. Add download progress tracking with Riverpod state
5. Implement download queue with priority support
6. Add storage management (usage tracking, cleanup)
7. Handle download resume after network interruption

### User Value
- Reliable downloads that complete even when app is backgrounded
- Clear progress indication
- Ability to pause/resume downloads
- Storage awareness before downloading

## Acceptance Criteria
- [ ] `ModelDownloadService` interface created
- [ ] Android DownloadManager platform channel implemented
- [ ] iOS URLSession background download implemented
- [ ] Download progress state management working
- [ ] Download queue with pause/resume functionality
- [ ] Storage usage tracking implemented
- [ ] Orphaned file cleanup implemented
- [ ] Unit and integration tests added

## CI Checklist
- [ ] `act` local run passed
- [ ] `flutter analyze` clean
- [ ] `flutter test` passes
- [ ] Unit tests added
- [ ] Docs/ADRs updated (if applicable)

## Files to Modify
```
packages/core_ai/lib/src/download/model_download_service.dart (new)
packages/core_ai/lib/src/download/download_progress.dart (new)
packages/core_ai/lib/src/storage/model_storage_manager.dart (new)
app/android/app/src/main/kotlin/.../ModelDownloadPlugin.kt (new)
app/ios/Runner/ModelDownloadPlugin.swift (new)
app/lib/core/ai/providers/download_providers.dart (new)
```

## Dependencies
- Issue #01: Model Registry and Catalog System

## Release Note Required?
yes - Background download support for large AI models


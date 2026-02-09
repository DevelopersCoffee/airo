## Problem

Need infrastructure to download and manage plugin bundles at runtime with proper UX.

## Requirements

### Download Features

1. **Resumable downloads** - Don't restart on network interruption
2. **Background downloads** - Continue when app is backgrounded
3. **Progress reporting** - Real-time progress for UI
4. **Bandwidth awareness** - Respect user's data preferences
5. **Parallel downloads** - Multiple plugins simultaneously
6. **Retry logic** - Exponential backoff on failures

### Storage Management

1. **Cache management** - LRU eviction when storage is low
2. **Version management** - Keep previous version for rollback
3. **Integrity checks** - Verify on every load
4. **Cleanup** - Remove orphaned files

## Technical Implementation

### Download Manager

```dart
class PluginDownloadManager {
  Future<DownloadTask> startDownload(PluginManifest manifest);
  Future<void> pauseDownload(String taskId);
  Future<void> resumeDownload(String taskId);
  Future<void> cancelDownload(String taskId);
  Stream<DownloadProgress> watchProgress(String taskId);
}

class DownloadProgress {
  final String pluginId;
  final int bytesDownloaded;
  final int totalBytes;
  final DownloadState state;
  final double speedBytesPerSecond;
  final Duration estimatedTimeRemaining;
}
```

### Storage Manager

```dart
class PluginStorageManager {
  Future<int> getAvailableSpace();
  Future<int> getUsedSpace();
  Future<List<InstalledPlugin>> getInstalledPlugins();
  Future<void> deletePlugin(String pluginId);
  Future<void> cleanupOldVersions();
  Future<void> evictLeastRecentlyUsed(int bytesToFree);
}
```

## UX Requirements

### Download UI

- Show download progress with percentage
- Show estimated time remaining
- Allow cancel at any time
- Show download speed
- Notify when complete

### Error Handling

- Network errors: Retry with backoff
- Storage full: Prompt to free space
- Corruption: Re-download
- Timeout: Resume from last position

## Acceptance Criteria

- [ ] Resumable downloads implemented
- [ ] Progress tracking with speed/ETA
- [ ] Background download support (Android WorkManager, iOS BGTask)
- [ ] LRU cache eviction
- [ ] Integrity verification on install
- [ ] Rollback to previous version on failure
- [ ] Unit tests for download manager
- [ ] Integration tests for full download flow

## Files to Create

- `packages/core_data/lib/src/plugins/download_manager.dart`
- `packages/core_data/lib/src/plugins/storage_manager.dart`
- `packages/core_data/lib/src/plugins/integrity_checker.dart`
- `app/lib/features/plugins/presentation/download_progress_widget.dart`

## Estimate

**12-16 hours**

---
Co-authored by [Augment Code](https://www.augmentcode.com/?utm_source=atlassian&utm_medium=jira_issue&utm_campaign=jira)


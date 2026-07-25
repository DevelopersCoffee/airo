import 'package:platform_history/platform_history.dart';

/// Drives CV-016's VOD resume behavior: offering a saved position to seek to
/// when a VOD item is (re)opened, and periodically persisting progress while
/// it plays. Live streams are always a no-op on both sides.
///
/// Kept separate from [VideoPlayerWidget] so the seek/save decisions are
/// unit-testable without a real engine or widget tree.
class VodResumeCoordinator {
  VodResumeCoordinator({required this.storage});

  final VodResumePositionStorage storage;

  final Set<String> _checkedChannelIds = {};
  final Map<String, Duration> _lastSavedPosition = {};

  /// The saved position to seek to for [channelId], or null when: it's a
  /// live stream, duration isn't known yet, nothing was saved, the saved
  /// position is nearly complete, or this channel was already checked this
  /// session (so a later user seek away from the resume point is never
  /// silently overridden on the next rebuild).
  Future<Duration?> maybeResumePosition({
    required String channelId,
    required bool isLiveStream,
    required Duration duration,
  }) async {
    if (isLiveStream || duration <= Duration.zero) return null;
    if (!_checkedChannelIds.add(channelId)) return null;

    final saved = await storage.getPosition(channelId);
    if (saved == null || saved.isNearlyComplete) return null;
    return saved.position;
  }

  /// Persists [position] for [channelId], throttled to at most once per
  /// [minInterval] of playback movement so every position tick doesn't
  /// trigger a storage write. A no-op for live streams or unknown duration.
  Future<void> saveProgressIfDue({
    required String channelId,
    required bool isLiveStream,
    required Duration position,
    required Duration duration,
    required DateTime now,
    Duration minInterval = const Duration(seconds: 5),
  }) async {
    if (isLiveStream || duration <= Duration.zero) return;

    final last = _lastSavedPosition[channelId];
    if (last != null && (position - last).abs() < minInterval) return;

    _lastSavedPosition[channelId] = position;
    await storage.savePosition(
      VodResumePosition(
        channelId: channelId,
        position: position,
        duration: duration,
        updatedAt: now,
      ),
    );
  }
}

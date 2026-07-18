import 'package:core_data/core_data.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bounded_recent_list_store.dart';

/// A saved playback position for a single VOD item, keyed by channel/item id.
///
/// Local-only (CV-016/CV-021 roadmap policy) -- no cross-device sync.
class VodResumePosition extends Equatable {
  const VodResumePosition({
    required this.channelId,
    required this.position,
    required this.duration,
    required this.updatedAt,
  });

  factory VodResumePosition.fromJson(Map<String, dynamic> json) {
    return VodResumePosition(
      channelId: json['channelId'] as String,
      position: Duration(milliseconds: json['positionMs'] as int),
      duration: Duration(milliseconds: json['durationMs'] as int),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String channelId;
  final Duration position;
  final Duration duration;
  final DateTime updatedAt;

  /// Fraction of [duration] already watched, clamped to [0, 1].
  double get completionRatio {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }

  /// Matches [AiroWatchProgressPolicy]'s default completion threshold
  /// (core_watch_progress) -- a position this close to the end shouldn't
  /// be offered as a resume point, it should just be treated as finished.
  bool get isNearlyComplete => completionRatio >= 0.9;

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'positionMs': position.inMilliseconds,
    'durationMs': duration.inMilliseconds,
    'updatedAt': updatedAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [channelId, position, duration, updatedAt];
}

/// Storage for VOD resume positions, one per channel/item id.
///
/// Same storage engine as [VodWatchHistoryStorage]/`RecentlyWatchedStorage`
/// (device-local [SharedPreferences] via [KeyValueStore]), under its own
/// storage key.
class VodResumePositionStorage {
  static const String _storageKey = 'vod_resume_positions';
  static const int _maxEntries = 100;

  final BoundedRecentListStore<VodResumePosition> _store;

  VodResumePositionStorage(
    SharedPreferences prefs, {
    KeyValueStore? store,
    int maxPreferenceValueBytes = kKeyValueStorePreferenceMaxValueBytes,
  }) : _store = BoundedRecentListStore<VodResumePosition>(
         store ??
             PreferencesStore(prefs, maxValueBytes: maxPreferenceValueBytes),
         storageKey: _storageKey,
         maxSize: _maxEntries,
         idOf: (item) => item.channelId,
         toJson: (item) => item.toJson(),
         fromJson: VodResumePosition.fromJson,
       );

  /// Saves [position], overwriting any existing entry for the same
  /// [VodResumePosition.channelId].
  Future<void> savePosition(VodResumePosition position) =>
      _store.addToRecent(position);

  /// The saved position for [channelId], or null if none exists.
  Future<VodResumePosition?> getPosition(String channelId) async {
    final all = await _store.getRecent();
    for (final entry in all) {
      if (entry.channelId == channelId) return entry;
    }
    return null;
  }

  Future<void> clearPosition(String channelId) =>
      _store.removeFromRecent(channelId);
}

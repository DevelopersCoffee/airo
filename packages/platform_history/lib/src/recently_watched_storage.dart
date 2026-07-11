import 'dart:convert';
import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage service for persisting recently watched IPTV channels
///
/// Uses SharedPreferences for local device storage.
/// Maintains privacy by storing data only on device.
class RecentlyWatchedStorage {
  static const String _recentKey = 'iptv_recently_watched';
  static const int _maxRecentSize = 20;

  final SharedPreferences _prefs;

  RecentlyWatchedStorage(this._prefs);

  /// Add channel to recently watched list
  ///
  /// If channel already exists, moves it to the top.
  /// Maintains max size of [_maxRecentSize] channels.
  Future<void> addToRecent(IPTVChannel channel) async {
    try {
      final recent = await getRecentlyWatched();

      // Remove if already in list (move to top)
      recent.removeWhere((c) => c.id == channel.id);

      // Add to beginning (most recent first)
      recent.insert(0, channel);

      // Trim to max size
      while (recent.length > _maxRecentSize) {
        recent.removeLast();
      }

      // Save
      await _saveRecent(recent);
    } catch (e) {
      print('[RecentlyWatchedStorage] Error adding to recent: $e');
    }
  }

  /// Get list of recently watched channels
  ///
  /// Returns channels in order of most recently watched first.
  Future<List<IPTVChannel>> getRecentlyWatched({int? limit}) async {
    try {
      final json = _prefs.getString(_recentKey);
      if (json == null) return [];

      final list = jsonDecode(json) as List;
      final channels = list
          .map((item) => IPTVChannel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (limit != null && channels.length > limit) {
        return channels.take(limit).toList();
      }
      return channels;
    } catch (e) {
      print('[RecentlyWatchedStorage] Error loading recent: $e');
      return [];
    }
  }

  /// Clear all recently watched history
  ///
  /// Used for privacy - allows users to clear their viewing history.
  Future<void> clearRecent() async {
    await _prefs.remove(_recentKey);
  }

  /// Remove a specific channel from recently watched
  Future<void> removeFromRecent(String channelId) async {
    try {
      final recent = await getRecentlyWatched();
      recent.removeWhere((c) => c.id == channelId);
      await _saveRecent(recent);
    } catch (e) {
      print('[RecentlyWatchedStorage] Error removing from recent: $e');
    }
  }

  /// Check if there are any recently watched channels
  bool hasRecentlyWatched() {
    return _prefs.containsKey(_recentKey);
  }

  /// Get the count of recently watched channels
  Future<int> getRecentCount() async {
    final recent = await getRecentlyWatched();
    return recent.length;
  }

  /// Save recently watched list to storage
  Future<void> _saveRecent(List<IPTVChannel> channels) async {
    final json = jsonEncode(channels.map((c) => c.toJson()).toList());
    await _prefs.setString(_recentKey, json);
  }
}

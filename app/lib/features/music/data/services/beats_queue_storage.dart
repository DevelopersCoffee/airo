import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/beats_queue_state.dart';
import '../../domain/models/beats_models.dart';

/// Storage service for persisting Beats queue state
class BeatsQueueStorage {
  static const String _queueKey = 'beats_queue_state';
  static const String _historyKey = 'beats_play_history';
  static const int _maxHistorySize = 50;

  final SharedPreferences _prefs;

  BeatsQueueStorage(this._prefs);

  /// Save queue state to persistent storage
  Future<void> saveQueue(BeatsQueueState state) async {
    try {
      final json = jsonEncode(state.toJson());
      await _prefs.setString(_queueKey, json);
    } catch (e) {
      print('[BeatsQueueStorage] Error saving queue: $e');
    }
  }

  /// Load queue state from persistent storage
  Future<BeatsQueueState?> loadQueue() async {
    try {
      final json = _prefs.getString(_queueKey);
      if (json == null) return null;

      final map = jsonDecode(json) as Map<String, dynamic>;
      return BeatsQueueState.fromJson(map);
    } catch (e) {
      print('[BeatsQueueStorage] Error loading queue: $e');
      return null;
    }
  }

  /// Clear saved queue
  Future<void> clearQueue() async {
    await _prefs.remove(_queueKey);
  }

  /// Add track to play history
  Future<void> addToHistory(BeatsTrack track) async {
    try {
      final history = await getHistory();

      // Remove if already in history (move to top)
      history.removeWhere((t) => t.id == track.id);

      // Add to beginning
      history.insert(0, track);

      // Trim to max size
      while (history.length > _maxHistorySize) {
        history.removeLast();
      }

      // Save
      await _saveHistory(history);
    } catch (e) {
      print('[BeatsQueueStorage] Error adding to history: $e');
    }
  }

  /// Get play history
  Future<List<BeatsTrack>> getHistory() async {
    try {
      final json = _prefs.getString(_historyKey);
      if (json == null) return [];

      final list = jsonDecode(json) as List;
      return list
          .map((item) => BeatsTrack.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[BeatsQueueStorage] Error loading history: $e');
      return [];
    }
  }

  /// Clear play history
  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
  }

  /// Save history to storage
  Future<void> _saveHistory(List<BeatsTrack> history) async {
    final json = jsonEncode(history.map((t) => t.toJson()).toList());
    await _prefs.setString(_historyKey, json);
  }

  /// Get recently played tracks (alias for getHistory)
  Future<List<BeatsTrack>> getRecentlyPlayed({int limit = 20}) async {
    final history = await getHistory();
    return history.take(limit).toList();
  }

  /// Check if queue has saved state
  bool hasSavedQueue() {
    return _prefs.containsKey(_queueKey);
  }
}

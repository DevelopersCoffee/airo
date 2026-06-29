import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/beats_models.dart';
import '../../domain/models/beats_queue_state.dart';
import '../../data/services/beats_queue_storage.dart';

/// State notifier for managing Beats queue with persistence
class BeatsQueueNotifier extends StateNotifier<BeatsQueueState> {
  final BeatsQueueStorage _storage;
  final Uuid _uuid = const Uuid();

  BeatsQueueNotifier(this._storage) : super(BeatsQueueState.empty()) {
    _loadSavedQueue();
  }

  /// Load saved queue from storage on startup
  Future<void> _loadSavedQueue() async {
    final savedQueue = await _storage.loadQueue();
    if (savedQueue != null) {
      state = savedQueue;
    }
  }

  /// Save current queue state
  Future<void> _saveQueue() async {
    await _storage.saveQueue(state);
  }

  /// Play a single track (clears queue)
  Future<void> playTrack(BeatsTrack track) async {
    state = BeatsQueueState(
      tracks: [track],
      currentIndex: 0,
      position: Duration.zero,
      repeatMode: state.repeatMode,
      shuffleEnabled: false,
      sessionId: _uuid.v4(),
      lastUpdated: DateTime.now(),
    );
    await _storage.addToHistory(track);
    await _saveQueue();
  }

  /// Play a list of tracks
  Future<void> playQueue(List<BeatsTrack> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;

    state = BeatsQueueState(
      tracks: tracks,
      currentIndex: startIndex.clamp(0, tracks.length - 1),
      position: Duration.zero,
      repeatMode: state.repeatMode,
      shuffleEnabled: false,
      sessionId: _uuid.v4(),
      lastUpdated: DateTime.now(),
      originalOrder: tracks.map((t) => t.id).toList(),
    );

    if (state.currentTrack != null) {
      await _storage.addToHistory(state.currentTrack!);
    }
    await _saveQueue();
  }

  /// Add track to end of queue
  Future<void> addToQueue(BeatsTrack track) async {
    final newTracks = [...state.tracks, track];
    final newIndex = state.currentIndex < 0 ? 0 : state.currentIndex;

    state = state.copyWith(
      tracks: newTracks,
      currentIndex: newIndex,
      lastUpdated: DateTime.now(),
    );
    await _saveQueue();
  }

  /// Add track to play next
  Future<void> addToPlayNext(BeatsTrack track) async {
    final newTracks = [...state.tracks];
    final insertIndex = state.currentIndex + 1;
    newTracks.insert(insertIndex.clamp(0, newTracks.length), track);

    state = state.copyWith(tracks: newTracks, lastUpdated: DateTime.now());
    await _saveQueue();
  }

  /// Remove track from queue
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= state.tracks.length) return;

    final newTracks = [...state.tracks]..removeAt(index);
    var newIndex = state.currentIndex;

    if (index < state.currentIndex) {
      newIndex--;
    } else if (index == state.currentIndex && newIndex >= newTracks.length) {
      newIndex = newTracks.length - 1;
    }

    state = state.copyWith(
      tracks: newTracks,
      currentIndex: newIndex,
      lastUpdated: DateTime.now(),
    );
    await _saveQueue();
  }

  /// Reorder track in queue (drag-drop)
  Future<void> reorderTrack(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= state.tracks.length) return;
    if (newIndex < 0 || newIndex > state.tracks.length) return;

    final newTracks = [...state.tracks];
    final track = newTracks.removeAt(oldIndex);

    // Adjust newIndex if moving down
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    newTracks.insert(adjustedIndex, track);

    // Adjust current index
    var newCurrentIndex = state.currentIndex;
    if (oldIndex == state.currentIndex) {
      newCurrentIndex = adjustedIndex;
    } else if (oldIndex < state.currentIndex &&
        adjustedIndex >= state.currentIndex) {
      newCurrentIndex--;
    } else if (oldIndex > state.currentIndex &&
        adjustedIndex <= state.currentIndex) {
      newCurrentIndex++;
    }

    state = state.copyWith(
      tracks: newTracks,
      currentIndex: newCurrentIndex,
      lastUpdated: DateTime.now(),
    );
    await _saveQueue();
  }

  /// Clear entire queue
  Future<void> clearQueue() async {
    state = BeatsQueueState.empty();
    await _storage.clearQueue();
  }

  /// Skip to next track
  Future<BeatsTrack?> skipToNext() async {
    if (state.isEmpty) return null;

    int nextIndex;
    if (state.repeatMode == BeatsRepeatMode.one) {
      // Repeat same track
      nextIndex = state.currentIndex;
    } else if (state.currentIndex >= state.tracks.length - 1) {
      // At end of queue
      if (state.repeatMode == BeatsRepeatMode.all) {
        nextIndex = 0; // Loop to beginning
      } else {
        return null; // No more tracks
      }
    } else {
      nextIndex = state.currentIndex + 1;
    }

    state = state.copyWith(
      currentIndex: nextIndex,
      position: Duration.zero,
      lastUpdated: DateTime.now(),
    );

    if (state.currentTrack != null) {
      await _storage.addToHistory(state.currentTrack!);
    }
    await _saveQueue();
    return state.currentTrack;
  }

  /// Skip to previous track
  Future<BeatsTrack?> skipToPrevious() async {
    if (state.isEmpty) return null;

    int prevIndex;
    if (state.repeatMode == BeatsRepeatMode.one) {
      prevIndex = state.currentIndex;
    } else if (state.currentIndex <= 0) {
      if (state.repeatMode == BeatsRepeatMode.all) {
        prevIndex = state.tracks.length - 1;
      } else {
        return null;
      }
    } else {
      prevIndex = state.currentIndex - 1;
    }

    state = state.copyWith(
      currentIndex: prevIndex,
      position: Duration.zero,
      lastUpdated: DateTime.now(),
    );

    if (state.currentTrack != null) {
      await _storage.addToHistory(state.currentTrack!);
    }
    await _saveQueue();
    return state.currentTrack;
  }

  /// Skip to specific index
  Future<BeatsTrack?> skipToIndex(int index) async {
    if (index < 0 || index >= state.tracks.length) return null;

    state = state.copyWith(
      currentIndex: index,
      position: Duration.zero,
      lastUpdated: DateTime.now(),
    );

    if (state.currentTrack != null) {
      await _storage.addToHistory(state.currentTrack!);
    }
    await _saveQueue();
    return state.currentTrack;
  }

  /// Toggle repeat mode (off -> all -> one -> off)
  void toggleRepeatMode() {
    final nextMode = BeatsRepeatMode
        .values[(state.repeatMode.index + 1) % BeatsRepeatMode.values.length];
    state = state.copyWith(repeatMode: nextMode, lastUpdated: DateTime.now());
    _saveQueue();
  }

  /// Set repeat mode
  void setRepeatMode(BeatsRepeatMode mode) {
    state = state.copyWith(repeatMode: mode, lastUpdated: DateTime.now());
    _saveQueue();
  }

  /// Toggle shuffle
  void toggleShuffle() {
    if (state.shuffleEnabled) {
      _unshuffle();
    } else {
      _shuffle();
    }
  }

  /// Enable shuffle
  void _shuffle() {
    if (state.tracks.length <= 1) return;

    final originalOrder = state.tracks.map((t) => t.id).toList();
    final currentTrack = state.currentTrack;
    final shuffled = [...state.tracks];

    // Remove current track, shuffle rest, put current at front
    if (currentTrack != null) {
      shuffled.removeWhere((t) => t.id == currentTrack.id);
    }
    shuffled.shuffle(Random());
    if (currentTrack != null) {
      shuffled.insert(0, currentTrack);
    }

    state = state.copyWith(
      tracks: shuffled,
      currentIndex: 0,
      shuffleEnabled: true,
      originalOrder: originalOrder,
      lastUpdated: DateTime.now(),
    );
    _saveQueue();
  }

  /// Disable shuffle and restore original order
  void _unshuffle() {
    if (state.originalOrder == null) {
      state = state.copyWith(shuffleEnabled: false);
      return;
    }

    final currentTrackId = state.currentTrack?.id;
    final trackMap = {for (var t in state.tracks) t.id: t};
    final restored = state.originalOrder!
        .where((id) => trackMap.containsKey(id))
        .map((id) => trackMap[id]!)
        .toList();

    final newIndex = currentTrackId != null
        ? restored.indexWhere((t) => t.id == currentTrackId)
        : 0;

    state = state.copyWith(
      tracks: restored,
      currentIndex: newIndex >= 0 ? newIndex : 0,
      shuffleEnabled: false,
      originalOrder: null,
      lastUpdated: DateTime.now(),
    );
    _saveQueue();
  }

  /// Update playback position (for resume support)
  void updatePosition(Duration position) {
    state = state.copyWith(position: position, lastUpdated: DateTime.now());
    // Don't save on every position update - too frequent
  }

  /// Save position (call periodically or on pause)
  Future<void> savePosition() async {
    await _saveQueue();
  }

  /// Get play history
  Future<List<BeatsTrack>> getHistory({int limit = 20}) async {
    return _storage.getRecentlyPlayed(limit: limit);
  }

  /// Clear play history
  Future<void> clearHistory() async {
    await _storage.clearHistory();
  }
}

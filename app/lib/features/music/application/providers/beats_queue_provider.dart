import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/beats_models.dart';
import '../../domain/models/beats_queue_state.dart';
import '../../data/services/beats_queue_storage.dart';
import '../notifiers/beats_queue_notifier.dart';
import '../../../iptv/application/providers/iptv_providers.dart'
    show sharedPreferencesProvider;

/// Provider for BeatsQueueStorage
final beatsQueueStorageProvider = Provider<BeatsQueueStorage>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return BeatsQueueStorage(prefs);
});

/// Provider for BeatsQueueNotifier - manages queue state with persistence
final beatsQueueNotifierProvider =
    StateNotifierProvider<BeatsQueueNotifier, BeatsQueueState>((ref) {
      final storage = ref.watch(beatsQueueStorageProvider);
      return BeatsQueueNotifier(storage);
    });

/// Provider for current queue
final beatsCurrentQueueProvider = Provider<List<BeatsTrack>>((ref) {
  return ref.watch(beatsQueueNotifierProvider).tracks;
});

/// Provider for current track
final beatsCurrentTrackProvider = Provider<BeatsTrack?>((ref) {
  return ref.watch(beatsQueueNotifierProvider).currentTrack;
});

/// Provider for current index
final beatsCurrentIndexProvider = Provider<int>((ref) {
  return ref.watch(beatsQueueNotifierProvider).currentIndex;
});

/// Provider for repeat mode
final beatsRepeatModeProvider = Provider<BeatsRepeatMode>((ref) {
  return ref.watch(beatsQueueNotifierProvider).repeatMode;
});

/// Provider for shuffle state
final beatsShuffleProvider = Provider<bool>((ref) {
  return ref.watch(beatsQueueNotifierProvider).shuffleEnabled;
});

/// Provider for queue length
final beatsQueueLengthProvider = Provider<int>((ref) {
  return ref.watch(beatsQueueNotifierProvider).length;
});

/// Provider for has next track
final beatsHasNextProvider = Provider<bool>((ref) {
  return ref.watch(beatsQueueNotifierProvider).hasNext;
});

/// Provider for has previous track
final beatsHasPreviousProvider = Provider<bool>((ref) {
  return ref.watch(beatsQueueNotifierProvider).hasPrevious;
});

/// Provider for play history
final beatsPlayHistoryProvider = FutureProvider<List<BeatsTrack>>((ref) async {
  final storage = ref.watch(beatsQueueStorageProvider);
  return storage.getRecentlyPlayed(limit: 20);
});

/// Provider for saved position (for resume)
final beatsSavedPositionProvider = Provider<Duration>((ref) {
  return ref.watch(beatsQueueNotifierProvider).position;
});

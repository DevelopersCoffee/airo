import 'package:airo_app/features/music/data/services/beats_queue_storage.dart';
import 'package:airo_app/features/music/domain/models/beats_models.dart';
import 'package:airo_app/features/music/domain/models/beats_queue_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const track = BeatsTrack(
    id: 'track-1',
    title: 'Focus Track',
    artist: 'Airo Beats',
    duration: Duration(minutes: 3),
    source: BeatsSource.youtube,
    sourceUrl: 'https://example.com/watch?v=track-1',
  );

  test('persists and loads queue state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = BeatsQueueStorage(prefs);
    final state = BeatsQueueState(
      tracks: const [track],
      currentIndex: 0,
      position: const Duration(seconds: 42),
      sessionId: 'session-1',
      lastUpdated: DateTime.utc(2026),
    );

    await storage.saveQueue(state);

    expect(storage.hasSavedQueue(), isTrue);
    final loaded = await storage.loadQueue();
    expect(loaded?.tracks, const [track]);
    expect(loaded?.currentIndex, 0);
    expect(loaded?.position, const Duration(seconds: 42));
  });

  test('deduplicates and trims play history', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = BeatsQueueStorage(prefs);

    for (var i = 0; i < 55; i++) {
      await storage.addToHistory(track.copyWith(id: 'track-$i'));
    }
    await storage.addToHistory(track.copyWith(id: 'track-10'));

    final history = await storage.getHistory();
    expect(history, hasLength(50));
    expect(history.first.id, 'track-10');
    expect(history.where((item) => item.id == 'track-10'), hasLength(1));
  });

  test('drops oversized queue state before persisting', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = BeatsQueueStorage(prefs, maxPreferenceValueBytes: 96);
    final oversized = BeatsQueueState(
      tracks: [track.copyWith(title: 'Track ${'x' * 128}')],
      currentIndex: 0,
      lastUpdated: DateTime.utc(2026),
    );

    await storage.saveQueue(oversized);

    expect(prefs.getString('beats_queue_state'), isNull);
    expect(await storage.loadQueue(), isNull);
  });

  test('drops oversized history entry before persisting', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = BeatsQueueStorage(prefs, maxPreferenceValueBytes: 96);

    await storage.addToHistory(track.copyWith(title: 'Track ${'x' * 128}'));

    expect(prefs.getString('beats_play_history'), isNull);
    expect(await storage.getHistory(), isEmpty);
  });
}

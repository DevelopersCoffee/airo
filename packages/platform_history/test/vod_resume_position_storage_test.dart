import 'package:flutter_test/flutter_test.dart';
import 'package:platform_history/platform_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late VodResumePositionStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = VodResumePositionStorage(prefs);
  });

  final position = VodResumePosition(
    channelId: 'movie-1',
    position: const Duration(minutes: 12),
    duration: const Duration(minutes: 90),
    updatedAt: DateTime.utc(2026, 7, 19),
  );

  test('save then get round-trips the resume position', () async {
    await storage.savePosition(position);

    final result = await storage.getPosition('movie-1');

    expect(result, position);
  });

  test('returns null when nothing is saved for that channel', () async {
    final result = await storage.getPosition('unknown');

    expect(result, isNull);
  });

  test(
    'saving again for the same channel overwrites the old position',
    () async {
      await storage.savePosition(position);
      final updated = VodResumePosition(
        channelId: 'movie-1',
        position: const Duration(minutes: 40),
        duration: const Duration(minutes: 90),
        updatedAt: DateTime.utc(2026, 7, 19, 1),
      );

      await storage.savePosition(updated);
      final result = await storage.getPosition('movie-1');

      expect(result, updated);
    },
  );

  test('clearPosition removes the saved position for that channel', () async {
    await storage.savePosition(position);

    await storage.clearPosition('movie-1');
    final result = await storage.getPosition('movie-1');

    expect(result, isNull);
  });

  test('completionRatio near 1.0 for a position close to duration', () async {
    final nearEnd = VodResumePosition(
      channelId: 'movie-2',
      position: const Duration(minutes: 85),
      duration: const Duration(minutes: 90),
      updatedAt: DateTime.utc(2026, 7, 19),
    );

    expect(nearEnd.completionRatio, closeTo(0.944, 0.01));
    expect(nearEnd.isNearlyComplete, isTrue);
    expect(position.isNearlyComplete, isFalse);
  });

  test('persists across storage instances (same prefs)', () async {
    await storage.savePosition(position);

    final restarted = VodResumePositionStorage(prefs);
    final result = await restarted.getPosition('movie-1');

    expect(result, position);
  });
}

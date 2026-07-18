import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late VodResumePositionStorage storage;
  late VodResumeCoordinator coordinator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    storage = VodResumePositionStorage(prefs);
    coordinator = VodResumeCoordinator(storage: storage);
  });

  group('maybeResumePosition', () {
    test('returns null for a live stream', () async {
      final result = await coordinator.maybeResumePosition(
        channelId: 'ch-1',
        isLiveStream: true,
        duration: const Duration(minutes: 90),
      );

      expect(result, isNull);
    });

    test('returns null when duration is unknown (zero)', () async {
      final result = await coordinator.maybeResumePosition(
        channelId: 'ch-1',
        isLiveStream: false,
        duration: Duration.zero,
      );

      expect(result, isNull);
    });

    test('returns null when nothing was saved for that channel', () async {
      final result = await coordinator.maybeResumePosition(
        channelId: 'ch-1',
        isLiveStream: false,
        duration: const Duration(minutes: 90),
      );

      expect(result, isNull);
    });

    test(
      'returns the saved position when one exists and is not near the end',
      () async {
        await storage.savePosition(
          VodResumePosition(
            channelId: 'ch-1',
            position: const Duration(minutes: 12),
            duration: const Duration(minutes: 90),
            updatedAt: DateTime.utc(2026, 7, 19),
          ),
        );

        final result = await coordinator.maybeResumePosition(
          channelId: 'ch-1',
          isLiveStream: false,
          duration: const Duration(minutes: 90),
        );

        expect(result, const Duration(minutes: 12));
      },
    );

    test('returns null when the saved position is nearly complete', () async {
      await storage.savePosition(
        VodResumePosition(
          channelId: 'ch-1',
          position: const Duration(minutes: 85),
          duration: const Duration(minutes: 90),
          updatedAt: DateTime.utc(2026, 7, 19),
        ),
      );

      final result = await coordinator.maybeResumePosition(
        channelId: 'ch-1',
        isLiveStream: false,
        duration: const Duration(minutes: 90),
      );

      expect(result, isNull);
    });

    test(
      'only offers the resume position once per channel per session',
      () async {
        await storage.savePosition(
          VodResumePosition(
            channelId: 'ch-1',
            position: const Duration(minutes: 12),
            duration: const Duration(minutes: 90),
            updatedAt: DateTime.utc(2026, 7, 19),
          ),
        );

        final first = await coordinator.maybeResumePosition(
          channelId: 'ch-1',
          isLiveStream: false,
          duration: const Duration(minutes: 90),
        );
        final second = await coordinator.maybeResumePosition(
          channelId: 'ch-1',
          isLiveStream: false,
          duration: const Duration(minutes: 90),
        );

        expect(first, const Duration(minutes: 12));
        expect(
          second,
          isNull,
          reason: 'a later seek by the user must not be overridden on rebuild',
        );
      },
    );
  });

  group('saveProgressIfDue', () {
    test('saves progress for a VOD channel', () async {
      await coordinator.saveProgressIfDue(
        channelId: 'ch-1',
        isLiveStream: false,
        position: const Duration(minutes: 5),
        duration: const Duration(minutes: 90),
        now: DateTime.utc(2026, 7, 19),
      );

      final saved = await storage.getPosition('ch-1');
      expect(saved?.position, const Duration(minutes: 5));
    });

    test('does not save progress for a live stream', () async {
      await coordinator.saveProgressIfDue(
        channelId: 'ch-1',
        isLiveStream: true,
        position: const Duration(minutes: 5),
        duration: const Duration(minutes: 90),
        now: DateTime.utc(2026, 7, 19),
      );

      final saved = await storage.getPosition('ch-1');
      expect(saved, isNull);
    });

    test('throttles repeated saves within the same channel', () async {
      await coordinator.saveProgressIfDue(
        channelId: 'ch-1',
        isLiveStream: false,
        position: const Duration(minutes: 5),
        duration: const Duration(minutes: 90),
        now: DateTime.utc(2026, 7, 19),
      );
      // Less than the 5-second throttle window -- should be a no-op.
      await coordinator.saveProgressIfDue(
        channelId: 'ch-1',
        isLiveStream: false,
        position: const Duration(minutes: 5, seconds: 2),
        duration: const Duration(minutes: 90),
        now: DateTime.utc(2026, 7, 19),
      );

      final saved = await storage.getPosition('ch-1');
      expect(saved?.position, const Duration(minutes: 5));
    });

    test('saves again once past the throttle window', () async {
      await coordinator.saveProgressIfDue(
        channelId: 'ch-1',
        isLiveStream: false,
        position: const Duration(minutes: 5),
        duration: const Duration(minutes: 90),
        now: DateTime.utc(2026, 7, 19),
      );
      await coordinator.saveProgressIfDue(
        channelId: 'ch-1',
        isLiveStream: false,
        position: const Duration(minutes: 5, seconds: 10),
        duration: const Duration(minutes: 90),
        now: DateTime.utc(2026, 7, 19),
      );

      final saved = await storage.getPosition('ch-1');
      expect(saved?.position, const Duration(minutes: 5, seconds: 10));
    });
  });
}

import 'package:airo_app/core/startup/app_startup_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deferred app startup tasks', () {
    test('schedules auth initialization after frame', () async {
      var calls = 0;
      final logs = <String>[];
      void Function(Duration timestamp)? frameCallback;

      scheduleDeferredAuthInitialization(
        initializeAuth: () async {
          calls++;
        },
        addPostFrameCallback: (callback) {
          frameCallback = callback;
        },
        log: logs.add,
      );

      expect(calls, 0);

      frameCallback!(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
      expect(
        logs,
        contains('✅ Deferred startup task completed: auth_initialization'),
      );
    });

    test('schedules feature initialization after frame', () async {
      var calls = 0;
      void Function(Duration timestamp)? frameCallback;

      scheduleDeferredFeatureInitialization(
        initializeFeatures: () async {
          calls++;
        },
        addPostFrameCallback: (callback) {
          frameCallback = callback;
        },
        log: (_) {},
      );

      expect(calls, 0);

      frameCallback!(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
    });

    test('schedules audio initialization after frame', () async {
      var calls = 0;
      void Function(Duration timestamp)? frameCallback;

      scheduleDeferredAudioInitialization(
        initializeAudio: () async {
          calls++;
        },
        addPostFrameCallback: (callback) {
          frameCallback = callback;
        },
        log: (_) {},
      );

      expect(calls, 0);

      frameCallback!(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
    });

    test('skips audio initialization on web when requested', () async {
      var calls = 0;
      var scheduled = false;

      scheduleDeferredAudioInitialization(
        initializeAudio: () async {
          calls++;
        },
        skipOnWeb: true,
        isWeb: true,
        addPostFrameCallback: (_) {
          scheduled = true;
        },
        log: (_) {},
      );

      expect(scheduled, isFalse);
      expect(calls, 0);
    });
  });
}

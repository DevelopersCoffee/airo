import 'package:core_product_shell/core_product_shell.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _testOptions = FirebaseOptions(
  apiKey: 'test-api-key',
  appId: 'test-app-id',
  messagingSenderId: 'test-sender-id',
  projectId: 'test-project-id',
);

// [AiroBootstrap.run] calls the real `runApp`, which asserts it is only ever
// invoked from inside `testWidgets`' frame-pumping machinery. These tests
// exercise the bootstrap's *ordering and policy logic*, not the widget
// engine, so every test substitutes a no-op `runWidget` (and, where relevant,
// a captured `schedulePostFrameCallback`) instead of driving a real widget
// tree through `testWidgets`.
void main() {
  group('ErrorHandlerPolicy', () {
    test('enabled calls the supplied initializer', () async {
      var initialized = false;

      await AiroBootstrap.run(
        shell: ShellId.mobile,
        errorHandler: ErrorHandlerPolicy.enabled(() => initialized = true),
        firebase: const FirebasePolicy.skip(reason: 'test'),
        composeApp: () => const SizedBox.shrink(),
        runWidget: (_) {},
      );

      expect(initialized, isTrue);
    });

    test(
      'disabled logs the required reason instead of a silent skip',
      () async {
        final logs = <String>[];

        await AiroBootstrap.run(
          shell: ShellId.coins,
          errorHandler: ErrorHandlerPolicy.disabled(
            reason: 'no bug-report deps',
          ),
          firebase: const FirebasePolicy.skip(reason: 'test'),
          composeApp: () => const SizedBox.shrink(),
          runWidget: (_) {},
          log: logs.add,
        );

        expect(
          logs,
          contains(
            '⚠️ Global error handler disabled for shell "coins": '
            'no bug-report deps',
          ),
        );
      },
    );
  });

  group('FirebasePolicy.skip', () {
    test('never touches Firebase', () async {
      var onResultCalled = false;

      await AiroBootstrap.run(
        shell: ShellId.coins,
        errorHandler: const ErrorHandlerPolicy.disabled(reason: 'test'),
        firebase: const FirebasePolicy.skip(reason: 'no firebase_core dep'),
        composeApp: () {
          onResultCalled = true;
          return const SizedBox.shrink();
        },
        runWidget: (_) {},
      );

      expect(onResultCalled, isTrue);
      expect(Firebase.apps, isEmpty);
    });
  });

  group('FirebasePolicy.blocking', () {
    test('awaits Firebase init before composeApp runs', () async {
      final events = <String>[];

      await AiroBootstrap.run(
        shell: ShellId.mobile,
        errorHandler: const ErrorHandlerPolicy.disabled(reason: 'test'),
        firebase: FirebasePolicy.blocking(
          options: _testOptions,
          isConfigured: true,
          initializeApp: () async {
            events.add('firebase');
          },
          onResult: (initialized) => events.add('onResult:$initialized'),
        ),
        composeApp: () {
          events.add('composeApp');
          return const SizedBox.shrink();
        },
        runWidget: (_) => events.add('runApp'),
      );

      expect(events, ['firebase', 'onResult:true', 'composeApp', 'runApp']);
    });

    test('skips init and reports false when not configured', () async {
      final logs = <String>[];
      var onResult = true;

      await AiroBootstrap.run(
        shell: ShellId.mobile,
        errorHandler: const ErrorHandlerPolicy.disabled(reason: 'test'),
        firebase: FirebasePolicy.blocking(
          options: _testOptions,
          isConfigured: false,
          onResult: (initialized) => onResult = initialized,
        ),
        composeApp: () => const SizedBox.shrink(),
        runWidget: (_) {},
        log: logs.add,
      );

      expect(onResult, isFalse);
      expect(
        logs,
        contains('⚠️ Firebase not configured for this platform; skipping init'),
      );
    });

    test('logs and degrades gracefully when init throws', () async {
      final logs = <String>[];
      var onResult = true;

      await AiroBootstrap.run(
        shell: ShellId.mobile,
        errorHandler: const ErrorHandlerPolicy.disabled(reason: 'test'),
        firebase: FirebasePolicy.blocking(
          options: _testOptions,
          isConfigured: true,
          initializeApp: () => throw StateError('boom'),
          onResult: (initialized) => onResult = initialized,
        ),
        composeApp: () => const SizedBox.shrink(),
        runWidget: (_) {},
        log: logs.add,
      );

      expect(onResult, isFalse);
      expect(
        logs,
        contains('⚠️ Firebase initialization failed: Bad state: boom'),
      );
    });
  });

  group('FirebasePolicy.deferred', () {
    test('never blocks composeApp / runApp', () async {
      final events = <String>[];
      void Function(Duration timestamp)? capturedFrameCallback;

      await AiroBootstrap.run(
        shell: ShellId.tv,
        errorHandler: const ErrorHandlerPolicy.disabled(reason: 'test'),
        firebase: FirebasePolicy.deferred(
          options: _testOptions,
          isConfigured: true,
          variantName: 'tvTest',
          initializeApp: () async {
            events.add('firebase');
          },
          onResult: (initialized) => events.add('onResult:$initialized'),
        ),
        composeApp: () {
          events.add('composeApp');
          return const SizedBox.shrink();
        },
        runWidget: (_) => events.add('runApp'),
        schedulePostFrameCallback: (callback) =>
            capturedFrameCallback = callback,
      );

      // Firebase init is scheduled for after the first frame, so composeApp
      // and runApp must complete first, and firebase init must not have run
      // yet — nothing has fired the captured callback.
      expect(events, ['composeApp', 'runApp']);
      expect(capturedFrameCallback, isNotNull);

      capturedFrameCallback!(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(events, ['composeApp', 'runApp', 'firebase', 'onResult:true']);
    });
  });

  group('earlyPhase / afterRunApp ordering', () {
    test(
      'runs earlyPhase before errorHandler, afterRunApp after runApp',
      () async {
        final events = <String>[];

        await AiroBootstrap.run(
          shell: ShellId.tv,
          earlyPhase: () => events.add('earlyPhase'),
          errorHandler: ErrorHandlerPolicy.enabled(
            () => events.add('errorHandler'),
          ),
          firebase: const FirebasePolicy.skip(reason: 'test'),
          composeApp: () {
            events.add('composeApp');
            return const SizedBox.shrink();
          },
          runWidget: (_) => events.add('runApp'),
          afterRunApp: () => events.add('afterRunApp'),
        );

        expect(events, [
          'earlyPhase',
          'errorHandler',
          'composeApp',
          'runApp',
          'afterRunApp',
        ]);
      },
    );
  });
}

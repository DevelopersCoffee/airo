// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:fake_async/fake_async.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

class ControllableVaultKeyManager extends VaultKeyManager {
  ControllableVaultKeyManager({
    required this.isAvailableCallback,
    required this.getDatabaseKeyCallback,
  }) : super.forTesting(
         secureStorage: InMemorySecureStorage(),
         authenticate: () async => true,
       );

  final Future<bool> Function() isAvailableCallback;
  final Future<Result<List<int>>> Function() getDatabaseKeyCallback;

  @override
  Future<bool> isEncryptionAvailable() => isAvailableCallback();

  @override
  Future<Result<List<int>>> getDatabaseKey() => getDatabaseKeyCallback();
}

void main() {
  VaultKeyManager keyManager({
    bool authenticate = true,
    bool available = true,
  }) => VaultKeyManager.forTesting(
    secureStorage: InMemorySecureStorage(),
    authenticate: () async => authenticate,
    isAvailable: () async => available,
  );

  ProviderContainer containerFor(VaultKeyManager keyManager) {
    final container = ProviderContainer(
      overrides: [vaultKeyManagerProvider.overrideWithValue(keyManager)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('VaultSessionNotifier', () {
    test('starts locked', () {
      final container = containerFor(keyManager());

      expect(container.read(vaultSessionProvider), isA<VaultLocked>());
    });

    test('unlock success transitions to unlocked', () async {
      final container = containerFor(keyManager());

      await container.read(vaultSessionProvider.notifier).unlock();

      expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());
    });

    test(
      'concurrent unlock calls do not double-prompt authentication',
      () async {
        final availability = Completer<bool>();
        var prompts = 0;
        final keyManager = VaultKeyManager.forTesting(
          secureStorage: InMemorySecureStorage(),
          authenticate: () async {
            prompts++;
            return true;
          },
          isAvailable: () => availability.future,
        );
        final container = containerFor(keyManager);
        final notifier = container.read(vaultSessionProvider.notifier);

        final firstUnlock = notifier.unlock();
        final secondUnlock = notifier.unlock();

        availability.complete(true);
        await Future.wait([firstUnlock, secondUnlock]);

        expect(prompts, 1);
        expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());
      },
    );

    test(
      'lock during pending unlock prevents stale successful unlock',
      () async {
        final keyCompleter = Completer<Result<List<int>>>();
        final returnedKey = List<int>.generate(32, (index) => index + 1);
        final keyManager = ControllableVaultKeyManager(
          isAvailableCallback: () async => true,
          getDatabaseKeyCallback: () => keyCompleter.future,
        );
        final container = containerFor(keyManager);
        final notifier = container.read(vaultSessionProvider.notifier);

        final unlockFuture = notifier.unlock();
        await Future<void>.delayed(Duration.zero);

        notifier.lock();
        keyCompleter.complete(Success(returnedKey));
        await unlockFuture;

        expect(container.read(vaultSessionProvider), isA<VaultLocked>());
        expect(returnedKey.every((byte) => byte == 0), isTrue);
        expect(await notifier.withKey((key) async => key.length), isNull);
      },
    );

    test('onAppBackground during pending unlock prevents stale successful '
        'unlock', () async {
      final keyCompleter = Completer<Result<List<int>>>();
      final returnedKey = List<int>.generate(32, (index) => index + 1);
      final keyManager = ControllableVaultKeyManager(
        isAvailableCallback: () async => true,
        getDatabaseKeyCallback: () => keyCompleter.future,
      );
      final container = containerFor(keyManager);
      final notifier = container.read(vaultSessionProvider.notifier);

      final unlockFuture = notifier.unlock();
      await Future<void>.delayed(Duration.zero);

      notifier.onAppBackground();
      keyCompleter.complete(Success(returnedKey));
      await unlockFuture;

      expect(container.read(vaultSessionProvider), isA<VaultLocked>());
      expect(returnedKey.every((byte) => byte == 0), isTrue);
      expect(await notifier.withKey((key) async => key.length), isNull);
    });

    test(
      'dispose during pending unlock zeroes a later stale key result',
      () async {
        final keyCompleter = Completer<Result<List<int>>>();
        final returnedKey = List<int>.generate(32, (index) => index + 1);
        final keyManager = ControllableVaultKeyManager(
          isAvailableCallback: () async => true,
          getDatabaseKeyCallback: () => keyCompleter.future,
        );
        final container = ProviderContainer(
          overrides: [vaultKeyManagerProvider.overrideWithValue(keyManager)],
        );
        final notifier = container.read(vaultSessionProvider.notifier);

        final unlockFuture = notifier.unlock();
        await Future<void>.delayed(Duration.zero);

        container.dispose();
        keyCompleter.complete(Success(returnedKey));
        await expectLater(unlockFuture, completes);

        expect(returnedKey.every((byte) => byte == 0), isTrue);
      },
    );

    test('availability check exception transitions to unavailable '
        'and never prompts', () async {
      var prompted = false;
      final keyManager = VaultKeyManager.forTesting(
        secureStorage: InMemorySecureStorage(),
        authenticate: () async {
          prompted = true;
          return true;
        },
        isAvailable: () async => throw StateError('availability failed'),
      );
      final container = containerFor(keyManager);

      await container.read(vaultSessionProvider.notifier).unlock();

      expect(container.read(vaultSessionProvider), isA<VaultUnavailable>());
      expect(prompted, isFalse);
    });

    test('unlock with no biometrics enrolled transitions to unavailable '
        'and never prompts', () async {
      var prompted = false;
      final keyManager = VaultKeyManager.forTesting(
        secureStorage: InMemorySecureStorage(),
        authenticate: () async {
          prompted = true;
          return true;
        },
        isAvailable: () async => false,
      );
      final container = containerFor(keyManager);

      await container.read(vaultSessionProvider.notifier).unlock();

      expect(container.read(vaultSessionProvider), isA<VaultUnavailable>());
      expect(prompted, isFalse);
    });

    test('failed biometric prompt transitions to authError', () async {
      final container = containerFor(keyManager(authenticate: false));

      await container.read(vaultSessionProvider.notifier).unlock();

      final state = container.read(vaultSessionProvider);
      expect(state, isA<VaultAuthError>());
      expect((state as VaultAuthError).failure, isA<AuthFailure>());
    });

    test(
      'withKey runs the operation while unlocked and null when locked',
      () async {
        final container = containerFor(keyManager());
        final notifier = container.read(vaultSessionProvider.notifier);

        expect(await notifier.withKey((key) async => key.length), isNull);

        await notifier.unlock();
        expect(await notifier.withKey((key) async => key.length), 32);

        notifier.lock();
        expect(await notifier.withKey((key) async => key.length), isNull);
      },
    );

    test('lock zeroes the cached DEK bytes in place', () async {
      final returnedKey = List<int>.generate(32, (index) => index + 1);
      final manager = ControllableVaultKeyManager(
        isAvailableCallback: () async => true,
        getDatabaseKeyCallback: () async => Success(returnedKey),
      );
      final container = containerFor(manager);
      final notifier = container.read(vaultSessionProvider.notifier);
      await notifier.unlock();

      expect(returnedKey.any((byte) => byte != 0), isTrue);

      notifier.lock();

      expect(returnedKey.every((byte) => byte == 0), isTrue);
      expect(container.read(vaultSessionProvider), isA<VaultLocked>());
    });

    test(
      'withKey uses an operation-owned key and zeroes it after use',
      () async {
        final container = containerFor(keyManager());
        final notifier = container.read(vaultSessionProvider.notifier);
        await notifier.unlock();

        List<int>? operationKey;
        final length = await notifier.withKey((key) async {
          operationKey = key;
          expect(key.any((byte) => byte != 0), isTrue);
          return key.length;
        });

        expect(length, 32);
        expect(operationKey!.every((byte) => byte == 0), isTrue);
        expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());
      },
    );

    test('withKey returns null when vault locks during operation', () async {
      final container = containerFor(keyManager());
      final notifier = container.read(vaultSessionProvider.notifier);
      await notifier.unlock();

      final operationStarted = Completer<void>();
      final releaseOperation = Completer<int>();
      List<int>? operationKey;
      final result = notifier.withKey((key) async {
        operationKey = key;
        operationStarted.complete();
        return releaseOperation.future;
      });
      await operationStarted.future;

      expect(operationKey!.any((byte) => byte != 0), isTrue);
      notifier.lock();
      expect(operationKey, isEmpty);
      releaseOperation.complete(7);

      expect(await result, isNull);
      expect(operationKey, isEmpty);
      expect(container.read(vaultSessionProvider), isA<VaultLocked>());
    });

    test('auto-locks after the idle timeout', () {
      fakeAsync((async) {
        final container = containerFor(keyManager());
        final notifier = container.read(vaultSessionProvider.notifier);

        notifier.unlock();
        async.flushMicrotasks();
        expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());

        async.elapse(VaultConfig.autoLockDuration);

        expect(container.read(vaultSessionProvider), isA<VaultLocked>());
      });
    });

    test('withKey interaction resets the idle timer', () {
      fakeAsync((async) {
        final container = containerFor(keyManager());
        final notifier = container.read(vaultSessionProvider.notifier);

        notifier.unlock();
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 45));
        notifier.withKey((key) async => 1);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 45));
        expect(container.read(vaultSessionProvider), isA<VaultUnlocked>());

        async.elapse(VaultConfig.autoLockDuration);
        expect(container.read(vaultSessionProvider), isA<VaultLocked>());
      });
    });

    test('onAppBackground locks an unlocked session', () async {
      final container = containerFor(keyManager());
      final notifier = container.read(vaultSessionProvider.notifier);
      await notifier.unlock();

      notifier.onAppBackground();

      expect(container.read(vaultSessionProvider), isA<VaultLocked>());
    });

    test('dispose zeroes the DEK', () {
      fakeAsync((async) {
        final manager = keyManager();
        List<int>? captured;
        final container = ProviderContainer(
          overrides: [vaultKeyManagerProvider.overrideWithValue(manager)],
        );
        final notifier = container.read(vaultSessionProvider.notifier);
        notifier.unlock();
        async.flushMicrotasks();
        notifier.withKey((key) async => captured = key);
        async.flushMicrotasks();

        container.dispose();

        expect(captured!.every((byte) => byte == 0), isTrue);
      });
    });
  });
}

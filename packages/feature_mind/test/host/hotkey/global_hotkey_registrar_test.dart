import 'package:feature_mind/src/host/hotkey/global_hotkey_port.dart';
import 'package:feature_mind/src/host/hotkey/global_hotkey_registrar.dart';
import 'package:feature_mind/src/host/hotkey/hotkey_combination.dart';
import 'package:feature_mind/src/host/hotkey/hotkey_permission_state.dart';
import 'package:feature_mind/src/host/hotkey/hotkey_registration_outcome.dart';
import 'package:feature_mind/src/host/hotkey/hotkey_request.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGlobalHotkeyPort extends Mock implements GlobalHotkeyPort {}

void main() {
  late _MockGlobalHotkeyPort port;
  final quickCapture = const HotkeyRequest(
    id: 'quick-capture',
    combination: HotkeyCombination.quickCapture,
    description: 'Open Quick Capture',
  );

  setUpAll(() {
    registerFallbackValue(quickCapture);
  });

  setUp(() {
    port = _MockGlobalHotkeyPort();
  });

  GlobalHotkeyRegistrar registrarFor(TargetPlatform platform) =>
      GlobalHotkeyRegistrar(port: port, currentPlatform: () => platform);

  group('invalid request', () {
    test('a combination with no modifiers is rejected before touching the port', () async {
      final registrar = registrarFor(TargetPlatform.macOS);
      final noModifiers = HotkeyRequest(
        id: 'bad',
        combination: const HotkeyCombination(modifiers: {}, key: 'K'),
        description: 'Bad request',
      );

      final outcome = await registrar.register(noModifiers);

      expect(outcome.status, HotkeyRegistrationStatus.failure);
      verifyNever(() => port.permissionState());
      verifyNever(() => port.register(any()));
    });
  });

  group('unsupported platform (phone/tablet)', () {
    test('permissionState short-circuits to unsupported without asking the port', () async {
      final registrar = registrarFor(TargetPlatform.android);

      expect(await registrar.permissionState(), HotkeyPermissionState.unsupported);
      verifyNever(() => port.permissionState());
    });

    test('register short-circuits to unsupported without asking the port', () async {
      final registrar = registrarFor(TargetPlatform.iOS);

      final outcome = await registrar.register(quickCapture);

      expect(outcome.status, HotkeyRegistrationStatus.unsupported);
      verifyNever(() => port.permissionState());
      verifyNever(() => port.register(any()));
      expect(registrar.registered, isEmpty);
    });
  });

  group('desktop platform, permission not determined', () {
    test('register returns permissionNotDetermined and does not call port.register', () async {
      when(() => port.permissionState())
          .thenAnswer((_) async => HotkeyPermissionState.notDetermined);
      final registrar = registrarFor(TargetPlatform.macOS);

      final outcome = await registrar.register(quickCapture);

      expect(outcome.status, HotkeyRegistrationStatus.permissionNotDetermined);
      verifyNever(() => port.register(any()));
      expect(registrar.registered, isEmpty);
    });
  });

  group('desktop platform, permission denied', () {
    test('register returns permissionDenied and does not call port.register', () async {
      when(() => port.permissionState())
          .thenAnswer((_) async => HotkeyPermissionState.denied);
      final registrar = registrarFor(TargetPlatform.macOS);

      final outcome = await registrar.register(quickCapture);

      expect(outcome.status, HotkeyRegistrationStatus.permissionDenied);
      verifyNever(() => port.register(any()));
      expect(registrar.registered, isEmpty);
    });

    test('openOsSettings delegates to the port and is never called by register itself', () async {
      when(() => port.permissionState())
          .thenAnswer((_) async => HotkeyPermissionState.denied);
      when(() => port.openOsSettings()).thenAnswer((_) async {});
      final registrar = registrarFor(TargetPlatform.macOS);

      await registrar.register(quickCapture);
      verifyNever(() => port.openOsSettings());

      await registrar.openOsSettings();
      verify(() => port.openOsSettings()).called(1);
    });
  });

  group('desktop platform, permission granted', () {
    test('a successful register adds the id to registered', () async {
      when(() => port.permissionState())
          .thenAnswer((_) async => HotkeyPermissionState.granted);
      when(() => port.register(quickCapture))
          .thenAnswer((_) async => const HotkeyRegistrationOutcome.success());
      final registrar = registrarFor(TargetPlatform.macOS);

      final outcome = await registrar.register(quickCapture);

      expect(outcome.isSuccess, isTrue);
      expect(registrar.registered.keys, contains('quick-capture'));
    });

    test('a Windows conflict is passed through and not added to registered', () async {
      when(() => port.permissionState())
          .thenAnswer((_) async => HotkeyPermissionState.granted);
      when(() => port.register(quickCapture)).thenAnswer(
        (_) async => const HotkeyRegistrationOutcome.conflict(
          'Another app already holds Win+Shift+Space.',
        ),
      );
      final registrar = registrarFor(TargetPlatform.windows);

      final outcome = await registrar.register(quickCapture);

      expect(outcome.status, HotkeyRegistrationStatus.conflict);
      expect(outcome.isRecoverableByRebind, isTrue);
      expect(registrar.registered, isEmpty);
    });

    test('unregister releases a registered id and calls the port once', () async {
      when(() => port.permissionState())
          .thenAnswer((_) async => HotkeyPermissionState.granted);
      when(() => port.register(quickCapture))
          .thenAnswer((_) async => const HotkeyRegistrationOutcome.success());
      when(() => port.unregister('quick-capture')).thenAnswer((_) async {});
      final registrar = registrarFor(TargetPlatform.macOS);

      await registrar.register(quickCapture);
      await registrar.unregister('quick-capture');

      expect(registrar.registered, isEmpty);
      verify(() => port.unregister('quick-capture')).called(1);
    });

    test('unregister on an id that was never registered is a no-op', () async {
      final registrar = registrarFor(TargetPlatform.linux);

      await registrar.unregister('never-registered');

      verifyNever(() => port.unregister(any()));
    });
  });

  group('isSupportedPlatform', () {
    test('true for macOS, Windows, and Linux', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(registrarFor(platform).isSupportedPlatform, isTrue, reason: '$platform');
      }
    });

    test('false for Android, iOS, and Fuchsia', () {
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.fuchsia,
      ]) {
        expect(registrarFor(platform).isSupportedPlatform, isFalse, reason: '$platform');
      }
    });
  });
}

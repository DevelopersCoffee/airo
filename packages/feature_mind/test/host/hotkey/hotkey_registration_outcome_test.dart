import 'package:feature_mind/src/host/hotkey/hotkey_registration_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HotkeyRegistrationOutcome', () {
    test('success is the only isSuccess case', () {
      const outcome = HotkeyRegistrationOutcome.success();
      expect(outcome.status, HotkeyRegistrationStatus.success);
      expect(outcome.isSuccess, isTrue);
      expect(outcome.isRecoverableByRebind, isFalse);
    });

    test('conflict is recoverable by rebind and not a success', () {
      const outcome = HotkeyRegistrationOutcome.conflict(
        'Another app already holds Win+Shift+Space.',
      );
      expect(outcome.status, HotkeyRegistrationStatus.conflict);
      expect(outcome.isSuccess, isFalse);
      expect(outcome.isRecoverableByRebind, isTrue);
      expect(outcome.detail, isNotEmpty);
    });

    test('permissionDenied and permissionNotDetermined are distinct', () {
      const denied = HotkeyRegistrationOutcome.permissionDenied('no');
      const notDetermined = HotkeyRegistrationOutcome.permissionNotDetermined(
        'not asked yet',
      );
      expect(denied.status, HotkeyRegistrationStatus.permissionDenied);
      expect(
        notDetermined.status,
        HotkeyRegistrationStatus.permissionNotDetermined,
      );
      expect(denied.isRecoverableByRebind, isFalse);
      expect(notDetermined.isRecoverableByRebind, isFalse);
    });

    test('unsupported and failure carry a detail and are not successes', () {
      const unsupported = HotkeyRegistrationOutcome.unsupported('no support');
      const failure = HotkeyRegistrationOutcome.failure('OS error');
      expect(unsupported.status, HotkeyRegistrationStatus.unsupported);
      expect(failure.status, HotkeyRegistrationStatus.failure);
      expect(unsupported.isSuccess, isFalse);
      expect(failure.isSuccess, isFalse);
    });
  });
}

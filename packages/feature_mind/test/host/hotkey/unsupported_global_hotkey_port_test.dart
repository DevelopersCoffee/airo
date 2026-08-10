import 'package:feature_mind/src/host/hotkey/global_hotkey_port.dart';
import 'package:feature_mind/src/host/hotkey/hotkey_combination.dart';
import 'package:feature_mind/src/host/hotkey/hotkey_permission_state.dart';
import 'package:feature_mind/src/host/hotkey/hotkey_registration_outcome.dart';
import 'package:feature_mind/src/host/hotkey/hotkey_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UnsupportedGlobalHotkeyPort', () {
    const port = UnsupportedGlobalHotkeyPort();

    test('permissionState is always unsupported', () async {
      expect(await port.permissionState(), HotkeyPermissionState.unsupported);
    });

    test('register always answers unsupported, never granted', () async {
      const request = HotkeyRequest(
        id: 'quick-capture',
        combination: HotkeyCombination.quickCapture,
        description: 'Open Quick Capture',
      );
      final outcome = await port.register(request);
      expect(outcome.status, HotkeyRegistrationStatus.unsupported);
      expect(outcome.isSuccess, isFalse);
    });

    test('unregister and openOsSettings are safe no-ops', () async {
      await port.unregister('quick-capture');
      await port.openOsSettings();
      // Reaching here without throwing is the assertion.
    });
  });
}

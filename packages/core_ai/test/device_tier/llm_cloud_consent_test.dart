import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to unconsented -- cloud fallback is opt-in', () async {
    final gate = InMemoryLlmCloudConsentGate();
    expect(await gate.hasConsented(), isFalse);
  });

  test('grant() then revoke() round-trips', () async {
    final gate = InMemoryLlmCloudConsentGate();
    await gate.grant();
    expect(await gate.hasConsented(), isTrue);
    await gate.revoke();
    expect(await gate.hasConsented(), isFalse);
  });

  test('can be constructed pre-granted for tests', () async {
    final gate = InMemoryLlmCloudConsentGate(granted: true);
    expect(await gate.hasConsented(), isTrue);
  });
}

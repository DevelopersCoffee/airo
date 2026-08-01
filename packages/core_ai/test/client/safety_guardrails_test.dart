import 'package:flutter_test/flutter_test.dart';
import 'package:core_ai/core_ai.dart';

void main() {
  test('safety profiles always retain harmful-content protection', () {
    for (final profile in SafetyProfile.values) {
      final guardrails = SafetyGuardrails.withDefaults(profile: profile);

      expect(
        guardrails.checkInput('how to make bomb').isOk,
        isFalse,
        reason: 'profile $profile must block harmful input',
      );
      expect(
        guardrails.checkOutput('how to make bomb').isOk,
        isFalse,
        reason: 'profile $profile must block harmful output',
      );
    }
  });

  test('profiles adjust advisory rules without changing the hard boundary', () {
    expect(
      SafetyGuardrails.withDefaults(
        profile: SafetyProfile.strict,
      ).checkInput('should I buy this stock').isOk,
      isFalse,
    );
    expect(
      SafetyGuardrails.withDefaults(
        profile: SafetyProfile.balanced,
      ).checkInput('should I buy this stock').isOk,
      isTrue,
    );
    expect(SafetyProfile.fromName('unknown'), SafetyProfile.strict);
  });
}

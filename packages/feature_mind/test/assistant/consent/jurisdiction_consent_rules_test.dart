import 'package:feature_mind/src/assistant/consent/jurisdiction_consent_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the unselected jurisdiction defaults to the stricter rule', () {
    // Before a person picks a jurisdiction, the gate must not assume the
    // weaker one-party posture -- that would let a two-party jurisdiction's
    // notification step be skipped by simply not choosing anything.
    expect(unselectedJurisdiction.requiresAllPartyNotification, isTrue);
  });

  test('every known jurisdiction code is unique', () {
    final codes = knownJurisdictions.map((j) => j.code).toList();
    expect(codes.toSet().length, codes.length);
  });

  test('jurisdictionByCode finds a known two-party jurisdiction', () {
    final california = jurisdictionByCode('US-CA');
    expect(california.rule, ConsentRule.twoPartyConsent);
    expect(california.requiresAllPartyNotification, isTrue);
  });

  test('jurisdictionByCode finds a known one-party jurisdiction', () {
    final uk = jurisdictionByCode('GB');
    expect(uk.rule, ConsentRule.onePartyConsent);
    expect(uk.requiresAllPartyNotification, isFalse);
  });

  test('jurisdictionByCode falls back to unselected for an unknown code', () {
    final unknown = jurisdictionByCode('does-not-exist');
    expect(unknown, unselectedJurisdiction);
  });

  test('the table contains at least one jurisdiction of each rule', () {
    // A table with only one-party (or only two-party) entries would make
    // the jurisdiction-aware branch in the consent gate dead code.
    expect(
      knownJurisdictions.any((j) => j.rule == ConsentRule.twoPartyConsent),
      isTrue,
    );
    expect(
      knownJurisdictions.any((j) => j.rule == ConsentRule.onePartyConsent),
      isTrue,
    );
  });
}

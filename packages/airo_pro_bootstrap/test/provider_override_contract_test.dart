import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart';
import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open-source bootstrap contributes no provider overrides', () {
    expect(createProviderOverrides(), isEmpty);
  });

  test('open-source prepareProEntitlements is a no-op', () async {
    await prepareProEntitlements();
    expect(createEntitlements(), isA<NoEntitlements>());
  });

  test('open-source bootstrap denies every pro feature', () {
    final entitlements = createEntitlements();

    expect(entitlements, isA<NoEntitlements>());
    for (final feature in ProFeature.values) {
      expect(entitlements.isEnabled(feature), isFalse, reason: feature.stableId);
    }
  });
}

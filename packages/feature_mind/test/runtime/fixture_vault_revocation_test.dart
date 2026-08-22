import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Revoking a device must never remove it from [VaultPort.devices] -- a
/// revoked device is evidence, not a deleted row.
///
/// Imports the runtime and its models directly rather than through
/// `package:feature_mind/feature_mind.dart`: the barrel currently fails to
/// build because of an unrelated, pre-existing gap (missing generated
/// `.freezed.dart` files under `lib/src/llama/` and `lib/src/whisper/`), and
/// this test has no business depending on either of those.
void main() {
  late FixtureMindRuntime runtime;

  setUp(() => runtime = FixtureMindRuntime());

  test('the fixture is seeded with a device already revoked', () async {
    // A revoked device must exist before any test calls revokeDevice(), or
    // "revoked devices stay listed" is only ever demonstrated on a device
    // this same test just revoked -- never on one that was revoked before
    // the surface loaded.
    final devices = await runtime.vault.devices();
    final preRevoked = devices.where((d) => d.isRevoked).toList();

    expect(
      preRevoked,
      isNotEmpty,
      reason:
          'The fixture must seed at least one already-revoked device so the '
          '"revoked devices stay listed" requirement is testable against '
          "state the test didn't just create.",
    );
    expect(preRevoked.single.name, 'MacBook · Old');
  });

  test(
    'revoking an active device keeps it in the list, marked revoked',
    () async {
      final before = await runtime.vault.devices();
      final target = before.firstWhere((d) => !d.isThisDevice && !d.isRevoked);
      final countBefore = before.length;

      await runtime.vault.revokeDevice(target.fingerprint);
      final after = await runtime.vault.devices();

      // Mutation test in spirit: a fixture whose devices() list is unaffected
      // by revokeDevice() (as it was before this fix) would let this pass for
      // the wrong reason if it only checked "still present" without also
      // checking the row actually flipped to revoked.
      expect(
        after.length,
        countBefore,
        reason: 'Revoking a device must not remove a row from the list.',
      );

      final revoked = after.firstWhere(
        (d) => d.fingerprint == target.fingerprint,
      );
      expect(
        revoked.isRevoked,
        isTrue,
        reason: 'The row must actually flip to revoked, not just survive.',
      );
      expect(revoked.name, target.name);
      expect(revoked.revokedAtMs, isNotNull);
    },
  );

  test('revoking a device does not disturb any other row', () async {
    final before = await runtime.vault.devices();
    final target = before.firstWhere((d) => !d.isThisDevice && !d.isRevoked);
    final others = before.where((d) => d.fingerprint != target.fingerprint);

    await runtime.vault.revokeDevice(target.fingerprint);
    final after = await runtime.vault.devices();

    for (final other in others) {
      final stillThere = after.firstWhere(
        (d) => d.fingerprint == other.fingerprint,
      );
      expect(stillThere, other);
    }
  });

  test('vault state reports one more revoked key after a revocation', () async {
    final before = await runtime.vault.state();
    final devices = await runtime.vault.devices();
    final target = devices.firstWhere((d) => !d.isThisDevice && !d.isRevoked);

    await runtime.vault.revokeDevice(target.fingerprint);
    final after = await runtime.vault.state();

    expect(after.revokedCount, before.revokedCount + 1);
  });

  test('DeviceFingerprint equality — the key revoke and lookups both use', () {
    const a = DeviceFingerprint('A731', '0C4E', '9982');
    const b = DeviceFingerprint('A731', '0C4E', '9982');
    const c = DeviceFingerprint('4F2A', '9C71', 'E0B3');

    expect(a, b);
    expect(a, isNot(c));
  });
}

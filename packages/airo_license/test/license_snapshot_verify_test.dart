import 'dart:convert';

import 'package:airo_license/airo_license.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

final _seed32 = List<int>.generate(32, (i) => i + 1);

LicenseSnapshot _unsigned({
  LicenseEntitlement entitlement = LicenseEntitlement.free,
}) {
  return LicenseSnapshot(
    licenseId: 'lic_test',
    productId: kDefaultAikaStreamProductId,
    installationId: 'inst_test',
    issuedAt: DateTime.utc(2026, 9, 29, 2),
    licenseType: entitlement == LicenseEntitlement.pro
        ? LicenseType.subscription
        : LicenseType.free,
    entitlement: entitlement,
    capabilities: entitlement == LicenseEntitlement.pro
        ? LicenseCapabilities({
            for (final id in AikaLicenseCapabilities.all) id: true,
          })
        : LicenseCapabilities.empty,
    isLocalOnly: false,
  );
}

Future<LicenseSnapshot> _sign(LicenseSnapshot snapshot) async {
  final pair = await Ed25519().newKeyPairFromSeed(_seed32);
  final signature = await Ed25519().sign(
    utf8.encode(licenseSnapshotCanonicalJson(snapshot)),
    keyPair: pair,
  );
  return snapshot.copyWith(signature: base64Encode(signature.bytes));
}

void main() {
  test('canonical JSON is key-sorted and omits the signature', () {
    final snapshot = _unsigned();
    expect(
      licenseSnapshotCanonicalJson(snapshot),
      '{"capabilities":{},"entitlement":"free","expires_at":null,'
      '"installation_id":"inst_test","issued_at":"2026-09-29T02:00:00Z",'
      '"license_id":"lic_test","license_type":"free","max_devices":-1,'
      '"policy_version":1,"product_id":"aika_stream","status":"active"}',
    );
  });

  test('valid signature is accepted; tampered entitlement is not', () async {
    final pair = await Ed25519().newKeyPairFromSeed(_seed32);
    final publicKey = await pair.extractPublicKey();
    final verifier = LicenseSnapshotVerifier(publicKey.bytes);

    final signed = await _sign(_unsigned(entitlement: LicenseEntitlement.pro));
    expect(await verifier.verify(signed), isTrue);
    expect(signed.hasCapability(AikaLicenseCapabilities.epgReminders), isTrue);

    final tampered = signed.copyWith(entitlement: LicenseEntitlement.free);
    expect(await verifier.verify(tampered), isFalse);
  });

  test('unsigned and local snapshots are not hosted-valid', () async {
    final pair = await Ed25519().newKeyPairFromSeed(_seed32);
    final publicKey = await pair.extractPublicKey();
    final verifier = LicenseSnapshotVerifier(publicKey.bytes);

    expect(await verifier.verify(_unsigned()), isFalse);
    expect(
      await verifier.verify(
        LicenseSnapshot(
          licenseId: 'lic_local',
          productId: kDefaultAikaStreamProductId,
          installationId: 'inst',
          issuedAt: DateTime.utc(2026, 2),
        ),
      ),
      isFalse,
    );
  });

  test('fromJson round-trips a hosted snapshot', () async {
    final signed = await _sign(_unsigned(entitlement: LicenseEntitlement.pro));
    final parsed = licenseSnapshotFromJson(licenseSnapshotToJson(signed));
    expect(parsed.licenseId, signed.licenseId);
    expect(parsed.entitlement, LicenseEntitlement.pro);
    expect(parsed.signature, signed.signature);
    expect(parsed.isLocalOnly, isFalse);
    expect(parsed.issuedAt, DateTime.utc(2026, 9, 29, 2));
  });
}

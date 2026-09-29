import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'license.dart';
import 'license_snapshot_codec.dart';

/// Verifies hosted [LicenseSnapshot.signature] with the server public key.
///
/// The private key stays on the license API. Play OSS never needs this:
/// local snapshots are unsigned and [LicenseSnapshot.isLocalOnly].
class LicenseSnapshotVerifier {
  LicenseSnapshotVerifier(this.publicKeyBytes)
    : assert(publicKeyBytes.length == 32);

  factory LicenseSnapshotVerifier.fromHex(String hex) {
    return LicenseSnapshotVerifier(_decodeHex(hex));
  }

  /// Raw 32-byte Ed25519 public key.
  final List<int> publicKeyBytes;

  Future<bool> verify(LicenseSnapshot snapshot) async {
    final signatureB64 = snapshot.signature;
    if (signatureB64 == null || signatureB64.isEmpty) return false;
    List<int> signatureBytes;
    try {
      signatureBytes = base64Decode(signatureB64);
    } catch (_) {
      return false;
    }
    if (signatureBytes.length != 64) return false;

    final publicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    return Ed25519().verify(
      utf8.encode(licenseSnapshotCanonicalJson(snapshot)),
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
  }
}

List<int> _decodeHex(String hex) {
  final normalized = hex.trim().replaceAll(RegExp(r'\s+'), '');
  if (normalized.length.isOdd) {
    throw const FormatException('hex length must be even');
  }
  return [
    for (var i = 0; i < normalized.length; i += 2)
      int.parse(normalized.substring(i, i + 2), radix: 16),
  ];
}

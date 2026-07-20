import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM field-level cipher. Each call to [encryptField] uses a fresh
/// random nonce, so encrypting identical plaintext twice yields different
/// ciphertext — this is expected, not a bug.
class FieldCipher {
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Encrypts [plaintext] with [keyBytes] (must be 32 bytes). Returns a
  /// base64-encoded string of `nonce || cipherText || mac`.
  Future<String> encryptField(String plaintext, List<int> keyBytes) async {
    final secretKey = SecretKey(keyBytes);
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    final combined = <int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return base64Encode(combined);
  }

  /// Decrypts a value produced by [encryptField]. Throws
  /// [SecretBoxAuthenticationError] if [keyBytes] is wrong or the ciphertext
  /// was tampered with.
  Future<String> decryptField(String encoded, List<int> keyBytes) async {
    final combined = base64Decode(encoded);
    const nonceLength = 12;
    const macLength = 16;

    final nonce = combined.sublist(0, nonceLength);
    final mac = combined.sublist(combined.length - macLength);
    final cipherText = combined.sublist(
      nonceLength,
      combined.length - macLength,
    );

    final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
    final secretKey = SecretKey(keyBytes);
    final plainBytes = await _algorithm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(plainBytes);
  }
}

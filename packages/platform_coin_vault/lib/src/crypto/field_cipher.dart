import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM field-level cipher, bound to a per-field associated-data
/// [context] string (e.g. `"table:column:id"`). Each call to [encryptField]
/// uses a fresh random nonce, so encrypting identical plaintext twice yields
/// different ciphertext — this is expected, not a bug. [context] is not
/// secret and is not stored — the caller must supply the exact same
/// [context] on [decryptField] that it used on [encryptField], or decryption
/// fails. This prevents ciphertext from one row/column being swapped into
/// another row/column and still decrypting successfully: GCM authenticates
/// the associated data along with the ciphertext, so a mismatched context
/// fails the MAC check just like a wrong key would.
class FieldCipher {
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Encrypts [plaintext] with [keyBytes] (must be 32 bytes), authenticated
  /// against [context]. Returns a base64-encoded string of
  /// `nonce || cipherText || mac`.
  Future<String> encryptField(
    String plaintext,
    List<int> keyBytes, {
    required String context,
  }) async {
    final secretKey = SecretKey(keyBytes);
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
      aad: utf8.encode(context),
    );

    final combined = <int>[
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return base64Encode(combined);
  }

  /// Decrypts a value produced by [encryptField]. [context] must exactly
  /// match the context used to encrypt it. Throws
  /// [SecretBoxAuthenticationError] if [keyBytes] or [context] is wrong, or
  /// the ciphertext was tampered with.
  Future<String> decryptField(
    String encoded,
    List<int> keyBytes, {
    required String context,
  }) async {
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
    final plainBytes = await _algorithm.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: utf8.encode(context),
    );
    return utf8.decode(plainBytes);
  }
}

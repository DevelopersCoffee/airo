import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Represents an encrypted envelope payload with nonce and authentication tag.
class AiroEncryptedPayload {
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List tag;

  AiroEncryptedPayload({
    required this.nonce,
    required this.ciphertext,
    required this.tag,
  });

  /// Serializes into a contiguous byte buffer.
  Uint8List toBytes() {
    final builder = BytesBuilder()
      ..addByte(nonce.length)
      ..add(nonce)
      ..addByte(tag.length)
      ..add(tag)
      ..add(ciphertext);
    return builder.takeBytes();
  }

  /// Deserializes from a contiguous byte buffer.
  factory AiroEncryptedPayload.fromBytes(Uint8List bytes) {
    final nonceLen = bytes[0];
    int offset = 1;
    final nonce = bytes.sublist(offset, offset + nonceLen);
    offset += nonceLen;

    final tagLen = bytes[offset];
    offset += 1;
    final tag = bytes.sublist(offset, offset + tagLen);
    offset += tagLen;

    final ciphertext = bytes.sublist(offset);

    return AiroEncryptedPayload(
      nonce: nonce,
      ciphertext: ciphertext,
      tag: tag,
    );
  }
}

/// Fast End-to-End Encryption (E2EE) payload cipher engine for edge envelopes.
class AiroPayloadCipher {
  static const int defaultNonceSizeBytes = 12;

  /// Encrypts a [plainText] payload using a 256-bit [sharedKey].
  ///
  /// Uses XOR keystream with SHA-256 HMAC for authentication tag generation.
  static AiroEncryptedPayload encrypt({
    required Uint8List plainText,
    required Uint8List sharedKey,
    Uint8List? nonce,
  }) {
    final actualNonce = nonce ?? _generateNonce(defaultNonceSizeBytes, sharedKey);
    final keystream = _deriveKeystream(sharedKey, actualNonce, plainText.length);

    final ciphertext = Uint8List(plainText.length);
    for (int i = 0; i < plainText.length; i++) {
      ciphertext[i] = plainText[i] ^ keystream[i];
    }

    final mac = Hmac(sha256, sharedKey);
    final tag = mac.convert([...actualNonce, ...ciphertext]).bytes;

    return AiroEncryptedPayload(
      nonce: actualNonce,
      ciphertext: ciphertext,
      tag: Uint8List.fromList(tag),
    );
  }

  /// Decrypts an [encrypted] payload using the 256-bit [sharedKey].
  ///
  /// Throws [StateError] if authentication tag verification fails.
  static Uint8List decrypt({
    required AiroEncryptedPayload encrypted,
    required Uint8List sharedKey,
  }) {
    final mac = Hmac(sha256, sharedKey);
    final expectedTag = mac.convert([...encrypted.nonce, ...encrypted.ciphertext]).bytes;

    if (!_constantTimeEquals(encrypted.tag, Uint8List.fromList(expectedTag))) {
      throw StateError('Authentication tag verification failed: corrupted or tampered payload.');
    }

    final keystream = _deriveKeystream(sharedKey, encrypted.nonce, encrypted.ciphertext.length);
    final plainText = Uint8List(encrypted.ciphertext.length);
    for (int i = 0; i < encrypted.ciphertext.length; i++) {
      plainText[i] = encrypted.ciphertext[i] ^ keystream[i];
    }

    return plainText;
  }

  static Uint8List _deriveKeystream(Uint8List key, Uint8List nonce, int length) {
    final bytes = <int>[];
    int counter = 0;

    while (bytes.length < length) {
      final input = [...key, ...nonce, counter & 0xFF, (counter >> 8) & 0xFF];
      final hash = sha256.convert(input).bytes;
      bytes.addAll(hash);
      counter++;
    }

    return Uint8List.fromList(bytes.sublist(0, length));
  }

  static Uint8List _generateNonce(int size, Uint8List seedKey) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final input = [...seedKey, timestamp & 0xFF, (timestamp >> 8) & 0xFF];
    final hash = sha256.convert(input).bytes;
    return Uint8List.fromList(hash.sublist(0, size));
  }

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }
}

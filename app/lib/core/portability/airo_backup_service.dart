import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

/// Encrypted, portable Airo Mind backup envelope.
///
/// The payload is authenticated with AES-256-GCM and the passphrase is
/// expanded with PBKDF2. No plaintext model prompts or settings are written.
class AiroBackupService {
  static const _format = 'airo-backup-v1';
  static const _aad = 'airo-mind-backup-v1';
  static const _iterations = 120000;
  static final _cipher = AesGcm.with256bits();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  Future<String> encrypt(
    Map<String, Object?> payload,
    String passphrase,
  ) async {
    _validatePassphrase(passphrase);
    final salt = _cipher.newNonce();
    final key = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final plaintext = utf8.encode(jsonEncode(payload));
    final nonce = _cipher.newNonce();
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
      aad: utf8.encode(_aad),
    );
    return jsonEncode({
      'format': _format,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<Map<String, Object?>> decrypt(
    String encoded,
    String passphrase,
  ) async {
    _validatePassphrase(passphrase);
    final envelope = jsonDecode(encoded);
    if (envelope is! Map) {
      throw const FormatException('Invalid Airo backup envelope');
    }
    if (envelope['format'] != _format) {
      throw const FormatException('Unsupported Airo backup format');
    }
    try {
      final salt = base64Decode(envelope['salt'] as String);
      final nonce = base64Decode(envelope['nonce'] as String);
      final cipherText = base64Decode(envelope['cipherText'] as String);
      final mac = base64Decode(envelope['mac'] as String);
      final key = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(passphrase)),
        nonce: salt,
      );
      final plaintext = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
        aad: utf8.encode(_aad),
      );
      final payload = jsonDecode(utf8.decode(plaintext));
      if (payload is! Map) {
        throw const FormatException('Invalid backup payload');
      }
      return payload.cast<String, Object?>();
    } on SecretBoxAuthenticationError {
      throw const FormatException('Incorrect passphrase or modified backup');
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('Could not decrypt this backup');
    }
  }

  Future<File> writeExport({
    required Directory directory,
    required Map<String, Object?> payload,
    required String passphrase,
  }) async {
    if (!await directory.exists()) await directory.create(recursive: true);
    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      ':',
      '-',
    );
    final file = File('${directory.path}/airo-mind-$timestamp.airobackup');
    await file.writeAsString(await encrypt(payload, passphrase), flush: true);
    return file;
  }

  void _validatePassphrase(String passphrase) {
    if (passphrase.trim().length < 8) {
      throw const FormatException(
        'Use a passphrase with at least 8 characters',
      );
    }
  }
}

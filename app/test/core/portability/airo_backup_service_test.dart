import 'dart:convert';
import 'dart:io';

import 'package:airo_app/core/portability/airo_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The backup envelope is the only thing standing between an exported Airo
/// vault and whoever ends up holding the file, so every rejection path here is
/// a security boundary: a tampered or wrong-key envelope has to fail closed
/// rather than return partial plaintext.
void main() {
  const passphrase = 'correct horse battery staple';
  const payload = {'scope': 'airo-mind', 'value': 'private'};

  group('round trip', () {
    test('an encrypted envelope decrypts back to the same payload', () async {
      final service = AiroBackupService();
      final encoded = await service.encrypt(payload, passphrase);

      expect(
        encoded,
        isNot(contains('private')),
        reason: 'the envelope must not carry plaintext payload values',
      );
      expect(await service.decrypt(encoded, passphrase), payload);
    });

    test(
      'the same payload encrypts to a different envelope each time',
      () async {
        final service = AiroBackupService();
        final first = await service.encrypt(payload, passphrase);
        final second = await service.encrypt(payload, passphrase);

        expect(
          jsonDecode(first)['cipherText'],
          isNot(jsonDecode(second)['cipherText']),
          reason:
              'a fresh salt and nonce per export is what stops two exports from '
              'being comparable ciphertexts',
        );
      },
    );
  });

  group('rejects envelopes it cannot trust', () {
    test('a tampered ciphertext is refused, not partially decoded', () async {
      final service = AiroBackupService();
      final envelope =
          jsonDecode(await service.encrypt(payload, passphrase))
              as Map<String, Object?>;

      // Flip one byte of ciphertext. The MAC covers it, so this must be
      // indistinguishable from a wrong passphrase.
      final cipher = base64Decode(envelope['cipherText']! as String);
      cipher[0] ^= 0x01;
      envelope['cipherText'] = base64Encode(cipher);

      await expectLater(
        service.decrypt(jsonEncode(envelope), passphrase),
        throwsA(isA<FormatException>()),
      );
    });

    test('a wrong passphrase is refused', () async {
      final service = AiroBackupService();
      final encoded = await service.encrypt(payload, passphrase);

      await expectLater(
        service.decrypt(encoded, 'a different passphrase'),
        throwsA(isA<FormatException>()),
      );
    });

    test('a non-object envelope is refused', () async {
      await expectLater(
        AiroBackupService().decrypt(jsonEncode([1, 2, 3]), passphrase),
        throwsA(isA<FormatException>()),
      );
    });

    test('an envelope from an unknown format version is refused', () async {
      final service = AiroBackupService();
      final envelope =
          jsonDecode(await service.encrypt(payload, passphrase))
              as Map<String, Object?>;
      envelope['format'] = 'airo-backup-from-the-future';

      await expectLater(
        service.decrypt(jsonEncode(envelope), passphrase),
        throwsA(isA<FormatException>()),
        reason:
            'reading an unknown layout with the current parser is how a format '
            'change turns into a silent wrong-data import',
      );
    });

    test('a structurally valid envelope with junk fields is refused', () async {
      final encoded = jsonEncode({
        'format': jsonDecode(
          await AiroBackupService().encrypt(payload, passphrase),
        )['format'],
        'salt': 'not-base64!!',
        'nonce': 'not-base64!!',
        'cipherText': 'not-base64!!',
        'mac': 'not-base64!!',
      });

      await expectLater(
        AiroBackupService().decrypt(encoded, passphrase),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('passphrase floor', () {
    test('a short passphrase is refused on both encrypt and decrypt', () async {
      final service = AiroBackupService();

      await expectLater(
        service.encrypt(payload, 'short'),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        service.decrypt('{}', '  spaces  '),
        throwsA(isA<FormatException>()),
        reason: 'whitespace must not count toward the minimum length',
      );
    });
  });

  group('writeExport', () {
    test('creates the target directory and writes a readable backup', () async {
      final root = await Directory.systemTemp.createTemp('airo-backup-test');
      addTearDown(() => root.delete(recursive: true));
      final target = Directory('${root.path}/nested/exports');

      final service = AiroBackupService();
      final file = await service.writeExport(
        directory: target,
        payload: payload,
        passphrase: passphrase,
      );

      expect(await file.exists(), isTrue);
      expect(file.path, endsWith('.airobackup'));
      expect(
        await service.decrypt(await file.readAsString(), passphrase),
        payload,
        reason: 'an exported file has to be importable by the same service',
      );
    });
  });
}

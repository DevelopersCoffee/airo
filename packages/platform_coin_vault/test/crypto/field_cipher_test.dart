import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/crypto/field_cipher.dart';

void main() {
  late FieldCipher cipher;
  late List<int> keyBytes;

  setUp(() {
    cipher = FieldCipher();
    keyBytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  });

  group('FieldCipher', () {
    test('decrypting an encrypted value returns the original plaintext', () async {
      const plaintext = '1234567890';

      final encrypted = await cipher.encryptField(plaintext, keyBytes);
      final decrypted = await cipher.decryptField(encrypted, keyBytes);

      expect(decrypted, plaintext);
    });

    test('encrypted output differs from plaintext', () async {
      const plaintext = 'ABCDE1234F';

      final encrypted = await cipher.encryptField(plaintext, keyBytes);

      expect(encrypted, isNot(contains(plaintext)));
    });

    test('same plaintext encrypted twice yields different ciphertext (random nonce)', () async {
      const plaintext = 'repeat-me';

      final first = await cipher.encryptField(plaintext, keyBytes);
      final second = await cipher.encryptField(plaintext, keyBytes);

      expect(first, isNot(equals(second)));
    });

    test('decrypting with the wrong key throws', () async {
      const plaintext = 'secret-value';
      final wrongKey = List<int>.generate(32, (_) => Random.secure().nextInt(256));

      final encrypted = await cipher.encryptField(plaintext, keyBytes);

      expect(() => cipher.decryptField(encrypted, wrongKey), throwsA(anything));
    });

    test('roundtrips empty string', () async {
      final encrypted = await cipher.encryptField('', keyBytes);
      final decrypted = await cipher.decryptField(encrypted, keyBytes);

      expect(decrypted, '');
    });
  });
}

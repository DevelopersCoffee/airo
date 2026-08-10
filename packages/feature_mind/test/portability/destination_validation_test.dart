import 'package:feature_mind/src/portability/destination_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isLocalDestinationTarget', () {
    test('accepts an empty descriptor', () {
      expect(isLocalDestinationTarget(''), isTrue);
    });

    test('accepts a bare device or share name', () {
      expect(isLocalDestinationTarget('Kitchen Tablet'), isTrue);
      expect(isLocalDestinationTarget(r'E:\airo-backups'), isTrue);
      expect(isLocalDestinationTarget('/Volumes/AIRO-USB'), isTrue);
    });

    test('rejects an http(s) URL', () {
      expect(isLocalDestinationTarget('http://example.com/upload'), isFalse);
      expect(isLocalDestinationTarget('https://example.com/upload'), isFalse);
    });

    for (final host in [
      's3.amazonaws.com',
      'storage.googleapis.com',
      'icloud.com',
      'dropbox.com',
      'onedrive',
      'drive.google.com',
      'blob.core.windows.net',
    ]) {
      test('rejects a known cloud host: $host', () {
        expect(isLocalDestinationTarget('backup.$host'), isFalse);
      });
    }

    test('is case-insensitive', () {
      expect(isLocalDestinationTarget('HTTPS://EXAMPLE.COM'), isFalse);
    });
  });
}

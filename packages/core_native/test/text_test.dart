import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeChannelName (Dart fallback)', () {
    test('empty string', () => expect(normalizeChannelName(''), ''));

    test('strips punctuation and lowercases', () {
      expect(normalizeChannelName('BBC  News!'), 'bbcnews');
    });

    test('alphanumeric kept', () {
      expect(normalizeChannelName('9XM'), '9xm');
    });

    test('non-ascii letters stripped', () {
      expect(normalizeChannelName('Café TV'), 'caftv');
    });

    test('already normalized', () {
      expect(normalizeChannelName('starnews'), 'starnews');
    });
  });
}

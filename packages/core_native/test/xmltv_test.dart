import 'dart:io';

import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseXmltvProgrammes (Dart fallback)', () {
    test('parses bounded programme summaries', () {
      final result = parseXmltvProgrammes('''
<tv>
  <programme channel="news.one" start="20260715090000 +0000" stop="20260715100000 +0000">
    <title lang="en">Morning &amp; Markets</title>
    <desc>Ignored by compact summary</desc>
  </programme>
  <programme channel="sports.one" start="20260715100000 +0000">
    <title>Live Match</title>
  </programme>
</tv>
''', maxProgrammes: 1);

      expect(result.programmes, hasLength(1));
      expect(result.programmes.single.channelId, 'news.one');
      expect(result.programmes.single.start, '20260715090000 +0000');
      expect(result.programmes.single.stop, '20260715100000 +0000');
      expect(result.programmes.single.title, 'Morning & Markets');
      expect(result.stats.programmeCount, 2);
      expect(result.stats.skippedProgrammeCount, 0);
      expect(result.stats.truncated, isTrue);
      expect(result.backend, NativeXmltvParseBackend.dartFallback);
    });

    test('skips programmes missing required channel or start', () {
      final result = parseXmltvProgrammes('''
<tv>
  <programme channel="news.one"><title>No Start</title></programme>
  <programme start="20260715090000 +0000"><title>No Channel</title></programme>
  <programme channel="valid" start="20260715100000 +0000"></programme>
</tv>
''');

      expect(result.programmes, hasLength(1));
      expect(result.programmes.single.channelId, 'valid');
      expect(result.programmes.single.title, isNull);
      expect(result.stats.programmeCount, 1);
      expect(result.stats.skippedProgrammeCount, 2);
      expect(result.stats.truncated, isFalse);
    });

    test('allows zero bound without storing programmes', () {
      final result = parseXmltvProgrammes('''
<tv>
  <programme channel="news.one" start="20260715090000 +0000">
    <title>Morning</title>
  </programme>
</tv>
''', maxProgrammes: 0);

      expect(result.programmes, isEmpty);
      expect(result.stats.programmeCount, 1);
      expect(result.stats.truncated, isTrue);
    });

    test('rejects negative bounds', () {
      expect(
        () => parseXmltvProgrammes('<tv></tv>', maxProgrammes: -1),
        throwsArgumentError,
      );
    });

    test('parses bounded programme summaries from file path', () {
      final directory = Directory.systemTemp.createTempSync(
        'core-native-xmltv-file-test-',
      );
      addTearDown(() {
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      });
      final file = File('${directory.path}/guide.xml')
        ..writeAsStringSync('''
<tv>
  <programme channel="file.one" start="20260715090000 +0000">
    <title>File Path</title>
  </programme>
</tv>
''');

      final result = parseXmltvProgrammesFile(file.path);

      expect(result.programmes, hasLength(1));
      expect(result.programmes.single.channelId, 'file.one');
      expect(result.programmes.single.title, 'File Path');
      expect(result.stats.programmeCount, 1);
    });

    test(
      'native-preferred async API parses file path when bridge falls back',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'core-native-xmltv-file-native-test-',
        );
        addTearDown(() {
          if (directory.existsSync()) {
            directory.deleteSync(recursive: true);
          }
        });
        final file = File('${directory.path}/guide.xml')
          ..writeAsStringSync('''
<tv>
  <programme channel="native.file" start="20260715090000 +0000">
    <title>Native Preferred File Path</title>
  </programme>
</tv>
''');

        final result = await parseXmltvProgrammesFileNative(file.path);

        expect(result.programmes, hasLength(1));
        expect(result.programmes.single.channelId, 'native.file');
        expect(result.programmes.single.title, 'Native Preferred File Path');
        expect(result.stats.programmeCount, 1);
      },
    );

    test('rejects invalid file parser inputs', () {
      expect(
        () => parseXmltvProgrammesFile('', maxProgrammes: 1),
        throwsArgumentError,
      );
      expect(
        () => parseXmltvProgrammesFile('/tmp/missing.xml', maxProgrammes: -1),
        throwsArgumentError,
      );
    });
  });
}

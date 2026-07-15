import 'dart:io';

import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixturePath = Platform.environment['CORE_NATIVE_XMLTV_FIXTURE'];

  test(
    'XMLTV file path reaches the generated native bridge',
    () async {
      final result = await parseXmltvProgrammesFileNative(fixturePath!);

      expect(result.backend, NativeXmltvParseBackend.nativeBridge);
      expect(result.stats.programmeCount, greaterThan(0));
      expect(result.programmes, hasLength(1000));
      expect(result.stats.truncated, isTrue);
    },
    skip: fixturePath == null || fixturePath.trim().isEmpty
        ? 'Set CORE_NATIVE_XMLTV_FIXTURE to an XMLTV file path.'
        : null,
  );

  test(
    'XMLTV current next file path reaches the generated native bridge',
    () async {
      final result = await parseXmltvCurrentNextFileNative(
        fixturePath!,
        channelIds: const ['channel-00000', 'channel-00001'],
        now: DateTime.utc(2026, 1, 1, 0, 15),
      );

      expect(result.backend, NativeXmltvParseBackend.nativeBridge);
      expect(result.stats.programmeCount, greaterThan(0));
      expect(result.stats.requestedChannelCount, 2);
      expect(result.stats.matchedProgrammeCount, greaterThanOrEqualTo(2));
      expect(result.entries, hasLength(2));
      expect(result.entries.first.current?.channelId, 'channel-00000');
      expect(result.entries.first.current?.title, contains('Programme'));
    },
    skip: fixturePath == null || fixturePath.trim().isEmpty
        ? 'Set CORE_NATIVE_XMLTV_FIXTURE to an XMLTV file path.'
        : null,
  );
}

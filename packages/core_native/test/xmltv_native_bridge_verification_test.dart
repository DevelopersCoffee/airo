import 'dart:io';

import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixturePath = Platform.environment['CORE_NATIVE_XMLTV_FIXTURE'];

  test(
    'XMLTV file path reaches the generated native bridge',
    () async {
      final result = await parseXmltvProgrammesFileNative(
        fixturePath!,
        maxProgrammes: 1000,
      );

      expect(result.backend, NativeXmltvParseBackend.nativeBridge);
      expect(result.stats.programmeCount, greaterThan(0));
      expect(result.programmes, hasLength(1000));
      expect(result.stats.truncated, isTrue);
    },
    skip: fixturePath == null || fixturePath.trim().isEmpty
        ? 'Set CORE_NATIVE_XMLTV_FIXTURE to an XMLTV file path.'
        : null,
  );
}

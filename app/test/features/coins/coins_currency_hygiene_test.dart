import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presentation code does not hardcode rupee symbols', () {
    final presentationDir = Directory('lib/features/coins/presentation');
    final offenders = presentationDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => file.readAsStringSync().contains('₹'))
        .map((file) => file.path)
        .toList();

    expect(offenders, isEmpty);
  });
}

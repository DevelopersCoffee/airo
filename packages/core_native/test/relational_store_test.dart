import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects an empty relational store path before bridge startup', () {
    expect(
      () => initializeAiroRelationalStore('  '),
      throwsA(isA<ArgumentError>()),
    );
  });
}

import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocalRuntimeKind includes mediaPipeWeb for browser inference', () {
    expect(LocalRuntimeKind.values, contains(LocalRuntimeKind.mediaPipeWeb));
  });
}

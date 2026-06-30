import 'package:flutter_test/flutter_test.dart';

class EngineAssertions {
  static Future<void> expectException<T extends Exception>(
    Future<void> Function() action,
  ) async {
    try {
      await action();
      fail('Expected exception of type $T to be thrown');
    } catch (e) {
      expect(e, isA<T>());
    }
  }
}

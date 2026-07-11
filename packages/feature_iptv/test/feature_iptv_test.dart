import 'package:flutter_test/flutter_test.dart';

import 'package:feature_iptv/feature_iptv.dart';

void main() {
  test('exposes shared preferences override provider', () {
    expect(sharedPreferencesProvider, isNotNull);
  });
}

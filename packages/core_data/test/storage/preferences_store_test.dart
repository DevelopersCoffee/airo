import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PreferencesStore size guard', () {
    late PreferencesStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = PreferencesStore(prefs, maxValueBytes: 8);
    });

    test('allows small preference strings', () async {
      await expectLater(store.setString('theme', 'tv'), completion(isTrue));

      await expectLater(store.getString('theme'), completion('tv'));
    });

    test(
      'rejects oversized preference strings without persisting them',
      () async {
        await expectLater(
          store.setString('playlist-cache', List.filled(9, 'x').join()),
          throwsA(isA<KeyValueStoreValueTooLargeException>()),
        );

        await expectLater(
          store.getString('playlist-cache'),
          completion(isNull),
        );
      },
    );

    test('rejects oversized string lists by combined UTF-8 bytes', () async {
      await expectLater(
        store.setStringList('recent-searches', const ['one', 'two', 'three']),
        throwsA(isA<KeyValueStoreValueTooLargeException>()),
      );

      await expectLater(
        store.getStringList('recent-searches'),
        completion(isNull),
      );
    });
  });
}

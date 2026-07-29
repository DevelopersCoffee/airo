import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'persists and rehydrates only redacted provider health samples',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final first = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      first
          .read(providerHealthTrackerProvider)
          .record(
            ProviderHealthSample.fetchFailure(
              sourceId: 'xtream-1',
              timestampUtc: DateTime.utc(2026, 7, 29),
              failureCategory: ProviderHealthFailureCategory.auth,
              httpStatus: 401,
            ),
          );
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final raw = preferences.getString(providerHealthStorageKey);
      expect(raw, isNotNull);
      expect(raw, isNot(contains('https://')));
      expect(raw, isNot(contains('password')));

      final restarted = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(restarted.dispose);
      final snapshot = restarted
          .read(providerHealthTrackerProvider)
          .snapshotFor('xtream-1');

      expect(snapshot.totalSamples, 1);
      expect(snapshot.healthClass, ProviderHealthClass.red);
      expect(
        snapshot.recentFailureCategory,
        ProviderHealthFailureCategory.auth,
      );
    },
  );

  test('ignores corrupt persisted health data', () async {
    SharedPreferences.setMockInitialValues({
      providerHealthStorageKey: '{not-json',
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(
      container
          .read(providerHealthTrackerProvider)
          .snapshotFor('xtream-1')
          .healthClass,
      ProviderHealthClass.unknown,
    );
  });
}

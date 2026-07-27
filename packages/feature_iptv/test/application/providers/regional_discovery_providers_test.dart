import 'dart:ui';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults from locale and persists a manual country override', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final first = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        regionalDiscoveryLocaleProvider.overrideWithValue(
          const Locale('en', 'IN'),
        ),
      ],
    );
    addTearDown(first.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(first.read(regionalDiscoveryCountryProvider), 'IN');
    first.read(channelFiltersProvider.notifier).setCountry('gb');
    expect(first.read(regionalDiscoveryCountryProvider), 'GB');
    await Future<void>.delayed(Duration.zero);

    final recreated = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        regionalDiscoveryLocaleProvider.overrideWithValue(
          const Locale('en', 'IN'),
        ),
      ],
    );
    addTearDown(recreated.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(recreated.read(regionalDiscoveryCountryProvider), 'GB');
  });
}

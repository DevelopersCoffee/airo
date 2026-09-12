import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Regression test for the favorite/not-for-me mutual exclusion invariant,
// exercised at the shared provider layer so every call site — existing and
// future — is covered by one test rather than per-screen coverage.
void main() {
  test('favoriting a channel clears an existing not-for-me flag, '
      'at the provider level', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final storage = container.read(favoriteChannelsStorageProvider);
    await storage.setNotForMe('ch1');
    expect(await storage.isNotForMe('ch1'), isTrue);

    final favoriteToggler = container.read(channelFavoriteTogglerProvider);
    await favoriteToggler('ch1');

    expect(await storage.isFavorite('ch1'), isTrue);
    expect(await storage.isNotForMe('ch1'), isFalse);
  });

  test(
    'marking not-for-me clears an existing favorite, at the provider level',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final storage = container.read(favoriteChannelsStorageProvider);
      await storage.setFavorite('ch1');
      expect(await storage.isFavorite('ch1'), isTrue);

      final notForMeToggler = container.read(channelNotForMeTogglerProvider);
      await notForMeToggler('ch1');

      expect(await storage.isNotForMe('ch1'), isTrue);
      expect(await storage.isFavorite('ch1'), isFalse);
    },
  );
}

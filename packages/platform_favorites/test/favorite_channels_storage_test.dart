import 'package:flutter_test/flutter_test.dart';
import 'package:platform_favorites/platform_favorites.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts with no favorite channels', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);

    expect(await storage.getFavoriteChannelIds(), isEmpty);
    expect(await storage.isFavorite('news'), isFalse);
  });

  test('adds a channel to favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);

    await storage.setFavorite('news');

    expect(await storage.getFavoriteChannelIds(), ['news']);
    expect(await storage.isFavorite('news'), isTrue);
  });

  test('adding the same channel twice does not duplicate it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);

    await storage.setFavorite('news');
    await storage.setFavorite('news');

    expect(await storage.getFavoriteChannelIds(), ['news']);
  });

  test('removes a channel from favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);

    await storage.setFavorite('news');
    await storage.setFavorite('sports');
    await storage.clearPreference('news');

    expect(await storage.getFavoriteChannelIds(), ['sports']);
    expect(await storage.isFavorite('news'), isFalse);
  });

  test('toggleFavorite adds when absent and removes when present', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);

    final afterFirstToggle = await storage.toggleFavorite('news');
    expect(afterFirstToggle, isTrue);
    expect(await storage.isFavorite('news'), isTrue);

    final afterSecondToggle = await storage.toggleFavorite('news');
    expect(afterSecondToggle, isFalse);
    expect(await storage.isFavorite('news'), isFalse);
  });

  test('persists favorites across storage instances', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await FavoriteChannelsStorage(prefs).setFavorite('news');

    final reloaded = FavoriteChannelsStorage(prefs);
    expect(await reloaded.getFavoriteChannelIds(), ['news']);
  });

  test(
    'setFavorite clears an existing not-for-me flag on the same channel',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = FavoriteChannelsStorage(prefs);
      await storage.setNotForMe('ch1');
      expect(await storage.isNotForMe('ch1'), isTrue);

      await storage.setFavorite('ch1');

      expect(await storage.isFavorite('ch1'), isTrue);
      expect(await storage.isNotForMe('ch1'), isFalse);
    },
  );

  test(
    'setNotForMe clears an existing favorite flag on the same channel',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = FavoriteChannelsStorage(prefs);
      await storage.setFavorite('ch1');

      await storage.setNotForMe('ch1');

      expect(await storage.isNotForMe('ch1'), isTrue);
      expect(await storage.isFavorite('ch1'), isFalse);
    },
  );

  test('getFavoriteChannelIds preserves insertion order', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);
    await storage.setFavorite('ch3');
    await storage.setFavorite('ch1');
    await storage.setFavorite('ch2');

    expect(await storage.getFavoriteChannelIds(), ['ch3', 'ch1', 'ch2']);
  });

  test(
    'setFavorite is a no-op dedup when the channel is already favorited',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = FavoriteChannelsStorage(prefs);
      await storage.setFavorite('ch1');
      await storage.setFavorite('ch1');

      expect(await storage.getFavoriteChannelIds(), ['ch1']);
    },
  );

  test('replaceAll preserves the order of the provided iterable', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);
    await storage.replaceAll(['chB', 'chA', 'chC']);

    expect(await storage.getFavoriteChannelIds(), ['chB', 'chA', 'chC']);
  });

  test('replaceAll clears not-for-me for every restored id, preserving the '
      'mutually-exclusive invariant', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);
    // The user marked 'chA' not-for-me locally, then restores a backup
    // that favorites 'chA' again.
    await storage.setNotForMe('chA');
    await storage.setNotForMe('chB');

    await storage.replaceAll(['chA', 'chC']);

    expect(await storage.getFavoriteChannelIds(), ['chA', 'chC']);
    // 'chA' is now a favorite again, so it must leave the not-for-me set.
    expect(await storage.isNotForMe('chA'), isFalse);
    // 'chB' was never part of the restored favorites, so its not-for-me
    // flag is untouched.
    expect(await storage.isNotForMe('chB'), isTrue);
  });

  test('replaceAll is a no-op on not-for-me when none of the restored ids '
      'overlap it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);
    await storage.setNotForMe('chB');

    await storage.replaceAll(['chA']);

    expect(await storage.isNotForMe('chB'), isTrue);
  });
}

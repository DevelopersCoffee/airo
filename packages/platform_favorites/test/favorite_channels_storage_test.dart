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

    await storage.addFavorite('news');

    expect(await storage.getFavoriteChannelIds(), {'news'});
    expect(await storage.isFavorite('news'), isTrue);
  });

  test('adding the same channel twice does not duplicate it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);

    await storage.addFavorite('news');
    await storage.addFavorite('news');

    expect(await storage.getFavoriteChannelIds(), {'news'});
  });

  test('removes a channel from favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = FavoriteChannelsStorage(prefs);

    await storage.addFavorite('news');
    await storage.addFavorite('sports');
    await storage.removeFavorite('news');

    expect(await storage.getFavoriteChannelIds(), {'sports'});
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

    await FavoriteChannelsStorage(prefs).addFavorite('news');

    final reloaded = FavoriteChannelsStorage(prefs);
    expect(await reloaded.getFavoriteChannelIds(), {'news'});
  });
}

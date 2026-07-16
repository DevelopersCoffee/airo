import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_history/platform_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late VodWatchHistoryStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    storage = VodWatchHistoryStorage(prefs);
  });

  const movie = VodItem(
    id: 'xtream-vod-1',
    title: 'Example Movie',
    streamUrl: 'https://example.com/movie.mp4',
    group: 'Movies',
    kind: VodContentKind.movie,
  );

  test('addToRecent then getRecentlyWatched round-trips', () async {
    await storage.addToRecent(movie);

    final result = await storage.getRecentlyWatched();

    expect(result, [movie]);
  });

  test("does not collide with RecentlyWatchedStorage's storage key", () async {
    final liveHistory = RecentlyWatchedStorage(prefs);

    await storage.addToRecent(movie);

    final liveResult = await liveHistory.getRecentlyWatched();
    expect(liveResult, isEmpty);
  });

  test('hasRecentlyWatched is false before any add, true after', () async {
    expect(await storage.hasRecentlyWatched(), isFalse);

    await storage.addToRecent(movie);

    expect(await storage.hasRecentlyWatched(), isTrue);
  });

  test('removeFromRecent removes by id', () async {
    await storage.addToRecent(movie);

    await storage.removeFromRecent(movie.id);
    final result = await storage.getRecentlyWatched();

    expect(result, isEmpty);
  });

  test('clearRecent empties the list', () async {
    await storage.addToRecent(movie);

    await storage.clearRecent();
    final result = await storage.getRecentlyWatched();

    expect(result, isEmpty);
  });
}

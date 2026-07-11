import 'package:flutter_test/flutter_test.dart';

import 'package:platform_channels/platform_channels.dart';
import 'package:platform_history/platform_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stores and loads recently watched channels', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = RecentlyWatchedStorage(prefs);

    await storage.addToRecent(
      const IPTVChannel(id: 'one', name: 'One', streamUrl: 'https://one.test'),
    );

    final recent = await storage.getRecentlyWatched();
    expect(recent.single.id, 'one');
  });
}

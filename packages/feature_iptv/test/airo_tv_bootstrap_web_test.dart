import 'package:feature_iptv/application/airo_tv_bootstrap_stub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('web bootstrap seeds the debug playlist when none exists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final seeded = await seedAiroTvDebugDefaultPlaylist(
      prefs,
      playlistUrl: ' https://example.com/debug.m3u ',
    );

    expect(seeded, isTrue);
    expect(
      prefs.getString('iptv_user_playlist_url'),
      'https://example.com/debug.m3u',
    );
  });

  test('web bootstrap preserves an existing user playlist', () async {
    SharedPreferences.setMockInitialValues({
      'iptv_user_playlist_url': 'https://example.com/user.m3u',
    });
    final prefs = await SharedPreferences.getInstance();

    final seeded = await seedAiroTvDebugDefaultPlaylist(
      prefs,
      playlistUrl: 'https://example.com/debug.m3u',
    );

    expect(seeded, isFalse);
    expect(
      prefs.getString('iptv_user_playlist_url'),
      'https://example.com/user.m3u',
    );
  });
}

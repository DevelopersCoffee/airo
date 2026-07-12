import 'package:airo_app/main_tv.dart';
import 'package:dio/dio.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('seeds DEBUG_IPTV_PLAYLIST_URL when no playlist exists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await seedTvDebugDefaultPlaylist(
      prefs,
      playlistUrl: 'https://example.com/tv.m3u',
    );

    final parser = M3UParserService(dio: Dio(), prefs: prefs);
    expect(parser.getPlaylistUrl(), 'https://example.com/tv.m3u');
  });

  test('does not overwrite an existing user playlist', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final parser = M3UParserService(dio: Dio(), prefs: prefs);
    await parser.setPlaylistUrl('https://example.com/user.m3u');

    await seedTvDebugDefaultPlaylist(
      prefs,
      playlistUrl: 'https://example.com/debug.m3u',
    );

    expect(parser.getPlaylistUrl(), 'https://example.com/user.m3u');
  });
}

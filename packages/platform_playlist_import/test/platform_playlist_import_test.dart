import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('parses M3U channel entries', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final parser = M3UParserService(dio: Dio(), prefs: prefs);

    final channels = parser.parseM3U('''
#EXTM3U
#EXTINF:-1 group-title="News",News One
https://example.com/news.m3u8
''');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'News One');
    expect(channels.single.streamUrl, 'https://example.com/news.m3u8');
  });

  group('M3UParserService BYOC source', () {
    late SharedPreferences prefs;
    late M3UParserService parser;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      parser = M3UParserService(dio: Dio(), prefs: prefs);
    });

    test(
      'returns no channels when no user playlist URL is configured',
      () async {
        await expectLater(parser.fetchPlaylist(), completion(isEmpty));
        expect(parser.getPlaylistUrl(), isNull);
      },
    );

    test('rejects empty and non-http playlist URLs', () async {
      expect(() => parser.setPlaylistUrl(''), throwsArgumentError);
      expect(
        () => parser.setPlaylistUrl('file:///private/playlist.m3u'),
        throwsArgumentError,
      );
      expect(
        () => parser.setPlaylistUrl('ftp://example.com/playlist.m3u'),
        throwsArgumentError,
      );
    });

    test('persists valid http and https playlist URLs', () async {
      await parser.setPlaylistUrl('https://example.com/playlist.m3u');
      expect(parser.getPlaylistUrl(), 'https://example.com/playlist.m3u');

      await parser.setPlaylistUrl('http://example.com/playlist.m3u');
      expect(parser.getPlaylistUrl(), 'http://example.com/playlist.m3u');
    });

    test('clears playlist URL and user-derived cache', () async {
      await parser.setPlaylistUrl('https://example.com/playlist.m3u');
      await parser.clearPlaylist();

      expect(parser.getPlaylistUrl(), isNull);
      await expectLater(parser.fetchPlaylist(), completion(isEmpty));
    });
  });
}

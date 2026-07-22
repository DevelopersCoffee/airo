import 'dart:io';

import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseM3uEntries (Dart fallback)', () {
    test('parses EXTINF attributes and following URL', () {
      final entries = parseM3uEntries('''
#EXTM3U
#EXTINF:-1 tvg-id="news.one" tvg-name="News One" tvg-logo="https://example.com/news.png" group-title="News" tvg-language="en",News One
https://example.com/news.m3u8
''');

      expect(entries, hasLength(1));
      expect(entries.single.name, 'News One');
      expect(entries.single.url, 'https://example.com/news.m3u8');
      expect(entries.single.logo, 'https://example.com/news.png');
      expect(entries.single.group, 'News');
      expect(entries.single.tvgId, 'news.one');
      expect(entries.single.tvgName, 'News One');
      expect(entries.single.language, 'en');
    });

    test('ignores comments and entries without URLs', () {
      final entries = parseM3uEntries('''
#EXTM3U
#EXTINF:-1,No Url
#EXTVLCOPT:http-user-agent=demo
#EXTINF:-1,Has Url
https://example.com/has-url.m3u8
''');

      expect(entries, hasLength(1));
      expect(entries.single.name, 'Has Url');
    });

    test('resets pending entry after the first URI line', () {
      final entries = parseM3uEntries('''
#EXTM3U
#EXTINF:-1,First
not-a-valid-url
https://example.com/ignored-without-extinf.m3u8
''');

      expect(entries, hasLength(1));
      expect(entries.single.name, 'First');
      expect(entries.single.url, 'not-a-valid-url');
    });

    test(
      'native-preferred async API falls back when bridge is unavailable',
      () async {
        final entries = await parseM3uEntriesNative('''
#EXTM3U
#EXTINF:-1 tvg-name="Async News",Async News
https://example.com/async-news.m3u8
''');

        expect(entries, hasLength(1));
        expect(entries.single.name, 'Async News');
      },
    );

    test('parses EXTINF duration for live and VOD entries', () {
      final entries = parseM3uEntries('''
#EXTM3U
#EXTINF:-1,Live Channel
https://example.com/live.m3u8
#EXTINF:120 tvg-id="movie.one",VOD Movie
https://example.com/movie.mp4
#EXTINF:,No Duration
https://example.com/noduration.m3u8
''');

      expect(entries, hasLength(3));
      expect(entries[0].duration, -1);
      expect(entries[1].duration, 120);
      expect(entries[2].duration, isNull);
    });

    test('preserves unknown EXTINF attributes in extras', () {
      final entries = parseM3uEntries('''
#EXTM3U
#EXTINF:-1 tvg-id="news.one" tvg-chno="42" catchup-days="7" radio="true" tvg-name="News One",News One
https://example.com/news.m3u8
''');

      expect(entries, hasLength(1));
      expect(entries.single.extras, {
        'tvg-chno': '42',
        'catchup-days': '7',
        'radio': 'true',
      });
    });

    test('captures #EXTM3U header attributes on playlist', () {
      final playlist = parseM3uPlaylist('''
#EXTM3U x-tvg-url="https://provider.com/epg.xml" url-tvg="https://provider.com/epg-alt.xml"
#EXTINF:-1,News One
https://example.com/news.m3u8
''');

      expect(playlist.entries, hasLength(1));
      expect(playlist.headers, {
        'x-tvg-url': 'https://provider.com/epg.xml',
        'url-tvg': 'https://provider.com/epg-alt.xml',
      });
    });

    test('bare #EXTM3U line yields no headers', () {
      final playlist = parseM3uPlaylist('''
#EXTM3U
#EXTINF:-1,News One
https://example.com/news.m3u8
''');

      expect(playlist.entries, hasLength(1));
      expect(playlist.headers, isEmpty);
    });

    test('reports redacted aggregate parse stats', () async {
      final result = await parseM3uPlaylistWithStatsNative('''
#EXTM3U
#EXTINF:-1 Broken entry without a comma
#EXTINF:-1,Skipped without URL
#EXTINF:-1,Parsed channel
https://example.com/parsed.m3u8
#EXTINF:-1,Trailing without URL
''');

      expect(result.playlist.entries, hasLength(1));
      expect(result.stats.parsedCount, 1);
      expect(result.stats.skippedCount, 2);
      expect(result.stats.malformedCount, 1);
      expect(result.stats.elapsedMillis, greaterThanOrEqualTo(0));
    });

    test(
      'native-preferred playlist API matches Dart fallback output',
      () async {
        const content = '''
#EXTM3U x-tvg-url="https://provider.com/epg.xml"
#EXTINF:-1 tvg-id="news.one" tvg-chno="42" tvg-name="News One",News One
https://example.com/news.m3u8
#EXTINF:120 tvg-id="movie.one" catchup-days="7",VOD Movie
https://example.com/movie.mp4
''';

        final fallback = parseM3uPlaylist(content);
        final nativePreferred = await parseM3uPlaylistNative(content);

        expect(nativePreferred.headers, fallback.headers);
        expect(nativePreferred.entries.length, fallback.entries.length);
        for (var i = 0; i < fallback.entries.length; i++) {
          final expected = fallback.entries[i];
          final actual = nativePreferred.entries[i];
          expect(actual.name, expected.name);
          expect(actual.url, expected.url);
          expect(actual.logo, expected.logo);
          expect(actual.group, expected.group);
          expect(actual.tvgId, expected.tvgId);
          expect(actual.tvgName, expected.tvgName);
          expect(actual.language, expected.language);
          expect(actual.duration, expected.duration);
          expect(actual.extras, expected.extras);
        }
      },
    );

    test('native-preferred file API matches Dart fallback output', () async {
      final directory = await Directory.systemTemp.createTemp(
        'core_native_m3u_file_test_',
      );
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });
      final file = File('${directory.path}/playlist.m3u');
      const content = '''
#EXTM3U x-tvg-url="https://provider.com/epg.xml"
#EXTINF:-1 tvg-id="file.news" tvg-name="File News",File News
https://example.com/file-news.m3u8
''';
      await file.writeAsString(content);

      final fallback = parseM3uPlaylistWithStats(content);
      final nativePreferred = await parseM3uPlaylistFileWithStatsNative(
        file.path,
      );

      expect(nativePreferred.playlist.headers, fallback.playlist.headers);
      expect(nativePreferred.playlist.entries.length, 1);
      expect(nativePreferred.playlist.entries.single.name, 'File News');
      expect(nativePreferred.stats.parsedCount, fallback.stats.parsedCount);
      expect(nativePreferred.stats.skippedCount, fallback.stats.skippedCount);
      expect(
        nativePreferred.stats.malformedCount,
        fallback.stats.malformedCount,
      );
    });

    test('channel-shaped API deduplicates and applies URL policy', () {
      final result = parseM3uChannelsWithStats('''
#EXTM3U
#EXTINF:-1,Local File
file:///etc/passwd
#EXTINF:-1,Private Host
http://192.168.1.1/live.m3u8
#EXTINF:-1 tvg-logo="file:///private/logo.png",Public Stream
https://cdn.example.com/live.m3u8
#EXTINF:-1 group-title="News",News One
https://example.com/news-no-logo.m3u8
#EXTINF:-1 tvg-logo="https://example.com/news.png" group-title="News", news-one
https://example.com/news-logo.m3u8
''');

      expect(result.stats.parsedCount, 5);
      expect(result.channels, hasLength(2));
      expect(result.channels[0].name, 'Public Stream');
      expect(result.channels[0].url, 'https://cdn.example.com/live.m3u8');
      expect(result.channels[0].logo, isNull);
      expect(result.channels[1].name, 'News-one');
      expect(result.channels[1].url, 'https://example.com/news-logo.m3u8');
      expect(result.channels[1].logo, 'https://example.com/news.png');
    });

    test('native-preferred channel API matches Dart fallback output', () async {
      const content = '''
#EXTM3U
#EXTINF:-1 tvg-logo="https://example.com/sports.png",SPORTS 24
https://example.com/sports-logo.m3u8
#EXTINF:-1,sports-24
https://example.com/sports-no-logo.m3u8
#EXTINF:-1,  BBC    WORLD   news
https://example.com/bbc-world-news.m3u8
''';

      final fallback = parseM3uChannelsWithStats(content);
      final nativePreferred = await parseM3uChannelsWithStatsNative(content);

      expect(nativePreferred.stats.parsedCount, fallback.stats.parsedCount);
      expect(nativePreferred.channels.length, fallback.channels.length);
      for (var i = 0; i < fallback.channels.length; i++) {
        final expected = fallback.channels[i];
        final actual = nativePreferred.channels[i];
        expect(actual.name, expected.name);
        expect(actual.url, expected.url);
        expect(actual.logo, expected.logo);
        expect(actual.group, expected.group);
        expect(actual.tvgId, expected.tvgId);
        expect(actual.tvgName, expected.tvgName);
        expect(actual.language, expected.language);
      }
    });

    test(
      'native-preferred file channel API matches Dart fallback output',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'core_native_m3u_file_channels_test_',
        );
        addTearDown(() async {
          if (directory.existsSync()) {
            await directory.delete(recursive: true);
          }
        });
        final file = File('${directory.path}/playlist.m3u');
        const content = '''
#EXTM3U
#EXTINF:-1 group-title="News",File Channel
https://cdn.example.com/file-channel.m3u8
''';
        await file.writeAsString(content);

        final fallback = parseM3uChannelsWithStats(content);
        final nativePreferred = await parseM3uFileChannelsWithStatsNative(
          file.path,
        );

        expect(nativePreferred.stats.parsedCount, fallback.stats.parsedCount);
        expect(nativePreferred.channels, hasLength(1));
        expect(nativePreferred.channels.single.name, 'File Channel');
        expect(
          nativePreferred.channels.single.url,
          'https://cdn.example.com/file-channel.m3u8',
        );
      },
    );
  });
}

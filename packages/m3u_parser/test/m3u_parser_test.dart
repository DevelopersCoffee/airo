import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_parser/m3u_parser.dart';

void main() {
  group('parseM3u (sync, pure-Dart)', () {
    test('parses EXTINF entries with attributes', () {
      final playlist = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-id="news.one" tvg-name="News One" tvg-logo="https://example.com/news.png" group-title="News" tvg-language="en",News One
https://example.com/news.m3u8
''');

      expect(playlist.entries, hasLength(1));
      final entry = playlist.entries.single;
      expect(entry.name, 'News One');
      expect(entry.url, 'https://example.com/news.m3u8');
      expect(entry.logo, 'https://example.com/news.png');
      expect(entry.group, 'News');
      expect(entry.tvgId, 'news.one');
      expect(entry.tvgName, 'News One');
      expect(entry.language, 'en');
    });

    test('ignores comments and entries without URLs', () {
      final playlist = parseM3u('''
#EXTM3U
#EXTINF:-1,No Url
#EXTVLCOPT:http-user-agent=demo
#EXTINF:-1,Has Url
https://example.com/has-url.m3u8
''');

      expect(playlist.entries, hasLength(1));
      expect(playlist.entries.single.name, 'Has Url');
    });

    test('parses EXTINF duration', () {
      final playlist = parseM3u('''
#EXTM3U
#EXTINF:-1,Live Channel
https://example.com/live.m3u8
#EXTINF:120 tvg-id="movie.one",VOD Movie
https://example.com/movie.mp4
''');

      expect(playlist.entries[0].duration, -1);
      expect(playlist.entries[1].duration, 120);
    });

    test('preserves unknown attributes in extras', () {
      final playlist = parseM3u('''
#EXTM3U
#EXTINF:-1 tvg-id="news.one" tvg-chno="42" catchup-days="7" radio="true" tvg-name="News One",News One
https://example.com/news.m3u8
''');

      final extras = playlist.entries.single.extras;
      expect(extras, hasLength(3));
      expect(extras['tvg-chno'], '42');
      expect(extras['catchup-days'], '7');
      expect(extras['radio'], 'true');
      expect(extras.containsKey('tvg-id'), isFalse);
    });

    test('captures EXTM3U header attributes', () {
      final playlist = parseM3u('''
#EXTM3U x-tvg-url="https://provider.com/epg.xml" url-tvg="https://provider.com/epg-alt.xml"
#EXTINF:-1,News One
https://example.com/news.m3u8
''');

      expect(playlist.headers, hasLength(2));
      expect(playlist.headers['x-tvg-url'], 'https://provider.com/epg.xml');
      expect(
        playlist.headers['url-tvg'],
        'https://provider.com/epg-alt.xml',
      );
    });
  });

  group('parseM3uWithStats', () {
    test('reports safe parse stats for malformed and skipped rows', () {
      final result = parseM3uWithStats('''
#EXTM3U
#EXTINF:-1 This row has no comma
#EXTINF:-1,Skipped without URL
# a comment does not consume the pending row
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
  });

  group('parseM3uChannelsWithStats', () {
    test('normalizes and deduplicates channels, preferring logo entries', () {
      final result = parseM3uChannelsWithStats('''
#EXTM3U
#EXTINF:-1 group-title="News",News One
https://example.com/news-no-logo.m3u8
#EXTINF:-1 tvg-logo="https://example.com/news.png" group-title="News", news-one
https://example.com/news-logo.m3u8
#EXTINF:-1,  BBC    WORLD   news
https://example.com/bbc-world-news.m3u8
''');

      expect(result.channels, hasLength(2));
      expect(result.channels[0].name, 'News-one');
      expect(result.channels[0].url, 'https://example.com/news-logo.m3u8');
      expect(result.channels[0].logo, 'https://example.com/news.png');
      expect(result.channels[1].name, 'BBC World News');
    });

    test('drops disallowed stream and logo URLs', () {
      final result = parseM3uChannelsWithStats('''
#EXTM3U
#EXTINF:-1,Local File
file:///etc/passwd
#EXTINF:-1,Private Host
http://192.168.1.1/live.m3u8
#EXTINF:-1 tvg-logo="file:///private/logo.png",Public Stream
https://cdn.example.com/live.m3u8
''');

      expect(result.channels, hasLength(1));
      expect(result.channels.single.name, 'Public Stream');
      expect(result.channels.single.url, 'https://cdn.example.com/live.m3u8');
      expect(result.channels.single.logo, isNull);
    });

    test('unions tags from both tvg-tags and tags attributes', () {
      final result = parseM3uChannelsWithStats('''
#EXTM3U
#EXTINF:-1 tvg-tags="news,live" tags="live,hd",Tagged Channel
https://example.com/tagged.m3u8
''');

      expect(result.channels, hasLength(1));
      expect(result.channels.single.tags, ['news', 'live', 'hd']);
    });

    test('whitespace-only tvg-country yields null country', () {
      final result = parseM3uChannelsWithStats('''
#EXTM3U
#EXTINF:-1 tvg-country="  ",Whitespace Country
https://example.com/whitespace-country.m3u8
''');

      expect(result.channels, hasLength(1));
      expect(result.channels.single.country, isNull);
    });

    test('mixed-case scheme/host with default port is preserved verbatim', () {
      final result = parseM3uChannelsWithStats('''
#EXTM3U
#EXTINF:-1,Mixed Case Url
HTTPS://Example.COM:443/News.m3u8
''');

      expect(result.channels, hasLength(1));
      expect(
        result.channels.single.url,
        'HTTPS://Example.COM:443/News.m3u8',
      );
    });
  });
}

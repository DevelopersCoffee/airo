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
  });
}

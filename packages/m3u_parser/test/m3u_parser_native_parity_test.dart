import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_parser/m3u_parser.dart';

/// Whichever path parseM3uWithStatsAsync actually took (Rust or the Dart
/// fallback — this test doesn't assume which, since the native bridge may
/// or may not load in a given test environment), its output must match the
/// deterministic Dart-only path exactly. This is the parity requirement
/// ADR-0026 calls out under "Which conformance tests become invalid?" — it
/// must hold in Task 5 and keep holding after any future codegen refresh.
const _corpus = '''
#EXTM3U x-tvg-url="https://provider.example/guide.xml"
#EXTINF:-1 tvg-id="news.one" tvg-name="News One" tvg-logo="https://example.com/news.png" group-title="News" tvg-language="en",News One
https://example.com/news.m3u8
#EXTINF:-1 tvg-chno="42" catchup-days="7",Unusual Attrs
https://example.com/unusual.m3u8
#EXTINF:-1,  BBC    WORLD   news
https://example.com/bbc-world-news.m3u8
#EXTINF:-1,Private Host
http://192.168.1.1/live.m3u8
''';

void main() {
  test('async (Rust-preferred) parity with sync Dart fallback', () async {
    final asyncResult = await parseM3uWithStatsAsync(_corpus);
    final syncResult = parseM3uWithStats(_corpus);

    expect(asyncResult.playlist.entries.length, syncResult.playlist.entries.length);
    expect(asyncResult.playlist.headers, syncResult.playlist.headers);
    expect(asyncResult.stats.parsedCount, syncResult.stats.parsedCount);
    expect(asyncResult.stats.skippedCount, syncResult.stats.skippedCount);
    expect(asyncResult.stats.malformedCount, syncResult.stats.malformedCount);

    for (var i = 0; i < syncResult.playlist.entries.length; i++) {
      final a = asyncResult.playlist.entries[i];
      final s = syncResult.playlist.entries[i];
      expect(a.name, s.name);
      expect(a.url, s.url);
      expect(a.logo, s.logo);
      expect(a.group, s.group);
      expect(a.tvgId, s.tvgId);
      expect(a.tvgName, s.tvgName);
      expect(a.language, s.language);
      expect(a.duration, s.duration);
      expect(a.extras, s.extras);
    }
  });

  test('async channel parity with sync Dart fallback', () async {
    final asyncResult = await parseM3uChannelsWithStatsAsync(_corpus);
    final syncResult = parseM3uChannelsWithStats(_corpus);

    expect(asyncResult.channels.length, syncResult.channels.length);
    for (var i = 0; i < syncResult.channels.length; i++) {
      expect(asyncResult.channels[i].name, syncResult.channels[i].name);
      expect(asyncResult.channels[i].url, syncResult.channels[i].url);
      expect(asyncResult.channels[i].logo, syncResult.channels[i].logo);
    }
  });
}

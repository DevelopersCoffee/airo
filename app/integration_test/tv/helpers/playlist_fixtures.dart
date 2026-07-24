/// Deterministic IPTV test fixtures for TV integration tests.
///
/// Provides offline-safe M3U playlists and XMLTV EPG data for automated
/// testing. The primary test channel is **Vevo Pop (1080p)** from the
/// iptv-org index.
///
/// Fixtures are written to temporary files on the device filesystem so the
/// full UI import flow can be tested (Settings → Import → URL/file → parse).
library;

import 'dart:io';

/// Confirmed Vevo Pop channel entry from iptv-org/iptv index.m3u (L25209).
class VevoPopFixture {
  VevoPopFixture._();

  static const String tvgId = 'VevoPop.us@SD';
  static const String name = 'Vevo Pop (1080p)';
  static const String displayName = 'Vevo Pop';
  static const String groupTitle = 'Music';
  static const String logoUrl = 'https://i.imgur.com/dZHktKR.png';
  static const String streamUrl =
      'https://d128y56w6v2kax.cloudfront.net/playlist/'
      'amg00056-vevotv-vevopopau-samsungau/playlist.m3u8';

  /// The raw M3U lines for this channel.
  static const String m3uEntry =
      '#EXTINF:-1 tvg-id="$tvgId" tvg-logo="$logoUrl" '
      'group-title="$groupTitle",$name\n$streamUrl';
}

/// Small 10-channel M3U playlist across 3 groups for navigation testing.
///
/// Groups: Music (3), News (4), Sports (3)
class SmallPlaylistFixture {
  SmallPlaylistFixture._();

  static const int channelCount = 10;

  static const String m3uContent = '''#EXTM3U
#EXTINF:-1 tvg-id="VevoPop.us@SD" tvg-logo="https://i.imgur.com/dZHktKR.png" group-title="Music",Vevo Pop (1080p)
https://d128y56w6v2kax.cloudfront.net/playlist/amg00056-vevotv-vevopopau-samsungau/playlist.m3u8
#EXTINF:-1 tvg-id="Vevo80s.us@SD" tvg-logo="https://images.pluto.tv/channels/5fd7b8bf927e090007685853/featuredImage.jpg" group-title="Music",Vevo 80s (1080p)
https://amg00056-vevotv-vevo80saunz-samsungau-rp5e3.amagi.tv/playlist/amg00056-vevotv-vevo80saunz-samsungau/playlist.m3u8
#EXTINF:-1 tvg-id="VevoCountry.us@SD" tvg-logo="https://images.pluto.tv/channels/5da0d75e84830900098a1ea0/featuredImage.jpg" group-title="Music",Vevo Country (1080p)
https://amg00056-vevotv-vevocountryau-samsungau-ktmqm.amagi.tv/playlist/amg00056-vevotv-vevocountryau-samsungau/playlist.m3u8
#EXTINF:-1 tvg-id="CGTN.cn" tvg-logo="https://i.imgur.com/VkjcSgZ.png" group-title="News",CGTN (1080p)
https://news.cgtn.com/resource/live/english/cgtn-news.m3u8
#EXTINF:-1 tvg-id="France24.fr" tvg-logo="https://i.imgur.com/wp4ExBr.png" group-title="News",France 24 English (1080p)
https://stream.france24.com/live/202305/FREN/amlst:FREN/master.m3u8
#EXTINF:-1 tvg-id="DWEnglish.de" tvg-logo="https://i.imgur.com/A1xIjwS.png" group-title="News",DW English (1080p)
https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8
#EXTINF:-1 tvg-id="AlJazeera.qa" tvg-logo="https://i.imgur.com/BFHt9Mo.png" group-title="News",Al Jazeera English (1080p)
https://live-hls-web-aje.getaj.net/AJE/01.m3u8
#EXTINF:-1 tvg-id="SkySportsNews.uk" tvg-logo="https://i.imgur.com/UDr3fkD.png" group-title="Sports",Sky Sports News
https://example.com/sky-sports-news.m3u8
#EXTINF:-1 tvg-id="ESPNews.us" tvg-logo="https://i.imgur.com/RDm7sCZ.png" group-title="Sports",ESPNews
https://example.com/espnews.m3u8
#EXTINF:-1 tvg-id="Eurosport1.fr" tvg-logo="https://i.imgur.com/bqKJOVC.png" group-title="Sports",Eurosport 1
https://example.com/eurosport1.m3u8''';
}

/// Broken stream fixture for error recovery testing.
class BrokenStreamFixture {
  BrokenStreamFixture._();

  static const String m3uContent = '''#EXTM3U
#EXTINF:-1 tvg-id="broken_404" tvg-logo="" group-title="Test",Broken 404 Channel
https://httpstat.us/404
#EXTINF:-1 tvg-id="broken_timeout" tvg-logo="" group-title="Test",Timeout Channel
https://httpstat.us/524
#EXTINF:-1 tvg-id="broken_invalid" tvg-logo="" group-title="Test",Invalid URL Channel
not-a-valid-url''';
}

/// Minimal XMLTV EPG fixture matching the small playlist channels.
///
/// Generates programme entries relative to [now] for ±6 hours so the
/// EPG grid always has data regardless of when the test runs.
class EpgFixture {
  EpgFixture._();

  /// Generate XMLTV content with programs relative to [now].
  static String generateXmltvContent({DateTime? now}) {
    final reference = now ?? DateTime.now().toUtc();
    final fmt = _xmltvDateFormat;

    final minus6h = reference.subtract(const Duration(hours: 6));
    final minus3h = reference.subtract(const Duration(hours: 3));
    final minus1h = reference.subtract(const Duration(hours: 1));
    final plus1h = reference.add(const Duration(hours: 1));
    final plus3h = reference.add(const Duration(hours: 3));
    final plus6h = reference.add(const Duration(hours: 6));

    return '''<?xml version="1.0" encoding="UTF-8"?>
<tv generator-info-name="airo-tv-test-fixture">
  <channel id="VevoPop.us@SD">
    <display-name>Vevo Pop</display-name>
    <icon src="https://i.imgur.com/dZHktKR.png"/>
  </channel>
  <channel id="CGTN.cn">
    <display-name>CGTN</display-name>
    <icon src="https://i.imgur.com/VkjcSgZ.png"/>
  </channel>
  <channel id="France24.fr">
    <display-name>France 24</display-name>
    <icon src="https://i.imgur.com/wp4ExBr.png"/>
  </channel>

  <!-- Vevo Pop programs -->
  <programme start="${fmt(minus6h)}" stop="${fmt(minus3h)}" channel="VevoPop.us@SD">
    <title lang="en">Top Hits Countdown</title>
    <desc lang="en">The biggest pop hits of the week.</desc>
    <category lang="en">Music</category>
  </programme>
  <programme start="${fmt(minus3h)}" stop="${fmt(minus1h)}" channel="VevoPop.us@SD">
    <title lang="en">New Releases</title>
    <desc lang="en">Fresh music videos from this week.</desc>
    <category lang="en">Music</category>
  </programme>
  <programme start="${fmt(minus1h)}" stop="${fmt(plus1h)}" channel="VevoPop.us@SD">
    <title lang="en">Pop Essentials</title>
    <desc lang="en">The essential pop music playlist — currently airing.</desc>
    <category lang="en">Music</category>
  </programme>
  <programme start="${fmt(plus1h)}" stop="${fmt(plus3h)}" channel="VevoPop.us@SD">
    <title lang="en">Artist Spotlight</title>
    <desc lang="en">Deep dive into a featured artist's catalog.</desc>
    <category lang="en">Music</category>
  </programme>
  <programme start="${fmt(plus3h)}" stop="${fmt(plus6h)}" channel="VevoPop.us@SD">
    <title lang="en">Late Night Vibes</title>
    <desc lang="en">Chill pop tracks for the evening.</desc>
    <category lang="en">Music</category>
  </programme>

  <!-- CGTN programs -->
  <programme start="${fmt(minus3h)}" stop="${fmt(minus1h)}" channel="CGTN.cn">
    <title lang="en">Global Watch</title>
    <desc lang="en">International news coverage.</desc>
    <category lang="en">News</category>
  </programme>
  <programme start="${fmt(minus1h)}" stop="${fmt(plus1h)}" channel="CGTN.cn">
    <title lang="en">World Insight</title>
    <desc lang="en">In-depth analysis of global events.</desc>
    <category lang="en">News</category>
  </programme>
  <programme start="${fmt(plus1h)}" stop="${fmt(plus6h)}" channel="CGTN.cn">
    <title lang="en">Asia Today</title>
    <desc lang="en">News from across the Asian continent.</desc>
    <category lang="en">News</category>
  </programme>

  <!-- France 24 programs -->
  <programme start="${fmt(minus1h)}" stop="${fmt(plus1h)}" channel="France24.fr">
    <title lang="en">France 24 Live</title>
    <desc lang="en">Live international news coverage.</desc>
    <category lang="en">News</category>
  </programme>
  <programme start="${fmt(plus1h)}" stop="${fmt(plus3h)}" channel="France24.fr">
    <title lang="en">The Debate</title>
    <desc lang="en">Panel discussion on current affairs.</desc>
    <category lang="en">News</category>
  </programme>
</tv>''';
  }

  /// XMLTV date format: YYYYMMDDHHMMSS +0000
  static String Function(DateTime) get _xmltvDateFormat => (DateTime dt) {
        final utc = dt.toUtc();
        final y = utc.year.toString().padLeft(4, '0');
        final m = utc.month.toString().padLeft(2, '0');
        final d = utc.day.toString().padLeft(2, '0');
        final h = utc.hour.toString().padLeft(2, '0');
        final min = utc.minute.toString().padLeft(2, '0');
        final s = utc.second.toString().padLeft(2, '0');
        return '$y$m$d$h$min$s +0000';
      };
}

/// Path to the full iptv-org index.m3u for stress testing.
///
/// This file contains 25,000+ channels and is used to test:
/// - Large playlist parse performance (isolate offload)
/// - Memory budget enforcement under load
/// - Channel grid scroll performance with many items
const String kLargePlaylistFixturePath =
    'iptv-data/fixtures/iptv-org/index.m3u';

/// Utility to write test fixtures to temporary device storage.
///
/// Returns the path to the written file, suitable for passing to the
/// playlist import UI.
class PlaylistFixtureWriter {
  PlaylistFixtureWriter._();

  /// Write the small 10-channel M3U to a temp file and return its path.
  static Future<String> writeSmallPlaylist() async {
    final dir = await Directory.systemTemp.createTemp('airo_tv_test_');
    final file = File('${dir.path}/test_playlist.m3u');
    await file.writeAsString(SmallPlaylistFixture.m3uContent);
    return file.path;
  }

  /// Write the broken stream fixture to a temp file.
  static Future<String> writeBrokenStreams() async {
    final dir = await Directory.systemTemp.createTemp('airo_tv_test_');
    final file = File('${dir.path}/broken_streams.m3u');
    await file.writeAsString(BrokenStreamFixture.m3uContent);
    return file.path;
  }

  /// Write the EPG fixture to a temp file.
  static Future<String> writeEpgFixture({DateTime? now}) async {
    final dir = await Directory.systemTemp.createTemp('airo_tv_test_');
    final file = File('${dir.path}/test_epg.xml');
    await file.writeAsString(EpgFixture.generateXmltvContent(now: now));
    return file.path;
  }

  /// Clean up all temp fixture files.
  static Future<void> cleanup() async {
    final tempDir = Directory.systemTemp;
    await for (final entity in tempDir.list()) {
      if (entity is Directory && entity.path.contains('airo_tv_test_')) {
        await entity.delete(recursive: true);
      }
    }
  }
}

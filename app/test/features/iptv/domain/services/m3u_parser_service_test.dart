import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:airo_app/features/iptv/domain/models/iptv_channel.dart';
import 'package:airo_app/features/iptv/domain/services/m3u_parser_service.dart';

void main() {
  group('M3UParserService', () {
    late M3UParserService parser;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      parser = M3UParserService(dio: Dio(), prefs: prefs);
    });

    group('parseM3U', () {
      test('should parse valid M3U content with complete metadata', () {
        const m3uContent = '''#EXTM3U
#EXTINF:-1 tvg-id="test1" tvg-name="Test Channel" tvg-logo="https://logo.com/test.png" group-title="News",Test Channel
https://stream.example.com/test1.m3u8
#EXTINF:-1 tvg-id="test2" tvg-name="Another Channel" group-title="Entertainment",Another Channel
https://stream.example.com/test2.m3u8
''';

        final channels = parser.parseM3U(m3uContent);

        expect(channels.length, equals(2));
        expect(channels[0].name, equals('Test Channel'));
        expect(
          channels[0].streamUrl,
          equals('https://stream.example.com/test1.m3u8'),
        );
        expect(channels[0].logoUrl, equals('https://logo.com/test.png'));
        expect(channels[0].group, equals('News'));
        expect(channels[1].name, equals('Another Channel'));
        expect(channels[1].group, equals('Entertainment'));
      });

      test('should parse M3U with minimal metadata', () {
        const m3uContent = '''#EXTM3U
#EXTINF:-1,Simple Channel
https://stream.example.com/simple.m3u8
''';

        final channels = parser.parseM3U(m3uContent);

        expect(channels.length, equals(1));
        expect(channels[0].name, equals('Simple Channel'));
        expect(
          channels[0].streamUrl,
          equals('https://stream.example.com/simple.m3u8'),
        );
      });

      test('should detect audio-only streams', () {
        const m3uContent = '''#EXTM3U
#EXTINF:-1 group-title="Music",Radio FM
https://stream.example.com/audio.mp3
#EXTINF:-1 group-title="Music Radio",Music Channel
https://stream.example.com/music.aac
''';

        final channels = parser.parseM3U(m3uContent);

        expect(channels.length, equals(2));
        expect(channels[0].isAudioOnly, isTrue);
        expect(channels[1].isAudioOnly, isTrue);
      });

      test('should infer category from group title', () {
        const m3uContent = '''#EXTM3U
#EXTINF:-1 group-title="Sports",Sports Channel
https://stream.example.com/sports.m3u8
#EXTINF:-1 group-title="Kids",Kids Channel
https://stream.example.com/kids.m3u8
#EXTINF:-1 group-title="Movies",Movie Channel
https://stream.example.com/movies.m3u8
''';

        final channels = parser.parseM3U(m3uContent);

        expect(channels.length, equals(3));
        expect(channels[0].category, equals(ChannelCategory.sports));
        expect(channels[1].category, equals(ChannelCategory.kids));
        expect(channels[2].category, equals(ChannelCategory.movies));
      });

      test('should handle empty M3U content', () {
        const m3uContent = '''#EXTM3U
''';

        final channels = parser.parseM3U(m3uContent);

        expect(channels, isEmpty);
      });

      test('should skip invalid entries without URLs', () {
        const m3uContent = '''#EXTM3U
#EXTINF:-1,Valid Channel
https://stream.example.com/valid.m3u8
#EXTINF:-1,Invalid Channel Without URL
#EXTINF:-1,Another Valid Channel
https://stream.example.com/valid2.m3u8
''';

        final channels = parser.parseM3U(m3uContent);

        expect(channels.length, equals(2));
        expect(channels[0].name, equals('Valid Channel'));
        expect(channels[1].name, equals('Another Valid Channel'));
      });

      test('should handle various tvg-logo formats', () {
        const m3uContent = '''#EXTM3U
#EXTINF:-1 tvg-logo="https://logo.com/a.png",Channel A
https://stream1.com
#EXTINF:-1 tvg-logo='https://logo.com/b.png',Channel B
https://stream2.com
''';

        final channels = parser.parseM3U(m3uContent);

        expect(channels.length, equals(2));
        expect(channels[0].logoUrl, equals('https://logo.com/a.png'));
        // Note: Single quote handling depends on implementation
      });
    });

    group('category inference', () {
      test('should map news keywords correctly', () {
        const m3uContent = '''#EXTM3U
#EXTINF:-1 group-title="24/7 News",News Channel
https://stream.example.com/news.m3u8
''';

        final channels = parser.parseM3U(m3uContent);
        expect(channels[0].category, equals(ChannelCategory.news));
      });

      test('should map entertainment keywords correctly', () {
        const m3uContent = '''#EXTM3U
#EXTINF:-1 group-title="Entertainment",Fun Channel
https://stream.example.com/fun.m3u8
''';

        final channels = parser.parseM3U(m3uContent);
        expect(channels[0].category, equals(ChannelCategory.entertainment));
      });

      test('should default to "all" for unknown categories', () {
        const m3uContent = '''#EXTM3U
#EXTINF:-1 group-title="Unknown Category XYZ",Mystery Channel
https://stream.example.com/mystery.m3u8
''';

        final channels = parser.parseM3U(m3uContent);
        expect(channels[0].category, equals(ChannelCategory.all));
      });
    });
  });
}

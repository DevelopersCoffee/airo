import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AiroPlaylistUrlPolicy', () {
    test('accepts public http and https media URLs', () {
      expect(
        AiroPlaylistUrlPolicy.normalizeStreamUrl(
          ' https://cdn.example.com/live.m3u8 ',
        ),
        Uri.parse('https://cdn.example.com/live.m3u8'),
      );
      expect(
        AiroPlaylistUrlPolicy.normalizeLogoUrl(
          'http://images.example.com/logo.png',
        ),
        Uri.parse('http://images.example.com/logo.png'),
      );
    });

    test('rejects unsafe schemes, credentials, and private hosts', () {
      expect(
        AiroPlaylistUrlPolicy.normalizeStreamUrl('file:///etc/passwd'),
        isNull,
      );
      expect(
        AiroPlaylistUrlPolicy.normalizeStreamUrl('javascript:alert(1)'),
        isNull,
      );
      expect(
        AiroPlaylistUrlPolicy.normalizeStreamUrl(
          'https://user:pass@example.com/live.m3u8',
        ),
        isNull,
      );
      expect(
        AiroPlaylistUrlPolicy.normalizeStreamUrl(
          'http://192.168.1.10/live.m3u8',
        ),
        isNull,
      );
      expect(
        AiroPlaylistUrlPolicy.normalizeStreamUrl(
          'http://192.168.1.10/live.m3u8',
          allowPrivateHosts: true,
        ),
        Uri.parse('http://192.168.1.10/live.m3u8'),
      );
      expect(
        AiroPlaylistUrlPolicy.normalizeStreamUrl(
          'https://fdn.example/live.m3u8',
        ),
        Uri.parse('https://fdn.example/live.m3u8'),
      );
      expect(
        AiroPlaylistUrlPolicy.normalizeStreamUrl('http://[fd00::1]/live.m3u8'),
        isNull,
      );
    });
  });

  group('ChannelDataService', () {
    test('returns no first-party channels for Play Store V2', () async {
      SharedPreferences.setMockInitialValues({
        'iptv_channels_cache':
            '{"channels":[{"id":"1","name":"Bundled","streamUrl":"https://example.com/live.m3u8"}]}',
        'iptv_channels_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final prefs = await SharedPreferences.getInstance();
      final service = ChannelDataService(dio: Dio(), prefs: prefs);

      await expectLater(service.fetchChannels(), completion(isEmpty));
    });
  });
}

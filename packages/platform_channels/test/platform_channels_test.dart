import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:platform_channels/platform_channels.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('adds one to input values', () {
    final calculator = Calculator();
    expect(calculator.addOne(2), 3);
    expect(calculator.addOne(-7), -6);
    expect(calculator.addOne(0), 1);
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

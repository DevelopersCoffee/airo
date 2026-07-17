import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('redactedUriForLog', () {
    test('never includes the URL path, so phone-media session tokens '
        'cannot reach logs', () {
      final summary = redactedUriForLog(
        Uri.parse('http://192.168.1.5:8080/m/secret-session-token/media'),
      );
      expect(summary, 'http://192.168.1.5:8080');
      expect(summary, isNot(contains('secret-session-token')));
    });

    test('never includes query parameters', () {
      final summary = redactedUriForLog(
        Uri.parse('http://10.0.0.2:9090/proxy?url=x&token=proxy-token'),
      );
      expect(summary, isNot(contains('proxy-token')));
      expect(summary, isNot(contains('?')));
    });

    test('omits the port suffix when the URL has none', () {
      expect(
        redactedUriForLog(Uri.parse('https://example.com/channel.m3u8')),
        'https://example.com',
      );
    });

    test('renders null as none', () {
      expect(redactedUriForLog(null), 'none');
    });
  });
}

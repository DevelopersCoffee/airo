import 'package:airo_app/core/cast/cast.dart';
import 'package:airo_app/core/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Cast media request logging does not expose query tokens', () {
    final request = AiroCastMediaRequest(
      url: Uri.parse('https://example.com/live.m3u8?token=secret'),
      contentType: 'application/x-mpegURL',
      title: 'Private Channel',
    );

    AppLogger.clearBuffer();
    AppLogger.info('Casting ${request.title}', tag: 'CAST');
    final logs = AppLogger.getRecentLogsAsString();

    expect(logs, contains('Private Channel'));
    expect(logs, isNot(contains('token=secret')));
    expect(logs, isNot(contains(request.url.toString())));
  });
}

import 'package:airo_notifications/airo_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const normalizer = NotificationRouteNormalizer();

  test('normalizes raw path strings cleanly', () {
    expect(normalizer.normalizePayload('/iptv?channel=ch1'), '/iptv?channel=ch1');
  });

  test('maps legacy routes to current screens', () {
    expect(normalizer.normalizePayload('/live_tv'), '/iptv');
    expect(normalizer.normalizePayload('/assistant'), '/mind');
    expect(normalizer.normalizePayload('/finance'), '/coins');
  });

  test('parses JSON payloads with deep_link attribute', () {
    const json = '{"deep_link": "/mind/chat", "category": "agent"}';
    expect(normalizer.normalizePayload(json), '/mind/chat');
  });

  test('falls back to /notifications for null or invalid payloads', () {
    expect(normalizer.normalizePayload(null), '/notifications');
    expect(normalizer.normalizePayload(''), '/notifications');
    expect(normalizer.normalizePayload('not_valid_json'), '/notifications');
  });
}

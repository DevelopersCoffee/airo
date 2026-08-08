import 'package:feature_mind/src/agent_chat/data/services/agent_notification_scheduler.dart';
import 'package:feature_mind/src/agent_chat/data/services/notification_navigation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeFromNotificationPayload', () {
    test('returns deep link from payload json when present', () {
      final route = routeFromNotificationPayload(
        '{"category":"downloads","deep_link":"/assistant/notifications?category=downloads"}',
      );

      expect(route, '/assistant/notifications?category=downloads');
    });

    test('routes raw app paths directly', () {
      final route = routeFromNotificationPayload('/iptv?channel=channel-1');

      expect(route, '/iptv?channel=channel-1');
    });

    test('falls back to category route when no explicit deep link exists', () {
      final route = routeFromNotificationPayload(
        '{"category":"recording","notification_id":42}',
      );

      expect(route, '/assistant/notifications?category=recording');
    });

    test('falls back to notifications index on malformed payload', () {
      final route = routeFromNotificationPayload('not-json');

      expect(route, '/assistant/notifications');
    });
  });

  test('bind navigates for launch payload and live responses', () async {
    final scheduler = _FakeNotificationRuntimeService(
      launchPayload:
          '{"deep_link":"/assistant/notifications?category=downloads"}',
    );
    final routes = <String>[];
    final service = NotificationNavigationService(scheduler: scheduler);

    await service.bind(navigate: routes.add);
    scheduler.emit(
      '{"category":"recording","deep_link":"/assistant/notifications?category=recording"}',
    );

    expect(routes, [
      '/assistant/notifications?category=downloads',
      '/assistant/notifications?category=recording',
    ]);
  });

  test('a deep link written before the /mind split is migrated', () {
    // A notification scheduled by an older build fires against this one. It
    // must land somewhere real, not on the route milestone 22 took over.
    expect(
      routeFromNotificationPayload(
        '{"deep_link":"/mind/notifications?category=downloads"}',
      ),
      '/assistant/notifications?category=downloads',
    );
    expect(routeFromNotificationPayload('/mind'), '/assistant');
    expect(routeFromNotificationPayload('/mind/chat'), '/assistant/chat');
  });

  test('migration does not touch a route that merely starts with mind', () {
    expect(
      routeFromNotificationPayload('/mindfulness/today'),
      '/mindfulness/today',
    );
  });
}

final class _FakeNotificationRuntimeService
    implements AgentNotificationRuntimeService {
  _FakeNotificationRuntimeService({this.launchPayload});

  final String? launchPayload;
  void Function(String payload)? _onNotificationPayload;

  @override
  Future<String?> getLaunchPayload() async => launchPayload;

  @override
  Future<void> initialize({
    void Function(String payload)? onNotificationPayload,
  }) async {
    _onNotificationPayload = onNotificationPayload;
  }

  void emit(String payload) {
    _onNotificationPayload?.call(payload);
  }
}

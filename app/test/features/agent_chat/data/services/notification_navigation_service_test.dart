import 'package:airo_app/features/agent_chat/data/services/agent_notification_scheduler.dart';
import 'package:airo_app/features/agent_chat/data/services/notification_navigation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeFromNotificationPayload', () {
    test('returns deep link from payload json when present', () {
      final route = routeFromNotificationPayload(
        '{"category":"downloads","deep_link":"/mind/notifications?category=downloads"}',
      );

      expect(route, '/mind/notifications?category=downloads');
    });

    test('falls back to category route when no explicit deep link exists', () {
      final route = routeFromNotificationPayload(
        '{"category":"recording","notification_id":42}',
      );

      expect(route, '/mind/notifications?category=recording');
    });

    test('falls back to notifications index on malformed payload', () {
      final route = routeFromNotificationPayload('not-json');

      expect(route, '/mind/notifications');
    });
  });

  test('bind navigates for launch payload and live responses', () async {
    final scheduler = _FakeNotificationRuntimeService(
      launchPayload: '{"deep_link":"/mind/notifications?category=downloads"}',
    );
    final routes = <String>[];
    final service = NotificationNavigationService(scheduler: scheduler);

    await service.bind(navigate: routes.add);
    scheduler.emit(
      '{"category":"recording","deep_link":"/mind/notifications?category=recording"}',
    );

    expect(routes, [
      '/mind/notifications?category=downloads',
      '/mind/notifications?category=recording',
    ]);
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

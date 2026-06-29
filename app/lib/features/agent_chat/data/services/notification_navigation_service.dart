import 'dart:convert';

import 'agent_notification_scheduler.dart';

class NotificationNavigationService {
  NotificationNavigationService({AgentNotificationRuntimeService? scheduler})
    : _scheduler = scheduler ?? LocalAgentNotificationScheduler.instance;

  static final NotificationNavigationService instance =
      NotificationNavigationService();

  final AgentNotificationRuntimeService _scheduler;
  bool _launchPayloadHandled = false;

  Future<void> bind({required void Function(String location) navigate}) async {
    await _scheduler.initialize(
      onNotificationPayload: (payload) {
        final route = routeFromNotificationPayload(payload);
        if (route != null) {
          navigate(route);
        }
      },
    );

    if (_launchPayloadHandled) {
      return;
    }
    _launchPayloadHandled = true;

    final payload = await _scheduler.getLaunchPayload();
    final route = routeFromNotificationPayload(payload);
    if (route != null) {
      navigate(route);
    }
  }
}

String? routeFromNotificationPayload(
  String? payload, {
  String fallbackRoute = '/mind/notifications',
}) {
  if (payload == null || payload.trim().isEmpty) {
    return null;
  }

  final trimmed = payload.trim();
  if (trimmed.startsWith('/')) {
    return trimmed;
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      return fallbackRoute;
    }

    final deepLink = decoded['deep_link'];
    if (deepLink is String && deepLink.trim().startsWith('/')) {
      return deepLink.trim();
    }

    final metadata = decoded['metadata'];
    if (metadata is Map) {
      final metadataDeepLink = metadata['deep_link'];
      if (metadataDeepLink is String &&
          metadataDeepLink.trim().startsWith('/')) {
        return metadataDeepLink.trim();
      }
    }

    final category = decoded['category'];
    if (category is String && category.trim().isNotEmpty) {
      return '$fallbackRoute?category=${Uri.encodeQueryComponent(category)}';
    }

    return fallbackRoute;
  } catch (_) {
    return fallbackRoute;
  }
}

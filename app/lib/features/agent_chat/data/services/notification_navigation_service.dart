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
  String fallbackRoute = '/assistant/notifications',
}) {
  if (payload == null || payload.trim().isEmpty) {
    return null;
  }

  final trimmed = payload.trim();
  if (trimmed.startsWith('/')) {
    return _migrateLegacyMindRoute(trimmed);
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      return fallbackRoute;
    }

    final deepLink = decoded['deep_link'];
    if (deepLink is String && deepLink.trim().startsWith('/')) {
      return _migrateLegacyMindRoute(deepLink.trim());
    }

    final metadata = decoded['metadata'];
    if (metadata is Map) {
      final metadataDeepLink = metadata['deep_link'];
      if (metadataDeepLink is String &&
          metadataDeepLink.trim().startsWith('/')) {
        return _migrateLegacyMindRoute(metadataDeepLink.trim());
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

/// Rewrites a deep link written before the assistant hub left `/mind`.
///
/// Notifications live in the OS, not in this process: one scheduled by an
/// older build fires against this one and would otherwise open a route that no
/// longer exists. Migrating here rather than with a router redirect keeps the
/// old path out of the route table, so milestone 22's Mind can claim it.
///
/// Delete once no device can still be holding a pre-split notification.
String _migrateLegacyMindRoute(String route) {
  const legacy = '/mind'; // mind-name-exempt: migration, not a live route.
  if (route == legacy) return '/assistant';
  if (route.startsWith('$legacy/')) {
    return '/assistant${route.substring(legacy.length)}';
  }
  return route;
}

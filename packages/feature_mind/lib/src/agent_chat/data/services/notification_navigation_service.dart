import 'dart:convert';

import '../../../routing/assistant_route_names.dart';
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

/// [fallbackRoute] defaults to the hub's notifications index — read off
/// [AssistantRouteNames], not written out: Phase 3 moved the hub's root and a
/// literal here would have kept sending every payload this function cannot
/// parse to a path no shell mounts.
String? routeFromNotificationPayload(
  String? payload, {
  String fallbackRoute = AssistantRouteNames.notifications,
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

/// Rewrites a deep link written before the hub moved to `/mind`.
///
/// This mapping ran the other way until Phase 3 of the SSOT plan: the hub had
/// been evicted from `/mind` so milestone 22 could claim the name, and this
/// function forwarded `/mind` -> `/assistant`. Mind is now the owner, so the
/// arrow points back the way it originally did.
///
/// Notifications live in the OS, not in this process: one scheduled by an older
/// build fires against this one and would otherwise open a route that no longer
/// exists. Migrating here rather than only with a router redirect means a
/// payload is normalised before it ever reaches the route table.
///
/// Delete once no device can still be holding a pre-Phase-3 notification.
String _migrateLegacyMindRoute(String route) {
  const legacy = '/assistant';
  if (route == legacy) return AssistantRouteNames.assistant;
  if (route.startsWith('$legacy/')) {
    return '${AssistantRouteNames.assistant}'
        '${route.substring(legacy.length)}';
  }
  return route;
}

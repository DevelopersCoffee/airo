import 'dart:convert';

class NotificationRouteNormalizer {
  const NotificationRouteNormalizer();

  static const String fallbackHubRoute = '/notifications';

  String normalizePayload(String? rawPayload) {
    if (rawPayload == null || rawPayload.trim().isEmpty) {
      return fallbackHubRoute;
    }

    final trimmed = rawPayload.trim();

    // Directly a URI path (e.g. "/iptv?channel=123" or "/mind/tasks")
    if (trimmed.startsWith('/')) {
      return _normalizePath(trimmed);
    }

    // Try parsing as JSON object payload
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        if (decoded['deep_link'] is String && (decoded['deep_link'] as String).trim().isNotEmpty) {
          return _normalizePath((decoded['deep_link'] as String).trim());
        }
        if (decoded['route'] is String && (decoded['route'] as String).trim().isNotEmpty) {
          return _normalizePath((decoded['route'] as String).trim());
        }
        if (decoded['category'] is String) {
          return _routeForCategory((decoded['category'] as String).trim());
        }
      }
    } catch (_) {
      // Not valid JSON
    }

    return fallbackHubRoute;
  }

  String _normalizePath(String path) {
    final uri = Uri.tryParse(path);
    if (uri == null) return fallbackHubRoute;

    // Handle legacy route renames cleanly at read time
    final normalizedPath = switch (uri.path) {
      '/live_tv' => '/iptv',
      '/guide' => '/iptv',
      '/assistant' => '/mind',
      '/agent' => '/mind',
      '/finance' => '/coins',
      String p when p.startsWith('/') => p,
      _ => '/$path',
    };

    return Uri(path: normalizedPath, queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters).toString();
  }

  String _routeForCategory(String category) {
    return switch (category) {
      'iptv' || 'epg_reminders' || 'epg' => '/iptv',
      'agent' || 'mind' || 'chat' => '/mind',
      'coins' || 'finance' => '/coins',
      'games' || 'arena' => '/games',
      _ => fallbackHubRoute,
    };
  }
}

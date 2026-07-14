import 'dart:async';

import 'package:core_analytics/core_analytics.dart';
import 'package:flutter/foundation.dart';

class AppLogger {
  static AiroAnalyticsService _analyticsService =
      const AiroNoOpAnalyticsService();

  static void setAnalyticsService(AiroAnalyticsService service) {
    _analyticsService = service;
  }

  static void info(String message, {String? tag}) {
    debugPrint(_format(message, tag));
  }

  static void analytics(String event, {Map<String, Object?>? params}) {
    final analyticsEvent = AiroAnalyticsEvent(
      name: event,
      owner: 'platform_media',
      purpose: AiroAnalyticsPurpose.playbackQuality,
      params: params ?? const {},
    );
    final validation = validateEvent(
      analyticsEvent,
      consent: const AiroAnalyticsConsentState.allEnabled(),
    );

    if (!validation.accepted) {
      final reasons = validation.violations
          .map((violation) => '${violation.field}:${violation.code.stableId}')
          .join(',');
      debugPrint(_format('rejected:$event [$reasons]', 'analytics'));
      return;
    }

    debugPrint(_format('$event ${analyticsEvent.params}', 'analytics'));
    unawaited(_analyticsService.track(analyticsEvent));
  }

  static String _format(String message, String? tag) {
    return tag == null ? message : '[$tag] $message';
  }
}

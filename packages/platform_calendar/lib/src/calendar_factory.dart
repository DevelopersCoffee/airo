import 'package:flutter/foundation.dart';

import 'calendar_service.dart';
import 'method_channel_calendar_service.dart';
import 'unsupported_calendar_service.dart';

/// Selects the calendar adapter for the current host.
CalendarService createCalendarService() {
  if (kIsWeb) {
    return const UnsupportedCalendarService(adapterName: 'web');
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => MethodChannelCalendarService(
      adapterName: 'android',
    ),
    TargetPlatform.iOS => MethodChannelCalendarService(adapterName: 'ios'),
    TargetPlatform.macOS => MethodChannelCalendarService(adapterName: 'macos'),
    TargetPlatform.windows => const UnsupportedCalendarService(
      adapterName: 'windows',
    ),
    TargetPlatform.linux => const UnsupportedCalendarService(
      adapterName: 'linux',
    ),
    _ => const UnsupportedCalendarService(),
  };
}

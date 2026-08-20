import 'package:flutter/foundation.dart';

/// Privacy-safe calendar diagnostics. Never logs titles, attendees, locations,
/// or descriptions.
void logCalendarDiagnostic({
  required String operation,
  int eventCount = 0,
  int durationMs = 0,
  String? adapter,
}) {
  debugPrint(
    'calendar tool invoked operation=$operation '
    'event_count=$eventCount duration=${durationMs}ms'
    '${adapter == null ? '' : ' adapter=$adapter'}',
  );
}

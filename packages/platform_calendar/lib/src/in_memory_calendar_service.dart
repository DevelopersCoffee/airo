import 'calendar_diagnostics.dart';
import 'calendar_models.dart';
import 'calendar_service.dart';

/// Test double. Never talks to a device calendar.
class InMemoryCalendarService implements CalendarService {
  InMemoryCalendarService({
    this.adapterName = 'in_memory',
    CalendarPermissionStatus permission = CalendarPermissionStatus.granted,
    List<CalendarAccount>? calendars,
    List<CalendarEvent>? events,
  }) : permission = CalendarPermission(
         status: permission,
         canRequest: permission == CalendarPermissionStatus.notDetermined,
         adapter: adapterName,
       ),
       calendars = calendars ?? const [],
       events = events ?? const [];

  @override
  final String adapterName;

  CalendarPermission permission;
  List<CalendarAccount> calendars;
  List<CalendarEvent> events;
  bool settingsOpened = false;
  bool calendarAppOpened = false;
  int requestCount = 0;

  void _requireGranted() {
    if (permission.status == CalendarPermissionStatus.unsupported) {
      throw CalendarException(
        code: CalendarFailureCode.platformUnsupported,
        message: "Calendar access isn't supported on this device yet.",
      );
    }
    if (permission.status == CalendarPermissionStatus.notDetermined) {
      throw const CalendarException(
        code: CalendarFailureCode.permissionRequired,
        message: 'Airo needs calendar access to read your events.',
      );
    }
    if (!permission.isGranted) {
      throw const CalendarException(
        code: CalendarFailureCode.permissionDenied,
        message:
            'Calendar access is disabled. Enable it in system settings to let Airo read your calendar.',
      );
    }
  }

  @override
  Future<CalendarPermission> permissionStatus() async => permission;

  @override
  Future<CalendarPermission> requestPermission() async {
    requestCount += 1;
    if (permission.status == CalendarPermissionStatus.notDetermined ||
        permission.canRequest) {
      permission = CalendarPermission(
        status: CalendarPermissionStatus.granted,
        adapter: adapterName,
      );
    }
    return permission;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return true;
  }

  @override
  Future<bool> openCalendarApp() async {
    calendarAppOpened = true;
    return true;
  }

  @override
  Future<List<CalendarAccount>> listCalendars() async {
    _requireGranted();
    return List.unmodifiable(calendars);
  }

  @override
  Future<List<CalendarEvent>> getEvents(CalendarQuery query) async {
    query.validate();
    _requireGranted();
    final stopwatch = Stopwatch()..start();
    final matched = events.where((event) {
      if (event.end.isBefore(query.start) || !event.start.isBefore(query.end)) {
        return false;
      }
      if (query.calendarIds != null && query.calendarIds!.isNotEmpty) {
        if (!query.calendarIds!.contains(event.calendarId)) return false;
      }
      final search = query.searchText?.trim().toLowerCase();
      if (search != null && search.isNotEmpty) {
        final haystack = [
          event.title,
          event.location ?? '',
          event.description ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(search)) return false;
      }
      return true;
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
    final limited = matched.take(query.maxResults).toList();
    stopwatch.stop();
    logCalendarDiagnostic(
      operation: 'getEvents',
      eventCount: limited.length,
      durationMs: stopwatch.elapsedMilliseconds,
      adapter: adapterName,
    );
    return limited;
  }

  @override
  Future<List<CalendarEvent>> getEventsForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return getEvents(
      CalendarQuery(start: start, end: start.add(const Duration(days: 1))),
    );
  }

  @override
  Future<CalendarEvent?> getEvent(String id) async {
    _requireGranted();
    try {
      return events.firstWhere((event) => event.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<List<CalendarEvent>> searchEvents(String query) {
    final now = DateTime.now();
    return getEvents(
      CalendarQuery(
        start: now.subtract(const Duration(days: 1)),
        end: now.add(const Duration(days: 30)),
        searchText: query,
      ),
    );
  }

  @override
  Future<CalendarEvent?> getNextEvent({DateTime? from}) async {
    final origin = from ?? DateTime.now();
    final upcoming = await getEvents(
      CalendarQuery(start: origin, end: origin.add(const Duration(days: 7))),
    );
    for (final event in upcoming) {
      if (event.start.isAfter(origin) || event.start.isAtSameMomentAs(origin)) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<FreeBusyResult> getFreeBusy(CalendarDateTimeRange range) async {
    final eventsInRange = await getEvents(
      CalendarQuery(start: range.start, end: range.end),
    );
    return buildFreeBusy(range: range, events: eventsInRange);
  }
}

FreeBusyResult buildFreeBusy({
  required CalendarDateTimeRange range,
  required List<CalendarEvent> events,
}) {
  final busy =
      events
          .map(
            (event) => FreeBusySlot(
              start: event.start.isBefore(range.start)
                  ? range.start
                  : event.start,
              end: event.end.isAfter(range.end) ? range.end : event.end,
            ),
          )
          .where((slot) => slot.end.isAfter(slot.start))
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  final free = <FreeBusySlot>[];
  var cursor = range.start;
  for (final slot in busy) {
    if (slot.start.isAfter(cursor)) {
      free.add(FreeBusySlot(start: cursor, end: slot.start));
    }
    if (slot.end.isAfter(cursor)) {
      cursor = slot.end;
    }
  }
  if (cursor.isBefore(range.end)) {
    free.add(FreeBusySlot(start: cursor, end: range.end));
  }
  return FreeBusyResult(range: range, busy: busy, free: free);
}

import 'calendar_models.dart';

/// Platform-independent calendar capability. Agent code talks only to this.
abstract interface class CalendarService {
  String get adapterName;

  Future<CalendarPermission> permissionStatus();

  Future<CalendarPermission> requestPermission();

  Future<bool> openSettings();

  Future<bool> openCalendarApp();

  Future<List<CalendarAccount>> listCalendars();

  Future<List<CalendarEvent>> getEvents(CalendarQuery query);

  Future<List<CalendarEvent>> getEventsForDay(DateTime day);

  Future<CalendarEvent?> getEvent(String id);

  Future<List<CalendarEvent>> searchEvents(String query);

  Future<CalendarEvent?> getNextEvent({DateTime? from});

  Future<FreeBusyResult> getFreeBusy(CalendarDateTimeRange range);
}

import 'calendar_models.dart';
import 'calendar_service.dart';

/// Hosts without a native calendar store. Never returns fake events.
class UnsupportedCalendarService implements CalendarService {
  const UnsupportedCalendarService({this.adapterName = 'unsupported'});

  @override
  final String adapterName;

  Never _unsupported() {
    throw const CalendarException(
      code: CalendarFailureCode.platformUnsupported,
      message: "Calendar access isn't supported on this device yet.",
    );
  }

  @override
  Future<CalendarPermission> permissionStatus() async {
    return CalendarPermission(
      status: CalendarPermissionStatus.unsupported,
      adapter: adapterName,
    );
  }

  @override
  Future<CalendarPermission> requestPermission() async => permissionStatus();

  @override
  Future<bool> openSettings() async => false;

  @override
  Future<bool> openCalendarApp() async => false;

  @override
  Future<List<CalendarAccount>> listCalendars() async => _unsupported();

  @override
  Future<List<CalendarEvent>> getEvents(CalendarQuery query) async =>
      _unsupported();

  @override
  Future<List<CalendarEvent>> getEventsForDay(DateTime day) async =>
      _unsupported();

  @override
  Future<CalendarEvent?> getEvent(String id) async => _unsupported();

  @override
  Future<List<CalendarEvent>> searchEvents(String query) async =>
      _unsupported();

  @override
  Future<CalendarEvent?> getNextEvent({DateTime? from}) async => _unsupported();

  @override
  Future<FreeBusyResult> getFreeBusy(CalendarDateTimeRange range) async =>
      _unsupported();
}

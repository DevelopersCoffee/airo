import 'unsupported_calendar_service.dart';

/// Reserved integration points. Not implemented in this package — native OS
/// calendars already surface Google, Outlook, and iCloud when the user has
/// those accounts in the system Calendar app.
class GoogleCalendarProvider extends UnsupportedCalendarService {
  const GoogleCalendarProvider() : super(adapterName: 'google');
}

class OutlookCalendarProvider extends UnsupportedCalendarService {
  const OutlookCalendarProvider() : super(adapterName: 'outlook');
}

class CalDavProvider extends UnsupportedCalendarService {
  const CalDavProvider() : super(adapterName: 'caldav');
}

class NativeCalendarProvider {
  const NativeCalendarProvider._();
}

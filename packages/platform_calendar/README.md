# platform_calendar

`platform_calendar` is Airo's product-neutral calendar capability. The agent
layer and the Calendar page both talk to `CalendarService`. They never see
Android `CalendarContract` types or EventKit objects.

## Contract

`calendar-service/v1` provides:

- explicit permission status, request, and settings APIs
- listing of OS calendars (Apple Calendar, Google, Outlook, and other accounts
  the operating system already synced)
- range queries for normalized events
- next-event and free/busy helpers
- `PLATFORM_UNSUPPORTED` on hosts without a native calendar store

Calendar data stays on device. Diagnostic logs record only `event_count` and
duration — never titles, attendees, locations, or descriptions.

## Usage

```dart
import 'package:platform_calendar/platform_calendar.dart';

final calendar = createCalendarService();
final permission = await calendar.permissionStatus();
if (permission.status == CalendarPermissionStatus.notDetermined) {
  await calendar.requestPermission();
}
final events = await calendar.getEventsForDay(DateTime.now());
```

Native adapters execute the query. Google Calendar REST, Microsoft Graph, and
CalDAV are reserved provider types, not implemented in this package.

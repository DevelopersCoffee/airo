import EventKit
import FlutterMacOS
import AppKit

public final class PlatformCalendarPlugin: NSObject, FlutterPlugin {
  private static let channelName = "dev.airo.platform_calendar/methods"
  private let eventStore = EKEventStore()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PlatformCalendarPlugin()
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPermissionStatus":
      result(permissionPayload())
    case "requestPermission":
      requestReadAccess { granted in
        result(self.permissionPayload(grantedOverride: granted))
      }
    case "openSettings":
      openSettings(result: result)
    case "openCalendarApp":
      openCalendarApp(result: result)
    case "listCalendars":
      listCalendars(result: result)
    case "getEvents":
      getEvents(arguments: call.arguments as? [String: Any], result: result)
    case "getEvent":
      getEvent(arguments: call.arguments as? [String: Any], result: result)
    case "createCalendarEvent":
      createCalendarEvent(arguments: call.arguments as? [String: Any], result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func permissionPayload(grantedOverride: Bool? = nil) -> [String: Any] {
    let status = EKEventStore.authorizationStatus(for: .event)
    let granted = grantedOverride ?? hasReadAccess(status)
    let wireStatus: String
    if granted {
      wireStatus = "granted"
    } else if status == .notDetermined {
      wireStatus = "notDetermined"
    } else if status == .restricted {
      wireStatus = "restricted"
    } else {
      wireStatus = "denied"
    }
    return [
      "status": wireStatus,
      "granted": granted,
      "can_request": status == .notDetermined,
      "adapter": "macos",
    ]
  }

  private func hasReadAccess(_ status: EKAuthorizationStatus? = nil) -> Bool {
    let current = status ?? EKEventStore.authorizationStatus(for: .event)
    if current == .authorized { return true }
    if #available(macOS 14.0, *) {
      return current == .fullAccess
    }
    return false
  }

  private func requestReadAccess(completion: @escaping (Bool) -> Void) {
    if hasReadAccess() {
      completion(true)
      return
    }
    if #available(macOS 14.0, *) {
      eventStore.requestFullAccessToEvents { granted, _ in
        DispatchQueue.main.async { completion(granted) }
      }
    } else {
      eventStore.requestAccess(to: .event) { granted, _ in
        DispatchQueue.main.async { completion(granted) }
      }
    }
  }

  private func permissionRequired() -> [String: Any] {
    let status = EKEventStore.authorizationStatus(for: .event)
    if status == .notDetermined {
      return [
        "error": "PERMISSION_REQUIRED",
        "message": "Airo needs calendar access to read your events.",
      ]
    }
    return [
      "error": "PERMISSION_DENIED",
      "message": "Calendar access is disabled. Enable it in system settings to let Airo read your calendar.",
    ]
  }

  private func openSettings(result: FlutterResult) {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
      NSWorkspace.shared.open(url)
      result(["opened": true])
      return
    }
    result(["opened": false])
  }

  private func openCalendarApp(result: FlutterResult) {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
      NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
      result(["opened": true])
      return
    }
    result(["opened": false])
  }

  private func listCalendars(result: FlutterResult) {
    guard hasReadAccess() else {
      result(permissionRequired())
      return
    }
    let calendars = eventStore.calendars(for: .event).map { calendar in
      [
        "id": calendar.calendarIdentifier,
        "title": calendar.title,
        "account": calendar.source.title,
        "isPrimary": calendar == eventStore.defaultCalendarForNewEvents,
      ] as [String: Any]
    }
    result(["calendars": calendars, "adapter": "macos"])
  }

  private func getEvents(arguments: [String: Any]?, result: FlutterResult) {
    guard hasReadAccess() else {
      result(permissionRequired())
      return
    }
    guard let arguments,
          let start = parseInstant(arguments["start"] as? String),
          let end = parseInstant(arguments["end"] as? String)
    else {
      result([
        "error": "INVALID_ARGUMENT",
        "message": "Calendar lookup requires start and end timestamps.",
      ])
      return
    }
    guard end >= start else {
      result([
        "error": "INVALID_ARGUMENT",
        "message": "Calendar end must be on or after start.",
      ])
      return
    }
    let maxResults = min(max((arguments["maxResults"] as? Int) ?? 50, 1), 200)
    let calendarIds = arguments["calendarIds"] as? [String]
    let search = (arguments["search"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let calendars: [EKCalendar]?
    if let calendarIds, !calendarIds.isEmpty {
      calendars = eventStore.calendars(for: .event).filter { calendarIds.contains($0.calendarIdentifier) }
    } else {
      calendars = nil
    }
    let startedAt = Date()
    let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
    var events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    if !search.isEmpty {
      let needle = search.lowercased()
      events = events.filter { event in
        let haystack = [
          event.title ?? "",
          event.location ?? "",
          event.notes ?? "",
        ].joined(separator: " ").lowercased()
        return haystack.contains(needle)
      }
    }
    result([
      "events": Array(events.prefix(maxResults)).map(serialize(event:)),
      "adapter": "macos",
      "duration_ms": Int(Date().timeIntervalSince(startedAt) * 1000),
    ])
  }

  private func getEvent(arguments: [String: Any]?, result: FlutterResult) {
    guard hasReadAccess() else {
      result(permissionRequired())
      return
    }
    guard let id = arguments?["id"] as? String, !id.isEmpty else {
      result([
        "error": "INVALID_ARGUMENT",
        "message": "Calendar event id is required.",
      ])
      return
    }
    guard let event = eventStore.event(withIdentifier: id) else {
      result(["event": NSNull()])
      return
    }
    result(["event": serialize(event: event)])
  }

  private func serialize(event: EKEvent) -> [String: Any] {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
    var payload: [String: Any] = [
      "id": event.eventIdentifier ?? "",
      "title": event.title ?? "Untitled event",
      "start": formatter.string(from: event.startDate),
      "end": formatter.string(from: event.endDate),
      "calendar": event.calendar.title,
      "calendarId": event.calendar.calendarIdentifier,
      "isAllDay": event.isAllDay,
      "attendees": event.attendees?.compactMap { $0.name } ?? [],
    ]
    if let timezone = event.timeZone?.identifier {
      payload["timezone"] = timezone
    }
    if let location = event.location, !location.isEmpty {
      payload["location"] = location
    }
    if let notes = event.notes, !notes.isEmpty {
      payload["description"] = notes
    }
    return payload
  }

  private func createCalendarEvent(arguments: [String: Any]?, result: FlutterResult) {
    guard hasReadAccess() else {
      result(permissionRequired())
      return
    }
    guard let arguments else {
      result([
        "error": "invalid_calendar_event",
        "message": "Calendar event arguments are required.",
      ])
      return
    }
    let event = EKEvent(eventStore: eventStore)
    if let start = parseInstant(arguments["start"] as? String),
       let end = parseInstant(arguments["end"] as? String),
       let title = arguments["title"] as? String,
       !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
       end > start {
      event.title = title
      event.startDate = start
      event.endDate = end
      event.notes = arguments["description"] as? String
      event.location = arguments["location"] as? String
    } else if let title = arguments["title"] as? String,
              let date = arguments["date"] as? String,
              let hour = arguments["hour"] as? Int,
              let startDate = dateFrom(date: date, hour: hour, minute: arguments["minute"] as? Int ?? 0) {
      let durationMinutes = max(arguments["duration_minutes"] as? Int ?? 30, 1)
      event.title = title
      event.notes = arguments["message"] as? String
      event.startDate = startDate
      event.endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    } else {
      result([
        "error": "missing_event_details",
        "message": "Calendar event creation requires title, date, and time.",
      ])
      return
    }
    event.calendar = eventStore.defaultCalendarForNewEvents
    do {
      try eventStore.save(event, span: .futureEvents)
      result(["created": true, "event_id": event.eventIdentifier as Any, "title": event.title as Any])
    } catch {
      result(["error": "calendar_insert_failed", "message": error.localizedDescription])
    }
  }

  private func parseInstant(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let parsed = iso.date(from: value) { return parsed }
    iso.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]
    if let parsed = iso.date(from: value) { return parsed }
    iso.formatOptions = [.withInternetDateTime]
    if let parsed = iso.date(from: value) { return parsed }
    let fallback = DateFormatter()
    fallback.locale = Locale(identifier: "en_US_POSIX")
    fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    fallback.isLenient = false
    return fallback.date(from: value)
  }

  private func dateFrom(date: String, hour: Int, minute: Int) -> Date? {
    guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
    let parts = date.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    var components = DateComponents()
    components.year = parts[0]
    components.month = parts[1]
    components.day = parts[2]
    components.hour = hour
    components.minute = minute
    components.second = 0
    components.timeZone = .current
    return Calendar.current.date(from: components)
  }
}
